#include "Library.hpp"
#include "FileTransaction.hpp"
#include "Appearance.hpp"
#include "Archive.hpp"

#include <Windows.h>

#include <algorithm>
#include <charconv>
#include <cctype>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <vector>

namespace cpm
{
namespace
{
namespace fs = std::filesystem;
constexpr std::size_t MaximumPresetBytes = 1048576;
constexpr std::size_t MaximumCatalogBytes = 8388608;
constexpr std::size_t MaximumCatalogLines = 32768;
constexpr std::size_t MaximumPresets = 8192;
constexpr std::size_t MaximumEntries = 1048576;

std::string Lower(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

std::string Parent(const std::string& name)
{
    const auto slash = name.find_last_of('/');
    return slash == std::string::npos ? "" : name.substr(0, slash);
}

std::string Leaf(const std::string& name)
{
    const auto slash = name.find_last_of('/');
    return slash == std::string::npos ? name : name.substr(slash + 1);
}

bool Relative(const std::string& value)
{
    if (value.empty() || value.front() == '/' || value.back() == '/' || value.find_first_of("\\:*?\"<>|") != std::string::npos)
        return false;
    if (std::any_of(value.begin(), value.end(), [](unsigned char c) { return c < 32 || c == 127; })) return false;
    std::istringstream input(value);
    std::string part;
    while (std::getline(input, part, '/'))
    {
        if (part.empty() || part == "." || part == ".." || part.back() == '.' || part.back() == ' ') return false;
        const auto device = Lower(part.substr(0, part.find('.')));
        if (device == "con" || device == "prn" || device == "aux" || device == "nul" ||
            (device.size() == 4 && (device.starts_with("com") || device.starts_with("lpt")) && device[3] >= '1' && device[3] <= '9'))
            return false;
    }
    return true;
}

std::string Decode(const std::string& value)
{
    std::string result;
    for (std::size_t index = 0; index < value.size(); ++index)
    {
        if (value[index] == '%' && index + 2 < value.size())
        {
            unsigned int byte = 0;
            const auto parsed = std::from_chars(value.data() + index + 1, value.data() + index + 3, byte, 16);
            if (parsed.ec == std::errc{} && parsed.ptr == value.data() + index + 3)
            {
                result += static_cast<char>(byte);
                index += 2;
                continue;
            }
        }
        result += value[index];
    }
    return result;
}

void Ancestors(Json& folders, std::string folder)
{
    while (!folder.empty())
    {
        folders[folder] = true;
        folder = Parent(folder);
    }
}

std::string Utf8(const fs::path& path)
{
    const auto bytes = path.generic_u8string();
    return {reinterpret_cast<const char*>(bytes.data()), bytes.size()};
}

std::string Fingerprint(const std::string& contents)
{
    std::uint64_t first = 0, second = 0;
    for (unsigned char byte : contents)
    {
        first = (first * 131 + byte) % 2147483647;
        second = (second * 137 + byte) % 2147483629;
    }
    return "2:" + std::to_string(contents.size()) + ':' + std::to_string(first) + ':' + std::to_string(second);
}

std::string Encode(const std::string& value)
{
    std::ostringstream output;
    output << std::uppercase << std::hex;
    for (unsigned char c : value)
    {
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
            c == '-' || c == '.' || c == '_' || c == '/') output << static_cast<char>(c);
        else output << '%' << std::setfill('0') << std::setw(2) << static_cast<unsigned int>(c);
    }
    return output.str();
}

std::string Timestamp()
{
    const auto now = std::time(nullptr);
    std::tm local{};
    localtime_s(&local, &now);
    std::ostringstream output;
    output << std::put_time(&local, "%Y-%m-%d %H:%M:%S");
    return output.str();
}

std::string ModifiedTimestamp(const Json& preset)
{
    const auto value = preset.value("modified", std::string{});
    if (value.size() != 19 || value[4] != '-' || value[7] != '-' || value[10] != ' ' || value[13] != ':' || value[16] != ':') return {};
    for (std::size_t index = 0; index < value.size(); ++index)
        if (index != 4 && index != 7 && index != 10 && index != 13 && index != 16 && (value[index] < '0' || value[index] > '9')) return {};
    const auto year = std::stoi(value.substr(0, 4)), month = std::stoi(value.substr(5, 2)), day = std::stoi(value.substr(8, 2));
    const auto hour = std::stoi(value.substr(11, 2)), minute = std::stoi(value.substr(14, 2)), second = std::stoi(value.substr(17, 2));
    return year >= 2000 && month >= 1 && month <= 12 && day >= 1 && day <= 31 && hour <= 23 && minute <= 59 && second <= 59 ? value : "";
}

bool ContainsName(const Json& values, const std::string& name, const std::string& except = {})
{
    const auto lowered = Lower(name);
    for (const auto& [key, value] : values.items())
    {
        static_cast<void>(value);
        if (key != except && Lower(key) == lowered) return true;
    }
    return false;
}

std::string Remap(const std::string& path, const std::string& source, const std::string& destination)
{
    if (path == source) return destination;
    if (path.starts_with(source + '/')) return destination + path.substr(source.size());
    return path;
}

void ValidateSize(const Json& presets, const Json& folders)
{
    if (presets.size() > MaximumPresets || folders.size() > MaximumCatalogLines)
        throw std::runtime_error("This action would exceed the library size limit.");
    std::size_t choices = 0;
    for (const auto& [name, preset] : presets.items())
    {
        static_cast<void>(name);
        choices += preset.value("entryCount", std::size_t{});
    }
    if (choices > MaximumEntries) throw std::runtime_error("This action would exceed the library's saved-choice limit.");
}
}

Library::Library(fs::path manager) : manager_(fs::absolute(std::move(manager)).lexically_normal()) {}

fs::path Library::SafePath(const std::string& relative) const
{
    if (!Relative(relative)) throw std::runtime_error("The file path is not safe to use.");
    auto current = manager_.root_path();
    for (const auto& part : manager_.relative_path())
    {
        current /= part;
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
            throw std::runtime_error("The preset folder uses a link that cannot be followed safely.");
    }
    for (const auto& part : fs::path(std::u8string(reinterpret_cast<const char8_t*>(relative.data()), relative.size())))
    {
        current /= part;
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
            throw std::runtime_error("A preset path uses a link that cannot be followed safely.");
    }
    return current;
}

std::string Library::Read(const std::string& relative, std::size_t maximum) const
{
    const auto path = SafePath(relative);
    const auto file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) throw std::runtime_error("The preset file could not be opened.");
    struct Close { HANDLE handle; ~Close() { CloseHandle(handle); } } close{file};
    BY_HANDLE_FILE_INFORMATION info{};
    if (!GetFileInformationByHandle(file, &info) ||
        (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0)
        throw std::runtime_error("The preset file could not be read safely.");
    LARGE_INTEGER size{};
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 0 || static_cast<std::uint64_t>(size.QuadPart) > maximum)
        throw std::runtime_error("The preset file exceeds the size limit.");
    std::string contents(static_cast<std::size_t>(size.QuadPart), '\0');
    DWORD received = 0;
    if (!ReadFile(file, contents.data(), static_cast<DWORD>(contents.size()), &received, nullptr) || received != contents.size())
        throw std::runtime_error("The preset file could not be read completely.");
    return contents;
}

void Library::RecoverLegacy(OperationContext& context)
{
    const std::string journalPath = "Data/Recovery/Recovery Journal.txt";
    if (!fs::exists(SafePath(journalPath))) return;
    const auto journal = Read(journalPath, 1048576);
    auto fields = [](const std::string& line) {
        std::vector<std::string> values;
        std::size_t start = 0;
        while (true)
        {
            const auto end = line.find('\t', start);
            values.push_back(Decode(line.substr(start, end == std::string::npos ? end : end - start)));
            if (end == std::string::npos) return values;
            start = end + 1;
        }
    };
    const auto invalid = [] { throw std::runtime_error("An earlier file recovery record is invalid. Its files were kept."); };
    std::istringstream input(journal);
    std::string line, phase, operation;
    std::vector<std::vector<std::string>> plans;
    std::map<std::string, bool> folders;
    bool version = false;
    std::size_t count = 0;
    while (std::getline(input, line))
    {
        context.CheckCanceled();
        if (++count > 8192) invalid();
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;
        const auto parts = fields(line);
        if (parts[0] == "V" && parts.size() == 2 && parts[1] == "1" && !version) version = true;
        else if (parts[0] == "H" && parts.size() == 3 && phase.empty()) { phase = parts[1]; operation = parts[2]; }
        else if ((parts[0] == "P" || parts[0] == "R") && parts.size() == 4 &&
            Relative(parts[1]) && Relative(parts[2]) && Relative(parts[3]))
        {
            if (parts[0] == "P" && (parts[2].size() <= 7 || parts[2].size() > 71 ||
                parts[2].find('/') != std::string::npos || !Lower(parts[2]).ends_with(".preset"))) invalid();
            plans.push_back(parts);
        }
        else if (parts[0] == "D" && parts.size() == 3 && Relative(parts[1]) && (parts[2] == "0" || parts[2] == "1"))
            folders[parts[1]] = parts[2] == "1";
        else invalid();
    }
    if (!version || (phase != "prepared" && phase != "committed") ||
        (operation != "trash" && operation != "restore" && operation != "rename") || plans.empty()) invalid();
    std::set<std::string> used;
    for (const auto& plan : plans)
    {
        if ((operation == "rename") != (plan[0] == "R")) invalid();
        const auto source = "Character Presets/" + plan[1] + ".preset";
        const auto destination = plan[0] == "R" ? "Character Presets/" + plan[2] + ".preset" : "Data/Recovery/Trash/" + plan[2];
        if (!used.insert(Lower(source)).second || !used.insert(Lower(destination)).second) invalid();
        SafePath(source); SafePath(destination);
    }
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    std::vector<FileChange> changes;
    if (phase == "prepared")
    {
        std::map<std::string, std::string> assignments, originals;
        for (const auto& plan : plans)
        {
            context.CheckCanceled();
            const auto main = "Character Presets/" + plan[1] + ".preset";
            const auto other = plan[0] == "R" ? "Character Presets/" + plan[2] + ".preset" : "Data/Recovery/Trash/" + plan[2];
            const auto source = operation == "restore" ? main : other;
            const auto destination = operation == "restore" ? other : main;
            const bool hasSource = fs::exists(SafePath(source)), hasDestination = fs::exists(SafePath(destination));
            if (hasSource && hasDestination)
                throw std::runtime_error("Both copies of an unfinished file move still exist. Recovery could not choose which copy to use, so both were kept for review.");
            if (!hasSource && !hasDestination)
                throw std::runtime_error("A file needed for an unfinished move is missing. The recovery record was kept.");
            if (hasSource)
            {
                const auto contents = Read(source, MaximumPresetBytes);
                changes.push_back({destination, contents, std::nullopt, true});
                changes.push_back({source, std::nullopt, contents, true});
            }
            else Read(destination, MaximumPresetBytes);
            if (operation == "restore") originals[plan[2]] = plan[3];
            else assignments[plan[1]] = plan[3];
        }
        const std::string catalogPath = "Data/Catalog/Virtual Folders.txt";
        const std::string trashPath = "Data/Recovery/Trash Catalog.txt";
        auto patch = [&](const std::string& path, bool trash) {
            std::optional<std::string> before;
            if (fs::exists(SafePath(path))) before = Read(path, MaximumCatalogBytes);
            std::istringstream lines(before.value_or(""));
            std::string updated, row;
            std::size_t entries = 0;
            while (std::getline(lines, row))
            {
                if (++entries > MaximumCatalogLines) invalid();
                if (!row.empty() && row.back() == '\r') row.pop_back();
                if (row.empty()) continue;
                const auto parts = fields(row);
                bool valid = false, replace = false;
                if (trash)
                {
                    valid = parts[0] == "P" && (parts.size() == 3 || parts.size() == 4) &&
                        Relative(parts[1]) && parts[1].find('/') == std::string::npos && Lower(parts[1]).ends_with(".preset") && Relative(parts[2]);
                    valid = valid || ((parts[0] == "G" || parts[0] == "F" || parts[0] == "M") && parts.size() == 3 && !parts[1].empty() && Relative(parts[2]));
                    replace = parts[0] == "P" && parts.size() >= 2 && originals.contains(parts[1]);
                }
                else
                {
                    valid = parts[0] == "P" && parts.size() == 3 && Relative(parts[1]) && Relative(parts[2]);
                    valid = valid || ((parts[0] == "F" || parts[0] == "X") && parts.size() == 2 && Relative(parts[1]));
                    replace = parts[0] == "P" && parts.size() >= 2 && assignments.contains(parts[1]);
                    if (parts[0] == "X" && parts.size() == 2 && folders.contains(parts[1]) && folders.at(parts[1])) replace = true;
                }
                if (!valid) invalid();
                if (!replace) updated += row + '\n';
            }
            for (const auto& [storage, name] : trash ? originals : assignments)
                updated += "P\t" + Encode(storage) + '\t' + Encode(name) + '\n';
            if (!trash) for (const auto& [folder, manual] : folders)
            {
                static_cast<void>(manual);
                updated += "F\t" + Encode(folder) + '\n';
            }
            if (updated.size() > MaximumCatalogBytes || std::count(updated.begin(), updated.end(), '\n') > MaximumCatalogLines) invalid();
            if (updated != before.value_or("")) changes.push_back({path, updated, before, true});
        };
        if (!assignments.empty() || !folders.empty()) patch(catalogPath, false);
        if (!originals.empty()) patch(trashPath, true);
    }
    changes.push_back({journalPath, std::nullopt, journal, true});
    transaction.Apply(changes, context);
}

