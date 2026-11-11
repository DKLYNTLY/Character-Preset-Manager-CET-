#pragma once

#include "PresetDocument9.hpp"

namespace cpm::legacy
{
inline constexpr std::size_t MaximumLines = 4096 * 4 + 64;

struct Diagnostic
{
    std::string message;
    std::string level = "warn";
};

struct Preset
{
    double format = 4;
    document9::Metadata metadata;
    bool managedByCpm = false;
    bool lazy = false;
    std::size_t entryCount = 0;
    std::vector<document9::LegacyEntry> entries;
    std::optional<std::string> body;
    std::optional<std::string> voice;
    std::optional<format9::Preset> appearance;
};

struct Result
{
    std::optional<Preset> preset;
    std::vector<Diagnostic> diagnostics;
};

Result DecodeText(std::string_view contents, std::string_view path, bool metadataOnly = false);
}
