#pragma once
#include "FileService.hpp"
namespace cpm
{
bool GameIsForeground();
struct OverlayEnvironment
{
    std::function<bool()> foreground = GameIsForeground;
    std::function<bool(std::stop_token)> wait = [](std::stop_token stop) {
        return WaitFor(stop, std::chrono::milliseconds(50));
    };
    std::function<bool()> held = [] {
        for (int key = 1; key <= 0xFE; ++key)
            if (GetAsyncKeyState(key) & 0x8000)
                return true;
        return false;
    };
    std::function<UINT(std::vector<INPUT>&)> send = [](std::vector<INPUT>& inputs) {
        return SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
    };
};

class OverlayOpener
{
public:
    explicit OverlayOpener(const fs::path& manager, OverlayEnvironment environment = {});
    void Poll(std::stop_token stop);
private:
    void Respond(const std::string& id, const std::string& status);
    fs::path request_, result_, bindings_;
    std::string previous_;
    OverlayEnvironment environment_;
};
}