Json Library::Refresh(OperationContext& context)
{
    context.CheckCanceled();
    FileTransaction([this](const auto& path) { return SafePath(path); }).Recover();
    RecoverLegacy(context);
    Json assignments = Json::object(), folders = Json::object(), ignored = Json::object();
    const std::string catalogPath = "Data/Catalog/Virtual Folders.txt";
    std::optional<std::string> catalogContents;
    if (fs::exists(SafePath(catalogPath)))
    {
        catalogContents = Read(catalogPath, MaximumCatalogBytes);
        std::istringstream catalog(*catalogContents);
        std::string line;
        std::size_t lines = 0;
        while (std::getline(catalog, line))
        {
            context.CheckCanceled();
            if (++lines > MaximumCatalogLines) throw std::runtime_error("The folder list exceeds the entry limit.");
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.empty()) continue;
            const auto firstTab = line.find('\t');
            const auto secondTab = firstTab == std::string::npos ? firstTab : line.find('\t', firstTab + 1);
            const auto kind = line.substr(0, firstTab);
            const auto first = firstTab == std::string::npos ? "" : Decode(line.substr(firstTab + 1,
                secondTab == std::string::npos ? secondTab : secondTab - firstTab - 1));
            const auto second = secondTab == std::string::npos ? "" : Decode(line.substr(secondTab + 1));
            if (kind == "P" && Relative(first) && Relative(second)) assignments[first] = second;
            else if (kind == "F" && Relative(first) && second.empty()) Ancestors(folders, first);
            else if (kind == "X" && Relative(first) && second.empty()) ignored[first] = true;
            else throw std::runtime_error("The saved folder list is invalid. The previous library was kept.");
        }
    }
    std::map<std::string, File> nextFiles;
    std::set<std::string> physical;
    Json warnings = Json::array();
    const auto root = SafePath("Character Presets");
    std::size_t entryCount = 0;
    std::size_t visited = 0;
    if (fs::exists(root))
    {
        for (fs::recursive_directory_iterator iterator(root), end; iterator != end; ++iterator)
        {
            context.CheckCanceled();
            if (++visited > MaximumCatalogLines) throw std::runtime_error("The preset folder has too many items.");
            if (iterator.depth() > 12) throw std::runtime_error("The preset folders have more than 12 nested levels.");
            const auto relative = Utf8(iterator->path().lexically_relative(root));
            const auto path = SafePath("Character Presets/" + relative);
            if (iterator->is_directory())
            {
                if (relative == ".Character Preset Manager Trash") { iterator.disable_recursion_pending(); continue; }
                physical.insert(relative);
                continue;
            }
            if (!iterator->is_regular_file() || !Lower(relative).ends_with(".preset")) continue;
            if (nextFiles.size() >= MaximumPresets) throw std::runtime_error("The library exceeds the preset limit.");
            const auto storage = relative.substr(0, relative.size() - 7);
            const auto bytes = fs::file_size(path);
            const auto modified = fs::last_write_time(path);
            const auto previous = files_.find(storage);
            Json preset;
            if (previous != files_.end() && previous->second.bytes == bytes && previous->second.modified == modified)
                preset = previous->second.metadata;
            else
            {
                if (bytes > MaximumPresetBytes) { warnings.push_back(relative + ": exceeds the size limit."); continue; }
                const auto contents = Read("Character Presets/" + relative, MaximumPresetBytes);
                preset = ParsePreset(contents, true);
                if (!preset.is_null()) preset["fingerprint"] = Fingerprint(contents);
            }
            if (preset.is_null()) { warnings.push_back(relative + ": no supported appearance choices."); continue; }
            entryCount += preset.value("entryCount", std::size_t{});
            if (entryCount > MaximumEntries) throw std::runtime_error("The library exceeds the saved-choice limit.");
            preset["storage"] = storage;
            nextFiles.emplace(storage, File{bytes, modified, std::move(preset)});
            context.Progress(static_cast<std::uint32_t>(nextFiles.size()), 0);
        }
    }
    std::vector<std::string> storageNames;
    for (const auto& [storage, file] : nextFiles) { static_cast<void>(file); storageNames.push_back(storage); }
    std::sort(storageNames.begin(), storageNames.end(), [](const auto& a, const auto& b) {
        const auto left = Lower(a), right = Lower(b);
        return left == right ? a < b : left < right;
    });
    std::set<std::string> used;
    Json presets = Json::object(), manual = Json::object();
    for (const auto& storage : storageNames)
    {
        context.CheckCanceled();
        const auto& preset = nextFiles.at(storage).metadata;
        std::string preferred = assignments.value(storage, std::string{});
        if (preferred.empty() && preset.value("managedByCpm", false) && preset.contains("libraryFolder"))
        {
            const auto folder = preset.value("libraryFolder", std::string{});
            const auto name = preset.value("presetName", Leaf(storage));
            if ((folder.empty() || Relative(folder)) && Relative(name) && name.find('/') == std::string::npos)
                preferred = folder.empty() ? name : folder + '/' + name;
        }
        if (preferred.empty()) preferred = storage;
        auto name = preferred;
        for (unsigned int suffix = 2; used.contains(Lower(name)); ++suffix)
        {
            if (suffix > 9999) throw std::runtime_error("The mod could not find an unused preset name.");
            const auto tail = " " + std::to_string(suffix);
            const auto folder = Parent(preferred);
            name = (folder.empty() ? "" : folder + '/') + Leaf(preferred).substr(0, 64 - tail.size()) + tail;
        }
        used.insert(Lower(name));
        presets[name] = preset;
        Ancestors(folders, Parent(name));
        if (name == storage)
        {
            auto folder = Parent(name);
            while (!folder.empty()) { manual[folder] = true; ignored.erase(folder); folder = Parent(folder); }
        }
    }
    for (const auto& folder : physical) if (!ignored.contains(folder)) { Ancestors(folders, folder); Ancestors(manual, folder); }
    ValidateSize(presets, folders);
    context.CheckCanceled();
    if (presets != presets_ || folders != folders_ || manual != manualFolders_
        || ignored != ignoredFolders_ || catalogContents != catalogContents_)
    {
        ++revision_;
        queryCache_.clear();
        viewKey_.clear();
    }
    presets_ = std::move(presets);
    folders_ = std::move(folders);
    manualFolders_ = std::move(manual);
    ignoredFolders_ = std::move(ignored);
    files_ = std::move(nextFiles);
    catalogContents_ = std::move(catalogContents);
    return {{"revision", revision_}, {"count", presets_.size()}, {"folders", folders_.size()}, {"warnings", warnings}};
}

Json Library::Query(const Json& request)
{
    auto query = Lower(request.value("query", std::string{}));
    const auto first = query.find_first_not_of(" \t\r\n\v\f");
    query = first == std::string::npos ? "" : query.substr(first, query.find_last_not_of(" \t\r\n\v\f") - first + 1);
    const auto sort = request.value("sort", "name");
    const auto offset = request.value("offset", std::size_t{});
    const auto limit = std::min(request.value("limit", std::size_t{96}), std::size_t{256});
    const auto favorites = request.value("favoritesOnly", false);
    const auto cacheKey = Json::array({query, sort, favorites}).dump();
    if (!queryCache_.contains(cacheKey))
    {
        if (queryCache_.size() >= 16) queryCache_.clear();
        std::vector<std::string> names;
        for (const auto& [name, preset] : presets_.items())
            if ((!favorites || preset.value("favorite", false)) &&
                (Lower(name).find(query) != std::string::npos || Lower(preset.value("tags", std::string{})).find(query) != std::string::npos))
                names.push_back(name);
        std::sort(names.begin(), names.end(), [&](const auto& left, const auto& right) {
        if (sort == "modified")
        {
            const auto a = ModifiedTimestamp(presets_.at(left));
            const auto b = ModifiedTimestamp(presets_.at(right));
            if (a != b) return a > b;
        }
        const auto a = Lower(Leaf(left)), b = Lower(Leaf(right));
        return a == b ? left < right : a < b;
        });
        queryCache_.emplace(cacheKey, std::move(names));
    }
    const auto& names = queryCache_.at(cacheKey);
    Json rows = Json::array();
    std::size_t pageBytes = 0;
    for (std::size_t index = std::min(offset, names.size()); index < names.size() && rows.size() < limit; ++index)
    {
        Json row = {{"name", names[index]}, {"preset", presets_.at(names[index])}};
        const auto bytes = row.dump().size();
        if (bytes > 1048576) throw std::runtime_error("A preset's details exceed the display size limit.");
        if (pageBytes + bytes > 1048576) break;
        pageBytes += bytes;
        rows.push_back(std::move(row));
    }
    return {{"revision", revision_}, {"total", names.size()}, {"offset", offset}, {"rows", rows}};
}

