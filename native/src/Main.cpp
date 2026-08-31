#include <RED4ext/RED4ext.hpp>

#include <Windows.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <cstdint>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace
{
namespace fs = std::filesystem;

constexpr std::uintmax_t kMaximumPresetBytes = 1048576;
constexpr auto kStartupDelay = std::chrono::seconds(5);
constexpr auto kRequestPoll = std::chrono::milliseconds(250);

RED4ext::v1::PluginHandle g_handle;
const RED4ext::v1::Sdk* g_sdk = nullptr;
std::mutex g_waitMutex;
std::condition_variable g_waitCondition;
std::jthread g_worker;

struct Record
{
    std::uintmax_t size = 0;
    std::int64_t modified = 0;
    std::string destination;
};

struct Paths
{
    fs::path source;
    fs::path destination;
    fs::path record;
    fs::path request;
    fs::path results;
};

void LogInfo(const std::string& message)
{
    if (g_sdk && g_sdk->logger)
        g_sdk->logger->Info(g_handle, message.c_str());
}

void LogWarning(const std::string& message)
{
    if (g_sdk && g_sdk->logger)
        g_sdk->logger->Warn(g_handle, message.c_str());
}

std::optional<fs::path> GameRoot()
{
    std::wstring buffer(32768, L'\0');
    const auto length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0 || length >= buffer.size())
        return std::nullopt;
    buffer.resize(length);
    const fs::path executable(buffer);
    const auto x64 = executable.parent_path();
    if (x64.filename() != L"x64" || x64.parent_path().filename() != L"bin")
        return std::nullopt;
    return x64.parent_path().parent_path();
}

std::optional<Paths> ResolvePaths()
{
    const auto root = GameRoot();
    if (!root)
        return std::nullopt;
    const auto mods = *root / L"bin" / L"x64" / L"plugins" / L"cyber_engine_tweaks" / L"mods";
    const auto manager = mods / L"Character Preset Manager (CET)";
    return Paths{
        mods / L"AppearanceChangeUnlocker" / L"character-presets",
        manager / L"Character Presets" / L"ACU Presets",
        manager / L"Data" / L"Catalog" / L"ACU Import Record.txt",
        manager / L"Data" / L"Config" / L"ACU Import Request.txt",
        manager / L"Data" / L"Catalog" / L"ACU Import Results.txt",
    };
}

