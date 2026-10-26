#pragma once

#include "../vendor/json.hpp"
#include <cmath>
#include <cstdlib>
#include <map>
#include <optional>
#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <sstream>
#include <string>
#include <vector>

namespace PresetData
{
struct Entry
{
    std::string key;
    std::uint32_t index = 0;
    std::string slot;
    std::string choice;
};

struct Preset
{
    int format = 4;
    std::map<std::string, std::string> meta{{"source", "Legacy or ACU-compatible"}};
    std::vector<Entry> entries;
    std::vector<std::pair<std::size_t, std::string>> warnings;
    std::size_t malformed = 0;
};

inline std::string Trim(std::string value)
{
    const auto start = value.find_first_not_of(" \t\r\n\f\v");
    if (start == std::string::npos) return {};
    return value.substr(start, value.find_last_not_of(" \t\r\n\f\v") - start + 1);
}

inline bool Controls(const std::string& value)
{
    return std::any_of(value.begin(), value.end(), [](unsigned char c) { return c < 32 || c == 127; });
}

inline std::string Sanitize(std::string value, std::size_t maximum)
{
    for (auto& c : value) if (static_cast<unsigned char>(c) < 32 || c == 127) c = ' ';
    value = Trim(std::move(value));
    if (value.size() > maximum) value.resize(maximum);
    return value;
}

inline bool StableChoice(const std::string& choice)
{
    return choice.size() <= 1024 && !Controls(choice) &&
        ((choice.starts_with("options:") && choice.size() > 8) ||
         (choice.starts_with("definitions:") && choice.size() > 12) ||
         (choice.starts_with("morphNames:") && choice.size() > 11)) &&
        choice.find("userdata: 0x") == std::string::npos && choice.find("table: 0x") == std::string::npos &&
        choice.find("function: 0x") == std::string::npos && choice.find("thread: 0x") == std::string::npos;
}

inline std::optional<std::uint32_t> Number(const std::string& text)
{
    if (text.empty()) return std::nullopt;
    char* end = nullptr;
    const auto value = std::strtod(text.c_str(), &end);
    if (!end || end == text.c_str() || !Trim(end).empty() || !std::isfinite(value) ||
        value < 0 || value > 4294967295.0 || std::floor(value) != value) return std::nullopt;
    return static_cast<std::uint32_t>(value);
}

inline std::optional<Preset> Json(const std::string& contents)
{
    try
    {
        auto root = nlohmann::json::parse(contents, [](int depth, nlohmann::json::parse_event_t,
                                                       nlohmann::json&) {
            if (depth > 16) throw std::runtime_error("Preset nesting limit exceeded");
            return true;
        });
        const nlohmann::json* options = nullptr;
        if (root.is_array()) options = &root;
        else if (root.is_object())
        {
            if (root.contains("options") && root["options"].is_array()) options = &root["options"];
            else if (root.contains("values") && root["values"].is_array()) options = &root["values"];
        }
        if (!options) return std::nullopt;
        Preset preset;
        preset.meta["source"] = root.is_object() && root.contains("isMaleVO")
            ? "ACU 3.0.0 JSON preset" : "ACU 3.0.1 or newer JSON preset";
        preset.meta["tags"] = "ACU";
        for (const auto& option : *options)
        {
            if (!option.is_object()) continue;
            const auto active = option.contains("is_active") ? option.find("is_active") : option.find("isActive");
            if (active != option.end() && active->is_boolean() && !active->get<bool>()) continue;
            std::string key;
            for (const auto* field : {"name", "optionName", "key"})
            {
                if (!option.contains(field) || option[field].is_null() || option[field] == false) continue;
                if (option[field].is_string()) key = option[field].get<std::string>();
                break;
            }
            const auto value = option.contains("value") ? option.find("value") : option.find("index");
            if (value == option.end()) continue;
            const auto number = value->is_string() ? Number(value->get<std::string>()) :
                value->is_number() ? Number(value->dump()) : std::nullopt;
            if (key.empty() || key.size() > 256 || !number) continue;
            if (preset.entries.size() >= 4096) return std::nullopt;
            preset.entries.push_back({key, *number, {}, {}});
        }
        if (preset.entries.empty()) return std::nullopt;
        return preset;
    }
    catch (const std::exception&) { return std::nullopt; }
}

template<typename Decode>
std::optional<Preset> Parse(const std::string& contents, Decode decode)
{
    const auto first = contents.find_first_not_of(" \t\r\n\f\v");
    if (first == std::string::npos) return std::nullopt;
    if (contents[first] == '{' || contents[first] == '[') return Json(contents);
    Preset preset;
    bool readable = false;
    std::string pendingSlot, pendingChoice, line;
    std::size_t lineNumber = 0;
    std::istringstream input(contents);
    while (std::getline(input, line))
    {
        if (++lineNumber > 16448) return std::nullopt;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line == "# CPM Preset" || line == "# Character Preset Manager (CET) preset")
            preset.meta["managedByCpm"] = "1";
        const auto legacyTab = line.starts_with("# CPM\t") ? line.find('\t', 6) : std::string::npos;
        const auto headingColon = line.starts_with("# ") ? line.find(':', 2) : std::string::npos;
        if (legacyTab != std::string::npos)
        {
            preset.meta["managedByCpm"] = "1";
            const auto key = line.substr(6, legacyTab - 6);
            const auto value = decode(line.substr(legacyTab + 1));
            if (key == "format")
            {
                const auto format = Number(value);
                preset.format = format && *format <= 2147483647 ? static_cast<int>(*format) : 4;
            }
            else if (key == "slot") pendingSlot = value.size() <= 256 && !Controls(value) ? value : "";
            else if (key == "choice") pendingChoice = StableChoice(value) ? value : "";
            else if (key == "favorite") preset.meta[key] = value == "true" || value == "1" ? "1" : "0";
            else if (key == "source" || key == "created" || key == "modified") preset.meta[key] = value;
            else if (key == "notes" || key == "tags") preset.meta[key] = Sanitize(value, key == "notes" ? 512 : 128);
        }
        if (headingColon != std::string::npos)
        {
            const auto key = line.substr(2, headingColon - 2);
            auto value = line.substr(headingColon + 1);
            if (!value.empty() && value.front() == ' ') value.erase(0, 1);
            if (key == "Format" && preset.entries.empty())
            {
                const auto format = Number(value);
                if (format && *format >= 8 && *format <= 2147483647)
                { preset.format = static_cast<int>(*format); readable = true; }
            }
            else if (readable)
            {
                if (key == "Editor slot" && !preset.entries.empty()) preset.entries.back().slot = Sanitize(value, 256);
                else if (key == "Saved choice" && !preset.entries.empty())
                {
                    const auto choice = Sanitize(value, 1024);
                    preset.entries.back().choice = StableChoice(choice) ? choice : "";
                }
                else if (key == "Favorite")
                {
                    auto lowered = value;
                    for (auto& c : lowered) if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
                    preset.meta["favorite"] = lowered == "yes" || lowered == "true" || lowered == "on" ? "1" : "0";
                }
                else
                {
                    for (const auto& [label, field] : std::map<std::string, std::string>{{"Source","source"},
                        {"Created","created"},{"Modified","modified"},{"Notes","notes"},{"Tags","tags"},
                        {"Name","presetName"},{"Library folder","libraryFolder"}})
                    {
                        if (key != label) continue;
                        if ((field == "presetName" || field == "libraryFolder") && preset.meta["managedByCpm"] != "1") break;
                        const auto maximum = field == "notes" ? 512 : field == "libraryFolder" ? 1024 :
                            field == "source" || field == "tags" ? 128 : 64;
                        preset.meta[field] = Sanitize(value, maximum);
                        break;
                    }
                }
            }
        }
        if (line.starts_with('#') || Trim(line).empty()) continue;
        const auto colon = line.rfind(':');
        auto tail = colon == std::string::npos ? "" : line.substr(colon + 1);
        const auto tailEnd = tail.find_last_not_of(" \t\r\n\f\v");
        tail = tailEnd == std::string::npos ? "" : tail.substr(0, tailEnd + 1);
        const auto digits = !tail.empty() && tail.front() == '-' ? tail.substr(1) : tail;
        const auto integer = !digits.empty() && std::all_of(digits.begin(), digits.end(),
            [](char c) { return c >= '0' && c <= '9'; });
        if (colon != std::string::npos && integer)
        {
            auto key = line.substr(0, colon);
            const auto start = key.find_first_not_of(" \t\r\n\f\v");
            key = start == std::string::npos ? "" : key.substr(start);
            const auto number = Number(tail);
            if (!key.empty())
            {
                if (!number || key.size() > 256 || preset.entries.size() >= 4096) return std::nullopt;
                preset.entries.push_back({key, *number, pendingSlot, pendingChoice});
                pendingSlot.clear(); pendingChoice.clear();
                continue;
            }
        }
        ++preset.malformed;
        if (preset.warnings.size() < 20) preset.warnings.emplace_back(lineNumber, line);
    }
    if (preset.entries.empty()) return std::nullopt;
    return preset;
}