Json Library::View(const Json& request)
{
    if (request.contains("revision") && request.at("revision") != revision_)
        throw std::runtime_error("The preset library changed. Refresh the list and try again.");
    const auto query = Lower(request.value("query", std::string{}));
    const auto first = query.find_first_not_of(" \t\r\n\v\f");
    const auto normalized = first == std::string::npos ? "" : query.substr(first, query.find_last_not_of(" \t\r\n\v\f") - first + 1);
    const auto sort = request.value("sort", "name");
    const auto favorites = request.value("favoritesOnly", false);
    const auto key = Json::array({normalized, sort, favorites}).dump();
    auto all = request;
    all["query"] = "";
    all["favoritesOnly"] = false;
    auto output = Query(all);
    for (auto& row : output["rows"])
    {
        const auto name = row.at("name").get<std::string>();
        const auto& preset = row.at("preset");
        row["folder"] = Parent(name);
        row["ancestors"] = Json::array();
        for (auto folder = Parent(name); !folder.empty(); folder = Parent(folder)) row["ancestors"].push_back(folder);
        row["matches"] = (!favorites || preset.value("favorite", false)) &&
            (Lower(name).find(normalized) != std::string::npos || Lower(preset.value("tags", "")).find(normalized) != std::string::npos);
    }
    if (viewKey_ != key)
    {
        Json counts = Json::object(), matching = Json::object(), nested = Json::object();
        for (const auto& [name, value] : folders_.items())
        {
            static_cast<void>(value);
            for (auto folder = Parent(name); !folder.empty(); folder = Parent(folder))
                nested[folder] = nested.value(folder, std::size_t{}) + 1;
        }
        for (const auto& [name, preset] : presets_.items())
        {
            const bool match = (!favorites || preset.value("favorite", false)) &&
                (Lower(name).find(normalized) != std::string::npos || Lower(preset.value("tags", "")).find(normalized) != std::string::npos);
            for (auto folder = Parent(name); !folder.empty(); folder = Parent(folder))
            {
                counts[folder] = counts.value(folder, std::size_t{}) + 1;
                if (match) matching[folder] = matching.value(folder, std::size_t{}) + 1;
            }
        }
        std::vector<std::string> names;
        for (const auto& [name, value] : folders_.items()) names.push_back(name);
        std::sort(names.begin(), names.end(), [](const auto& a, const auto& b) {
            const auto left = Lower(a), right = Lower(b);
            return left == right ? a < b : left < right;
        });
        viewFolders_ = Json::array();
        for (const auto& name : names)
            viewFolders_.push_back({{"name", name}, {"count", counts.value(name, std::size_t{})},
                {"matching", matching.value(name, std::size_t{})}, {"matches", Lower(name).find(normalized) != std::string::npos},
                {"nested", nested.value(name, std::size_t{})}});
        for (auto& folder : viewFolders_) folder["manual"] = manualFolders_.contains(folder.at("name").get<std::string>());
        viewKey_ = key;
    }
    const auto folderOffset = request.value("folderOffset", std::size_t{});
    const auto limit = std::min(request.value("limit", std::size_t{96}), std::size_t{256});
    output["folderRows"] = Json::array();
    for (auto index = std::min(folderOffset, viewFolders_.size()); index < viewFolders_.size() && output["folderRows"].size() < limit; ++index)
        output["folderRows"].push_back(viewFolders_[index]);
    output["folderOffset"] = folderOffset;
    output["folderTotal"] = viewFolders_.size();
    output["query"] = normalized;
    output["sort"] = sort;
    output["favoritesOnly"] = favorites;
    return output;
}

Json Library::Execute(const Json& request, OperationContext& context)
{
    const auto action = request.at("action").get<std::string>();
    if (action == "keys_save")
    {
        const auto editor = request.at("editorKey").get<int>(), panel = request.at("panelKey").get<int>();
        if (editor < 0 || editor > 65535 || panel < 0 || panel > 65535) throw std::runtime_error("Choose valid keys.");
        const std::string path = "Data/Config/Native Keys.txt";
        std::optional<std::string> before;
        if (fs::exists(SafePath(path))) before = Read(path, 128);
        FileTransaction([this](const auto& relative) { return SafePath(relative); }).Apply({{path, std::to_string(editor) + " " + std::to_string(panel) + "\n", before, true}}, context);
        return {{"editorKey", editor}, {"panelKey", panel}};
    }
    if (action == "refresh") return Refresh(context);
    if (action == "synchronize")
    {
        Refresh(context);
        const auto imported = ImportAcu(context);
        auto result = Refresh(context);
        result["imported"] = imported.value("imported", std::size_t{});
        return result;
    }
    if (action == "import_acu") return ImportAcu(context);
    if (action == "query") return Query(request);
    if (action == "view") return View(request);
    if (action == "config_read" || action == "config_save" || action == "inventory") return Preferences(request, context);
    if (action == "folders") return {{"revision", revision_}, {"folders", folders_}};
    if (action == "read")
    {
        const auto name = request.at("name").get<std::string>();
        if (!presets_.contains(name)) throw std::runtime_error("That preset is no longer available. Refresh the library.");
        const auto contents = CheckedContents(name);
        const auto fingerprint = Fingerprint(contents);
        if (request.contains("fingerprint") && request.at("fingerprint") != fingerprint)
            throw std::runtime_error("The selected preset changed. Refresh and select it again.");
        const auto preset = ParsePreset(contents);
        if (preset.is_null()) throw std::runtime_error("That preset could not be read safely.");
        return {{"revision", revision_}, {"name", name}, {"preset", preset}, {"fingerprint", fingerprint}};
    }
    if (action == "parse") return ParsePreset(request.at("contents").get<std::string>(), request.value("metadataOnly", false));
    if (action == "encode") return {{"contents", WritePreset(request.at("preset"))}};
    if (action == "compare") return CompareAppearance(request.at("preset"), request.at("options"));
    if (action == "plan_load" || action == "load_step") return PlanAppearance(request);
    if (action == "history" || action == "history_save" || action == "history_read" || action == "history_clear")
        return History(request, context);
    if (action == "trash_query" || action == "trash_move" || action == "trash_restore" || action == "trash_empty")
        return Trash(request, context);
    if (action == "archive_list" || action == "bundle_preview" || action == "backup_preview" || action == "bundle_info" || action == "backup_info" ||
        action == "bundle_export" || action == "backup_export" || action == "bundle_import" || action == "backup_import" || action == "backup_delete" || action == "bundle_trash" || action == "bundle_restore")
        return ArchiveAction(request, context);
    if (action == "save" || action == "metadata" || action == "favorite" || action == "duplicate" ||
        action == "rename" || action == "move" || action == "move_many" || action == "create_folder" || action == "rename_folder" || action == "duplicate_folder" || action == "remove_folder")
        return Mutate(request, context);
    throw std::runtime_error("This preset action is not supported. Install the complete Character Preset Manager package.");
}

std::string Library::Catalog(const Json& presets, const Json& folders, const Json& manual, const Json& ignored) const
{
    std::vector<std::string> lines;
    for (const auto& [name, preset] : presets.items())
        lines.push_back("P\t" + Encode(preset.at("storage").get<std::string>()) + '\t' + Encode(name));
    for (const auto& [name, value] : folders.items())
    {
        static_cast<void>(value);
        if (!manual.contains(name)) lines.push_back("F\t" + Encode(name));
    }
    for (const auto& [name, value] : ignored.items()) { static_cast<void>(value); lines.push_back("X\t" + Encode(name)); }
    if (lines.size() > MaximumCatalogLines) throw std::runtime_error("The folder list exceeds the entry limit.");
    std::sort(lines.begin(), lines.end(), [](const auto& a, const auto& b) { return Lower(a) < Lower(b); });
    std::string contents;
    for (const auto& line : lines) contents += line + '\n';
    if (contents.size() > MaximumCatalogBytes) throw std::runtime_error("The folder list exceeds the size limit.");
    return contents;
}

std::string Library::CheckedContents(const std::string& name) const
{
    if (!presets_.contains(name)) throw std::runtime_error("That preset is no longer available. Refresh the library.");
    const auto& preset = presets_.at(name);
    const auto contents = Read("Character Presets/" + preset.at("storage").get<std::string>() + ".preset", MaximumPresetBytes);
    if (Fingerprint(contents) != preset.value("fingerprint", std::string{}))
        throw std::runtime_error("That preset changed outside Character Preset Manager. Refresh before changing it.");
    return contents;
}

std::string Library::UniqueStorage(const std::string& leaf) const
{
    for (unsigned int index = 1; index < 10000; ++index)
    {
        const auto suffix = index == 1 ? "" : " " + std::to_string(index);
        const auto storage = leaf.substr(0, 64 - suffix.size()) + suffix;
        if (!fs::exists(SafePath("Character Presets/" + storage + ".preset"))) return storage;
    }
    throw std::runtime_error("A free preset file name could not be found.");
}

