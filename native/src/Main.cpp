#include <RED4ext/RED4ext.hpp>
#include "NativeBindings.hpp"

#include <Windows.h>

#include <filesystem>
#include <string>

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle,
    RED4ext::v1::EMainReason reason, const RED4ext::v1::Sdk*)
{
    if (reason == RED4ext::v1::EMainReason::Load)
    {
        try
        {
            std::wstring buffer(32768, L'\0');
            const auto length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
            if (length == 0 || length >= buffer.size()) return false;
            buffer.resize(length);
            const auto executable = std::filesystem::path(buffer);
            const auto x64 = executable.parent_path();
            if (x64.filename() != L"x64" || x64.parent_path().filename() != L"bin") return false;
            const auto manager = x64.parent_path().parent_path() / L"red4ext" / L"plugins" / L"CharacterPresetManager";
            cpm::StartNativeService(manager);
            cpm::RegisterNativeService();
        }
        catch (...) { cpm::StopNativeService(); return false; }
    }
    else if (reason == RED4ext::v1::EMainReason::Unload) cpm::StopNativeService();
    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* info)
{
    info->name = L"Character Preset Manager";
    info->author = L"dnydd (formerly dklyntly)";
    info->version = RED4EXT_V1_SEMVER(3, 1, 4);
    info->runtime = RED4EXT_V1_RUNTIME_VERSION_INDEPENDENT;
    info->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}