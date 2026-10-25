#include "../src/Main.cpp"

#include <fstream>
#include <stdexcept>

void CheckOverlay(const bool condition)
{
    if (!condition)
        throw std::runtime_error("CET opening test failed");
}

void TestOverlay(const fs::path& root)
{
    CheckOverlay(DecodeOverlayBinding(R"({"cet":{"overlay_key":54043195528445952}})") == std::vector<WORD>{VK_OEM_3});
    const auto encoded = (std::uint64_t{VK_CONTROL} << 48) | (std::uint64_t{VK_F4} << 32);
    const auto bindings = std::string("{\"cet\":{\"overlay_key\":") + std::to_string(encoded) + "}}";
    CheckOverlay(DecodeOverlayBinding(bindings) == std::vector<WORD>({VK_CONTROL, VK_F4}));
    for (const auto& invalid : {std::string("{}"), std::string("{\"cet\":{\"overlay_key\":0}}"),
            std::string("{\"cet\":{\"overlay_key\":18446744073709551616}}"),
            std::string("{\"other\":{\"overlay_key\":54043195528445952},\"cet\":{}}")})
        CheckOverlay(DecodeOverlayBinding(invalid).empty());
    const auto inputs = OverlayInputs({VK_CONTROL, VK_F4});
    CheckOverlay(inputs.size() == 4 && inputs[0].ki.wVk == VK_CONTROL &&
        inputs[1].ki.wVk == VK_F4 && inputs[2].ki.wVk == VK_F4 && inputs[3].ki.wVk == VK_CONTROL);
    CheckOverlay(!(inputs[0].ki.dwFlags & KEYEVENTF_KEYUP) && (inputs[3].ki.dwFlags & KEYEVENTF_KEYUP));
    const auto manager = root / L"overlay" / L"mods" / L"CPM";
    const auto config = manager / L"Data" / L"Config";
    fs::create_directories(config);
    const auto request = config / L"CET Overlay Request.txt";
    const auto result = config / L"CET Overlay Result.txt";
    const auto bindingFile = manager.parent_path().parent_path() / L"bindings.json";
    std::ofstream(bindingFile) << bindings;
    bool foreground = true, partial = false, cancelled = false, loseFocus = false;
    int sends = 0, waits = 0, heldChecks = 0;
    OverlayEnvironment environment;
    environment.foreground = [&] { return foreground; };
    environment.wait = [&](std::stop_token) {
        ++waits;
        if (loseFocus) foreground = false;
        if (cancelled) std::ofstream(request) << "4\tcancel";
        return false;
    };
    environment.held = [&] { return ++heldChecks == 1; };
    environment.send = [&](std::vector<INPUT>& sent) {
        ++sends;
        if (partial && sends == 2) return UINT{1};
        if (partial) CheckOverlay(sent.size() == 2 && (sent[0].ki.dwFlags & KEYEVENTF_KEYUP));
        return static_cast<UINT>(sent.size());
    };
    OverlayOpener opener(manager, environment);
    std::stop_source stop;
    std::ofstream(request) << "1\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 1 && waits == 2 && ReadOverlayFile(result) == "1\tsent");
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 1);
    foreground = false;
    std::ofstream(request) << "2\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 1 && ReadOverlayFile(result) == "2\tcancelled");
    foreground = true;
    partial = true;
    std::ofstream(request) << "3\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 3 && ReadOverlayFile(result) == "3\tinput-failed");
    cancelled = true;
    std::ofstream(request) << "4\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 3);
    cancelled = false;
    std::ofstream(bindingFile) << "{}";
    std::ofstream(request) << "5\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 3 && ReadOverlayFile(result) == "5\tbinding-unavailable");
    std::ofstream(bindingFile) << bindings;
    OverlayOpener restarted(manager, environment);
    restarted.Poll(stop.get_token());
    CheckOverlay(sends == 3);
    loseFocus = true;
    std::ofstream(request) << "6\topen";
    opener.Poll(stop.get_token());
    CheckOverlay(sends == 3 && ReadOverlayFile(result) == "6\tcancelled");
}

int main()
{
    const auto root = fs::temp_directory_path() /
        (L"cpm-native-test-" + std::to_wstring(GetCurrentProcessId()));
    const Paths paths{
        root / L"AppearanceChangeUnlocker" / L"character-presets",
        root / L"Character Presets" / L"ACU Presets",
        root / L"Character Presets",
        root / L"Data" / L"Catalog" / L"ACU Import Record.txt",
        root / L"Data" / L"Config" / L"ACU Import Request.txt",
        root / L"Data" / L"Catalog" / L"ACU Import Results.txt",
        root / L"Data" / L"Catalog" / L"Native File Catalog.txt",
    };
    std::error_code error;
    fs::remove_all(root, error);
    fs::create_directories(paths.source / L"female", error);
    if (error)
        return 1;
    TestOverlay(root);
    const auto source = paths.source / L"female" / L"Example.preset";
    {
        std::ofstream output(source, std::ios::binary);
        output << "LocKey#123:4\n";
    }
    Scan(paths);
    if (!fs::is_regular_file(paths.destination / L"female" / L"Example.preset"))
        return 2;
    {
        std::ifstream input(paths.results, std::ios::binary);
        const std::string results((std::istreambuf_iterator<char>(input)),
                                  std::istreambuf_iterator<char>());
        if (results.find("summary\t1\t0") == std::string::npos ||
            results.find("file\tACU Presets/female/Example.preset") == std::string::npos)
            return 3;
    }
    {
        std::ifstream input(paths.catalog, std::ios::binary);
        const std::string catalog((std::istreambuf_iterator<char>(input)),
                                  std::istreambuf_iterator<char>());
        if (catalog.find("protocol\t1") == std::string::npos ||
            catalog.find("directory\tACU Presets/female") == std::string::npos ||
            catalog.find("file\tACU Presets/female/Example.preset") == std::string::npos ||
            catalog.find("2:13:") == std::string::npos)
            return 9;
    }
    Scan(paths);
    {
        std::ifstream input(paths.results, std::ios::binary);
        const std::string results((std::istreambuf_iterator<char>(input)),
                                  std::istreambuf_iterator<char>());
        if (results.find("summary\t0\t0") == std::string::npos)
            return 4;
    }
    {
        std::ofstream output(source, std::ios::binary | std::ios::trunc);
        output << "LocKey#123:8\n";
    }
    fs::last_write_time(source, fs::last_write_time(source) + std::chrono::seconds(1));
    Scan(paths);
    {
        std::ifstream input(paths.destination / L"female" / L"Example.preset", std::ios::binary);
        const std::string copied((std::istreambuf_iterator<char>(input)),
                                 std::istreambuf_iterator<char>());
        if (copied != "LocKey#123:8\n")
            return 5;
    }
    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!g_stopEvent)
        return 6;
    DirectoryWatcher watcher;
    if (!watcher.Start(paths.source))
        return 7;
    {
        std::ofstream output(paths.source / L"female" / L"Watched.preset", std::ios::binary);
        output << "LocKey#456:2\n";
    }
    if (watcher.Wait(std::chrono::seconds(2)) != DirectoryWatcher::Result::Changed)
        return 8;
    watcher.Close();
    CloseHandle(g_stopEvent);
    g_stopEvent = nullptr;
    fs::remove_all(root, error);
    return 0;
}