Json Library::Preferences(const Json& request, OperationContext& context)
{
    const auto action = request.at("action").get<std::string>();
    const std::string path = action == "inventory" ? "Data/Catalog/Preset Inventory.txt" : "Data/Config/Config.txt";
    std::optional<std::string> before;
    if (fs::exists(SafePath(path))) before = Read(path, action == "inventory" ? MaximumCatalogBytes : 16384);
    const auto fingerprint = Fingerprint(before.value_or(""));
    if (action == "config_read")
    {
        Json warnings = Json::array();
        std::string sort = "name", line;
        const std::set<std::string> retired = {"discoveryReminder", "clothingWarning", "activityLogDetail",
            "nativePanel", "historySize", "saveBeforeHistoryRestore", "comparisonDetails", "missingWarnings", "cetFallback"};
        const auto trim = [](const std::string& value) {
            const auto first = value.find_first_not_of(" \t\r\n\v\f");
            return first == std::string::npos ? std::string{} : value.substr(first, value.find_last_not_of(" \t\r\n\v\f") - first + 1);
        };
        std::istringstream input(before.value_or(""));
        while (std::getline(input, line))
        {
            line = trim(line);
            if (line.empty() || line.starts_with('#')) continue;
            const auto equals = line.find('=');
            const auto key = trim(line.substr(0, equals));
            const auto value = equals == std::string::npos ? "" : trim(line.substr(equals + 1));
            if (key == "presetSort" && (value == "name" || value == "modified")) sort = value;
            else if (!retired.contains(key)) warnings.push_back("An unsupported settings line was ignored: " + line);
        }
        return {{"preferences", {{"presetSort", sort}}}, {"found", before.has_value()}, {"fingerprint", fingerprint}, {"warnings", warnings}};
    }
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before changing saved files.");
    std::string contents;
    if (action == "config_save")
    {
        if (request.value("fingerprint", std::string{}) != fingerprint)
            throw std::runtime_error("Settings changed outside Character Preset Manager. Read them again before saving.");
        const auto sort = request.at("preferences").value("presetSort", "name");
        if (sort != "name" && sort != "modified") throw std::runtime_error("Choose name or date order for the preset list.");
        contents = "presetSort=" + sort + '\n';
    }
    else
    {
        if (!request.contains("revision") || request.at("revision") != revision_)
            throw std::runtime_error("The library changed. Refresh before saving its file list.");
        std::vector<std::string> lines;
        for (const auto& [name, preset] : presets_.items())
            lines.push_back("P2\t" + Encode(name) + '\t' + std::to_string(preset.value("entryCount", std::size_t{})) +
                '\t' + std::to_string(preset.value("format", 4)) + '\t' + Encode(preset.value("modified", "")) + '\t' + preset.value("fingerprint", "-"));
        for (const auto& [name, value] : folders_.items()) { static_cast<void>(value); lines.push_back("F:" + name); }
        std::sort(lines.begin(), lines.end(), [](const auto& a, const auto& b) { return Lower(a) < Lower(b); });
        for (const auto& line : lines) contents += line + '\n';
        if (lines.size() > MaximumCatalogLines || contents.size() > MaximumCatalogBytes)
            throw std::runtime_error("The preset file list exceeds the size limit.");
    }
    if (!before || contents != *before)
        FileTransaction([this](const auto& relative) { return SafePath(relative); }).Apply({{path, contents, before, true}}, context);
    return {{"fingerprint", Fingerprint(contents)}, {"saved", !before || contents != *before}, {"revision", revision_}};
}

Json Library::Mutate(const Json& request, OperationContext& context)
{
    if (!request.contains("revision") || request.at("revision") != revision_)
        throw std::runtime_error("The library changed. Refresh the selection before trying again.");
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before changing saved files.");
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    transaction.Recover();
    const std::string catalogPath = "Data/Catalog/Virtual Folders.txt";
    std::optional<std::string> currentCatalog;
    if (fs::exists(SafePath(catalogPath))) currentCatalog = Read(catalogPath, MaximumCatalogBytes);
    if (currentCatalog != catalogContents_)
        throw std::runtime_error("The saved folder list changed outside Character Preset Manager. Refresh before changing it.");
    const auto action = request.at("action").get<std::string>();
    const auto name = request.at("name").get<std::string>();
    if ((!Relative(name) && !(action == "move_many" && name.empty())) || Leaf(name).size() > 64)
        throw std::runtime_error("Enter a valid name of at most 64 characters.");
    auto presets = presets_, folders = folders_, manual = manualFolders_, ignored = ignoredFolders_;
    std::vector<FileChange> changes;
    std::string selected = name;
    auto patchFolder = [&](const std::string& oldName, const std::string& newName, const std::string& storage) {
        const auto contents = CheckedContents(oldName);
        auto preset = ParsePreset(contents);
        if (preset.is_null()) throw std::runtime_error("That preset could not be read safely.");
        if (preset.value("managedByCpm", false) && preset.value("format", 4) >= 8)
        {
            preset["presetName"] = Leaf(newName);
            preset["libraryFolder"] = Parent(newName);
            changes.push_back({"Character Presets/" + storage + ".preset", WritePreset(preset)});
        }
    };
    if (action == "create_folder")
    {
        if (ContainsName(folders, name)) throw std::runtime_error("That folder already exists.");
        Ancestors(folders, name);
        ignored.erase(name);
    }
    else if (action == "remove_folder")
    {
        if (!folders.contains(name)) throw std::runtime_error("That folder is no longer available.");
        const auto parent = Parent(name);
        const auto map = [&](const std::string& value) {
            return (parent.empty() ? "" : parent + '/') + value.substr(name.size() + 1);
        };
        Json updated = Json::object();
        std::set<std::string> used;
        for (const auto& [key, preset] : presets.items())
        {
            const auto next = key.starts_with(name + '/') ? map(key) : key;
            if (!used.insert(Lower(next)).second)
                throw std::runtime_error("Removing this folder would give two presets the same name.");
            if (next != key) patchFolder(key, next, preset.at("storage").get<std::string>());
            updated[next] = preset;
        }
        presets = std::move(updated);
        updated = Json::object();
        used.clear();
        for (const auto& [folder, value] : folders.items())
        {
            static_cast<void>(value);
            if (folder == name) { manual.erase(folder); ignored[folder] = true; continue; }
            const auto next = folder.starts_with(name + '/') ? map(folder) : folder;
            if (!used.insert(Lower(next)).second)
                throw std::runtime_error("Removing this folder would give two nested folders the same name.");
            Ancestors(updated, next);
            if (next != folder) { manual.erase(folder); ignored[folder] = true; }
        }
        folders = std::move(updated);
        selected = parent;
    }
    else if (action == "rename_folder")
    {
        const auto destination = request.at("destination").get<std::string>();
        if (!Relative(destination) || Leaf(destination).size() > 64 || !folders.contains(name) ||
            ContainsName(folders, destination, name) || Lower(destination).starts_with(Lower(name) + '/'))
            throw std::runtime_error("Choose an unused folder name outside the selected folder.");
        Json updated = Json::object();
        for (const auto& [oldName, preset] : presets.items())
        {
            const auto newName = Remap(oldName, name, destination);
            if (newName != oldName)
            {
                if (ContainsName(presets, newName, oldName)) throw std::runtime_error("The destination already contains a preset with that name.");
                patchFolder(oldName, newName, preset.at("storage").get<std::string>());
            }
            updated[newName] = preset;
        }
        presets = std::move(updated);
        updated = Json::object();
        for (const auto& [folder, value] : folders.items())
        {
            const auto next = Remap(folder, name, destination);
            Ancestors(updated, next);
            if (next != folder) { manual.erase(folder); ignored[folder] = true; }
        }
        folders = std::move(updated);
        selected = destination;
    }
    else if (action == "duplicate_folder")
    {
        if (!folders.contains(name)) throw std::runtime_error("Select an available folder first.");
        auto destination = request.value("destination", std::string{});
        if (destination.empty()) for (unsigned int index = 1; index < 10000; ++index)
        {
            const auto suffix = index == 1 ? " Copy" : " Copy " + std::to_string(index);
            destination = (Parent(name).empty() ? "" : Parent(name) + '/') + Leaf(name).substr(0, 64 - suffix.size()) + suffix;
            if (!ContainsName(folders, destination)) break;
        }
        if (!Relative(destination) || Leaf(destination).size() > 64 || ContainsName(folders, destination) ||
            Lower(destination).starts_with(Lower(name) + '/'))
            throw std::runtime_error("Choose an unused folder name outside the selected folder.");
        std::set<std::string> reserved;
        for (const auto& [storage, file] : files_) { static_cast<void>(file); reserved.insert(Lower(storage)); }
        auto allocate = [&](const std::string& leaf) {
            for (unsigned int index = 1; index < 10000; ++index)
            {
                const auto suffix = index == 1 ? "" : " " + std::to_string(index);
                const auto storage = leaf.substr(0, 64 - suffix.size()) + suffix;
                if (!reserved.contains(Lower(storage)) && !fs::exists(SafePath("Character Presets/" + storage + ".preset")))
                {
                    reserved.insert(Lower(storage));
                    return storage;
                }
            }
            throw std::runtime_error("A free preset file name could not be found.");
        };
        for (const auto& [oldName, preset] : presets_.items()) if (oldName.starts_with(name + '/'))
        {
            context.CheckCanceled();
            const auto mapped = Remap(oldName, name, destination);
            if (ContainsName(presets, mapped)) throw std::runtime_error("The copied folder would contain repeated preset names.");
            auto contents = CheckedContents(oldName);
            auto full = ParsePreset(contents);
            if (full.is_null()) throw std::runtime_error("A source preset could not be read safely.");
            if (full.value("managedByCpm", false) && full.value("format", 4) >= 8)
            {
                full["presetName"] = Leaf(mapped);
                full["libraryFolder"] = Parent(mapped);
                contents = WritePreset(full);
            }
            const auto storage = allocate(Leaf(mapped));
            changes.push_back({"Character Presets/" + storage + ".preset", contents});
            auto copy = preset;
            copy["storage"] = storage;
            presets[mapped] = std::move(copy);
        }
        for (const auto& [folder, value] : folders_.items())
        {
            static_cast<void>(value);
            if (folder == name || folder.starts_with(name + '/')) Ancestors(folders, Remap(folder, name, destination));
        }
        selected = destination;
    }
    else if (action == "move_many")
    {
        if (!name.empty() && !folders.contains(name)) throw std::runtime_error("Select an available destination folder.");
        const auto& names = request.at("names");
        if (!names.is_array() || names.empty() || names.size() > MaximumPresets)
            throw std::runtime_error("Select presets within the supported limit.");
        std::set<std::string> moved;
        for (const auto& value : names)
        {
            context.CheckCanceled();
            const auto oldName = value.get<std::string>();
            if (!presets_.contains(oldName) || !moved.insert(Lower(oldName)).second)
                throw std::runtime_error("The preset selection is missing or repeated. Refresh and select it again.");
            const auto destination = (name.empty() ? "" : name + '/') + Leaf(oldName);
            if (destination == oldName) continue;
            if (ContainsName(presets, destination)) throw std::runtime_error("The destination already contains a preset with that name.");
            auto preset = presets_.at(oldName);
            patchFolder(oldName, destination, preset.at("storage").get<std::string>());
            presets.erase(oldName);
            presets[destination] = std::move(preset);
        }
    }
    else if (action == "save" || action == "metadata" || action == "favorite")
    {
        const bool exists = presets.contains(name);
        if (action != "save" && !exists) throw std::runtime_error("Select an available preset first.");
        if (action == "save" && exists && !request.value("replace", false))
            throw std::runtime_error("That preset already exists. Confirm that you want to replace it before saving.");
        if (!exists && ContainsName(presets, name)) throw std::runtime_error("A preset with that name already exists.");
        Json preset;
        if (exists) preset = ParsePreset(CheckedContents(name));
        if (action == "save") preset = request.at("preset");
        if (!preset.is_object()) throw std::runtime_error("The appearance choices could not be read safely.");
        if (action == "metadata")
        {
            preset["notes"] = request.value("notes", std::string{});
            preset["tags"] = request.value("tags", std::string{});
        }
        if (action == "favorite") preset["favorite"] = !preset.value("favorite", false);
        preset["presetName"] = Leaf(name);
        preset["libraryFolder"] = Parent(name);
        preset["modified"] = Timestamp();
        if (!preset.contains("created")) preset["created"] = preset["modified"];
        const auto storage = exists ? presets.at(name).at("storage").get<std::string>() : UniqueStorage(Leaf(name));
        const auto contents = WritePreset(preset);
        if (ParsePreset(contents).is_null()) throw std::runtime_error("The saved preset did not pass verification.");
        changes.push_back({"Character Presets/" + storage + ".preset", contents});
        presets[name] = ParsePreset(contents, true);
        presets[name]["storage"] = storage;
        Ancestors(folders, Parent(name));
    }
    else
    {
        const auto contents = CheckedContents(name);
        auto destination = request.value("destination", std::string{});
        if (action == "duplicate" && destination.empty())
        {
            for (unsigned int index = 1; index < 10000; ++index)
            {
                const auto suffix = index == 1 ? " Copy" : " Copy " + std::to_string(index);
                destination = (Parent(name).empty() ? "" : Parent(name) + '/') + Leaf(name).substr(0, 64 - suffix.size()) + suffix;
                if (!ContainsName(presets, destination)) break;
            }
        }
        if (!Relative(destination) || Leaf(destination).size() > 64 || ContainsName(presets, destination, action == "duplicate" ? "" : name))
            throw std::runtime_error("Choose an unused preset name of at most 64 characters.");
        auto preset = presets.at(name);
        const auto oldStorage = preset.at("storage").get<std::string>();
        const auto storage = action == "move" ? oldStorage : UniqueStorage(Leaf(destination));
        if (action == "move") patchFolder(name, destination, storage);
        else
        {
            auto full = ParsePreset(contents);
            auto copy = contents;
            if (full.value("managedByCpm", false) && full.value("format", 4) >= 8)
            {
                full["presetName"] = Leaf(destination);
                full["libraryFolder"] = Parent(destination);
                copy = WritePreset(full);
            }
            changes.push_back({"Character Presets/" + storage + ".preset", copy});
            if (action == "rename") changes.push_back({"Character Presets/" + oldStorage + ".preset", std::nullopt});
        }
        if (action != "duplicate") presets.erase(name);
        preset["storage"] = storage;
        presets[destination] = preset;
        Ancestors(folders, Parent(destination));
        selected = destination;
    }
    ValidateSize(presets, folders);
    changes.push_back({"Data/Catalog/Virtual Folders.txt", Catalog(presets, folders, manual, ignored)});
    for (auto& change : changes)
    {
        change.checkExpected = true;
        if (change.path == catalogPath) change.expected = catalogContents_;
        else
        {
            const auto storage = change.path.substr(18, change.path.size() - 25);
            const auto previous = files_.find(storage);
            if (previous != files_.end())
            {
                auto original = Read(change.path, MaximumPresetBytes);
                if (Fingerprint(original) != previous->second.metadata.value("fingerprint", std::string{}))
                    throw std::runtime_error("A selected preset changed outside Character Preset Manager. Refresh before trying again.");
                change.expected = std::move(original);
            }
        }
    }
    transaction.Apply(changes, context);
    auto result = Refresh(context);
    result["selected"] = selected;
    result["message"] = "Library updated.";
    return result;
}

