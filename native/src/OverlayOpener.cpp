#include "OverlayOpener.hpp"
namespace cpm
{
bool GameIsForeground()
{
    DWORD process = 0;
    GetWindowThreadProcessId(GetForegroundWindow(), &process);
    return process == GetCurrentProcessId();
}

OverlayOpener::OverlayOpener(const fs::path& manager, OverlayEnvironment environment)
        : request_(manager / L"Data" / L"Config" / L"CET Overlay Request.txt"),
          result_(manager / L"Data" / L"Config" / L"CET Overlay Result.txt"),
          bindings_(manager.parent_path().parent_path() / L"bindings.json"),
          previous_(ReadOverlayFile(request_)), environment_(std::move(environment)) {}

void OverlayOpener::Poll(std::stop_token stop)
{
    const auto request = ReadOverlayFile(request_);
    if (request == previous_)
        return;
    previous_ = request;
    const auto id = ParseOverlayRequest(request);
    if (!id)
        return;
    const auto keys = DecodeOverlayBinding(ReadOverlayFile(bindings_));
    if (keys.empty()) { Respond(*id, "binding-unavailable"); return; }
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(1);
    for (;;)
    {
        if (!environment_.foreground() || environment_.wait(stop))
        { Respond(*id, "cancelled"); return; }
        if (ReadOverlayFile(request_) != request)
            return;
        if (!environment_.held())
            break;
        if (std::chrono::steady_clock::now() >= deadline)
        { Respond(*id, "keys-held"); return; }
    }
    if (!environment_.foreground()) { Respond(*id, "cancelled"); return; }
    if (stop.stop_requested() || ReadOverlayFile(request_) != request)
        return;
    auto inputs = OverlayInputs(keys);
    const auto sent = environment_.send(inputs);
    if (sent != inputs.size())
    {
        std::vector<INPUT> releases(inputs.begin() + keys.size(), inputs.end());
        environment_.send(releases);
        Respond(*id, "input-failed");
        return;
    }
    Respond(*id, "sent");
}

void OverlayOpener::Respond(const std::string& id, const std::string& status)
{
    std::ofstream output(result_, std::ios::binary | std::ios::trunc);
    output << id << '\t' << status;
    LogInfo("Character Preset Manager: CET opening request " + status + ".");
}

}
