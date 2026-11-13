#pragma once

#include "LegacyPresetText.hpp"
#include "PresetJson.hpp"

namespace cpm::acu
{
std::optional<legacy::Preset> DecodeJson(const json::Value& decoded, bool metadataOnly = false);
}
