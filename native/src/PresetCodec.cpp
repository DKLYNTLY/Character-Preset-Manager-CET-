#include "PresetCodec.hpp"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <cctype>
#include <limits>
#include <optional>
#include <regex>
#include <sstream>
#include <stdexcept>

namespace cpm
{
namespace
{
constexpr std::size_t MaximumBytes = 1048576;
constexpr std::size_t MaximumEntries = 4096;
constexpr std::size_t MaximumLines = MaximumEntries * 4 + 64;

std::string Trim(std::string value)
{
    const auto first = value.find_first_not_of(" \r\n\t\f\v");
    if (first == std::string::npos) return {};
    return value.substr(first, value.find_last_not_of(" \r\n\t\f\v") - first + 1);
}

std::string Clean(std::string value, std::size_t maximum)
{
    for (auto& character : value)
        if (static_cast<unsigned char>(character) < 32 || character == 127) character = ' ';
    value = Trim(value);
    if (value.size() > maximum) value.resize(maximum);
    return value;
}

std::string Text(const Json& object, const char* key, const std::string& fallback = {})
{
    const auto entry = object.find(key);
    return entry != object.end() && entry->is_string() ? entry->get<std::string>() : fallback;
}

bool Relative(const std::string& value)
{
    if (value.empty() || value.front() == '/' || value.back() == '/' ||
        value.find_first_of("\\:*?\"<>|") != std::string::npos) return false;
    std::istringstream parts(value);
    std::string part;
    while (std::getline(parts, part, '/'))
        if (part.empty() || part == "." || part == ".." || part.back() == '.' || part.back() == ' ') return false;
    return std::none_of(value.begin(), value.end(), [](unsigned char c) { return c < 32 || c == 127; });
}

std::string Decode(const std::string& input)
{
    std::string result;
    for (std::size_t i = 0; i < input.size(); ++i)
    {
        if (input[i] == '%' && i + 2 < input.size())
        {
            unsigned int byte = 0;
            const auto parsed = std::from_chars(input.data() + i + 1, input.data() + i + 3, byte, 16);
            if (parsed.ec == std::errc{} && parsed.ptr == input.data() + i + 3)
            {
                result += static_cast<char>(byte);
                i += 2;
                continue;
            }
        }
        result += input[i];
    }
    return result;
}

std::optional<std::uint32_t> Index(const Json& value)
{
    double number = -1;
    if (value.is_number()) number = value.get<double>();
    else if (value.is_string())
    {
        const auto text = Trim(value.get<std::string>());
        const auto parsed = std::from_chars(text.data(), text.data() + text.size(), number);
        if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size()) return {};
    }
    if (!std::isfinite(number) || number < 0 || number > 4294967295.0 || std::floor(number) != number) return {};
    return static_cast<std::uint32_t>(number);
}

std::string Choice(const std::string& value)
{
    const auto colon = value.find(':');
    if (colon == std::string::npos || colon + 1 == value.size()) return {};
    const auto field = value.substr(0, colon);
    if (field != "options" && field != "definitions" && field != "morphNames") return {};
    static const std::regex pointer("^(userdata|table|function|thread): 0x[0-9a-fA-F]+$");
    return std::regex_match(value.substr(colon + 1), pointer) ? std::string{} : value;
}

void SetOptional(Json& object, const char* name, const std::string& value)
{
    if (!value.empty()) object[name] = value;
}

Json Finish(Json result, Json entries, bool metadataOnly)
{
    if (entries.empty()) return nullptr;
    result["entryCount"] = entries.size();
    result["entryCountKnown"] = true;
    result["metadataLoaded"] = true;
    result["lazy"] = metadataOnly;
    if (!metadataOnly) result["entries"] = std::move(entries);
    return result;
}
}

