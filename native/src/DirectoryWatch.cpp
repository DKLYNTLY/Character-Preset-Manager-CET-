#include "DirectoryWatch.hpp"

#include <Windows.h>

#include <array>
#include <chrono>
#include <utility>

namespace cpm
{
namespace
{
namespace fs = std::filesystem;
struct Watch
{
    HANDLE handle = INVALID_HANDLE_VALUE;
    fs::path path;
    ~Watch() { Close(); }
    void Close()
    {
        if (handle != INVALID_HANDLE_VALUE) FindCloseChangeNotification(handle);
        handle = INVALID_HANDLE_VALUE;
        path.clear();
    }
    void Open(fs::path preferred)
    {
        std::error_code error;
        while (!preferred.empty() && !fs::is_directory(preferred, error))
        {
            const auto parent = preferred.parent_path();
            if (parent == preferred) return;
            preferred = parent;
            error.clear();
        }
        if (preferred == path && handle != INVALID_HANDLE_VALUE) return;
        Close();
        const bool recursive = preferred.filename() == L"Character Presets" || preferred.filename() == L"character-presets";
        handle = FindFirstChangeNotificationW(preferred.c_str(), recursive,
            FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME | FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_LAST_WRITE);
        if (handle != INVALID_HANDLE_VALUE) path = std::move(preferred);
    }
};
}

DirectoryWatch::DirectoryWatch(fs::path manager, std::function<void()> changed) :
    manager_(std::move(manager)), changed_(std::move(changed))
{
    stop_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (stop_) worker_ = std::jthread([this](std::stop_token token) {
        try { Run(token); } catch (...) {}
    });
}

DirectoryWatch::~DirectoryWatch()
{
    worker_.request_stop();
    if (stop_) SetEvent(stop_);
    if (worker_.joinable()) worker_.join();
    if (stop_) CloseHandle(stop_);
}

void DirectoryWatch::Run(std::stop_token stop)
{
    using namespace std::chrono;
    std::array<Watch, 2> watches;
    auto retry = steady_clock::time_point{};
    auto due = steady_clock::time_point{};
    bool pending = false;
    while (!stop.stop_requested())
    {
        const auto now = steady_clock::now();
        if (now >= retry)
        {
            watches[0].Open(manager_ / L"Character Presets");
            watches[1].Open((manager_.parent_path().filename() == L"plugins" && manager_.parent_path().parent_path().filename() == L"red4ext" ? manager_.parent_path().parent_path().parent_path() / L"bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker" : manager_.parent_path() / L"AppearanceChangeUnlocker") / L"character-presets");
            retry = now + seconds(2);
        }
        std::array<HANDLE, 3> handles{stop_};
        std::array<Watch*, 3> owners{};
        DWORD count = 1;
        for (auto& watch : watches) if (watch.handle != INVALID_HANDLE_VALUE)
        {
            handles[count] = watch.handle;
            owners[count++] = &watch;
        }
        const auto result = WaitForMultipleObjects(count, handles.data(), FALSE, 250);
        if (result == WAIT_OBJECT_0) break;
        if (result > WAIT_OBJECT_0 && result < WAIT_OBJECT_0 + count)
        {
            auto& watch = *owners[result - WAIT_OBJECT_0];
            if (!FindNextChangeNotification(watch.handle)) watch.Close();
            if (!pending) due = steady_clock::now() + milliseconds(750);
            pending = true;
        }
        else if (result == WAIT_FAILED)
            for (auto& watch : watches) watch.Close();
        if (pending && steady_clock::now() >= due)
        {
            changed_();
            pending = false;
        }
    }
}
}
