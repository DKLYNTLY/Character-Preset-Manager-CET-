#include "Archive.hpp"

#include <algorithm>
#include <charconv>
#include <cctype>
#include <sstream>
#include <stdexcept>

namespace cpm
{
namespace
{
std::string Lower(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

bool ValidPath(const std::string& path, bool strict)
{
    if (path.empty() || path.front() == '/' || path.back() == '/' || path.find_first_of("\\:*?\"<>|") != std::string::npos) return false;
    for (unsigned char c : path) if (c < 32 || c == 127) return false;
    std::istringstream input(path);
    std::string part;
    while (std::getline(input, part, '/'))
    {
        if (part.empty() || part == "." || part == ".." || part.back() == '.' || part.back() == ' ' || (strict && (part.size() > 64 || part.front() == ' '))) return false;
        const auto device = Lower(part.substr(0, part.find('.')));
        if (device == "con" || device == "prn" || device == "aux" || device == "nul" ||
            (device.size() == 4 && (device.starts_with("com") || device.starts_with("lpt")) && device[3] >= '1' && device[3] <= '9')) return false;
    }
    return true;
}

std::string Decode(const std::string& value, bool hex)
{
    std::string output;
    for (std::size_t index = 0; index < value.size();)
    {
        if (hex || value[index] == '%')
        {
            if (!hex)
            {
                unsigned int byte = 0;
                if (index + 3 <= value.size())
                {
                    const auto parsed = std::from_chars(value.data() + index + 1, value.data() + index + 3, byte, 16);
                    if (parsed.ec == std::errc{} && parsed.ptr == value.data() + index + 3)
                    {
                        output += static_cast<char>(byte);
                        index += 3;
                        continue;
                    }
                }
                output += value[index++];
                continue;
            }
            if (index + 2 > value.size()) throw std::runtime_error("The shared file contains incomplete encoded text.");
            unsigned int byte = 0;
            const auto result = std::from_chars(value.data() + index, value.data() + index + 2, byte, 16);
            if (result.ec != std::errc{} || result.ptr != value.data() + index + 2)
                throw std::runtime_error("The shared file contains invalid encoded text.");
            output += static_cast<char>(byte);
            index += 2;
        }
        else output += value[index++];
    }
    return output;
}

std::string Encode(const std::string& value, bool hex)
{
    constexpr char digits[] = "0123456789ABCDEF";
    std::string output;
    output.reserve(value.size() * 2);
    for (unsigned char c : value)
    {
        if (!hex && ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '/')) output += static_cast<char>(c);
        else
        {
            if (!hex) output += '%';
            output += digits[c >> 4];
            output += digits[c & 15];
        }
    }
    return output;
}
}

Archive ReadArchive(const std::string& contents, bool backup)
{
    const std::size_t maximum = backup ? 268435456 : 33554432;
    if (contents.size() > maximum) throw std::runtime_error("The selected shared file exceeds its size limit.");
    Archive archive;
    archive.backup = backup;
    std::istringstream input(contents);
    std::string line;
    std::size_t lineNumber = 0;
    std::set<std::string> names, folders;
    while (std::getline(input, line))
    {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (!backup && line.empty()) continue;
        if (++lineNumber > 65536) throw std::runtime_error("The shared file has too many records.");
        if (lineNumber == 1)
        {
            if (line != (backup ? "CPMBACKUP\t1" : "CPMFOLDER\t1")) throw std::runtime_error("The shared file has an unsupported format.");
            continue;
        }
        if (line.empty()) continue;
        const auto firstTab = line.find('\t');
        const auto secondTab = firstTab == std::string::npos ? firstTab : line.find('\t', firstTab + 1);
        const auto kind = line.substr(0, firstTab);
        const auto first = firstTab == std::string::npos ? "" : line.substr(firstTab + 1, secondTab == std::string::npos ? secondTab : secondTab - firstTab - 1);
        if (kind == "CONFIG" && backup && secondTab == std::string::npos && !archive.config)
        {
            if (first.size() > 16777216) throw std::runtime_error("The backup settings exceed the size limit.");
            archive.config = Decode(first, true);
        }
        else if (kind == "ROOT" && !backup && secondTab == std::string::npos && archive.root.empty())
        {
            archive.root = Decode(first, false);
            if (!ValidPath(archive.root, true) || archive.root.find('/') != std::string::npos)
                throw std::runtime_error("The shared folder has an invalid main folder name.");
        }
        else if (kind == "F" && secondTab == std::string::npos)
        {
            const auto folder = Decode(first, false);
            if (!ValidPath(folder, !backup) || (!folders.insert(Lower(folder)).second && !backup))
                throw std::runtime_error("The shared file contains an invalid or repeated folder.");
            archive.folders.insert(folder);
            if (archive.folders.size() > 32768) throw std::runtime_error("The shared file has too many folders.");
        }
        else if (kind == "P" && secondTab != std::string::npos)
        {
            const auto name = Decode(first, false);
            const auto encoded = line.substr(secondTab + 1);
            if (!ValidPath(name, !backup) || encoded.empty() || encoded.size() > 2097152 || !names.insert(Lower(name)).second || archive.presets.size() >= (backup ? 8192 : 512))
                throw std::runtime_error("The shared file contains an invalid or repeated preset.");
            archive.presets.emplace(name, Decode(encoded, true));
        }
        else throw std::runtime_error("The shared file contains an invalid record.");
    }
    if (archive.presets.empty() || (backup ? !archive.config.has_value() : archive.root.empty()))
        throw std::runtime_error("The shared file is empty or incomplete.");
    return archive;
}

std::string WriteArchive(const Archive& archive)
{
    std::string contents = archive.backup ? "CPMBACKUP\t1\nCONFIG\t" + Encode(archive.config.value_or(""), true) + '\n' : "CPMFOLDER\t1\nROOT\t" + Encode(archive.root, false) + '\n';
    const std::size_t maximum = archive.backup ? 268435456 : 33554432;
    auto append = [&](const std::string& line) {
        if (contents.size() + line.size() + 1 > maximum) throw std::runtime_error("The shared file would exceed its size limit.");
        contents += line + '\n';
    };
    for (const auto& folder : archive.folders) append("F\t" + Encode(folder, false));
    for (const auto& [name, preset] : archive.presets)
    {
        if (preset.size() > 1048576) throw std::runtime_error("A selected preset exceeds the file size limit.");
        append("P\t" + Encode(name, false) + '\t' + Encode(preset, true));
    }
    const auto verified = ReadArchive(contents, archive.backup);
    if (verified.presets != archive.presets || verified.folders != archive.folders)
        throw std::runtime_error("The shared file did not pass verification.");
    return contents;
}
}
