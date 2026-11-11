#pragma once

#include "PresetFormat9.hpp"

namespace cpm::document9
{
struct Metadata
{
    std::optional<std::string> name;
    std::optional<std::string> source;
    std::optional<std::string> created;
    std::optional<std::string> modified;
    std::string notes;
    std::string tags;
    bool favorite = false;
    std::optional<std::string> libraryFolder;
};

enum class SelectionKind
{
    Appearance,
    Morph,
    Switcher
};

struct Selection
{
    SelectionKind kind;
    std::vector<std::string> names;
};

struct LegacyEntry
{
    std::optional<std::string> key;
    std::optional<std::string> slot;
    std::optional<std::uint32_t> index;
    std::optional<std::string> choice;
    std::optional<Selection> selection;
    bool negativeZero = false;
};

struct Preset
{
    Metadata metadata;
    format9::Preset appearance;
    std::size_t entryCount = 0;
    std::vector<LegacyEntry> entries;
};

std::optional<std::string> Encode(const Preset& preset, std::string_view modName);
std::optional<Preset> Decode(std::string_view text);
bool SameAppearance(const Preset& first, const Preset& second);
std::optional<format9::Preset> FromLegacy(const std::vector<LegacyEntry>& entries,
    std::optional<std::string> body = std::nullopt, std::optional<std::string> voice = std::nullopt);
}