Json Library::ImportAcu(OperationContext& context)
{
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    transaction.Recover();
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before you import any more files.");
    const auto game = manager_.parent_path().parent_path().parent_path();
    const auto acu = manager_.parent_path().filename() == "plugins" && manager_.parent_path().parent_path().filename() == "red4ext"
        ? game / "bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker" : manager_.parent_path() / "AppearanceChangeUnlocker";
    Library source(acu);
    const auto sourceRoot = source.SafePath("character-presets");
    if (!fs::exists(sourceRoot)) return {{"imported", 0}, {"skipped", 0}, {"revision", revision_}, {"message", "No ACU preset folder was found."}};
    const std::string statePath = "Data/Catalog/Native ACU Imports.txt";
    std::optional<std::string> previous;
    Json records = Json::object();
    if (fs::exists(SafePath(statePath)))
    {
        previous = Read(statePath, MaximumCatalogBytes);
        records = Json::parse(*previous, [](int depth, Json::parse_event_t, Json&) {
            if (depth > 4) throw std::runtime_error("The ACU import record is invalid.");
            return true;
        });
        if (!records.is_object() || records.size() > MaximumPresets) throw std::runtime_error("The ACU import record exceeds its entry limit.");
        std::set<std::string> destinations;
        for (const auto& [name, record] : records.items())
            if (!Relative(name) || !Lower(name).ends_with(".preset") || !record.is_object() || !record.contains("destination") || !record["destination"].is_string() ||
                !Relative(record["destination"]) || !record["destination"].get<std::string>().starts_with("ACU Presets/") ||
                !Lower(record["destination"].get<std::string>()).ends_with(".preset") || !destinations.insert(Lower(record["destination"].get<std::string>())).second ||
                !record.contains("source") || !record["source"].is_string() || !record.contains("saved") || !record["saved"].is_string())
                throw std::runtime_error("The ACU import record contains an unsafe entry.");
    }
    std::vector<FileChange> changes;
    Json warnings = Json::array();
    std::size_t visited = 0, presets = 0, imported = 0, unchanged = 0;
    std::uintmax_t totalBytes = 0;
    Json projected = Json::object(), projectedFolders = folders_;
    for (const auto& [storage, file] : files_) projected[storage] = file.metadata;
    std::set<std::string> reserved;
    for (fs::recursive_directory_iterator iterator(sourceRoot), end; iterator != end; ++iterator)
    {
        context.CheckCanceled();
        if (++visited > MaximumCatalogLines || iterator.depth() > 11) throw std::runtime_error("The ACU preset folder exceeds the scan limits.");
        const auto relative = Utf8(iterator->path().lexically_relative(sourceRoot));
        const auto path = source.SafePath("character-presets/" + relative);
        if (!fs::is_regular_file(path) || !Lower(relative).ends_with(".preset")) continue;
        if (++presets > MaximumPresets) throw std::runtime_error("The ACU preset folder exceeds the preset limit.");
        const auto size = fs::file_size(path);
        if (size > MaximumPresetBytes) { warnings.push_back(relative + ": file exceeds the size limit."); continue; }
        const auto text = source.Read("character-presets/" + relative, MaximumPresetBytes);
        auto metadata = ParsePreset(text, true);
        if (metadata.is_null()) { warnings.push_back(relative + ": no supported appearance choices."); continue; }
        const auto fingerprint = Fingerprint(text);
        auto destination = records.contains(relative) ? records.at(relative).at("destination").get<std::string>() : "ACU Presets/" + relative;
        std::optional<std::string> existing;
        const auto target = "Character Presets/" + destination;
        if (fs::exists(SafePath(target))) existing = Read(target, MaximumPresetBytes);
        if (existing && *existing == text)
        {
            records[relative] = {{"destination", destination}, {"source", fingerprint}, {"saved", fingerprint}};
            ++unchanged;
            continue;
        }
        if (existing && records.contains(relative))
        {
            const auto& record = records.at(relative);
            if (Fingerprint(*existing) != record.at("saved").get<std::string>())
            {
                warnings.push_back(relative + ": the imported preset was edited; its contents were kept.");
                continue;
            }
        }
        else if (existing)
        {
            const auto folder = Parent(destination);
            const auto leaf = Leaf(destination);
            for (unsigned int index = 2; index < 10000; ++index)
            {
                const auto suffix = " " + std::to_string(index);
                destination = folder + '/' + leaf.substr(0, std::min(leaf.size() - 7, 64 - suffix.size())) + suffix + ".preset";
                if (!fs::exists(SafePath("Character Presets/" + destination)) && !reserved.contains(Lower(destination))) break;
            }
            if (fs::exists(SafePath("Character Presets/" + destination))) throw std::runtime_error("A free ACU import file name could not be found.");
            existing.reset();
        }
        if (!reserved.insert(Lower(destination)).second) throw std::runtime_error("Two ACU records refer to the same destination.");
        totalBytes += text.size() + (existing ? existing->size() : 0);
        if (totalBytes > 251658240) throw std::runtime_error("The ACU imports exceed the size limit for one action.");
        changes.push_back({"Character Presets/" + destination, text, existing, true});
        projected[destination.substr(0, destination.size() - 7)] = std::move(metadata);
        Ancestors(projectedFolders, Parent(destination));
        records[relative] = {{"destination", destination}, {"source", fingerprint}, {"saved", fingerprint}};
        ++imported;
        context.Progress(static_cast<std::uint32_t>(presets), 0);
    }
    ValidateSize(projected, projectedFolders);
    if (records.size() > MaximumPresets) throw std::runtime_error("The ACU import record exceeds its entry limit.");
    const auto updated = records.dump();
    if (updated.size() > MaximumCatalogBytes) throw std::runtime_error("The ACU import record exceeds the size limit.");
    if (!previous || updated != *previous) changes.push_back({statePath, updated, previous, true});
    transaction.Apply(changes, context);
    auto result = Refresh(context);
    result["imported"] = imported;
    result["unchanged"] = unchanged;
    result["skipped"] = warnings.size();
    result["details"] = warnings;
    result["message"] = "ACU preset scan finished.";
    return result;
}

