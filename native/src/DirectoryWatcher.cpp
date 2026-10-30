#include "DirectoryWatcher.hpp"

namespace cpm
{
DirectoryWatcher::~DirectoryWatcher()
{
    Close();
}

bool DirectoryWatcher::Start(const fs::path& path)
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

void DirectoryWatcher::Close()
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

bool DirectoryWatcher::Active() const
{
    return directory_ != INVALID_HANDLE_VALUE && changeEvent_;
}

DirectoryWatcher::Result DirectoryWatcher::Wait(const std::chrono::milliseconds timeout)
{
    const auto bounded = static_cast<DWORD>(std::clamp<std::int64_t>(
        timeout.count(), 0, static_cast<std::int64_t>(INFINITE - 1)));
    if (!Active())
    {
        const auto wait = WaitForSingleObject(stopEvent_, bounded);
        return wait == WAIT_OBJECT_0 ? Result::Stopped :
            wait == WAIT_TIMEOUT ? Result::Timeout : Result::Failed;
    }
    const HANDLE events[] = {stopEvent_, changeEvent_};
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

bool DirectoryWatcher::Arm()
{
    ResetEvent(changeEvent_);
    DWORD ignored = 0;
    return ReadDirectoryChangesW(directory_, buffer_.data(),
        static_cast<DWORD>(buffer_.size()), TRUE,
        FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_SIZE |
            FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_CREATION,
        &ignored, &overlapped_, nullptr) != FALSE;
}
}