Json ParsePreset(std::string_view contents, bool metadataOnly)
{
    if (contents.empty() || contents.size() > MaximumBytes) return nullptr;
    const auto first = contents.find_first_not_of(" \r\n\t\v\f");
    if (first == std::string_view::npos) return nullptr;
    Json result = {{"format", 4}, {"source", "ACU preset (older format)"},
        {"notes", ""}, {"tags", ""}, {"favorite", false}, {"managedByCpm", false}};
    Json entries = Json::array();
    if (contents[first] == '{' || contents[first] == '[')
    {
        Json decoded;
        try
        {
            decoded = Json::parse(contents, [](int depth, Json::parse_event_t, Json&) {
                if (depth > 16) throw std::runtime_error("Preset nesting exceeds the limit.");
                return true;
            });
        }
        catch (const std::exception&) { return nullptr; }
        const Json* options = &decoded;
        if (decoded.is_object())
        {
            if (decoded.contains("options")) options = &decoded["options"];
            else if (decoded.contains("values")) options = &decoded["values"];
        }
        if (!options->is_array()) return nullptr;
        for (const auto& option : *options)
        {
            if (!option.is_object()) continue;
            const auto key = Text(option, "name", Text(option, "optionName", Text(option, "key")));
            const auto value = option.find(option.contains("value") ? "value" : "index");
            const auto active = option.find(option.contains("is_active") ? "is_active" : "isActive");
            if (active != option.end() && *active == false) continue;
            if (key.empty() || key.size() > 256 || value == option.end()) continue;
            const auto index = Index(*value);
            if (!index) continue;
            if (entries.size() == MaximumEntries) return nullptr;
            entries.push_back({{"key", key}, {"index", *index}});
        }
        result["source"] = decoded.is_object() && decoded.contains("isMaleVO")
            ? "ACU 3.0.0 JSON preset" : "ACU 3.0.1 or newer JSON preset";
        result["tags"] = "ACU";
        return Finish(std::move(result), std::move(entries), metadataOnly);
    }
    std::istringstream input{std::string(contents)};
    std::string line, pendingSlot, pendingChoice;
    std::size_t lines = 0;
    bool readable = false;
    static const std::regex legacy("^# CPM\\t([a-zA-Z]+)\\t(.*)$");
    static const std::regex header("^# ([a-zA-Z ]+):\\s?(.*)$");
    static const std::regex mainLine("^\\s*(.*?):(-?[0-9]+)\\s*$");
    static const std::regex labelLine("^(.*?)\\s+(-?[0-9]+)$");
    while (std::getline(input, line))
    {
        if (++lines > MaximumLines) return nullptr;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line == "# CPM Preset" || line == "# Character Preset Manager (CET) preset") result["managedByCpm"] = true;
        std::smatch match;
        if (std::regex_match(line, match, legacy))
        {
            result["managedByCpm"] = true;
            const auto name = match[1].str();
            const auto value = Decode(match[2].str());
            if (name == "format") result["format"] = Index(value).value_or(4);
            else if (name == "source" || name == "created" || name == "modified") result[name] = value;
            else if (name == "notes") result[name] = Clean(value, 512);
            else if (name == "tags") result[name] = Clean(value, 128);
            else if (name == "favorite") result[name] = value == "true" || value == "1";
            else if (name == "slot") pendingSlot = value.size() <= 256 && Clean(value, 256) == value ? value : "";
            else if (name == "choice") pendingChoice = value.size() <= 1024 && Clean(value, 1024) == value ? Choice(value) : "";
        }
        if (std::regex_match(line, match, header))
        {
            const auto name = match[1].str();
            const auto value = match[2].str();
            if (name == "Format" && entries.empty())
            {
                auto format = Index(value);
                if (format && *format >= 8) { result["format"] = *format; readable = true; }
            }
            else if (readable)
            {
                if (name == "Source") result["source"] = Clean(value, 128);
                else if (name == "Created") result["created"] = Clean(value, 64);
                else if (name == "Modified") result["modified"] = Clean(value, 64);
                else if (name == "Notes") result["notes"] = Clean(value, 512);
                else if (name == "Tags") result["tags"] = Clean(value, 128);
                else if (name == "Favorite")
                {
                    auto lowered = value;
                    std::transform(lowered.begin(), lowered.end(), lowered.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
                    result["favorite"] = lowered == "yes" || lowered == "true" || lowered == "on";
                }
                else if (name == "Name" && result["managedByCpm"] == true)
                {
                    const auto clean = Clean(value, 64);
                    if (Relative(clean) && clean.find('/') == std::string::npos) result["presetName"] = clean;
                }
                else if (name == "Library folder" && result["managedByCpm"] == true)
                {
                    const auto clean = Clean(value, 1024);
                    if (clean.empty() || clean == "/" || Relative(clean)) result["libraryFolder"] = clean == "/" ? "" : clean;
                }
                else if (!entries.empty())
                {
                    auto& entry = entries.back();
                    if (name == "Option")
                    {
                        std::smatch label;
                        if (std::regex_match(value, label, labelLine) && Index(label[2].str()) == Index(entry["index"]))
                            SetOptional(entry, "label", Clean(label[1].str(), 128));
                    }
                    else if (name == "Editor slot") SetOptional(entry, "slot", Clean(value, 256));
                    else if (name == "Saved choice") SetOptional(entry, "choice", Choice(Clean(value, 1024)));
                }
            }
        }
        if (!line.starts_with('#') && std::regex_match(line, match, mainLine) && !match[1].str().empty())
        {
            const auto key = match[1].str();
            const auto index = Index(match[2].str());
            if (key.size() > 256 || !index || entries.size() == MaximumEntries) return nullptr;
            Json entry = {{"key", key}, {"index", *index}};
            SetOptional(entry, "slot", pendingSlot);
            SetOptional(entry, "choice", pendingChoice);
            entries.push_back(std::move(entry));
            pendingSlot.clear();
            pendingChoice.clear();
        }
    }
    return Finish(std::move(result), std::move(entries), metadataOnly);
}