Json Library::ArchiveAction(const Json& request, OperationContext& context)
{
    const auto action = request.at("action").get<std::string>();
    const bool backup = action.starts_with("backup_");
    const auto extension = backup ? ".cpmbackup" : ".cpmfolder";
    const std::size_t maximum = backup ? 268435456 : 33554432;
    const std::string catalogPath = "Data/Catalog/Virtual Folders.txt";
    const std::string configPath = "Data/Config/Config.txt";
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    transaction.Recover();
    if (action == "archive_list")
    {
        Json bundles = Json::array(), backups = Json::array();
        const auto root = SafePath("Character Presets");
        std::size_t visited = 0;
        if (fs::exists(root)) for (const auto& entry : fs::directory_iterator(root))
        {
            context.CheckCanceled();
            if (++visited > MaximumCatalogLines) throw std::runtime_error("The preset folder has too many items.");
            const auto name = Utf8(entry.path().filename());
            if (!fs::is_regular_file(SafePath("Character Presets/" + name))) continue;
            if (Lower(name).ends_with(".cpmfolder")) bundles.push_back(name);
            if (Lower(name).ends_with(".cpmbackup")) backups.push_back(name);
        }
        std::sort(bundles.begin(), bundles.end());
        std::sort(backups.begin(), backups.end());
        return {{"bundles", bundles}, {"backups", backups}, {"revision", revision_}};
    }
    const bool exporting = action.ends_with("_export");
    std::string filename, text;
    Archive archive;
    if (!exporting)
    {
        filename = request.at("filename").get<std::string>();
        if (!Relative(filename) || filename.find('/') != std::string::npos || !Lower(filename).ends_with(extension))
            throw std::runtime_error("Select a valid shared file from Character Presets.");
        text = Read((action == "bundle_restore" ? "Data/Recovery/Trash/" : "Character Presets/") + filename, maximum);
        const auto fingerprint = Fingerprint(text);
        if (action.ends_with("_info")) return {{"filename", filename}, {"fingerprint", fingerprint}, {"revision", revision_}};
        if (action.ends_with("_preview"))
        {
            archive = ReadArchive(text, backup);
            Json names = Json::array(), folders = Json::array();
            for (const auto& [name, contents] : archive.presets) { static_cast<void>(contents); names.push_back(name); }
            for (const auto& folder : archive.folders) folders.push_back(folder);
            return {{"filename", filename}, {"root", archive.root}, {"names", names}, {"folders", folders}, {"fingerprint", fingerprint}, {"revision", revision_}};
        }
        if (request.value("fingerprint", std::string{}) != fingerprint)
            throw std::runtime_error("The selected shared file changed. Open its preview again before you continue.");
        if (action != "backup_delete" && action != "bundle_trash" && action != "bundle_restore") archive = ReadArchive(text, backup);
    }
    if (request.value("revision", std::uint64_t{}) != revision_)
        throw std::runtime_error("The library changed. Refresh before trying again.");
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before changing saved files.");
    std::optional<std::string> currentCatalog;
    if (fs::exists(SafePath(catalogPath))) currentCatalog = Read(catalogPath, MaximumCatalogBytes);
    if (currentCatalog != catalogContents_) throw std::runtime_error("The saved folder list changed. Refresh before trying again.");
    if (action == "bundle_trash" || action == "bundle_restore")
    {
        const std::string source = action == "bundle_trash" ? "Character Presets/" : "Data/Recovery/Trash/";
        const std::string destination = action == "bundle_trash" ? "Data/Recovery/Trash/" : "Character Presets/";
        const auto stem = filename.substr(0, filename.size() - 10);
        std::string target;
        for (unsigned int index = 1; index < 10000; ++index)
        {
            const auto suffix = index == 1 ? "" : " " + std::to_string(index);
            target = stem.substr(0, 245 - suffix.size()) + suffix + ".cpmfolder";
            if (!fs::exists(SafePath(destination + target))) break;
        }
        if (fs::exists(SafePath(destination + target))) throw std::runtime_error("An unused shared-folder file name could not be found.");
        transaction.Apply({{destination + target, text, std::nullopt, true}, {source + filename, std::nullopt, text, true}}, context);
        return {{"filename", target}, {"fingerprint", Fingerprint(text)}, {"revision", revision_}, {"message", action == "bundle_trash" ? "Shared-folder file moved to Trash." : "Shared-folder file restored."}};
    }
    if (action == "backup_delete")
    {
        if (!request.value("confirmed", false)) throw std::runtime_error("Confirm permanently deleting the selected backup.");
        transaction.Apply({{"Character Presets/" + filename, std::nullopt, text, true}}, context);
        return {{"filename", filename}, {"revision", revision_}, {"message", "Library backup deleted."}};
    }
    if (exporting)
    {
        archive.backup = backup;
        const auto folder = request.value("folder", std::string{});
        if (!backup && !folder.empty() && !folders_.contains(folder)) throw std::runtime_error("Select an available folder first.");
        archive.root = folder.empty() ? request.value("label", "Shared Presets") : Leaf(folder);
        if (backup) archive.config = fs::exists(SafePath(configPath)) ? Read(configPath, MaximumCatalogBytes) : "presetSort=name\n";
        auto names = request.value("names", Json::array());
        if (backup || !folder.empty())
        {
            names = Json::array();
            for (const auto& [name, preset] : presets_.items())
            {
                static_cast<void>(preset);
                if (backup || name.starts_with(folder + '/')) names.push_back(name);
            }
            for (const auto& [name, value] : folders_.items())
            {
                static_cast<void>(value);
                if (backup) archive.folders.insert(name);
                else if (name.starts_with(folder + '/')) archive.folders.insert(name.substr(folder.size() + 1));
            }
        }
        if (!names.is_array() || names.empty()) throw std::runtime_error("Select at least one preset to export.");
        for (const auto& item : names)
        {
            context.CheckCanceled();
            const auto name = item.get<std::string>();
            const auto relative = !backup && !folder.empty() ? name.substr(folder.size() + 1) : name;
            if (!archive.presets.emplace(relative, CheckedContents(name)).second) throw std::runtime_error("The export selection contains a repeated preset.");
        }
        text = WriteArchive(archive);
        const auto stem = backup ? "Character Preset Manager Library Backup" : "Character Preset Manager Folder - " + archive.root;
        for (unsigned int index = 1; index < 1000; ++index)
        {
            filename = stem + (index == 1 ? "" : " Copy " + std::to_string(index)) + extension;
            if (!fs::exists(SafePath("Character Presets/" + filename)) && !fs::exists(SafePath("Character Presets/" + filename + ".tmp")) && !fs::exists(SafePath("Character Presets/" + filename + ".bak"))) break;
        }
        if (fs::exists(SafePath("Character Presets/" + filename)) || fs::exists(SafePath("Character Presets/" + filename + ".tmp")) ||
            fs::exists(SafePath("Character Presets/" + filename + ".bak"))) throw std::runtime_error("An unused export file name could not be found.");
        transaction.Apply({{"Character Presets/" + filename, text, std::nullopt, true}}, context);
        return {{"filename", filename}, {"fingerprint", Fingerprint(text)}, {"revision", revision_}, {"count", archive.presets.size()}, {"message", backup ? "Library backup saved." : "Shared-folder file saved."}};
    }
    const std::string registryPath = "Data/Catalog/Imported Bundles.txt";
    std::optional<std::string> registryContents;
    Json registry = Json::object();
    if (!backup)
    {
        if (fs::exists(SafePath(registryPath)))
        {
            registryContents = Read(registryPath, MaximumCatalogBytes);
            std::istringstream records(*registryContents);
            std::string line;
            std::size_t count = 0;
            while (std::getline(records, line))
            {
                if (++count > MaximumCatalogLines) throw std::runtime_error("The imported-folder list has too many records.");
                if (!line.empty() && line.back() == '\r') line.pop_back();
                if (line.empty()) continue;
                std::istringstream fields(line);
                std::string kind, encoded, fingerprint, root;
                std::getline(fields, kind, '\t'); std::getline(fields, encoded, '\t');
                std::getline(fields, fingerprint, '\t'); std::getline(fields, root);
                const auto name = Decode(encoded);
                root = Decode(root);
                const auto colonCount = std::count(fingerprint.begin(), fingerprint.end(), ':');
                if (kind != "B" || !Relative(name) || name.find('/') != std::string::npos || !Lower(name).ends_with(".cpmfolder") ||
                    (colonCount != 1 && (colonCount != 3 || !fingerprint.starts_with("2:"))) ||
                    fingerprint.empty() || fingerprint.front() == ':' || fingerprint.back() == ':' || fingerprint.find("::") != std::string::npos ||
                    std::any_of(fingerprint.begin(), fingerprint.end(), [](char c) { return (c < '0' || c > '9') && c != ':'; }) ||
                    (!root.empty() && !Relative(root)))
                    throw std::runtime_error("The imported-folder list is invalid. Your shared folders were kept as they were.");
                registry[Lower(name)] = {{"filename", name}, {"fingerprint", fingerprint}, {"root", root}};
            }
        }
        const auto current = Fingerprint(text);
        const auto legacy = current.substr(2, current.find_last_of(':') - 2);
        if (registry.contains(Lower(filename)))
        {
            const auto& previous = registry.at(Lower(filename));
            const auto saved = previous.at("fingerprint").get<std::string>();
            const auto root = previous.at("root").get<std::string>();
            if ((saved == current || saved == legacy) && folders_.contains(root))
                return {{"root", root}, {"imported", 0}, {"revision", revision_}, {"message", "This shared folder is already installed."}};
        }
    }
    auto presets = presets_, folders = folders_;
    bool needsRoot = !backup;
    for (const auto& name : archive.folders) if (ContainsName(folders, name)) needsRoot = true;
    for (const auto& [name, contents] : archive.presets) { static_cast<void>(contents); if (ContainsName(presets, name)) needsRoot = true; }
    std::string root;
    if (needsRoot)
    {
        const std::string base = backup ? "Imported Library" : archive.root;
        for (unsigned int index = 1; index < 1000; ++index)
        {
            const auto suffix = index == 1 ? "" : " Copy " + std::to_string(index);
            root = base.substr(0, 64 - suffix.size()) + suffix;
            if (!ContainsName(folders, root) && !ContainsName(presets, root)) break;
        }
        if (ContainsName(folders, root) || ContainsName(presets, root)) throw std::runtime_error("A free import folder name could not be found.");
        Ancestors(folders, root);
    }
    const auto prefix = root.empty() ? "" : root + '/';
    for (const auto& folder : archive.folders) Ancestors(folders, prefix + folder);
    std::vector<FileChange> changes;
    std::set<std::string> reserved;
    for (const auto& [name, contents] : archive.presets)
    {
        context.CheckCanceled();
        auto metadata = ParsePreset(contents, true);
        if (metadata.is_null()) throw std::runtime_error("A preset in the shared file could not be read safely. No presets were imported.");
        std::string storage;
        for (unsigned int index = 1; index < 10000; ++index)
        {
            const auto suffix = index == 1 ? "" : " " + std::to_string(index);
            storage = Leaf(name).substr(0, 64 - suffix.size()) + suffix;
            if (!fs::exists(SafePath("Character Presets/" + storage + ".preset")) && !reserved.contains(Lower(storage))) break;
        }
        if (fs::exists(SafePath("Character Presets/" + storage + ".preset")) || !reserved.insert(Lower(storage)).second)
            throw std::runtime_error("A free imported preset file name could not be found.");
        changes.push_back({"Character Presets/" + storage + ".preset", contents, std::nullopt, true});
        metadata["storage"] = storage;
        presets[prefix + name] = std::move(metadata);
        Ancestors(folders, Parent(prefix + name));
    }
    ValidateSize(presets, folders);
    changes.push_back({catalogPath, Catalog(presets, folders, manualFolders_, ignoredFolders_), catalogContents_, true});
    if (backup && request.value("restoreSettings", true))
    {
        std::optional<std::string> previous;
        if (fs::exists(SafePath(configPath))) previous = Read(configPath, MaximumCatalogBytes);
        changes.push_back({configPath, archive.config, previous, true});
    }
    if (!backup)
    {
        registry[Lower(filename)] = {{"filename", filename}, {"fingerprint", Fingerprint(text)}, {"root", root}};
        if (registry.size() > MaximumCatalogLines) throw std::runtime_error("The imported-folder list has too many records.");
        std::string updated;
        for (const auto& [key, item] : registry.items())
        {
            static_cast<void>(key);
            updated += "B\t" + Encode(item.at("filename").get<std::string>()) + '\t' + item.at("fingerprint").get<std::string>();
            if (!item.at("root").get<std::string>().empty()) updated += '\t' + Encode(item.at("root").get<std::string>());
            updated += '\n';
        }
        if (updated.size() > MaximumCatalogBytes) throw std::runtime_error("The imported-folder list exceeds the size limit.");
        changes.push_back({registryPath, updated, registryContents, true});
    }
    transaction.Apply(changes, context);
    auto result = Refresh(context);
    result["root"] = root;
    result["imported"] = archive.presets.size();
    result["message"] = backup ? "Library backup imported." : "Shared folder imported.";
    return result;
}

