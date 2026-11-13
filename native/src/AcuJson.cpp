#include "AcuJson.hpp"

#include <cmath>

namespace cpm::acu
{
std::optional<legacy::Preset> DecodeJson(const json::Value& decoded, bool metadataOnly)
{
    if (!decoded.IsTable()) return std::nullopt;
    auto options = decoded.Get("options");
    if (!options || !options->Truthy()) options = decoded.Get("values");
    if (!options || !options->IsTable())
    {
        const auto array = std::get_if<json::Value::Array>(&decoded.data);
        if (array && !array->empty()) options = &decoded;
    }
    if (!options || !options->IsTable()) return std::nullopt;
    const auto array = std::get_if<json::Value::Array>(&options->data);
    if (!array) return std::nullopt;
    legacy::Preset preset;
    preset.metadata.source = decoded.Get("isMaleVO") ? "ACU 3.0.0 JSON preset" : "ACU 3.0.1 or newer JSON preset";
    preset.metadata.tags = "ACU";
    preset.lazy = metadataOnly;
    for (const auto& option : *array)
    {
        if (!option.IsTable()) continue;
        auto key = option.Get("name");
        if (!key || !key->Truthy()) key = option.Get("optionName");
        if (!key || !key->Truthy()) key = option.Get("key");
        auto index = option.Get("value");
        if (!index) index = option.Get("index");
        auto active = option.Get("is_active");
        if (!active) active = option.Get("isActive");
        if ((active && !active->Truthy()) || !key || !index) continue;
        const auto name = std::get_if<std::string>(&key->data);
        if (!name || name->empty() || name->size() > 256) continue;
        std::optional<double> number;
        if (const auto value = std::get_if<double>(&index->data)) number = *value;
        else if (const auto text = std::get_if<std::string>(&index->data)) number = json::Number(*text);
        if (!number || *number != std::floor(*number) || *number < 0 || *number > 4294967295.0) continue;
        if (preset.entryCount >= 4096) return std::nullopt;
        ++preset.entryCount;
        if (!metadataOnly) preset.entries.push_back({*name, std::nullopt, static_cast<std::uint32_t>(*number),
            std::nullopt, std::nullopt, *number == 0 && std::signbit(*number)});
    }
    if (!preset.entryCount) return std::nullopt;
    return preset;
}
}
