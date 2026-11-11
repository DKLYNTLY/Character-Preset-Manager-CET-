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

struct Preset
{
    Metadata metadata;
    format9::Preset appearance;
    std::size_t entryCount = 0;
};

std::optional<std::string> Encode(const Preset& preset, std::string_view modName);
std::optional<Preset> Decode(std::string_view text);
bool SameAppearance(const Preset& first, const Preset& second);
}