Json Library::Trash(const Json& request, OperationContext& context)
{
    if (request.at("action") == "trash_query" && request.value("offset", std::size_t{}) > 0)
    {
        if (trashView_.empty() || request.value("fingerprint", std::string{}) != trashView_.value("fingerprint", std::string{}))
            throw std::runtime_error("The Trash list changed. Refresh before reading the next page.");
        auto result = trashView_;
        result["items"] = Json::object();
        const auto offset = request.at("offset").get<std::size_t>();
        const auto limit = std::min(request.value("limit", std::size_t{96}), std::size_t{256});
        std::size_t index = 0;
        for (const auto& [name, item] : trashView_.at("items").items())
            if (index++ >= offset && result["items"].size() < limit) result["items"][name] = item;
        result["offset"] = offset;
        return result;
    }
    const std::string directory = "Data/Recovery/Trash/";
    const std::string trashCatalogPath = "Data/Recovery/Trash Catalog.txt";
    const std::string libraryCatalogPath = "Data/Catalog/Virtual Folders.txt";
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    transaction.Recover();
    Json items = Json::object(), groups = Json::object(), bundles = Json::object();
    std::optional<std::string> catalog;
    auto validFilename = [](const std::string& name) {
        return Relative(name) && name.find('/') == std::string::npos && name.size() > 7 && name.size() <= 71 && Lower(name).ends_with(".preset");
    };
    if (fs::exists(SafePath(trashCatalogPath)))
    {
        catalog = Read(trashCatalogPath, MaximumCatalogBytes);
        std::istringstream input(*catalog);
        std::string line;
        std::size_t count = 0;
        while (std::getline(input, line))
        {
            context.CheckCanceled();
            if (++count > MaximumCatalogLines) throw std::runtime_error("The Trash list exceeds the entry limit.");
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.empty()) continue;
            std::istringstream fields(line);
            std::string kind, first, second, third;
            std::getline(fields, kind, '\t');
            std::getline(fields, first, '\t');
            std::getline(fields, second, '\t');
            std::getline(fields, third);
            first = Decode(first); second = Decode(second); third = Decode(third);
            if (kind == "P" && validFilename(first) && Relative(second) && third.size() <= 256)
                items[first] = {{"original", second}, {"group", third}};
            else if ((kind == "G" || kind == "F" || kind == "M") && !first.empty() && first.size() <= 256 && Relative(second) && third.empty())
            {
                if (!groups.contains(first)) groups[first] = {{"root", second}, {"folders", Json::object()}, {"manualFolders", Json::object()}};
                if (kind == "G") groups[first]["root"] = second;
                else groups[first][kind == "F" ? "folders" : "manualFolders"][second] = true;
            }
            else throw std::runtime_error("The saved Trash list is invalid. Its files were kept.");
        }
    }
    for (const auto& [name, item] : items.items())
    {
        static_cast<void>(name);
        const auto group = item.value("group", std::string{});
        if (!group.empty() && !groups.contains(group)) throw std::runtime_error("The Trash list refers to a missing folder group.");
    }
    std::map<std::string, std::string> originalContents;
    Json found = Json::object();
    std::string identity = catalog.value_or("");
    const auto root = SafePath("Data/Recovery/Trash");
    if (fs::exists(root))
    {
        std::size_t visited = 0;
        std::uintmax_t totalBytes = 0;
        for (const auto& entry : fs::directory_iterator(root))
        {
            context.CheckCanceled();
            if (++visited > MaximumCatalogLines) throw std::runtime_error("Trash has too many items.");
            const auto name = Utf8(entry.path().filename());
            const auto path = SafePath(directory + name);
            if (!fs::is_regular_file(path)) continue;
            const bool bundle = Lower(name).ends_with(".cpmfolder");
            if (!bundle && !validFilename(name)) continue;
            if (originalContents.size() >= MaximumPresets) throw std::runtime_error("Trash exceeds the file limit.");
            totalBytes += fs::file_size(path);
            if (totalBytes > 268435456) throw std::runtime_error("Trash exceeds the size limit for one action.");
            const auto text = Read(directory + name, bundle ? 33554432 : MaximumPresetBytes);
            originalContents[name] = text;
            if (bundle) bundles[name] = {{"fingerprint", Fingerprint(text)}};
            else
            {
                auto item = items.contains(name) ? items.at(name) : Json{{"original", name.substr(0, name.size() - 7)}, {"group", ""}};
                item["preset"] = ParsePreset(text, true);
                item["fingerprint"] = Fingerprint(text);
                found[name] = item;
            }
        }
    }
    for (const auto& [name, text] : originalContents) identity += '\n' + name + ':' + Fingerprint(text);
    items = std::move(found);
    const auto fingerprint = Fingerprint(identity);
    const auto action = request.at("action").get<std::string>();
    if (action == "trash_query")
    {
        trashView_ = {{"items", items}, {"total", items.size()}, {"offset", 0}, {"groups", groups},
            {"bundles", bundles}, {"fingerprint", fingerprint}, {"revision", revision_}};
        Json names = Json::array(), groupNames = Json::array(), bundleNames = Json::array(), statistics = Json::object();
        std::vector<std::string> sorted;
        for (const auto& [name, item] : items.items())
        {
            sorted.push_back(name);
            const auto group = item.value("group", "");
            if (!group.empty())
            {
                if (!statistics.contains(group)) statistics[group] = {{"presets", 0}, {"folders", 0}};
                statistics[group]["presets"] = statistics[group]["presets"].get<std::size_t>() + 1;
            }
        }
        const auto byName = [](const auto& a, const auto& b) { const auto x = Lower(a), y = Lower(b); return x == y ? a < b : x < y; };
        std::sort(sorted.begin(), sorted.end(), byName);
        for (const auto& name : sorted) names.push_back(name);
        sorted.clear();
        for (const auto& [name, group] : groups.items())
        {
            sorted.push_back(name);
            if (!statistics.contains(name)) statistics[name] = {{"presets", 0}, {"folders", 0}};
            statistics[name]["folders"] = group.at("folders").size();
        }
        std::sort(sorted.begin(), sorted.end(), [&](const auto& a, const auto& b) {
            const auto x = Lower(groups.at(a).at("root").get<std::string>()), y = Lower(groups.at(b).at("root").get<std::string>());
            return x == y ? a < b : x < y;
        });
        for (const auto& name : sorted) groupNames.push_back(name);
        sorted.clear();
        for (const auto& [name, value] : bundles.items()) { static_cast<void>(value); sorted.push_back(name); }
        std::sort(sorted.begin(), sorted.end(), byName);
        for (const auto& name : sorted) bundleNames.push_back(name);
        trashView_["names"] = names; trashView_["groupNames"] = groupNames; trashView_["bundleNames"] = bundleNames;
        trashView_["statistics"] = statistics;
        Json page = Json::object();
        const auto offset = request.value("offset", std::size_t{});
        const auto limit = std::min(request.value("limit", std::size_t{96}), std::size_t{256});
        std::size_t index = 0;
        for (const auto& [name, item] : items.items())
            if (index++ >= offset && page.size() < limit) page[name] = item;
        auto result = trashView_;
        result["items"] = page;
        result["offset"] = offset;
        return result;
    }
    if (request.value("fingerprint", std::string{}) != fingerprint)
        throw std::runtime_error("Trash changed. Refresh it before trying again.");
    if (request.value("revision", std::uint64_t{}) != revision_)
        throw std::runtime_error("The library changed. Refresh before trying again.");
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before changing saved files.");
    std::optional<std::string> currentCatalog;
    if (fs::exists(SafePath(libraryCatalogPath))) currentCatalog = Read(libraryCatalogPath, MaximumCatalogBytes);
    if (currentCatalog != catalogContents_) throw std::runtime_error("The saved folder list changed. Refresh before trying again.");
    auto presets = presets_, folders = folders_, manual = manualFolders_, ignored = ignoredFolders_;
    std::vector<FileChange> changes;
    Json selected = Json::array();
    if (action == "trash_move")
    {
        if (!request.value("confirmed", false)) throw std::runtime_error("Confirm moving the selected items to Trash.");
        const auto folder = request.value("folder", std::string{});
        auto names = request.value("names", Json::array());
        if (!names.is_array()) throw std::runtime_error("The selected preset list is invalid.");
        if (!folder.empty())
        {
            if (!Relative(folder) || !folders.contains(folder)) throw std::runtime_error("That folder is no longer available.");
            names = Json::array();
            for (const auto& [name, value] : presets.items())
            {
                static_cast<void>(value);
                if (name.starts_with(folder + '/')) names.push_back(name);
            }
        }
        if (names.size() > MaximumPresets || (names.empty() && folder.empty())) throw std::runtime_error("Select presets or a folder first.");
        std::set<std::string> reserved;
        std::string groupId;
        if (!folder.empty())
        {
            for (std::size_t index = 1; index <= MaximumCatalogLines; ++index)
            {
                groupId = "Folder " + std::to_string(index);
                if (!groups.contains(groupId)) break;
            }
            if (groups.contains(groupId)) throw std::runtime_error("Trash has too many saved folder groups.");
            groups[groupId] = {{"root", folder}, {"folders", Json::object()}, {"manualFolders", Json::object()}};
            std::vector<std::string> removed;
            for (const auto& [name, value] : folders.items())
            {
                static_cast<void>(value);
                if (name == folder || name.starts_with(folder + '/')) removed.push_back(name);
            }
            for (const auto& name : removed)
            {
                groups[groupId]["folders"][name] = true;
                if (manual.contains(name)) groups[groupId]["manualFolders"][name] = true;
                folders.erase(name); manual.erase(name); ignored[name] = true;
            }
        }
        for (const auto& value : names)
        {
            context.CheckCanceled();
            const auto name = value.get<std::string>();
            const auto text = CheckedContents(name);
            const auto storage = presets.at(name).at("storage").get<std::string>();
            std::string filename;
            for (std::size_t index = 1; index < 10000; ++index)
            {
                const auto suffix = index == 1 ? "" : " " + std::to_string(index);
                filename = Leaf(name).substr(0, 64 - suffix.size()) + suffix + ".preset";
                if (!fs::exists(SafePath(directory + filename)) && !reserved.contains(Lower(filename))) break;
            }
            if (fs::exists(SafePath(directory + filename)) || !reserved.insert(Lower(filename)).second)
                throw std::runtime_error("A free Trash file name could not be found.");
            changes.push_back({directory + filename, text, std::nullopt, true});
            changes.push_back({"Character Presets/" + storage + ".preset", std::nullopt, text, true});
            items[filename] = {{"original", name}, {"group", groupId}};
            presets.erase(name);
            selected.push_back(filename);
        }
    }
    else if (action == "trash_restore")
    {
        std::vector<std::string> names;
        const auto groupId = request.value("group", std::string{});
        if (!groupId.empty())
        {
            if (!groups.contains(groupId)) throw std::runtime_error("That saved folder group is no longer available.");
            for (const auto& [name, item] : items.items()) if (item.value("group", "") == groupId) names.push_back(name);
            for (const auto& [name, value] : groups.at(groupId).at("folders").items())
            {
                static_cast<void>(value);
                Ancestors(folders, name); ignored.erase(name);
            }
            groups.erase(groupId);
        }
        else names.push_back(request.at("filename").get<std::string>());
        std::set<std::string> reserved;
        for (const auto& filename : names)
        {
            context.CheckCanceled();
            if (!items.contains(filename)) throw std::runtime_error("That preset is no longer in Trash.");
            const auto original = items.at(filename).at("original").get<std::string>();
            auto destination = original;
            for (unsigned int index = 1; ContainsName(presets, destination) && index < 10000; ++index)
            {
                const auto suffix = " Restored " + std::to_string(index);
                destination = (Parent(original).empty() ? "" : Parent(original) + '/') + Leaf(original).substr(0, 64 - suffix.size()) + suffix;
            }
            if (ContainsName(presets, destination)) throw std::runtime_error("A free restored preset name could not be found.");
            std::string storage;
            for (unsigned int index = 1; index < 10000; ++index)
            {
                const auto suffix = index == 1 ? "" : " " + std::to_string(index);
                storage = Leaf(destination).substr(0, 64 - suffix.size()) + suffix;
                if (!fs::exists(SafePath("Character Presets/" + storage + ".preset")) && !reserved.contains(Lower(storage))) break;
            }
            if (fs::exists(SafePath("Character Presets/" + storage + ".preset")) || !reserved.insert(Lower(storage)).second)
                throw std::runtime_error("A free restored preset file name could not be found.");
            const auto& text = originalContents.at(filename);
            auto metadata = ParsePreset(text, true);
            if (metadata.is_null()) throw std::runtime_error("A preset in Trash could not be read safely. Its file was kept.");
            changes.push_back({"Character Presets/" + storage + ".preset", text, std::nullopt, true});
            changes.push_back({directory + filename, std::nullopt, text, true});
            items.erase(filename);
            metadata["storage"] = storage;
            presets[destination] = std::move(metadata);
            Ancestors(folders, Parent(destination));
            selected.push_back(destination);
        }
    }
    else
    {
        if (!request.value("confirmed", false)) throw std::runtime_error("Confirm permanently emptying Trash.");
        for (const auto& [filename, text] : originalContents) changes.push_back({directory + filename, std::nullopt, text, true});
        items.clear(); groups.clear(); bundles.clear();
    }
    ValidateSize(presets, folders);
    std::vector<std::string> lines;
    for (const auto& [filename, item] : items.items())
        lines.push_back("P\t" + Encode(filename) + '\t' + Encode(item.at("original").get<std::string>()) + '\t' + Encode(item.value("group", "")));
    for (const auto& [id, group] : groups.items())
    {
        lines.push_back("G\t" + Encode(id) + '\t' + Encode(group.at("root").get<std::string>()));
        for (const auto& [name, value] : group.at("folders").items()) { static_cast<void>(value); lines.push_back("F\t" + Encode(id) + '\t' + Encode(name)); }
        for (const auto& [name, value] : group.at("manualFolders").items()) { static_cast<void>(value); lines.push_back("M\t" + Encode(id) + '\t' + Encode(name)); }
    }
    if (lines.size() > MaximumCatalogLines) throw std::runtime_error("The Trash list exceeds the entry limit.");
    std::sort(lines.begin(), lines.end());
    std::string updated;
    for (const auto& line : lines) updated += line + '\n';
    if (updated.size() > MaximumCatalogBytes) throw std::runtime_error("The Trash list exceeds the size limit.");
    changes.push_back({trashCatalogPath, updated, catalog, true});
    changes.push_back({libraryCatalogPath, Catalog(presets, folders, manual, ignored), catalogContents_, true});
    transaction.Apply(changes, context);
    auto result = Refresh(context);
    result["selected"] = selected;
    result["message"] = action == "trash_move" ? "Selected items moved to Trash." : action == "trash_restore" ? "Selected items restored from Trash." : "Trash emptied permanently.";
    return result;
}

