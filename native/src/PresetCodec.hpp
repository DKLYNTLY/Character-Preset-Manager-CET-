#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <string_view>

namespace cpm
{
using Json = nlohmann::json;
Json ParsePreset(std::string_view contents, bool metadataOnly = false);
std::string WritePreset(const Json& preset);
}
