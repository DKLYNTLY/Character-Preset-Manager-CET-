#include "PresetSave.hpp"
#include "PresetRead.hpp"
#include <Windows.h>
#include <atomic>

namespace cpm
{
namespace
{
std::atomic<std::uint64_t> sequence = 0;
struct Temporary
{
    std::filesystem::path path;
    HANDLE handle = INVALID_HANDLE_VALUE;
    ~Temporary()
    {
        if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
        if (!path.empty()) DeleteFileW(path.c_str());
    }
};
}

OperationStatus SavePreset(const std::filesystem::path& destination, const document9::Preset& preset,
    const std::optional<std::string>& expectedFingerprint)
{
    const auto contents = document9::Encode(preset, "Character Preset Manager (CET)");
    if (!contents) return OperationStatus::Failure;
    if (expectedFingerprint)
    {
        const auto current = ReadPresetBytes(destination);
        if (!current || current->fingerprint != *expectedFingerprint) return OperationStatus::Conflict;
    }
    else if (GetFileAttributesW(destination.c_str()) != INVALID_FILE_ATTRIBUTES) return OperationStatus::Conflict;
    Temporary temporary;
    temporary.path = destination;
    temporary.path += L".cpm-" + std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(++sequence) + L".tmp";
    temporary.handle = CreateFileW(temporary.path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (temporary.handle == INVALID_HANDLE_VALUE) return OperationStatus::Failure;
    DWORD written = 0;
    if (!WriteFile(temporary.handle, contents->data(), static_cast<DWORD>(contents->size()), &written, nullptr)
        || written != contents->size() || !FlushFileBuffers(temporary.handle)) return OperationStatus::Failure;
    CloseHandle(temporary.handle);
    temporary.handle = INVALID_HANDLE_VALUE;
    if (expectedFingerprint)
    {
        const auto current = ReadPresetBytes(destination);
        if (!current || current->fingerprint != *expectedFingerprint) return OperationStatus::Conflict;
    }
    const DWORD flags = MOVEFILE_WRITE_THROUGH | (expectedFingerprint ? MOVEFILE_REPLACE_EXISTING : 0);
    if (!MoveFileExW(temporary.path.c_str(), destination.c_str(), flags))
    {
        if (!expectedFingerprint && GetFileAttributesW(destination.c_str()) != INVALID_FILE_ATTRIBUTES)
            return OperationStatus::Conflict;
        return OperationStatus::Failure;
    }
    temporary.path.clear();
    return OperationStatus::Success;
}
}
