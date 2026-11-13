#pragma once

#include "PresetDocument9.hpp"
#include "PresetOperations.hpp"
#include <filesystem>

namespace cpm
{
OperationStatus SavePreset(const std::filesystem::path& destination, const document9::Preset& preset,
    const std::optional<std::string>& expectedFingerprint);
}