inline std::string Fingerprint(const std::string& contents)
{
    std::uint64_t first = 0, second = 0;
    for (unsigned char c : contents)
    {
        first = (first * 131 + c) % 2147483647;
        second = (second * 137 + c) % 2147483629;
    }
    return "2:" + std::to_string(contents.size()) + ':' + std::to_string(first) + ':' + std::to_string(second);
}

inline std::string CacheName(std::string fingerprint)
{
    std::replace(fingerprint.begin(), fingerprint.end(), ':', '-');
    return "p1-" + fingerprint + ".txt";
}

template<typename Encode>
std::string Serialize(const Preset& preset, const std::string& fingerprint, Encode encode)
{
    std::ostringstream output;
    output << "CPMParsed\t1\t" << fingerprint << '\t' << preset.format << '\t' << preset.entries.size() << '\n';
    for (const auto& [key, value] : preset.meta) output << "meta\t" << key << '\t' << encode(value) << '\n';
    output << "meta\tmalformed\t" << preset.malformed << '\n';
    for (const auto& entry : preset.entries)
        output << "entry\t" << encode(entry.key) << '\t' << entry.index << '\t' << encode(entry.slot) << '\t' << encode(entry.choice) << '\n';
    for (const auto& [line, text] : preset.warnings) output << "warning\t" << line << '\t' << encode(text) << '\n';
    output << "end\t" << preset.entries.size() << '\n';
    return output.str();
}
}
