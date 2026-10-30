#include "FileService.hpp"
#include "AcuImporter.hpp"
#include "DirectoryWatcher.hpp"
#include "OverlayOpener.hpp"

namespace cpm
{
namespace
{
std::mutex g_waitMutex;
std::condition_variable g_waitCondition;
std::jthread g_worker;
HANDLE g_stopEvent = nullptr;
constexpr auto kUnexpectedWorkerError = "Character Preset Manager: native file service stopped after an unexpected error.";
LogCallback g_info = nullptr;
LogCallback g_warning = nullptr;
}
void SetLogCallbacks(LogCallback info, LogCallback warning) noexcept
{
    g_info = info;
    g_warning = warning;
}
void LogInfo(const std::string& message) noexcept
{
    try { if (g_info) g_info(message); } catch (...) {}
}
void LogWarning(const std::string& message) noexcept
{
    try { if (g_warning) g_warning(message); } catch (...) {}
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

bool IsReparsePoint(const fs::path& path)
{
    const auto attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
}

std::map<std::string, Record> ReadRecords(const fs::path& path)
{
    std::ifstream input(path, std::ios::binary);
    return ParseRecords(input);
}

std::map<std::string, NativeRecord> ReadNativeRecords(const fs::path& path)
{
    std::ifstream input(path, std::ios::binary);
    return ParseNativeRecords(input);
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

std::int64_t ModifiedValue(const fs::file_time_type value)
{
    return static_cast<std::int64_t>(value.time_since_epoch().count());
}

void WriteRecords(const fs::path& path, const std::map<std::string, Record>& records)
{
    if (!AtomicWrite(path, BuildRecords(records)))
        LogWarning("Character Preset Manager: could not save the ACU import record.");
}

void WriteResults(const fs::path& path, const std::vector<std::string>& changed, const std::size_t skipped)
{
    const auto generation = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    if (!AtomicWrite(path, BuildResults(changed, skipped, generation)))
        LogWarning("Character Preset Manager: could not save the ACU import results.");
}

void WriteNativeCatalog(const Paths& paths)
{
    std::error_code error;
    fs::create_directories(paths.library, error);
    if (error)
    {
        LogWarning("Character Preset Manager: could not prepare the preset folder for the file list.");
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
    if (!AtomicWrite(paths.catalog, BuildNativeCatalog(files, directories, skipped, generation)))
        LogWarning("Character Preset Manager: could not save the native file list.");
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

std::string ReadOverlayFile(const fs::path& path)
{
    std::error_code error;
    const auto size = fs::file_size(path, error);
    if (error || size > 1048576)
        return {};
    std::ifstream stream(path, std::ios::binary);
    return std::string(std::istreambuf_iterator<char>(stream), {});
}
void Worker(std::stop_token stop)
{
    const auto paths = ResolvePaths();
    if (!paths)
    {
        LogWarning("Character Preset Manager: could not find the game folder for ACU imports.");
        return;
    }
    auto requestTime = RequestTime(paths->request);
    OverlayOpener overlay(paths->library.parent_path());
    if (WaitFor(stop, std::chrono::duration_cast<std::chrono::milliseconds>(kStartupDelay)))
        return;
    DirectoryWatcher acuWatcher(g_stopEvent);
    DirectoryWatcher libraryWatcher(g_stopEvent);
    if (acuWatcher.Start(paths->source))
        LogInfo("Character Preset Manager: watching the ACU folder for changes.");
    else
        LogWarning("Character Preset Manager: ACU folder watching is not available. Select Refresh to check files.");
    if (libraryWatcher.Start(paths->library))
        LogInfo("Character Preset Manager: watching the preset folder for changes.");
    else
        LogWarning("Character Preset Manager: preset folder watching is not available. Select Refresh to check files.");
    Scan(*paths);
    requestTime = RequestTime(paths->request);
    bool watcherChangePending = false;
    auto watcherScanDue = std::chrono::steady_clock::time_point{};
    while (!stop.stop_requested())
    {
        overlay.Poll(stop);
        auto timeout = kRequestPoll;
        const auto beforeWait = std::chrono::steady_clock::now();
        if (watcherChangePending)
        {
            if (WatcherScanReady(watcherChangePending, beforeWait, watcherScanDue))
            {
                Scan(*paths);
                watcherChangePending = false;
                requestTime = RequestTime(paths->request);
                continue;
            }
            timeout = WatcherWaitTimeout(watcherChangePending, beforeWait, watcherScanDue);
        }
        const auto acuWatcherResult = acuWatcher.Wait(timeout);
        if (acuWatcherResult == DirectoryWatcher::Result::Stopped)
            break;
        const auto libraryWatcherResult = libraryWatcher.Wait(std::chrono::milliseconds(0));
        if (libraryWatcherResult == DirectoryWatcher::Result::Stopped)
            break;
        if (WatcherChanged(acuWatcherResult, libraryWatcherResult))
        {
            watcherChangePending = true;
            watcherScanDue = std::chrono::steady_clock::now() + kWatcherDebounce;
        }
        if (acuWatcherResult == DirectoryWatcher::Result::Failed && acuWatcher.Active())
        {
            acuWatcher.Close();
            LogWarning("Character Preset Manager: ACU folder watching stopped. Select Refresh to check files.");
        }
        if (libraryWatcherResult == DirectoryWatcher::Result::Failed && libraryWatcher.Active())
        {
            libraryWatcher.Close();
            LogWarning("Character Preset Manager: preset folder watching stopped. Select Refresh to check files.");
        }
        const auto current = RequestTime(paths->request);
        if (current && (!requestTime || *current != *requestTime))
        {
            requestTime = current;
            Scan(*paths);
            watcherChangePending = false;
            if (!acuWatcher.Active() && acuWatcher.Start(paths->source))
                LogInfo("Character Preset Manager: watching the ACU folder again after Refresh.");
            if (!libraryWatcher.Active() && libraryWatcher.Start(paths->library))
                LogInfo("Character Preset Manager: watching the preset folder again after Refresh.");
        }
    }
}
bool StartFileService(LogCallback info, LogCallback warning)
{
    SetLogCallbacks(info, warning);
    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!g_stopEvent)
        return false;
    try
    {
        g_worker = std::jthread([](std::stop_token stop) {
            try { Worker(stop); }
            catch (...)
            {
                try { LogWarning(kUnexpectedWorkerError); }
                catch (...) {}
            }
        });
        LogInfo("Character Preset Manager: the native file service is ready.");
    }
    catch (...)
    {
        CloseHandle(g_stopEvent);
        g_stopEvent = nullptr;
        SetLogCallbacks(nullptr, nullptr);
        return false;
    }
    return true;
}
void StopFileService()
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
    SetLogCallbacks(nullptr, nullptr);
}
}
