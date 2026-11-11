#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace cpm::format9
{
inline constexpr std::size_t MaximumBytes = 1048576;
inline constexpr std::size_t MaximumEntries = 4096;

struct Action
{
    std::uint32_t kind = 0;
    bool immediate = false;
    bool uiSlot = false;
    std::string params;
};

struct Details
{
    std::optional<std::string> localizedName;
    std::vector<std::string> unavailable;
    std::vector<std::string> tags;
    std::vector<Action> actions;
};

struct Entry
{
    std::string slot;
    std::string name;
    std::optional<std::uint32_t> occurrence;
    std::string state;
    std::optional<std::string> kind;
    std::optional<std::vector<std::string>> choices;
    std::optional<bool> active;
    std::optional<bool> editable;
    std::optional<std::string> value;
    std::optional<std::string> sourceKind;
    std::optional<std::string> reason;
    std::optional<std::string> legacyKey;
    std::optional<std::string> legacyChoice;
    std::optional<Details> details;
};

struct Preset
{
    std::vector<Entry> entries;
    std::optional<std::string> body;
    std::optional<std::string> voice;
};

std::optional<std::string> Encode(const Preset& preset);
std::optional<Preset> Decode(std::string_view text);
}
