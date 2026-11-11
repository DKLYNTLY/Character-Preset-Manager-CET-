#include "PresetFormat9.hpp"

#include <algorithm>
#include <charconv>
#include <set>
#include <tuple>

namespace cpm::format9
{
namespace
{
constexpr std::string_view Header = "# CPM Preset\n# Format: 9\n";

bool Text(std::string_view value, std::size_t limit)
{
    return !value.empty() && value.size() <= limit
        && std::none_of(value.begin(), value.end(), [](unsigned char c) { return c < 32 || c == 127; });
}

bool Body(const std::optional<std::string>& value)
{
    return !value || *value == "Male" || *value == "Female" || *value == "Unknown";
}

std::optional<std::uint32_t> Number(std::string_view value)
{
    if (value.empty()) return std::nullopt;
    std::uint32_t result{};
    const auto parsed = std::from_chars(value.data(), value.data() + value.size(), result);
    if (parsed.ec != std::errc{} || parsed.ptr != value.data() + value.size()) return std::nullopt;
    return result;
}

bool SourceValue(std::string_view value)
{
    return value.size() <= 10 && Number(value).has_value();
}

std::string Bool(bool value)
{
    return value ? "true" : "false";
}

std::string Bool(const std::optional<bool>& value)
{
    return value ? Bool(*value) : "";
}

bool ReadBool(std::string_view value, std::optional<bool>& result)
{
    if (value != "true" && value != "false") return false;
    result = value == "true";
    return true;
}

std::vector<std::string_view> Split(std::string_view text, char separator)
{
    std::vector<std::string_view> fields;
    std::size_t begin = 0;
    while (true)
    {
        const auto end = text.find(separator, begin);
        fields.push_back(text.substr(begin, end == text.npos ? text.npos : end - begin));
        if (end == text.npos) return fields;
        begin = end + 1;
    }
}

class Writer
{
public:
    bool Add(std::string_view text)
    {
        if (text.size() > MaximumBytes - output.size()) return false;
        output += text;
        return true;
    }

    bool Field(std::string_view label, std::string_view value)
    {
        return Add("# ") && Add(label) && Add(": ") && Add(value) && Add("\n");
    }