bool HasPresetSuffix(const fs::path& path)
{
    auto name = path.filename().wstring();
    std::transform(name.begin(), name.end(), name.begin(),
                   [](const wchar_t value) { return static_cast<wchar_t>(std::towlower(value)); });
    return name.size() > 7 && name.ends_with(L".preset");
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

std::map<std::string, Record> ReadRecords(const fs::path& path)
{
    std::map<std::string, Record> records;
    std::ifstream input(path, std::ios::binary);
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

bool AtomicWrite(const fs::path& destination, const std::string& contents)
{
    std::error_code error;
    fs::create_directories(destination.parent_path(), error);
    if (error)
        return false;
    auto temporary = destination;
    temporary += L".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output || !output.write(contents.data(), static_cast<std::streamsize>(contents.size())) || !output.flush())
            return false;
    }
    return MoveFileExW(temporary.c_str(), destination.c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
}

bool CopyPreset(const fs::path& source, const fs::path& destination)
{
    std::error_code error;
    fs::create_directories(destination.parent_path(), error);
    if (error)
        return false;
    auto temporary = destination;
    temporary += L".importing";
    fs::remove(temporary, error);
    error.clear();
    if (!fs::copy_file(source, temporary, fs::copy_options::overwrite_existing, error) || error)
        return false;
    if (MoveFileExW(temporary.c_str(), destination.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) == FALSE)
    {
        fs::remove(temporary, error);
        return false;
    }
    return true;
}

std::int64_t ModifiedValue(const fs::file_time_type value)
{
    return static_cast<std::int64_t>(value.time_since_epoch().count());
}

void WriteRecords(const fs::path& path, const std::map<std::string, Record>& records)
{
    std::ostringstream output;
    for (const auto& [source, record] : records)
        output << EscapeField(source) << '\t' << record.size << '\t' << record.modified << '\t'
               << EscapeField(record.destination) << '\n';
    if (!AtomicWrite(path, output.str()))
        LogWarning("Character Preset Manager: the ACU import record could not be saved");
}

void WriteResults(const fs::path& path, const std::vector<std::string>& changed, const std::size_t skipped)
{
    const auto generation = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    std::ostringstream output;
    output << "generation\t" << generation << '\n';
    output << "summary\t" << changed.size() << '\t' << skipped << '\n';
    for (const auto& destination : changed)
        output << "file\t" << EscapeField(destination) << '\n';
    if (!AtomicWrite(path, output.str()))
        LogWarning("Character Preset Manager: ACU import results could not be saved");
}

void Scan(const Paths& paths)
{
    std::error_code error;
    if (!fs::is_directory(paths.source, error) || error)
    {
        WriteResults(paths.results, {}, 0);
        return;
    }

    auto records = ReadRecords(paths.record);
    std::vector<std::string> changed;
    std::size_t skipped = 0;
    fs::recursive_directory_iterator iterator(paths.source,
        fs::directory_options::skip_permission_denied, error);
    const fs::recursive_directory_iterator end;
    while (!error && iterator != end)
    {
        const auto entry = *iterator;
        iterator.increment(error);
        std::error_code entryError;
        if (entry.is_symlink(entryError) || !entry.is_regular_file(entryError) ||
            entryError || !HasPresetSuffix(entry.path()))
            continue;
        const auto relative = entry.path().lexically_relative(paths.source);
        if (!SafeRelativePath(relative))
        {
            ++skipped;
            continue;
        }
        const auto size = entry.file_size(entryError);
        if (entryError || size == 0 || size > kMaximumPresetBytes)
        {
            ++skipped;
            continue;
        }
        const auto modifiedTime = entry.last_write_time(entryError);
        if (entryError)
        {
            ++skipped;
            continue;
        }
        const auto sourceKey = relative.generic_string();
        const auto destinationRelative = (fs::path(L"ACU Presets") / relative).generic_string();
        const auto modified = ModifiedValue(modifiedTime);
        const auto found = records.find(sourceKey);
        const auto destination = paths.destination / relative;
        const auto destinationReady = fs::is_regular_file(destination, entryError) && !entryError &&
            fs::file_size(destination, entryError) == size && !entryError;
        if (found != records.end() && found->second.size == size &&
            found->second.modified == modified && found->second.destination == destinationRelative &&
            destinationReady)
            continue;
        if (!CopyPreset(entry.path(), destination))
        {
            ++skipped;
            continue;
        }
        records[sourceKey] = Record{size, modified, destinationRelative};
        changed.push_back(destinationRelative);
    }
    if (error)
        ++skipped;
    WriteRecords(paths.record, records);
    WriteResults(paths.results, changed, skipped);
    LogInfo("Character Preset Manager: ACU import scan completed");
}

std::optional<fs::file_time_type> RequestTime(const fs::path& path)
{
    std::error_code error;
    const auto value = fs::last_write_time(path, error);
    if (error)
        return std::nullopt;
    return value;
}

bool WaitFor(std::stop_token stop, const std::chrono::milliseconds duration)
{
    std::unique_lock lock(g_waitMutex);
    return g_waitCondition.wait_for(lock, duration, [&] { return stop.stop_requested(); });
}

void Worker(std::stop_token stop)
{
    const auto paths = ResolvePaths();
    if (!paths)
    {
        LogWarning("Character Preset Manager: the game folder could not be found for ACU imports");
        return;
    }
    auto requestTime = RequestTime(paths->request);
    if (WaitFor(stop, std::chrono::duration_cast<std::chrono::milliseconds>(kStartupDelay)))
        return;
    Scan(*paths);
    requestTime = RequestTime(paths->request);
    while (!stop.stop_requested())
    {
        if (WaitFor(stop, std::chrono::duration_cast<std::chrono::milliseconds>(kRequestPoll)))
            break;
        const auto current = RequestTime(paths->request);
        if (current && (!requestTime || *current != *requestTime))
        {
            requestTime = current;
            Scan(*paths);
        }
    }
}
}

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle handle,
                                        RED4ext::v1::EMainReason reason,
                                        const RED4ext::v1::Sdk* sdk)
{
    if (reason == RED4ext::v1::EMainReason::Load)
    {
        g_handle = handle;
        g_sdk = sdk;
        g_worker = std::jthread(Worker);
        LogInfo("Character Preset Manager: ACU import service loaded");
    }
    else if (reason == RED4ext::v1::EMainReason::Unload)
    {
        g_worker.request_stop();
        g_waitCondition.notify_all();
        if (g_worker.joinable())
            g_worker.join();
        g_sdk = nullptr;
    }
    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* info)
{
    info->name = L"Character Preset Manager ACU Import Service";
    info->author = L"dklyntly";
    info->version = RED4EXT_V1_SEMVER(3, 0, 10);
    info->runtime = RED4EXT_V1_RUNTIME_VERSION_INDEPENDENT;
    info->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
