#include "FileTransaction.hpp"

#include <Windows.h>

#include <algorithm>
#include <cctype>
#include <cstring>
#include <fstream>
#include <set>
#include <stdexcept>

namespace cpm
{
namespace
{
namespace fs = std::filesystem;
const std::string Directory = "Data/Recovery/Native Transaction";
const std::string Journal = Directory + "/manifest.json";
constexpr std::size_t MaximumFileBytes = 268435456;
constexpr std::size_t MaximumChanges = 32768;

bool TargetPath(const std::string& path)
{
    auto lower = path;
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return path.starts_with("Character Presets/") ||
        (path.starts_with("Data/") && !path.starts_with(Directory) &&
            (lower.ends_with(".txt") || lower.ends_with(".preset") || lower.ends_with(".cpmfolder")));
}

std::string Read(const fs::path& path, std::size_t maximum = MaximumFileBytes)
{
    const auto size = fs::file_size(path);
    if (size > maximum) throw std::runtime_error("A file used for this action is larger than the size limit.");
    std::ifstream file(path, std::ios::binary);
    std::string text(static_cast<std::size_t>(size), '\0');
    if (!file.read(text.data(), static_cast<std::streamsize>(size)))
        throw std::runtime_error("A file used for this action could not be read in full.");
    return text;
}

void WriteNew(const fs::path& path, const std::string& contents)
{
    const auto file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) throw std::runtime_error("A safe working copy could not be created.");
    struct Close { HANDLE handle; ~Close() { CloseHandle(handle); } } close{file};
    DWORD written = 0;
    if (contents.size() > MaximumFileBytes ||
        !WriteFile(file, contents.data(), static_cast<DWORD>(contents.size()), &written, nullptr) ||
        written != contents.size() || !FlushFileBuffers(file))
        throw std::runtime_error("A safe working copy could not be saved completely.");
}

bool Same(const fs::path& first, const fs::path& second)
{
    if (!fs::exists(first) || fs::file_size(first) != fs::file_size(second)) return false;
    std::ifstream left(first, std::ios::binary), right(second, std::ios::binary);
    char a[65536], b[65536];
    while (left && right)
    {
        left.read(a, sizeof(a));
        right.read(b, sizeof(b));
        if (left.gcount() != right.gcount() || std::memcmp(a, b, static_cast<std::size_t>(left.gcount())) != 0) return false;
    }
    return left.eof() && right.eof();
}

bool StageName(const std::string& name)
{
    if (name == "manifest.pending") return true;
    const auto dash = name.find('-');
    if (dash == std::string::npos || (name.substr(0, dash) != "before" && name.substr(0, dash) != "after" && name.substr(0, dash) != "install")) return false;
    return dash + 1 < name.size() && name.size() <= 18 &&
        std::all_of(name.begin() + static_cast<std::ptrdiff_t>(dash + 1), name.end(), [](char c) { return c >= '0' && c <= '9'; });
}
}

FileTransaction::FileTransaction(Resolver resolver) : resolve_(std::move(resolver)) {}

void FileTransaction::CleanStages()
{
    const auto directory = resolve_(Directory);
    if (!fs::exists(directory)) return;
    for (const auto& entry : fs::directory_iterator(directory))
    {
        const auto name = entry.path().filename().string();
        if (StageName(name))
        {
            const auto path = resolve_(Directory + '/' + name);
            if (fs::is_regular_file(path)) fs::remove(path);
        }
    }
}

void FileTransaction::Recover()
{
    const auto journal = resolve_(Journal);
    if (!fs::exists(journal)) { CleanStages(); return; }
    const auto manifest = Json::parse(Read(journal, 2097152));
    Finish(manifest);
}