    std::string output;
};
}

std::optional<std::string> Encode(const Preset& preset)
{
    if (!Body(preset.body) || !Body(preset.voice) || preset.entries.empty()
        || preset.entries.size() > MaximumEntries) return std::nullopt;
    Writer writer;
    writer.Add(Header);
    if (preset.body && !writer.Field("Source body", *preset.body)) return std::nullopt;
    if (preset.voice && !writer.Field("Source voice", *preset.voice)) return std::nullopt;
    std::set<std::tuple<std::string, std::string, std::uint32_t>> seen;
    for (const auto& entry : preset.entries)
    {
        if (!Text(entry.slot, 256) || !Text(entry.name, 256)
            || (entry.occurrence && (*entry.occurrence < 1 || *entry.occurrence > MaximumEntries))
            || !seen.emplace(entry.slot, entry.name, entry.occurrence.value_or(1)).second) return std::nullopt;
        if (entry.state != "Selected" && entry.state != "Off")
        {
            if ((entry.state != "Inactive" && entry.state != "Not captured" && entry.state != "Unverified"
                    && entry.state != "Read only") || entry.kind || entry.choices || entry.details) return std::nullopt;
            const auto reason = entry.reason.value_or("");
            const auto value = entry.value.value_or("");
            const auto sourceKind = entry.sourceKind.value_or("");
            if ((!reason.empty() && !Text(reason, 1024)) || (!value.empty() && !SourceValue(value))
                || (!sourceKind.empty() && !Text(sourceKind, 256))) return std::nullopt;
            const auto row = "# Roster\t" + entry.slot + "\t" + entry.name + "\t"
                + (entry.occurrence ? std::to_string(*entry.occurrence) : "") + "\t" + entry.state + "\t"
                + Bool(entry.active) + "\t" + value + "\t" + sourceKind + "\t" + Bool(entry.editable) + "\t" + reason + "\n";
            if (!writer.Add(row)) return std::nullopt;
            continue;
        }
        if (!writer.Field("Editor slot", entry.slot) || !writer.Field("Option name", entry.name)
            || (entry.occurrence && !writer.Field("Option occurrence", std::to_string(*entry.occurrence)))
            || !writer.Field("Selection state", entry.state)) return std::nullopt;
        if (!entry.kind || (*entry.kind != "Appearance" && *entry.kind != "Morph" && *entry.kind != "Switcher"
                && *entry.kind != "Legacy label" && *entry.kind != "Legacy index") || !entry.choices
            || entry.choices->empty() || (*entry.kind != "Switcher" && entry.choices->size() != 1)) return std::nullopt;
        if (!writer.Field("Identity kind", *entry.kind)) return std::nullopt;
        std::size_t bytes = 0;
        for (const auto& choice : *entry.choices)
        {
            if (!Text(choice, 1024)) return std::nullopt;
            bytes += choice.size() + 1;
            if (bytes > 1025 || !writer.Field("Choice identity", choice)) return std::nullopt;
        }
        if (entry.active && !writer.Field("Source active", Bool(*entry.active))) return std::nullopt;
        if (entry.editable && !writer.Field("Source editable", Bool(*entry.editable))) return std::nullopt;
        if (entry.value && (!SourceValue(*entry.value) || !writer.Field("Source value", *entry.value))) return std::nullopt;
        if (entry.legacyKey && (!Text(*entry.legacyKey, 256) || !writer.Field("Option label", *entry.legacyKey))) return std::nullopt;
        if (entry.legacyChoice && (!Text(*entry.legacyChoice, 1024) || !writer.Field("Legacy choice", *entry.legacyChoice))) return std::nullopt;
        if (entry.details)
        {
            const auto& details = *entry.details;
            if (details.localizedName && ((!details.localizedName->empty() && !Text(*details.localizedName, 1024))
                    || !writer.Field("Localized name", *details.localizedName))) return std::nullopt;
            for (const auto& field : details.unavailable)
                if (!Text(field, 256) || !writer.Field("Detail unavailable", field)) return std::nullopt;
            for (const auto& tag : details.tags)
                if (!Text(tag, 1024) || !writer.Field("Appearance tag", tag)) return std::nullopt;
            for (const auto& action : details.actions)
            {
                if (!action.params.empty() && !Text(action.params, 1024)) return std::nullopt;
                if (!writer.Add("# Action\t" + std::to_string(action.kind) + "\t" + Bool(action.immediate)
                    + "\t" + Bool(action.uiSlot) + "\t" + action.params + "\n")) return std::nullopt;
            }
        }
        if (!writer.Add("\n")) return std::nullopt;
    }
    return std::move(writer.output);
}

std::optional<Preset> Decode(std::string_view input)
{
    if (input.empty() || input.size() > MaximumBytes || input.back() != '\n') return std::nullopt;
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
    Preset preset;
    Entry entry;
    bool pending = false;
    while (!text.empty())
    {
        const auto end = text.find('\n');
        auto line = text.substr(0, end);
        text.remove_prefix(end + 1);
        if (line.starts_with("# Source body: ") || line.starts_with("# Source voice: "))
        {
            const bool body = line.starts_with("# Source body: ");
            auto& destination = body ? preset.body : preset.voice;
            if (destination) return std::nullopt;
            destination = line.substr(body ? 15 : 16);
            continue;
        }
        if (!line.empty())
        {
            if (!line.starts_with("# ")) return std::nullopt;
            line.remove_prefix(2);
        }
        if (line.starts_with("Roster\t"))
        {
            if (pending) return std::nullopt;
            const auto fields = Split(line, '\t');
            if (fields.size() != 10) return std::nullopt;
            Entry row;
            row.slot = fields[1]; row.name = fields[2]; row.state = fields[4];
            if (!fields[3].empty())
            {
                row.occurrence = Number(fields[3]);
                if (!row.occurrence) return std::nullopt;
            }
            if (!fields[5].empty() && !ReadBool(fields[5], row.active)) return std::nullopt;
            if (!fields[6].empty()) row.value = fields[6];
            if (!fields[7].empty()) row.sourceKind = fields[7];
            if (!fields[8].empty() && !ReadBool(fields[8], row.editable)) return std::nullopt;
            if (!fields[9].empty()) row.reason = fields[9];
            preset.entries.push_back(std::move(row));
        }
        else if (line.starts_with("Action\t"))
        {
            const auto fields = Split(line, '\t');
            if (fields.size() != 5) return std::nullopt;
            const auto kind = Number(fields[1]);
            std::optional<bool> immediate, uiSlot;
            if (!kind || !ReadBool(fields[2], immediate) || !ReadBool(fields[3], uiSlot)) return std::nullopt;
            if (!entry.details) entry.details.emplace();
            entry.details->actions.push_back({*kind, *immediate, *uiSlot, std::string(fields[4])});
            pending = true;
        }
        else if (line.empty())
        {
            preset.entries.push_back(std::move(entry));
            entry = {};
            pending = false;
        }
        else
        {
            const auto separator = line.find(": ");
            if (separator == line.npos) return std::nullopt;
            const auto field = line.substr(0, separator);
            const auto value = line.substr(separator + 2);
            if (field == "Editor slot" && entry.slot.empty()) entry.slot = value;
            else if (field == "Option name" && entry.name.empty()) entry.name = value;
            else if (field == "Option occurrence" && !entry.occurrence)
            {
                entry.occurrence = Number(value);
                if (!entry.occurrence) return std::nullopt;
            }
            else if (field == "Selection state" && entry.state.empty()) entry.state = value;
            else if (field == "Identity kind" && !entry.kind) entry.kind = value;
            else if (field == "Choice identity")
            {
                if (!entry.choices) entry.choices.emplace();
                entry.choices->emplace_back(value);
            }
            else if (field == "Option label") entry.legacyKey = value;
            else if (field == "Legacy choice") entry.legacyChoice = value;
            else if (field == "Source value") entry.value = value;
            else if (field == "Source active") { if (!ReadBool(value, entry.active)) return std::nullopt; }
            else if (field == "Source editable") { if (!ReadBool(value, entry.editable)) return std::nullopt; }
            else if (field == "Localized name" || field == "Detail unavailable" || field == "Appearance tag")
            {
                if (!entry.details) entry.details.emplace();
                if (field == "Localized name") entry.details->localizedName = value;
                else if (field == "Detail unavailable") entry.details->unavailable.emplace_back(value);
                else entry.details->tags.emplace_back(value);
            }
            else return std::nullopt;
            pending = true;
        }
        if (preset.entries.size() > MaximumEntries) return std::nullopt;
    }
    const auto canonical = Encode(preset);
    if (!canonical || *canonical != normalized) return std::nullopt;
    return preset;
}
}
