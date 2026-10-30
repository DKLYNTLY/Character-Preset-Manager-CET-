#include "FileFormats.hpp"

namespace cpm
{
bool HasPresetSuffix(const fs::path& path)
{
    auto name = path.filename().wstring();
    std::transform(name.begin(), name.end(), name.begin(),
                   [](const wchar_t value) { return static_cast<wchar_t>(std::towlower(value)); });
    return name.size() > 7 && name.ends_with(L".preset");
}

bool HasSupportedSuffix(const fs::path& path)
{
    auto name = path.filename().wstring();
    std::transform(name.begin(), name.end(), name.begin(),
                   [](const wchar_t value) { return static_cast<wchar_t>(std::towlower(value)); });
    return name.ends_with(L".preset") || name.ends_with(L".cpmfolder") ||
        name.ends_with(L".cpmbackup");
}

bool ValidFingerprint(const std::string& value, const std::uintmax_t expectedSize)
{
    return value.starts_with("2:" + std::to_string(expectedSize) + ":") && value.size() <= 64 &&
        std::count(value.begin(), value.end(), ':') == 3 &&
        std::all_of(value.begin(), value.end(), [](const char character) {
            return (character >= '0' && character <= '9') || character == ':';
        });
}

bool SafeComponent(const fs::path& component)
{
    const auto value = component.wstring();
    if (value.empty() || value == L"." || value == L".." || value.size() > 255)
        return false;
    for (const auto character : value)
    {
        if (character < 32 || character == L'<' || character == L'>' || character == L':' ||
            character == L'"' || character == L'/' || character == L'\\' || character == L'|' ||
            character == L'?' || character == L'*')
            return false;
    }
    return value.back() != L'.' && value.back() != L' ';
}

bool SafeRelativePath(const fs::path& relative)
{
    if (relative.empty() || relative.is_absolute())
        return false;
    std::size_t depth = 0;
    for (const auto& component : relative)
    {
        if (!SafeComponent(component) || ++depth > 12)
            return false;
    }
    return true;
}

std::string EscapeField(const std::string& value)
{
    std::ostringstream output;
    output << std::hex;
    for (const auto character : value)
    {
        const auto byte = static_cast<unsigned char>(character);
        if (byte == '%' || byte == '\t' || byte == '\r' || byte == '\n')
            output << '%' << "0123456789ABCDEF"[(byte >> 4) & 0xF] << "0123456789ABCDEF"[byte & 0xF];
        else
            output << character;
    }
    return output.str();
}

std::string UnescapeField(const std::string& value)
{
    std::string output;
    output.reserve(value.size());
    for (std::size_t index = 0; index < value.size(); ++index)
    {
        if (value[index] == '%' && index + 2 < value.size())
        {
            const auto hex = value.substr(index + 1, 2);
            char* end = nullptr;
            const auto decoded = std::strtoul(hex.c_str(), &end, 16);
            if (end && *end == '\0')
            {
                output.push_back(static_cast<char>(decoded));
                index += 2;
                continue;
            }
        }
        output.push_back(value[index]);
    }
    return output;
}

std::vector<WORD> DecodeOverlayBinding(const std::string& text)
{
    if (text.size() > 1048576)
        return {};
    const std::regex pattern(R"("cet"\s*:\s*\{[^{}]*"overlay_key"\s*:\s*([0-9]+)\s*[,}])");
    std::smatch match;
    if (!std::regex_search(text, match, pattern))
        return {};
    std::uint64_t encoded = 0;
    try { encoded = std::stoull(match[1].str()); }
    catch (...) { return {}; }
    std::vector<WORD> keys;
    bool ended = false;
    for (int shift = 48; shift >= 0; shift -= 16)
    {
        const auto key = static_cast<WORD>((encoded >> shift) & 0xFFFF);
        if (!key) { ended = true; continue; }
        if (ended || key <= VK_XBUTTON2 || key > 0xFE ||
            std::find(keys.begin(), keys.end(), key) != keys.end())
            return {};
        keys.push_back(key);
    }
    return keys;
}

std::vector<INPUT> OverlayInputs(const std::vector<WORD>& keys)
{
    std::vector<INPUT> inputs;
    for (const auto key : keys)
    {
        INPUT input{};
        input.type = INPUT_KEYBOARD;
        input.ki.wVk = key;
        if (key == VK_RCONTROL || key == VK_RMENU || key == VK_INSERT ||
            key == VK_DELETE || key == VK_HOME || key == VK_END || key == VK_PRIOR ||
            key == VK_NEXT || (key >= VK_LEFT && key <= VK_DOWN) || key == VK_DIVIDE ||
            key == VK_NUMLOCK || key == VK_SNAPSHOT || key == VK_LWIN || key == VK_RWIN || key == VK_APPS)
            input.ki.dwFlags = KEYEVENTF_EXTENDEDKEY;
        inputs.push_back(input);
    }
    const auto count = inputs.size();
    for (auto index = count; index > 0; --index)
    {
        auto input = inputs[index - 1];
        input.ki.dwFlags |= KEYEVENTF_KEYUP;
        inputs.push_back(input);
    }
    return inputs;
}

std::map<std::string, Record> ParseRecords(std::istream& input)
{
    std::map<std::string, Record> records;
    std::string line;
    while (std::getline(input, line))
    {
        std::istringstream fields(line);
        std::string source;
        std::string size;
        std::string modified;
        std::string destination;
        if (!std::getline(fields, source, '\t') || !std::getline(fields, size, '\t') ||
            !std::getline(fields, modified, '\t') || !std::getline(fields, destination))
            continue;
        try
        {
            records[UnescapeField(source)] = Record{
                static_cast<std::uintmax_t>(std::stoull(size)),
                std::stoll(modified),
                UnescapeField(destination),
            };
        }
        catch (...)
        {
        }
    }
    return records;
}

std::map<std::string, NativeRecord> ParseNativeRecords(std::istream& input)
{
    std::map<std::string, NativeRecord> records;
    std::string line;
    while (std::getline(input, line))
    {
        std::istringstream fields(line);
        std::string kind;
        std::string relative;
        std::string size;
        std::string modified;
        std::string fingerprint;
        if (!std::getline(fields, kind, '\t') || kind != "file" ||
            !std::getline(fields, relative, '\t') || !std::getline(fields, size, '\t') ||
            !std::getline(fields, modified, '\t') || !std::getline(fields, fingerprint))
            continue;
        try
        {
            records[UnescapeField(relative)] = NativeRecord{
                static_cast<std::uintmax_t>(std::stoull(size)),
                std::stoll(modified),
                fingerprint,
            };
        }
        catch (...)
        {
        }
    }
    return records;
}

std::string BuildRecords(const std::map<std::string, Record>& records)
{
    std::ostringstream output;
    for (const auto& [source, record] : records)
        output << EscapeField(source) << '\t' << record.size << '\t' << record.modified << '\t'
               << EscapeField(record.destination) << '\n';
    return output.str();
}

std::string BuildResults(const std::vector<std::string>& changed, const std::size_t skipped, const std::int64_t generation)
{
    std::ostringstream output;
    output << "generation\t" << generation << '\n';
    output << "summary\t" << changed.size() << '\t' << skipped << '\n';
    for (const auto& destination : changed)
        output << "file\t" << EscapeField(destination) << '\n';
    return output.str();
}

std::string BuildNativeCatalog(const std::map<std::string, NativeRecord>& files,
    const std::vector<std::string>& directories, const std::size_t skipped, const std::int64_t generation)
{
    std::ostringstream output;
    output << "protocol\t" << kCatalogProtocol << '\n';
    output << "generation\t" << generation << '\n';
    output << "summary\t" << files.size() << '\t' << directories.size() << '\t' << skipped << '\n';
    for (const auto& directory : directories)
        output << "directory\t" << EscapeField(directory) << '\n';
    for (const auto& [relative, record] : files)
        output << "file\t" << EscapeField(relative) << '\t' << record.size << '\t'
               << record.modified << '\t' << record.fingerprint << '\n';
    return output.str();
}

std::optional<std::string> ParseOverlayRequest(const std::string& request)
{
    const auto separator = request.find('\t');
    if (separator == std::string::npos || request.substr(separator + 1) != "open")
        return std::nullopt;
    auto id = request.substr(0, separator);
    if (id.empty() || id.size() > 80 || id.find_first_not_of("0123456789-") != std::string::npos)
        return std::nullopt;
    return id;
}
}