Json Library::History(const Json& request, OperationContext& context)
{
    const auto action = request.at("action").get<std::string>();
    FileTransaction transaction([this](const auto& path) { return SafePath(path); });
    transaction.Recover();
    auto historyPath = [](int index) {
        return "Data/Recovery/Appearance History/Appearance " + std::to_string(index) + ".preset";
    };
    const std::string lastPath = "Data/Recovery/LastAppearance.preset";
    Json entries = Json::array();
    std::map<int, std::string> contents;
    std::string identity;
    for (int index = 0; index <= 10; ++index)
    {
        context.CheckCanceled();
        const auto path = index == 0 ? lastPath : historyPath(index);
        if (!fs::exists(SafePath(path))) continue;
        auto text = Read(path, MaximumPresetBytes);
        identity += std::to_string(index) + ':' + Fingerprint(text) + '\n';
        auto preset = ParsePreset(text, true);
        if (index >= 1 && index <= 5 && !preset.is_null())
            entries.push_back({{"index", index}, {"preset", preset}});
        contents.emplace(index, std::move(text));
    }
    const auto fingerprint = Fingerprint(identity);
    if (action == "history")
        return {{"entries", entries}, {"fingerprint", fingerprint}, {"recoveryAvailable", !entries.empty() || contents.contains(0)}};
    if (action == "history_read")
    {
        const auto index = request.at("index").get<int>();
        if (index < 0 || index > 5 || !contents.contains(index))
            throw std::runtime_error("That appearance history entry is no longer available.");
        if (request.value("fingerprint", std::string{}) != fingerprint)
            throw std::runtime_error("Appearance history changed. Refresh before restoring it.");
        const auto preset = ParsePreset(contents.at(index));
        if (preset.is_null()) throw std::runtime_error("That saved appearance could not be read safely.");
        return {{"preset", preset}, {"index", index}, {"fingerprint", fingerprint}};
    }
    if (fs::exists(SafePath("Data/Recovery/Recovery Journal.txt")))
        throw std::runtime_error("An earlier library action needs recovery. Refresh before changing saved files.");
    std::vector<FileChange> changes;
    if (action == "history_clear")
    {
        if (!request.value("confirmed", false) || request.value("fingerprint", std::string{}) != fingerprint)
            throw std::runtime_error("Review the current appearance history and confirm clearing it.");
        for (const auto& [index, text] : contents)
        {
            static_cast<void>(text);
            changes.push_back({index == 0 ? lastPath : historyPath(index), std::nullopt});
        }
    }
    else
    {
        auto preset = request.at("preset");
        preset["presetName"] = "Appearance History";
        preset["libraryFolder"] = "";
        preset["source"] = "Character Preset Manager (CET) appearance history";
        preset["notes"] = request.value("description", "Appearance saved for recovery");
        preset["tags"] = "appearance history";
        preset["favorite"] = false;
        preset["created"] = Timestamp();
        preset["modified"] = preset["created"];
        const auto saved = WritePreset(preset);
        const auto verified = ParsePreset(saved);
        if (verified.is_null()) throw std::runtime_error("The saved recovery appearance could not be checked safely.");
        auto sameAppearance = [](const Json& first, const Json& second) {
            if (first.is_null() || second.is_null() || first.at("entries").size() != second.at("entries").size()) return false;
            for (std::size_t index = 0; index < first.at("entries").size(); ++index)
            {
                const auto& a = first.at("entries").at(index);
                const auto& b = second.at("entries").at(index);
                if (a.at("key") != b.at("key") || a.at("index") != b.at("index") ||
                    a.value("slot", std::string{}) != b.value("slot", std::string{}) ||
                    a.value("choice", std::string{}) != b.value("choice", std::string{})) return false;
            }
            return true;
        };
        if (contents.contains(1) && sameAppearance(verified, ParsePreset(contents.at(1))))
            return {{"saved", false}, {"message", "This appearance matches the newest saved recovery appearance."}, {"fingerprint", fingerprint}};
        for (int index = 5; index >= 2; --index)
        {
            if (contents.contains(index - 1))
            {
                if (ParsePreset(contents.at(index - 1)).is_null())
                    throw std::runtime_error("An older recovery appearance could not be read. Its file was kept for review.");
                changes.push_back({historyPath(index), contents.at(index - 1)});
            }
            else if (contents.contains(index)) changes.push_back({historyPath(index), std::nullopt});
        }
        changes.push_back({historyPath(1), saved});
        changes.push_back({lastPath, saved});
        for (int index = 6; index <= 10; ++index)
            if (contents.contains(index)) changes.push_back({historyPath(index), std::nullopt});
    }
    for (auto& change : changes)
    {
        change.checkExpected = true;
        for (const auto& [index, text] : contents)
            if (change.path == (index == 0 ? lastPath : historyPath(index))) change.expected = text;
    }
    transaction.Apply(changes, context);
    auto result = History({{"action", "history"}}, context);
    result["saved"] = action == "history_save";
    result["message"] = action == "history_save" ? "Recovery appearance saved." : "Appearance history cleared.";
    return result;
}
}