std::string WritePreset(const Json& preset)
{
    if (!preset.is_object() || !preset.contains("entries") || !preset["entries"].is_array() ||
        preset["entries"].empty() || preset["entries"].size() > MaximumEntries)
        throw std::runtime_error("The preset has no valid appearance choices.");
    auto folder = Text(preset, "libraryFolder");
    if (!Relative(folder)) folder.clear();
    std::ostringstream output;
    output << "# CPM Preset\n# Format: 8\n# Name: " << Clean(Text(preset, "presetName"), 64)
        << "\n# Source: " << Clean(Text(preset, "source", "Character Preset Manager (CET)"), 128)
        << "\n# Created: " << Clean(Text(preset, "created"), 64)
        << "\n# Modified: " << Clean(Text(preset, "modified"), 64)
        << "\n# Notes: " << Clean(Text(preset, "notes"), 512)
        << "\n# Tags: " << Clean(Text(preset, "tags"), 128)
        << "\n# Favorite: " << (preset.value("favorite", false) ? "Yes" : "No")
        << "\n# Library folder: " << (folder.empty() ? "/" : folder)
        << "\n#\n# Appearance options\n# Each main line is OptionKey:SavedNumber.\n"
        << "# Option, Editor slot, and Saved choice lines describe the option above them.\n\n";
    for (const auto& entry : preset["entries"])
    {
        const auto key = Text(entry, "key");
        const auto index = entry.contains("index") ? Index(entry["index"]) : std::nullopt;
        if (key.empty() || key.size() > 256 || key.front() == '#' || Clean(key, 256) != key || !index)
            throw std::runtime_error("The preset contains an invalid appearance choice.");
        auto label = Clean(Text(entry, "label"), 128);
        if (label.empty() || label == "Custom/CCXL option (no localization provided)")
        {
            label = Clean(Text(entry, "slot"), 128);
            for (auto& c : label) if (c == '_' || c == '-') c = ' ';
            if (!label.empty()) label[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(label[0])));
        }
        if (label.empty()) label = Clean(key, 128);
        output << key << ':' << *index << "\n# Option: " << label << ' ' << *index << '\n';
        const auto slot = Clean(Text(entry, "slot"), 256);
        const auto choice = Choice(Clean(Text(entry, "choice"), 1024));
        if (!slot.empty()) output << "# Editor slot: " << slot << '\n';
        if (!choice.empty()) output << "# Saved choice: " << choice << '\n';
        output << '\n';
    }
    auto result = output.str();
    if (result.size() > MaximumBytes) throw std::runtime_error("The preset exceeds the file size limit.");
    return result;
}
}
