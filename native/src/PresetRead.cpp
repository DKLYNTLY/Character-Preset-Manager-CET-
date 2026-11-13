#include "PresetRead.hpp"
#include "PresetFormat9.hpp"
#include <Windows.h>
#include <array>

namespace cpm
{
namespace
{
struct File
{
    HANDLE value = INVALID_HANDLE_VALUE;
    ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
}

std::optional<PresetBytes> ReadPresetBytes(const std::filesystem::path& path)
{
    File file{CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, nullptr)};
    if (file.value == INVALID_HANDLE_VALUE) return std::nullopt;
    BY_HANDLE_FILE_INFORMATION info{};
    if (!GetFileInformationByHandle(file.value, &info)
        || (info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY))
        || info.nFileSizeHigh || info.nFileSizeLow > format9::MaximumBytes) return std::nullopt;
    PresetBytes result;
    result.contents.reserve(info.nFileSizeLow);
    std::array<char, 65536> buffer;
    std::uint64_t first = 0, second = 0;
    while (true)
    {
        DWORD count = 0;
        if (!ReadFile(file.value, buffer.data(), static_cast<DWORD>(buffer.size()), &count, nullptr)) return std::nullopt;
        if (!count) break;
        if (count > format9::MaximumBytes - result.contents.size()) return std::nullopt;
        result.contents.append(buffer.data(), count);
        for (DWORD i = 0; i < count; ++i)
        {
            const auto byte = static_cast<unsigned char>(buffer[i]);
            first = (first * 131 + byte) % 2147483647;
            second = (second * 137 + byte) % 2147483629;
        }
    }
    if (result.contents.size() != info.nFileSizeLow) return std::nullopt;
    result.fingerprint = "2:" + std::to_string(result.contents.size()) + ":" + std::to_string(first) + ":" + std::to_string(second);
    return result;
}
}
