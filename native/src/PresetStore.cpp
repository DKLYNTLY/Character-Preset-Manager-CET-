#include "PresetStore.hpp"
#include "PresetRead.hpp"
#include <Windows.h>

namespace cpm
{
PresetStore::PresetStore(std::filesystem::path root, std::size_t capacity)
    : root_(std::filesystem::absolute(root).lexically_normal()), operations_(capacity) {}

std::optional<std::filesystem::path> PresetStore::Resolve(const std::filesystem::path& root, const std::string& relative)
{
    if (relative.empty() || relative.size() > 1024 || relative.front() == '/' || relative.back() == '/'
        || relative.find_first_of("\\<>:\"|?*") != relative.npos || relative.find("//") != relative.npos) return std::nullopt;
    for (const unsigned char c : relative) if (c < 32 || c == 127) return std::nullopt;
    const std::filesystem::path leaf(std::u8string(relative.begin(), relative.end()));
    auto extension = leaf.extension().wstring();
    for (auto& c : extension) if (c >= L'A' && c <= L'Z') c = static_cast<wchar_t>(c - L'A' + L'a');
    if (extension != L".preset") return std::nullopt;
    auto current = root.root_path();
    auto safe = [](const std::filesystem::path& path) {
        const auto attributes = GetFileAttributesW(path.c_str());
        return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_REPARSE_POINT)
            && (attributes & FILE_ATTRIBUTE_DIRECTORY);
    };
    for (const auto& part : root.relative_path())
    {
        current /= part;
        if (!safe(current)) return std::nullopt;
    }
    std::size_t depth = 0;
    for (const auto& part : leaf)
    {
        const auto name = part.wstring();
        if (++depth > 32 || name.empty() || name.size() > 255 || name == L"." || name == L".."
            || name.back() == L'.' || name.back() == L' ') return std::nullopt;
        auto device = name.substr(0, name.find(L'.'));
        for (auto& c : device) if (c >= L'a' && c <= L'z') c = static_cast<wchar_t>(c - L'a' + L'A');
        if (device == L"CON" || device == L"PRN" || device == L"AUX" || device == L"NUL"
            || (device.size() == 4 && (device.starts_with(L"COM") || device.starts_with(L"LPT"))
                && device[3] >= L'1' && device[3] <= L'9')) return std::nullopt;
        current /= part;
        if (current != root / leaf && !safe(current)) return std::nullopt;
    }
    const auto attributes = GetFileAttributesW(current.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY))) return std::nullopt;
    return current;
}

bool PresetStore::Read(std::uint64_t id, std::uint64_t session, std::string relative)
{
    return operations_.Submit(id, session, [root = root_, relative = std::move(relative)](std::stop_token stop) {
        OperationResult result;
        const auto path = Resolve(root, relative);
        if (!path) return result;
        if (stop.stop_requested()) { result.status = OperationStatus::Cancelled; return result; }
        const auto bytes = ReadPresetBytes(*path);
        if (!bytes) return result;
        result.status = OperationStatus::Success;
        result.payload = bytes->contents; result.fingerprint = bytes->fingerprint;
        return result;
    });
}

bool PresetStore::Save(std::uint64_t id, std::uint64_t session, std::string relative,
    document9::Preset preset, std::optional<std::string> expectedFingerprint)
{
    return operations_.Submit(id, session, [root = root_, relative = std::move(relative),
        preset = std::move(preset), expected = std::move(expectedFingerprint)](std::stop_token stop) {
        OperationResult result;
        const auto path = Resolve(root, relative);
        if (!path) return result;
        if (stop.stop_requested()) { result.status = OperationStatus::Cancelled; return result; }
        result.status = SavePreset(*path, preset, expected);
        return result;
    });
}

std::optional<OperationResult> PresetStore::Poll() { return operations_.Poll(); }
void PresetStore::Stop() { operations_.Stop(); }
}