void FileTransaction::Finish(const Json& manifest)
{
    if (!manifest.is_object() || manifest.value("version", 0) != 1 || !manifest.contains("changes") ||
        !manifest["changes"].is_array() || manifest["changes"].size() > MaximumChanges)
        throw std::runtime_error("The saved recovery information is invalid. No other files were changed during this attempt.");
    std::set<std::string> paths;
    std::size_t index = 0;
    for (const auto& change : manifest["changes"])
    {
        const auto relative = change.at("path").get<std::string>();
        auto identity = relative;
        std::transform(identity.begin(), identity.end(), identity.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        if (!TargetPath(relative) || !paths.insert(identity).second)
            throw std::runtime_error("Saved file recovery information contains an unsafe path.");
        const auto target = resolve_(relative);
        const auto before = resolve_(Directory + "/before-" + std::to_string(index));
        const auto after = resolve_(Directory + "/after-" + std::to_string(index));
        const bool hadBefore = change.at("before").get<bool>();
        const bool hasAfter = change.at("after").get<bool>();
        if ((hadBefore && !fs::is_regular_file(before)) || (hasAfter && !fs::is_regular_file(after)))
            throw std::runtime_error("A recovery copy is missing. No other files were changed during this attempt.");
        const bool alreadyDone = hasAfter ? Same(target, after) : !fs::exists(target);
        if (!alreadyDone && (hadBefore ? !Same(target, before) : fs::exists(target)))
            throw std::runtime_error("A file changed outside Character Preset Manager during recovery. Its contents were kept.");
        ++index;
    }
    index = 0;
    for (const auto& change : manifest["changes"])
    {
        const auto target = resolve_(change.at("path").get<std::string>());
        const auto after = resolve_(Directory + "/after-" + std::to_string(index));
        const auto before = resolve_(Directory + "/before-" + std::to_string(index));
        const bool alreadyDone = change.at("after").get<bool>() ? Same(target, after) : !fs::exists(target);
        if (!alreadyDone && (change.at("before").get<bool>() ? !Same(target, before) : fs::exists(target)))
            throw std::runtime_error("A file changed outside Character Preset Manager during recovery. Its contents were kept.");
        if (change.at("after").get<bool>())
        {
            if (!Same(target, after))
            {
                fs::create_directories(target.parent_path());
                const auto install = resolve_(Directory + "/install-" + std::to_string(index));
                if (fs::exists(install)) fs::remove(install);
                WriteNew(install, Read(after));
                if (!MoveFileExW(install.c_str(), target.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
                    throw std::runtime_error("A file change could not finish. Recovery will try again before the next library change.");
            }
        }
        else if (fs::exists(target) && !fs::remove(target))
            throw std::runtime_error("A file could not be removed. Recovery will retry it before the next library change.");
        ++index;
    }
    fs::remove(resolve_(Journal));
    CleanStages();
}

void FileTransaction::Apply(const std::vector<FileChange>& changes, OperationContext& context)
{
    Recover();
    if (changes.empty()) return;
    if (changes.size() > MaximumChanges) throw std::runtime_error("Too many files were selected for one action.");
    fs::create_directories(resolve_(Directory));
    Json manifest = {{"version", 1}, {"changes", Json::array()}};
    std::set<std::string> paths;
    try
    {
        std::size_t index = 0;
        std::size_t stagedBytes = 0;
        for (const auto& change : changes)
        {
            context.CheckCanceled();
            auto identity = change.path;
            std::transform(identity.begin(), identity.end(), identity.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            if (!TargetPath(change.path) || !paths.insert(identity).second)
                throw std::runtime_error("The file action contains a repeated or unsafe path.");
            const auto target = resolve_(change.path);
            const bool existed = fs::exists(target);
            std::optional<std::string> original;
            if (existed) original = Read(target);
            if (change.checkExpected && original != change.expected)
                throw std::runtime_error("A file changed outside Character Preset Manager. Refresh before trying again.");
            stagedBytes += (original ? original->size() : 0) + (change.contents ? change.contents->size() : 0);
            if (stagedBytes > MaximumFileBytes)
                throw std::runtime_error("The selected files exceed the size limit for one action.");
            if (original) WriteNew(resolve_(Directory + "/before-" + std::to_string(index)), *original);
            if (change.contents) WriteNew(resolve_(Directory + "/after-" + std::to_string(index)), *change.contents);
            manifest["changes"].push_back({{"path", change.path}, {"before", existed}, {"after", change.contents.has_value()}});
            ++index;
            context.Progress(static_cast<std::uint32_t>(index), static_cast<std::uint32_t>(changes.size()));
        }
        const auto serialized = manifest.dump();
        if (serialized.size() > 2097152) throw std::runtime_error("The file action exceeds the recovery limit.");
        WriteNew(resolve_(Directory + "/manifest.pending"), serialized);
        context.Commit([&] {
            if (!MoveFileExW(resolve_(Directory + "/manifest.pending").c_str(), resolve_(Journal).c_str(), MOVEFILE_WRITE_THROUGH))
                throw std::runtime_error("The recovery record could not be saved. No library files were changed.");
            Finish(manifest);
        });
    }
    catch (...)
    {
        if (!fs::exists(resolve_(Journal))) CleanStages();
        throw;
    }
}
}
