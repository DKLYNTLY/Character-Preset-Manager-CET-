#pragma once

#include <filesystem>
#include <optional>
#include <string>

namespace cpm
{
struct PresetBytes
{
    std::string contents;
    std::string fingerprint;
};

std::optional<PresetBytes> ReadPresetBytes(const std::filesystem::path& path);
}
