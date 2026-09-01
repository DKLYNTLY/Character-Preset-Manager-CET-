#include <RED4ext/RED4ext.hpp>

#include <Windows.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstddef>
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
constexpr std::uintmax_t kMaximumCatalogFileBytes = 268435456;
constexpr std::size_t kMaximumCatalogEntries = 32768;
constexpr std::uint32_t kCatalogProtocol = 1;
constexpr auto kStartupDelay = std::chrono::seconds(5);
constexpr auto kRequestPoll = std::chrono::milliseconds(250);
constexpr auto kWatcherDebounce = std::chrono::milliseconds(750);

RED4ext::v1::PluginHandle g_handle;
const RED4ext::v1::Sdk* g_sdk = nullptr;
std::mutex g_waitMutex;
std::condition_variable g_waitCondition;
std::jthread g_worker;
HANDLE g_stopEvent = nullptr;

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
    fs::path library;
    fs::path record;
    fs::path request;
    fs::path results;
    fs::path catalog;
};

struct NativeRecord
{
    std::uintmax_t size = 0;
    std::int64_t modified = 0;
    std::string fingerprint;
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
        manager / L"Character Presets",
        manager / L"Data" / L"Catalog" / L"ACU Import Record.txt",
        manager / L"Data" / L"Config" / L"ACU Import Request.txt",
        manager / L"Data" / L"Catalog" / L"ACU Import Results.txt",
        manager / L"Data" / L"Catalog" / L"Native File Catalog.txt",
    };
}

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

