#pragma once

#include "FileFormats.hpp"

namespace cpm
{
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

using LogCallback = void (*)(const std::string&);
void SetLogCallbacks(LogCallback info, LogCallback warning) noexcept;
void LogInfo(const std::string& message) noexcept;
void LogWarning(const std::string& message) noexcept;
bool StartFileService(LogCallback info, LogCallback warning);
void StopFileService();
std::optional<fs::path> GameRoot();
std::optional<Paths> ResolvePaths();
bool IsReparsePoint(const fs::path& path);
std::map<std::string, Record> ReadRecords(const fs::path& path);
std::map<std::string, NativeRecord> ReadNativeRecords(const fs::path& path);
std::optional<std::string> FileFingerprint(const fs::path& path, const std::uintmax_t maximumBytes);
bool AtomicWrite(const fs::path& destination, const std::string& contents);
std::int64_t ModifiedValue(const fs::file_time_type value);
void WriteRecords(const fs::path& path, const std::map<std::string, Record>& records);
void WriteResults(const fs::path& path, const std::vector<std::string>& changed, const std::size_t skipped);
void WriteNativeCatalog(const Paths& paths);
std::optional<fs::file_time_type> RequestTime(const fs::path& path);
bool WaitFor(std::stop_token stop, const std::chrono::milliseconds duration);
std::string ReadOverlayFile(const fs::path& path);
}
