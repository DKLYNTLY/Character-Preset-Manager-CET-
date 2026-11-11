#include "PresetDocument9.hpp"

#include <algorithm>
#include <array>
#include <charconv>
#include <map>

namespace cpm::document9
{
namespace
{
constexpr std::string_view Header = "# CPM Preset\n# Format: 9\n";
constexpr std::string_view DefaultSource = "Character Preset Manager (CET)";
constexpr std::array<std::string_view, 8> Labels = {
    "Name", "Source", "Created", "Modified", "Notes", "Tags", "Favorite", "Library folder"};
constexpr std::array<std::size_t, 8> Limits = {64, 128, 64, 64, 512, 128, 0, 1024};

bool Control(unsigned char c)
{
    return c < 32 || c == 127;
}

bool Space(unsigned char c)
{
    return c == ' ' || (c >= 9 && c <= 13);
}

bool RelativePath(std::string_view path)
{
    if (path.empty() || path.front() == '/' || path.back() == '/'
        || path.find("//") != path.npos || path.find('\\') != path.npos) return false;
    while (!path.empty())
    {
        const auto end = path.find('/');
        const auto part = path.substr(0, end);
        if (part == "." || part == "..") return false;
        if (end == path.npos) break;
        path.remove_prefix(end + 1);
    }
    return true;
}

bool Name(std::string_view name)
{
    if (name.empty()) return true;
    if (Space(static_cast<unsigned char>(name.front())) || Space(static_cast<unsigned char>(name.back()))
        || name.back() == '.' || name.find_first_of("<>:\"/\\|?*") != name.npos) return false;
    auto end = name.find('.');
    if (end == 0) end = name.npos;
    std::string device(name.substr(0, end));
    for (auto& c : device) if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 'a' + 'A');
    if (device == "CON" || device == "PRN" || device == "AUX" || device == "NUL") return false;
    return !(device.size() == 4 && (device.starts_with("COM") || device.starts_with("LPT"))
        && device[3] >= '1' && device[3] <= '9');
}

std::string Sanitize(std::string value, std::size_t maximum)
{
    for (auto& c : value) if (Control(static_cast<unsigned char>(c))) c = ' ';
    const auto first = value.find_first_not_of(' ');
    if (first == value.npos) return "";
    const auto last = value.find_last_not_of(' ');
    return value.substr(first, std::min(last - first + 1, maximum));
}

format9::Preset Appearance(const Preset& preset)
{
    auto appearance = preset.appearance;
    if (!appearance.body) appearance.body = "Unknown";
    if (!appearance.voice) appearance.voice = "Unknown";
    return appearance;
}
}

std::optional<std::string> Encode(const Preset& preset, std::string_view modName)
{
    auto records = format9::Encode(Appearance(preset));
    if (!records) return std::nullopt;
    const auto& metadata = preset.metadata;
    auto folder = metadata.libraryFolder.value_or("");
    if (!folder.empty() && !RelativePath(folder)) return std::nullopt;
    if (folder.empty()) folder = "/";
    std::array<std::string, 8> values = {metadata.name.value_or(""),
        metadata.source.value_or(std::string(modName)), metadata.created.value_or(""),
        metadata.modified.value_or(""), metadata.notes, metadata.tags, metadata.favorite ? "Yes" : "No", folder};
    std::string output(Header);
    for (std::size_t i = 0; i < Labels.size(); ++i)
    {
        if (i < 6) values[i] = Sanitize(std::move(values[i]), Limits[i]);
        const auto fieldSize = 2 + Labels[i].size() + 2 + values[i].size() + 1;
        if (fieldSize > format9::MaximumBytes - output.size()) return std::nullopt;
        output += "# "; output += Labels[i]; output += ": "; output += values[i]; output += '\n';
    }
    const auto remaining = records->size() - Header.size();
    if (remaining > format9::MaximumBytes - output.size()) return std::nullopt;
    output.append(*records, Header.size(), remaining);
    return output;
}