bool IsReparsePoint(const fs::path& path)
{
    const auto attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
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

std::map<std::string, NativeRecord> ReadNativeRecords(const fs::path& path)
{
    std::map<std::string, NativeRecord> records;
    std::ifstream input(path, std::ios::binary);
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

std::optional<std::string> FileFingerprint(const fs::path& path, const std::uintmax_t maximumBytes)
{
    std::error_code error;
    const auto size = fs::file_size(path, error);
    if (error || size > maximumBytes)
        return std::nullopt;
    std::ifstream input(path, std::ios::binary);
    if (!input)
        return std::nullopt;
    std::uint64_t hash = 0;
    std::uint64_t secondHash = 0;
    std::uintmax_t bytesRead = 0;
    std::vector<char> buffer(65536);
    while (input)
    {
        input.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));
        const auto count = input.gcount();
        bytesRead += static_cast<std::uintmax_t>(count);
        for (std::streamsize index = 0; index < count; ++index)
        {
            const auto byte = static_cast<unsigned char>(buffer[static_cast<std::size_t>(index)]);
            hash = (hash * 131 + byte) % 2147483647;
            secondHash = (secondHash * 137 + byte) % 2147483629;
        }
    }
    if (!input.eof() || bytesRead != size)
        return std::nullopt;
    std::ostringstream output;
    output << "2:" << bytesRead << ':' << hash << ':' << secondHash;
    return output.str();
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

bool CopyPreset(const fs::path& source, const fs::path& destination,
                const std::uintmax_t expectedSize,
                const fs::file_time_type expectedModified)
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
    const auto copiedSize = fs::file_size(temporary, error);
    if (error || copiedSize != expectedSize)
    {
        fs::remove(temporary, error);
        return false;
    }
    const auto currentSize = fs::file_size(source, error);
    if (error || currentSize != expectedSize || fs::last_write_time(source, error) != expectedModified || error)
    {
        fs::remove(temporary, error);
        return false;
    }
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

void WriteNativeCatalog(const Paths& paths)
{
    std::error_code error;
    fs::create_directories(paths.library, error);
    if (error)
    {
        LogWarning("Character Preset Manager: the preset folder could not be prepared for the native file catalog");
        return;
    }
    const auto previous = ReadNativeRecords(paths.catalog);
    std::map<std::string, NativeRecord> files;
    std::vector<std::string> directories;
    std::size_t skipped = 0;
    fs::recursive_directory_iterator iterator(paths.library,
        fs::directory_options::skip_permission_denied, error);
    const fs::recursive_directory_iterator end;
    while (!error && iterator != end)
    {
        const auto entry = *iterator;
        const auto reparsePoint = IsReparsePoint(entry.path());
        if (reparsePoint)
            iterator.disable_recursion_pending();
        iterator.increment(error);
        std::error_code entryError;
        if (reparsePoint || entry.is_symlink(entryError) || entryError)
        {
            ++skipped;
            continue;
        }
        const auto relative = entry.path().lexically_relative(paths.library);
        if (!SafeRelativePath(relative))
        {
            ++skipped;
            continue;
        }
        const auto relativeKey = relative.generic_string();
        if (entry.is_directory(entryError) && !entryError)
        {
            if (directories.size() + files.size() >= kMaximumCatalogEntries)
            {
                ++skipped;
                break;
            }
            directories.push_back(relativeKey);
            continue;
        }
        if (!entry.is_regular_file(entryError) || entryError || !HasSupportedSuffix(entry.path()))
            continue;
        if (directories.size() + files.size() >= kMaximumCatalogEntries)
        {
            ++skipped;
            break;
        }
        const auto size = entry.file_size(entryError);
        const auto modifiedTime = entry.last_write_time(entryError);
        if (entryError || size > kMaximumCatalogFileBytes)
        {
            ++skipped;
            continue;
        }
        const auto modified = ModifiedValue(modifiedTime);
        std::string fingerprint;
        const auto found = previous.find(relativeKey);
        if (found != previous.end() && found->second.size == size &&
            found->second.modified == modified && ValidFingerprint(found->second.fingerprint, size))
        {
            fingerprint = found->second.fingerprint;
        }
        else
        {
            const auto value = FileFingerprint(entry.path(), kMaximumCatalogFileBytes);
            if (!value)
            {
                ++skipped;
                continue;
            }
            fingerprint = *value;
        }
        files[relativeKey] = NativeRecord{size, modified, fingerprint};
    }
    if (error)
        ++skipped;
    std::sort(directories.begin(), directories.end());
    const auto generation = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    std::ostringstream output;
    output << "protocol\t" << kCatalogProtocol << '\n';
    output << "generation\t" << generation << '\n';
    output << "summary\t" << files.size() << '\t' << directories.size() << '\t' << skipped << '\n';
    for (const auto& directory : directories)
        output << "directory\t" << EscapeField(directory) << '\n';
    for (const auto& [relative, record] : files)
        output << "file\t" << EscapeField(relative) << '\t' << record.size << '\t'
               << record.modified << '\t' << record.fingerprint << '\n';
    if (!AtomicWrite(paths.catalog, output.str()))
        LogWarning("Character Preset Manager: the native file catalog could not be saved");
}

void Scan(const Paths& paths)
{
    std::error_code error;
    if (!fs::is_directory(paths.source, error) || error)
    {
        WriteResults(paths.results, {}, 0);
        WriteNativeCatalog(paths);
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
        const auto reparsePoint = IsReparsePoint(entry.path());
        if (reparsePoint)
            iterator.disable_recursion_pending();
        iterator.increment(error);
        std::error_code entryError;
        if (reparsePoint || entry.is_symlink(entryError) || !entry.is_regular_file(entryError) ||
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
        if (!CopyPreset(entry.path(), destination, size, modifiedTime))
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
    WriteNativeCatalog(paths);
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

class DirectoryWatcher
{
public:
    enum class Result
    {
        Timeout,
        Changed,
        Stopped,
        Failed,
    };

    ~DirectoryWatcher()
    {
        Close();
    }

    bool Start(const fs::path& path)
    {
        Close();
        directory_ = CreateFileW(path.c_str(), FILE_LIST_DIRECTORY,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
            OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED, nullptr);
        if (directory_ == INVALID_HANDLE_VALUE)
            return false;
        changeEvent_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!changeEvent_)
        {
            Close();
            return false;
        }
        overlapped_ = {};
        overlapped_.hEvent = changeEvent_;
        if (!Arm())
        {
            Close();
            return false;
        }
        return true;
    }

    void Close()
    {
        if (directory_ != INVALID_HANDLE_VALUE)
        {
            CancelIoEx(directory_, &overlapped_);
            CloseHandle(directory_);
            directory_ = INVALID_HANDLE_VALUE;
        }
        if (changeEvent_)
        {
            CloseHandle(changeEvent_);
            changeEvent_ = nullptr;
        }
        overlapped_ = {};
    }

    bool Active() const
    {
        return directory_ != INVALID_HANDLE_VALUE && changeEvent_;
    }

    Result Wait(const std::chrono::milliseconds timeout)
    {
        const auto bounded = static_cast<DWORD>(std::clamp<std::int64_t>(
            timeout.count(), 0, static_cast<std::int64_t>(INFINITE - 1)));
        if (!Active())
        {
            const auto wait = WaitForSingleObject(g_stopEvent, bounded);
            return wait == WAIT_OBJECT_0 ? Result::Stopped :
                wait == WAIT_TIMEOUT ? Result::Timeout : Result::Failed;
        }
        const HANDLE events[] = {g_stopEvent, changeEvent_};
        const auto wait = WaitForMultipleObjects(2, events, FALSE, bounded);
        if (wait == WAIT_OBJECT_0)
            return Result::Stopped;
        if (wait == WAIT_TIMEOUT)
            return Result::Timeout;
        if (wait != WAIT_OBJECT_0 + 1)
            return Result::Failed;
        DWORD bytes = 0;
        if (!GetOverlappedResult(directory_, &overlapped_, &bytes, FALSE))
            return Result::Failed;
        if (!Arm())
            return Result::Failed;
        return bytes > 0 ? Result::Changed : Result::Failed;
    }

private:
    bool Arm()
    {
        ResetEvent(changeEvent_);
        DWORD ignored = 0;
        return ReadDirectoryChangesW(directory_, buffer_.data(),
            static_cast<DWORD>(buffer_.size()), TRUE,
            FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_SIZE |
                FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION,
            &ignored, &overlapped_, nullptr) != FALSE;
    }

    HANDLE directory_ = INVALID_HANDLE_VALUE;
    HANDLE changeEvent_ = nullptr;
    OVERLAPPED overlapped_{};
    std::vector<std::byte> buffer_ = std::vector<std::byte>(65536);
};

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
    DirectoryWatcher acuWatcher;
    DirectoryWatcher libraryWatcher;
    if (acuWatcher.Start(paths->source))
        LogInfo("Character Preset Manager: ACU folder watcher started");
    else
        LogWarning("Character Preset Manager: ACU folder watcher is unavailable; Refresh remains available");
    if (libraryWatcher.Start(paths->library))
        LogInfo("Character Preset Manager: preset folder watcher started");
    else
        LogWarning("Character Preset Manager: preset folder watcher is unavailable; Refresh remains available");
    Scan(*paths);
    requestTime = RequestTime(paths->request);
    bool watcherChangePending = false;
    auto watcherScanDue = std::chrono::steady_clock::time_point{};
    while (!stop.stop_requested())
    {
        auto timeout = kRequestPoll;
        const auto beforeWait = std::chrono::steady_clock::now();
        if (watcherChangePending)
        {
            if (beforeWait >= watcherScanDue)
            {
                Scan(*paths);
                watcherChangePending = false;
                requestTime = RequestTime(paths->request);
                continue;
            }
            timeout = std::min(timeout, std::chrono::duration_cast<std::chrono::milliseconds>(
                watcherScanDue - beforeWait));
        }
        const auto acuWatcherResult = acuWatcher.Wait(timeout);
        if (acuWatcherResult == DirectoryWatcher::Result::Stopped)
            break;
        const auto libraryWatcherResult = libraryWatcher.Wait(std::chrono::milliseconds(0));
        if (libraryWatcherResult == DirectoryWatcher::Result::Stopped)
            break;
        if (acuWatcherResult == DirectoryWatcher::Result::Changed ||
            libraryWatcherResult == DirectoryWatcher::Result::Changed)
        {
            watcherChangePending = true;
            watcherScanDue = std::chrono::steady_clock::now() + kWatcherDebounce;
        }
        if (acuWatcherResult == DirectoryWatcher::Result::Failed && acuWatcher.Active())
        {
            acuWatcher.Close();
            LogWarning("Character Preset Manager: ACU folder watcher stopped; Refresh remains available");
        }
        if (libraryWatcherResult == DirectoryWatcher::Result::Failed && libraryWatcher.Active())
        {
            libraryWatcher.Close();
            LogWarning("Character Preset Manager: preset folder watcher stopped; Refresh remains available");
        }
        const auto current = RequestTime(paths->request);
        if (current && (!requestTime || *current != *requestTime))
        {
            requestTime = current;
            Scan(*paths);
            watcherChangePending = false;
            if (!acuWatcher.Active() && acuWatcher.Start(paths->source))
                LogInfo("Character Preset Manager: ACU folder watcher started after Refresh");
            if (!libraryWatcher.Active() && libraryWatcher.Start(paths->library))
                LogInfo("Character Preset Manager: preset folder watcher started after Refresh");
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
        g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!g_stopEvent)
            return false;
        g_worker = std::jthread(Worker);
        LogInfo("Character Preset Manager: native file service loaded");
    }
    else if (reason == RED4ext::v1::EMainReason::Unload)
    {
        g_worker.request_stop();
        g_waitCondition.notify_all();
        if (g_worker.joinable())
        {
            SetEvent(g_stopEvent);
            g_worker.join();
        }
        if (g_stopEvent)
        {
            CloseHandle(g_stopEvent);
            g_stopEvent = nullptr;
        }
        g_sdk = nullptr;
    }
    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* info)
{
    info->name = L"Character Preset Manager Native File Service";
    info->author = L"dklyntly";
    info->version = RED4EXT_V1_SEMVER(3, 1, 1);
    info->runtime = RED4EXT_V1_RUNTIME_VERSION_INDEPENDENT;
    info->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
