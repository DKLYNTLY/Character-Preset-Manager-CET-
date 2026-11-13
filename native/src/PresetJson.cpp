#include "PresetJson.hpp"

#include <cstdlib>

namespace cpm::json
{
namespace
{
bool Space(unsigned char c) { return c == ' ' || (c >= 9 && c <= 13); }
bool Digit(unsigned char c) { return c >= '0' && c <= '9'; }

class Parser
{
public:
    Parser(std::string_view input, const CodepointEncoder& encoder) : text(input), encode(encoder) {}

    void SkipSpace()
    {
        while (!text.empty() && Space(text.front())) text.remove_prefix(1);
    }

    bool Consume(char c)
    {
        if (text.empty() || text.front() != c) return false;
        text.remove_prefix(1);
        return true;
    }

    std::optional<std::int64_t> Hex(std::string_view value)
    {
        if (value.empty()) return std::nullopt;
        std::string copy(value);
        char* end = nullptr;
        const auto number = std::strtoll(copy.c_str(), &end, 16);
        if (end == copy.c_str()) return std::nullopt;
        while (Space(static_cast<unsigned char>(*end))) ++end;
        if (end != copy.data() + copy.size()) return std::nullopt;
        return number;
    }

    std::optional<std::string> String()
    {
        if (!Consume('"')) return std::nullopt;
        std::string result;
        while (!text.empty())
        {
            const auto c = static_cast<unsigned char>(text.front());
            text.remove_prefix(1);
            if (c == '"') return result;
            if (c == '\\')
            {
                if (text.empty()) return std::nullopt;
                const auto escaped = text.front();
                text.remove_prefix(1);
                switch (escaped)
                {
                case '"': result += '"'; break;
                case '\\': result += '\\'; break;
                case '/': result += '/'; break;
                case 'b': result += '\b'; break;
                case 'f': result += '\f'; break;
                case 'n': result += '\n'; break;
                case 'r': result += '\r'; break;
                case 't': result += '\t'; break;
                case 'u':
                {
                    if (text.size() < 4) return std::nullopt;
                    auto point = Hex(text.substr(0, 4));
                    if (!point) return std::nullopt;
                    text.remove_prefix(4);
                    if (*point >= 0xD800 && *point <= 0xDBFF && text.starts_with("\\u"))
                    {
                        const auto trailing = Hex(text.substr(2, 4));
                        if (trailing && *trailing >= 0xDC00 && *trailing <= 0xDFFF)
                        {
                            *point = 0x10000 + (*point - 0xD800) * 0x400 + *trailing - 0xDC00;
                            text.remove_prefix(6);
                        }
                    }
                    const auto encoded = encode(*point);
                    result += encoded.value_or("?");
                    break;
                }
                default: return std::nullopt;
                }
            }
            else
            {
                if (c < 32) return std::nullopt;
                result += static_cast<char>(c);
            }
        }
        return std::nullopt;
    }

    std::optional<Value> Parse(unsigned depth)
    {
        if (depth > 16) return std::nullopt;
        SkipSpace();
        if (text.starts_with('"'))
        {
            auto string = String();
            if (!string) return std::nullopt;
            return Value{std::move(*string)};
        }
        if (Consume('['))
        {
            Value::Array array;
            SkipSpace();
            if (Consume(']')) return Value{std::move(array)};
            while (true)
            {
                auto value = Parse(depth + 1);
                if (!value) return std::nullopt;
                array.push_back(std::move(*value));
                SkipSpace();
                if (Consume(']')) return Value{std::move(array)};
                if (!Consume(',')) return std::nullopt;
            }
        }
        if (Consume('{'))
        {
            Value::Object object;
            SkipSpace();
            if (Consume('}')) return Value{std::move(object)};
            while (true)
            {
                SkipSpace();
                auto key = String();
                if (!key) return std::nullopt;
                SkipSpace();
                if (!Consume(':')) return std::nullopt;
                auto value = Parse(depth + 1);
                if (!value) return std::nullopt;
                object.insert_or_assign(std::move(*key), std::move(*value));
                SkipSpace();
                if (Consume('}')) return Value{std::move(object)};
                if (!Consume(',')) return std::nullopt;
            }
        }
        for (const auto keyword : {"true", "false", "null"})
        {
            const std::string_view word(keyword);
            if (text.starts_with(word))
            {
                text.remove_prefix(word.size());
                return Value{word == "true"};
            }
        }
        std::size_t size = 0;
        if (size < text.size() && text[size] == '-') ++size;
        const auto first = size;
        while (size < text.size() && Digit(text[size])) ++size;
        if (size == first) return std::nullopt;
        if (size < text.size() && text[size] == '.') ++size;
        while (size < text.size() && Digit(text[size])) ++size;
        if (size < text.size() && (text[size] == 'e' || text[size] == 'E')) ++size;
        if (size < text.size() && (text[size] == '+' || text[size] == '-')) ++size;
        while (size < text.size() && Digit(text[size])) ++size;
        const auto number = Number(text.substr(0, size));
        if (!number) return std::nullopt;
        text.remove_prefix(size);
        return Value{*number};
    }

    std::string_view text;
    const CodepointEncoder& encode;
};
}

bool Value::IsTable() const { return std::holds_alternative<Array>(data) || std::holds_alternative<Object>(data); }
bool Value::Truthy() const { const auto boolean = std::get_if<bool>(&data); return !boolean || *boolean; }
const Value* Value::Get(std::string_view key) const
{
    const auto object = std::get_if<Object>(&data);
    if (!object) return nullptr;
    const auto found = object->find(std::string(key));
    return found == object->end() ? nullptr : &found->second;
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

std::optional<Value> Decode(std::string_view text, const CodepointEncoder& encodeCodepoint)
{
    Parser parser(text, encodeCodepoint);
    auto result = parser.Parse(0);
    parser.SkipSpace();
    if (!parser.text.empty()) return std::nullopt;
    return result;
}
}