std::optional<Preset> Decode(std::string_view input)
{
    if (input.size() > format9::MaximumBytes) return std::nullopt;
    std::string normalized;
    normalized.reserve(input.size());
    for (std::size_t i = 0; i < input.size(); ++i)
    {
        if (input[i] == '\r' && i + 1 < input.size() && input[i + 1] == '\n') continue;
        normalized += input[i];
    }
    std::string_view text = normalized;
    if (!text.starts_with(Header)) return std::nullopt;
    text.remove_prefix(Header.size());
    std::array<std::optional<std::string>, 8> values;
    while (!text.empty())
    {
        const auto end = text.find('\n');
        if (end == text.npos) return std::nullopt;
        const auto line = text.substr(0, end);
        const auto colon = line.find(':');
        if (!line.starts_with("# ") || colon == line.npos || colon < 2) break;
        const auto label = line.substr(2, colon - 2);
        const auto found = std::find(Labels.begin(), Labels.end(), label);
        if (found == Labels.end()) break;
        const auto index = static_cast<std::size_t>(found - Labels.begin());
        if (values[index]) return std::nullopt;
        auto value = line.substr(colon + 1);
        if (!value.empty() && Space(static_cast<unsigned char>(value.front()))) value.remove_prefix(1);
        if (index == 6)
        {
            if (value != "Yes" && value != "No") return std::nullopt;
        }
        else if (index == 7)
        {
            if (value == "/") value = "";
            if (!value.empty() && !RelativePath(value)) return std::nullopt;
        }
        else if (value.size() > Limits[index] || std::any_of(value.begin(), value.end(), Control)
            || (index == 0 && !Name(value))) return std::nullopt;
        values[index] = value;
        text.remove_prefix(end + 1);
    }
    auto appearance = format9::Decode(std::string(Header) + std::string(text));
    if (!appearance) return std::nullopt;
    Preset preset;
    for (const auto& row : appearance->entries)
    {
        if (row.state != "Selected" && row.state != "Off") continue;
        LegacyEntry entry;
        entry.key = row.legacyKey.value_or(row.name);
        if (row.slot != "[unavailable]") entry.slot = row.slot;
        std::uint32_t index = 0;
        if (row.value) std::from_chars(row.value->data(), row.value->data() + row.value->size(), index);
        entry.index = index;
        entry.choice = row.legacyChoice;
        if (row.kind == "Appearance") entry.selection = Selection{SelectionKind::Appearance, *row.choices};
        else if (row.kind == "Morph") entry.selection = Selection{SelectionKind::Morph, *row.choices};
        else if (row.kind == "Switcher") entry.selection = Selection{SelectionKind::Switcher, *row.choices};
        preset.entries.push_back(std::move(entry));
    }
    preset.entryCount = preset.entries.size();
    if (!preset.entryCount) return std::nullopt;
    if (!appearance->body) appearance->body = "Unknown";
    if (!appearance->voice) appearance->voice = "Unknown";
    preset.appearance = std::move(*appearance);
    preset.metadata = {values[0], values[1].value_or(std::string(DefaultSource)), values[2], values[3],
        values[4].value_or(""), values[5].value_or(""), values[6] == "Yes", values[7]};
    return preset;
}

bool SameAppearance(const Preset& first, const Preset& second)
{
    const auto encoded = format9::Encode(Appearance(first));
    return encoded && encoded == format9::Encode(Appearance(second));
}

std::optional<format9::Preset> FromLegacy(const std::vector<LegacyEntry>& entries,
    std::optional<std::string> body, std::optional<std::string> voice)
{
    if (entries.empty() || entries.size() > format9::MaximumEntries) return std::nullopt;
    format9::Preset appearance;
    appearance.body = body.value_or("Unknown");
    appearance.voice = voice.value_or("Unknown");
    std::map<std::string, std::uint32_t> counts;
    for (const auto& entry : entries)
    {
        format9::Entry row;
        row.slot = entry.slot.value_or("[unavailable]");
        row.name = "[unavailable]";
        row.occurrence = ++counts[row.slot + "\n" + entry.key.value_or("nil")];
        row.state = "Selected";
        row.legacyKey = entry.key;
        row.legacyChoice = entry.choice;
        row.value = entry.negativeZero && entry.index.value_or(0) == 0 ? "-0" : std::to_string(entry.index.value_or(0));
        row.kind = "Legacy index";
        row.choices = std::vector<std::string>{*row.value};
        if (entry.choice)
        {
            const auto colon = entry.choice->find(':');
            if (colon != entry.choice->npos && colon > 0 && colon + 1 < entry.choice->size())
            {
                const auto field = entry.choice->substr(0, colon);
                const auto value = entry.choice->substr(colon + 1);
                if (field == "definitions") row.kind = "Appearance";
                else if (field == "morphNames") row.kind = "Morph";
                else if (field == "options") row.kind = "Legacy label";
                if (row.kind != "Legacy index") row.choices = std::vector<std::string>{value};
            }
        }
        appearance.entries.push_back(std::move(row));
    }
    if (!format9::Encode(appearance)) return std::nullopt;
    return appearance;
}
}
