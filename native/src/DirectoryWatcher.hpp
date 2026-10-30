#pragma once
#include "FileFormats.hpp"
namespace cpm
{
class DirectoryWatcher
{
public:
    using Result = WatchResult;
    explicit DirectoryWatcher(HANDLE& stopEvent) : stopEvent_(stopEvent) {}
    ~DirectoryWatcher();
    bool Start(const fs::path& path);
    void Close();
    bool Active() const;
    Result Wait(std::chrono::milliseconds timeout);
private:
    bool Arm();
    HANDLE& stopEvent_;
    HANDLE directory_ = INVALID_HANDLE_VALUE;
    HANDLE changeEvent_ = nullptr;
    OVERLAPPED overlapped_{};
    std::vector<std::byte> buffer_ = std::vector<std::byte>(65536);
};
}
