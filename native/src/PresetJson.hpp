#pragma once

#include <functional>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

namespace cpm::json
{
struct Value
{
    using Array = std::vector<Value>;
    using Object = std::map<std::string, Value>;
    std::variant<bool, double, std::string, Array, Object> data = false;

    bool IsTable() const;
    bool Truthy() const;
    const Value* Get(std::string_view key) const;
};

using CodepointEncoder = std::function<std::optional<std::string>(std::int64_t)>;
std::optional<double> Number(std::string_view text);
std::optional<Value> Decode(std::string_view text, const CodepointEncoder& encodeCodepoint);
}
