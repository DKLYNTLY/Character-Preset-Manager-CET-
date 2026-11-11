#include "LegacyPresetText.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>

namespace cpm::legacy
{
namespace
{
bool Space(unsigned char c) { return c == ' ' || (c >= 9 && c <= 13); }
bool Control(unsigned char c) { return c < 32 || c == 127; }
bool Alpha(unsigned char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
bool Digit(unsigned char c) { return c >= '0' && c <= '9'; }
int Hex(unsigned char c)
{
    if (Digit(c)) return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

std::string DecodePercent(std::string_view text)
{
    std::string result;
    for (std::size_t i = 0; i < text.size(); ++i)
    {
        if (text[i] == '%' && i + 2 < text.size() && Hex(text[i + 1]) >= 0 && Hex(text[i + 2]) >= 0)
        {
            result += static_cast<char>(Hex(text[i + 1]) * 16 + Hex(text[i + 2]));
            i += 2;
        }
        else result += text[i];
    }
    return result;
}

std::string Sanitize(std::string text, std::size_t limit)
{
    for (auto& c : text) if (Control(c)) c = ' ';
    const auto first = text.find_first_not_of(' ');
    if (first == text.npos) return "";
    return text.substr(first, std::min(limit, text.find_last_not_of(' ') - first + 1));
}

std::optional<double> Number(std::string_view text)
{
    std::string value(text);
    char* end = nullptr;
    const auto result = std::strtod(value.c_str(), &end);
    if (end == value.c_str()) return std::nullopt;
    while (Space(static_cast<unsigned char>(*end))) ++end;
    if (end != value.data() + value.size()) return std::nullopt;
    return result;
}

std::optional<std::string> Choice(std::string value)
{
    const auto colon = value.find(':');
    if (colon == value.npos || colon + 1 == value.size()) return std::nullopt;
    const auto field = value.substr(0, colon);
    if (field != "definitions" && field != "options" && field != "morphNames") return std::nullopt;
    const auto name = std::string_view(value).substr(colon + 1);
    for (const auto prefix : {"userdata: 0x", "table: 0x", "function: 0x", "thread: 0x"})
    {
        const std::string_view start(prefix);
        if (name.starts_with(start) && name.size() > start.size()
            && std::all_of(name.begin() + start.size(), name.end(), [](unsigned char c) { return Hex(c) >= 0; }))
            return std::nullopt;
    }
    return value;
}

bool Name(std::string_view name)
{
    if (name.empty() || name.back() == '.' || name.back() == ' '
        || name.find_first_of("<>:\"/\\|?*") != name.npos) return false;
    auto end = name.find('.');
    if (end == 0) end = name.npos;
    std::string device(name.substr(0, end));
    for (auto& c : device) if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 'a' + 'A');
    if (device == "CON" || device == "PRN" || device == "AUX" || device == "NUL") return false;
    return !(device.size() == 4 && (device.starts_with("COM") || device.starts_with("LPT"))
        && device[3] >= '1' && device[3] <= '9');
}

bool Folder(std::string_view folder)
{
    if (folder.empty()) return true;
    if (folder.front() == '/' || folder.back() == '/' || folder.find("//") != folder.npos
        || folder.find('\\') != folder.npos) return false;
    while (!folder.empty())
    {
        const auto end = folder.find('/');
        const auto part = folder.substr(0, end);
        if (part == "." || part == "..") return false;
        if (end == folder.npos) break;
        folder.remove_prefix(end + 1);
    }
    return true;
}
}

Result DecodeText(std::string_view contents, std::string_view path, bool metadataOnly)
{
    Result result;
    auto header = contents;
    if (header.starts_with("# CPM Preset\n")) header.remove_prefix(13);
    else if (header.starts_with("# CPM Preset\r\n")) header.remove_prefix(14);
    else header = {};
    if (header.starts_with("# Format: "))
    {
        header.remove_prefix(10);
        const auto end = header.find('\n');
        if (end != header.npos)
        {
            auto version = header.substr(0, end);
            if (version.ends_with('\r')) version.remove_suffix(1);
            if (!version.empty() && std::all_of(version.begin(), version.end(), Digit)
                && Number(version).value_or(0) >= 9)
            {
                auto document = document9::Decode(contents);
                if (!document)
                    result.diagnostics.push_back({"[FILES] The CPM preset format or data could not be read safely. File: " + std::string(path)});
                else
                {
                    Preset preset;
                    preset.format = 9; preset.managedByCpm = true; preset.lazy = metadataOnly;
                    preset.metadata = std::move(document->metadata); preset.entryCount = document->entryCount;
                    preset.body = document->appearance.body; preset.voice = document->appearance.voice;
                    if (!metadataOnly)
                    {
                        preset.entries = std::move(document->entries);
                        preset.appearance = std::move(document->appearance);
                    }
                    result.preset = std::move(preset);
                }
                return result;
            }
        }
    }
    Preset preset;
    preset.metadata.source = "Legacy or ACU-compatible";
    preset.lazy = metadataOnly;
    std::optional<std::string> pendingSlot, pendingChoice;
    bool readable = false;
    std::size_t lineNumber = 0, malformed = 0;
    const std::string filename(path);
    while (!contents.empty())
    {
        const auto newline = contents.find('\n');
        const auto line = contents.substr(0, newline);
        if (newline == contents.npos) contents = {};
        else contents.remove_prefix(newline + 1);
        if (++lineNumber > MaximumLines)
        {
            result.diagnostics.push_back({"[FILES] Preset rejected because it exceeds " + std::to_string(MaximumLines)
                + " lines: file='" + filename + "'."});
            return result;
        }
        if (line == "# CPM Preset" || line == "# Character Preset Manager (CET) preset") preset.managedByCpm = true;
        std::string_view key, value;
        if (line.starts_with("# CPM\t"))
        {
            const auto tab = line.find('\t', 6);
            if (tab != line.npos && tab > 6 && std::all_of(line.begin() + 6, line.begin() + tab, Alpha))
            {
                key = line.substr(6, tab - 6); value = line.substr(tab + 1);
                preset.managedByCpm = true;
            }
        }
        auto& metadata = preset.metadata;
        if (key == "format") preset.format = Number(value).value_or(4);
        else if (key == "source") metadata.source = DecodePercent(value);
        else if (key == "created") metadata.created = DecodePercent(value);
        else if (key == "modified") metadata.modified = DecodePercent(value);
        else if (key == "notes") metadata.notes = Sanitize(DecodePercent(value), 512);
        else if (key == "tags") metadata.tags = Sanitize(DecodePercent(value), 128);
        else if (key == "favorite") metadata.favorite = value == "true" || value == "1";
        else if (!metadataOnly && (key == "slot" || key == "choice"))
        {
            auto decoded = DecodePercent(value);
            auto& pending = key == "slot" ? pendingSlot : pendingChoice;
            pending.reset();
            if (decoded.size() <= (key == "slot" ? 256U : 1024U)
                && std::none_of(decoded.begin(), decoded.end(), Control))
                pending = key == "slot" ? std::optional<std::string>(decoded) : Choice(std::move(decoded));
        }
        std::string_view label, readableValue;
        if (line.starts_with("# "))
        {
            const auto colon = line.find(':', 2);
            if (colon != line.npos && colon > 2 && std::all_of(line.begin() + 2, line.begin() + colon,
                [](unsigned char c) { return Alpha(c) || c == ' '; }))
            {
                label = line.substr(2, colon - 2); readableValue = line.substr(colon + 1);
                if (!readableValue.empty() && Space(readableValue.front())) readableValue.remove_prefix(1);
            }
        }
        if (label == "Format" && preset.entryCount == 0)
        {
            if (const auto format = Number(readableValue); format && *format >= 8)
            { preset.format = *format; readable = true; }
        }
        else if (readable)
        {
            if (label == "Source") metadata.source = Sanitize(std::string(readableValue), 128);
            else if (label == "Created") metadata.created = Sanitize(std::string(readableValue), 64);
            else if (label == "Modified") metadata.modified = Sanitize(std::string(readableValue), 64);
            else if (label == "Notes") metadata.notes = Sanitize(std::string(readableValue), 512);
            else if (label == "Tags") metadata.tags = Sanitize(std::string(readableValue), 128);
            else if (label == "Favorite")
            {
                std::string favorite(readableValue);
                for (auto& c : favorite) if (c >= 'A' && c <= 'Z') c = static_cast<char>(c - 'A' + 'a');
                metadata.favorite = favorite == "yes" || favorite == "true" || favorite == "on";
            }
            else if (label == "Name" && preset.managedByCpm)
            {
                auto name = Sanitize(std::string(readableValue), 64);
                if (Name(name)) metadata.name = std::move(name);
            }
            else if (label == "Library folder" && preset.managedByCpm)
            {
                auto folder = Sanitize(std::string(readableValue), 1024);
                if (folder == "/") folder.clear();
                if (Folder(folder)) metadata.libraryFolder = std::move(folder);
            }
            else if (!metadataOnly && !preset.entries.empty() && label == "Editor slot")
            {
                auto slot = Sanitize(std::string(readableValue), 256);
                preset.entries.back().slot = slot.empty() ? std::nullopt : std::optional<std::string>(slot);
            }
            else if (!metadataOnly && !preset.entries.empty() && label == "Saved choice")
                preset.entries.back().choice = Choice(Sanitize(std::string(readableValue), 1024));
        }
        std::string_view entryKey, index;
        if (!line.starts_with('#'))
        {
            auto trimmed = line;
            while (!trimmed.empty() && Space(trimmed.front())) trimmed.remove_prefix(1);
            while (!trimmed.empty() && Space(trimmed.back())) trimmed.remove_suffix(1);
            const auto colon = trimmed.rfind(':');
            if (colon != trimmed.npos)
            {
                auto digits = trimmed.substr(colon + 1);
                if (digits.starts_with('-')) digits.remove_prefix(1);
                if (!digits.empty() && std::all_of(digits.begin(), digits.end(), Digit))
                { entryKey = trimmed.substr(0, colon); index = trimmed.substr(colon + 1); }
            }
        }
        if (!entryKey.empty())
        {
            const auto number = Number(index);
            std::string error = "none";
            if (!number) error = "not numeric";
            else if (*number != std::floor(*number)) error = "not an integer";
            else if (*number < 0) error = "below zero";
            else if (*number > 4294967295.0) error = "above the native Uint32 maximum";
            if (entryKey.size() > 256 || error != "none" || preset.entryCount >= 4096)
            {
                result.diagnostics.push_back({"[FILES] Preset rejected at line " + std::to_string(lineNumber)
                    + ": file='" + filename + "' keyBytes=" + std::to_string(entryKey.size()) + " index='"
                    + std::string(index) + "' indexError='" + error + "' entriesBefore=" + std::to_string(preset.entryCount) + "."});
                return result;
            }
            ++preset.entryCount;
            if (!metadataOnly) preset.entries.push_back({std::string(entryKey), pendingSlot,
                static_cast<std::uint32_t>(*number), pendingChoice, std::nullopt, *number == 0 && std::signbit(*number)});
            pendingSlot.reset(); pendingChoice.reset();
        }
        else if (key.empty() && !line.starts_with('#') && std::any_of(line.begin(), line.end(), [](unsigned char c) { return !Space(c); }))
        {
            if (++malformed <= 20) result.diagnostics.push_back({"[FILES] Malformed preset line skipped: file='"
                + filename + "' line=" + std::to_string(lineNumber) + " content='" + std::string(line) + "'."});
        }
    }
    if (malformed) result.diagnostics.push_back({"[FILES] Preset '" + filename + "' contains " + std::to_string(malformed)
        + " malformed nonblank line" + (malformed == 1 ? "" : "s") + "; valid entries remain loadable."});
    if (preset.entryCount) result.preset = std::move(preset);
    return result;
}
}
