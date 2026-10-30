#pragma once

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
#include <functional>
#include <map>
#include <mutex>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace cpm
{
namespace fs = std::filesystem;

constexpr std::uintmax_t kMaximumPresetBytes = 1048576;
constexpr std::uintmax_t kMaximumCatalogFileBytes = 268435456;
constexpr std::size_t kMaximumCatalogEntries = 32768;
constexpr std::uint32_t kCatalogProtocol = 1;
constexpr auto kStartupDelay = std::chrono::seconds(5);
constexpr auto kRequestPoll = std::chrono::milliseconds(250);
constexpr auto kWatcherDebounce = std::chrono::milliseconds(750);

struct Record
{
    std::uintmax_t size = 0;
    std::int64_t modified = 0;
    std::string destination;
};

struct NativeRecord
{
    std::uintmax_t size = 0;
    std::int64_t modified = 0;
    std::string fingerprint;
};

bool HasPresetSuffix(const fs::path& path);
bool HasSupportedSuffix(const fs::path& path);
bool ValidFingerprint(const std::string& value, const std::uintmax_t expectedSize);
bool SafeComponent(const fs::path& component);
bool SafeRelativePath(const fs::path& relative);
std::string EscapeField(const std::string& value);
std::string UnescapeField(const std::string& value);
std::vector<WORD> DecodeOverlayBinding(const std::string& text);
std::vector<INPUT> OverlayInputs(const std::vector<WORD>& keys);

std::map<std::string, Record> ParseRecords(std::istream& input);
std::map<std::string, NativeRecord> ParseNativeRecords(std::istream& input);
std::string BuildRecords(const std::map<std::string, Record>& records);
std::string BuildResults(const std::vector<std::string>& changed, std::size_t skipped, std::int64_t generation);
std::string BuildNativeCatalog(const std::map<std::string, NativeRecord>& files,
    const std::vector<std::string>& directories, std::size_t skipped, std::int64_t generation);
std::optional<std::string> ParseOverlayRequest(const std::string& request);
enum class WatchResult { Timeout, Changed, Stopped, Failed };
inline bool WatcherScanReady(bool pending, std::chrono::steady_clock::time_point now,
    std::chrono::steady_clock::time_point due)
{
    return pending && now >= due;
}
inline std::chrono::milliseconds WatcherWaitTimeout(bool pending,
    std::chrono::steady_clock::time_point now, std::chrono::steady_clock::time_point due)
{
    return pending ? std::min(kRequestPoll,
        std::chrono::duration_cast<std::chrono::milliseconds>(due - now)) : kRequestPoll;
}
inline bool WatcherChanged(WatchResult acu, WatchResult library)
{
    return acu == WatchResult::Changed || library == WatchResult::Changed;
}
}
