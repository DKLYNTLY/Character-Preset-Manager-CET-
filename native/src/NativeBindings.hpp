#pragma once

#include <filesystem>

namespace cpm
{
void RegisterNativeService();
void StartNativeService(const std::filesystem::path& manager);
void StopNativeService();
}
