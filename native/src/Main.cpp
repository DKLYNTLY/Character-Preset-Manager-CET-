#include <RED4ext/RED4ext.hpp>
#include "FileService.hpp"

namespace
{
RED4ext::v1::PluginHandle g_handle;
const RED4ext::v1::Sdk* g_sdk = nullptr;

void LogInfo(const std::string& message)
{
    if (g_sdk && g_sdk->logger)
        g_sdk->logger->Info(g_handle, message.c_str());
}

void LogWarning(const std::string& message)
{
    if (g_sdk && g_sdk->logger)
        g_sdk->logger->Warn(g_handle, message.c_str());
}

}

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle handle,
                                        RED4ext::v1::EMainReason reason,
                                        const RED4ext::v1::Sdk* sdk)
{
    try
    {
        if (reason == RED4ext::v1::EMainReason::Load)
        {
            g_handle = handle;
            g_sdk = sdk;
            return cpm::StartFileService(LogInfo, LogWarning);
        }
        if (reason == RED4ext::v1::EMainReason::Unload)
        {
            cpm::StopFileService();
            g_sdk = nullptr;
        }
        return true;
    }
    catch (...)
    {
        return false;
    }
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* info)
{
    info->name = L"Character Preset Manager Native File Service";
    info->author = L"Dnydd";
    info->version = RED4EXT_V1_SEMVER(4, 0, 1);
    info->runtime = RED4EXT_V1_RUNTIME_VERSION_INDEPENDENT;
    info->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
