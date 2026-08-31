#include "../src/Main.cpp"

#include <fstream>

int main()
{
    const auto root = fs::temp_directory_path() /
        (L"cpm-native-test-" + std::to_wstring(GetCurrentProcessId()));
    const Paths paths{
        root / L"AppearanceChangeUnlocker" / L"character-presets",
        root / L"Character Presets" / L"ACU Presets",
        root / L"Data" / L"Catalog" / L"ACU Import Record.txt",
        root / L"Data" / L"Config" / L"ACU Import Request.txt",
        root / L"Data" / L"Catalog" / L"ACU Import Results.txt",
    };
    std::error_code error;
    fs::remove_all(root, error);
    fs::create_directories(paths.source / L"female", error);
    if (error)
        return 1;
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
