#include "NativeController.hpp"
#include "Migration.hpp"
#include <Windows.h>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>

namespace
{
namespace fs = std::filesystem;
using cpm::Json;
void Check(bool value, const std::string& message) { if (!value) throw std::runtime_error(message); }
void Write(const fs::path& path, const std::string& text) { fs::create_directories(path.parent_path()); std::ofstream(path, std::ios::binary) << text; }
std::string Read(const fs::path& path) { std::ifstream stream(path, std::ios::binary); return {std::istreambuf_iterator<char>(stream), {}}; }
void Migration(const fs::path& root)
{
    const auto old = root / "old", destination = root / "native";
    Write(old / "Character Presets/Legacy.preset", "LocKey#1:2\n");
    Write(old / "Data/Config/Config.txt", "presetSort=name\n");
    Write(destination / "Character Presets/Legacy.preset", "LocKey#1:2\n");
    Write(destination / "Data/Config/Config.txt", "presetSort=modified\n");
    Check(!cpm::MigrateStorage(old, destination).empty(), "Conflicting records must block completion.");
    Check(Read(destination / "Data/Config/Config.txt") == "presetSort=modified\n", "Active records were replaced.");
    Check(Read(destination / "Data/Migration/Conflicts/Data/Config/Config.txt") == "presetSort=name\n", "The conflict copy was not preserved.");
    Check(!fs::exists(destination / "Data/Migration/Completed.txt"), "A blocked migration was marked complete.");
    Check(!cpm::MigrateStorage(old, destination).empty(), "Repeated conflicts must remain blocked.");
    Write(destination / "Data/Config/Config.txt", "presetSort=name\n");
    Write(old / "Character Presets/Nested/Second.preset", "LocKey#2:1\n");
    Write(destination / "Character Presets/Nested/Second.preset.migration-tmp", "interrupted");
    Check(cpm::MigrateStorage(old, destination).empty(), "Resumed migration failed.");
    Check(Read(destination / "Character Presets/Nested/Second.preset") == "LocKey#2:1\n", "Nested copy failed verification.");
    Check(fs::exists(old / "Character Presets/Legacy.preset"), "Original files were removed.");
    Write(old / "Character Presets/Later.preset", "LocKey#1:9\n");
    Check(cpm::MigrateStorage(old, destination).empty(), "Completed migration did not stay complete.");
    Check(!fs::exists(destination / "Character Presets/Later.preset"), "Completed migration reimported old files.");
    Check(cpm::MigrateStorage(root / "missing", root / "fresh").empty(), "Fresh installation failed.");
    Check(fs::exists(root / "fresh/Data/Migration/Completed.txt"), "Fresh completion was not recorded.");
}
Json Options(unsigned current)
{
    return Json::array({{{"key", "LocKey#1"}, {"slot", "hair"}, {"currIndex", current}, {"isActive", true},
        {"isEditable", true}, {"choices", {{"options", Json::array({"off", "first", "second"})}}}}});
}
void Controller(const fs::path& game)
{
    const auto old = game / "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)";
    const auto root = game / "red4ext/plugins/CharacterPresetManager";
    Write(old / "Character Presets/Legacy.preset", "LocKey#1:2\n");
    Write(game / "bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets/Imported.preset", "LocKey#1:1\n");
    cpm::NativeController controller(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return controller.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](const std::string& command, const std::string& text = "", const std::string& extra = "", Json options = Json::array(), bool confirmed = false, bool unconfirmed = false) {
        const Json request = {{"command", command}, {"text", text}, {"extra", extra}, {"options", options}, {"confirmed", confirmed}, {"unconfirmed", unconfirmed}};
        auto accepted = service.SubmitRaw(session, "native_ui", request.dump());
        Check(accepted.value("accepted", false), accepted.dump());
        const auto operation = accepted["operation"].get<std::uint64_t>();
        for (int count = 0; count < 10000; ++count)
        {
            auto reply = service.Poll(session, operation, false);
            if (reply.value("status", "") == "complete") return service.Poll(session, operation, true).at("result");
            if (reply.value("status", "") == "failed") throw std::runtime_error(command + ": " + reply.dump());
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
        throw std::runtime_error("Controller action timed out: " + command);
    };
    auto opened = call("open");
    Check(opened["kind"] == "list", "Native library did not open.");
    Check(opened.at("payload").get<std::string>().find("ACU Presets/Imported") != std::string::npos, "ACU path did not follow the game directory.");
    const auto original = Read(root / "Character Presets/Legacy.preset");
    call("select", "Legacy");
    Check(call("load", "", "", Options(0))["kind"] == "start_load", "Native loading did not start.");
    auto options = Options(0);
    bool complete = false;
    for (int index = 0; index < 20; ++index)
    {
        const auto reply = call("step", "", "", options);
        if (reply["kind"] == "change") options[0]["currIndex"] = reply["change"]["target"];
        if (reply["kind"] == "complete") { complete = true; break; }
    }
    Check(complete && options[0]["currIndex"] == 2, "Native staged loading failed.");
    Check(Read(root / "Character Presets/Legacy.preset") == original, "Loading rewrote an old preset.");
    Check(call("compare", "", "", Options(2))["kind"] == "comparison", "Comparison failed.");
    call("metadata", "My notes", "hair");
    Check(Read(root / "Character Presets/Legacy.preset").find("# Format: 8") != std::string::npos, "Metadata did not upgrade format 8.");
    call("favorite");
    call("create_folder", "Looks");
    call("rename_folder", "Looks", "My Looks");
    call("duplicate_folder", "My Looks", "Copied Looks");
    call("create_folder", "ToTrash/Nested");
    call("trash_folder", "ToTrash", "", Json::array(), true);
    const auto groupList = call("trash_query").at("payload").get<std::string>();
    const auto groupStart = groupList.find("ROW\tGROUP\t");
    Check(groupStart != std::string::npos, "Empty nested folder group was lost in Trash.");
    const auto groupBegin = groupStart + 10;
    call("restore_group", groupList.substr(groupBegin, groupList.find('\t', groupBegin) - groupBegin));
    Check(call("folder_list").at("payload").get<std::string>().find("ToTrash/Nested") != std::string::npos, "Nested folder group was not restored.");
    call("mark_page"); call("clear_marks");
    call("save_location", "My Looks");
    call("save", "Saved", "", Options(1));
    const auto saved = Read(root / "Character Presets/Saved.preset");
    call("save", "Saved", "", Options(2));
    Check(Read(root / "Character Presets/Saved.preset") == saved, "Overwrite lacked confirmation.");
    call("save", "Saved", "", Options(2));
    call("duplicate", "My Looks/Copy");
    call("rename", "My Looks/Renamed");
    call("move", "Moved");
    call("mark");
    call("select", "Legacy"); call("mark");
    call("move_many", "My Looks");
    call("select", "My Looks/Legacy");
    call("bundle_export", "My Looks");
    call("backup_export");
    auto archives = call("archive_list").at("payload").get<std::string>();
    Check(archives.find(".cpmfolder") != std::string::npos && archives.find(".cpmbackup") != std::string::npos, "Native exports failed.");
    std::string bundle, backup;
    for (const auto& entry : fs::directory_iterator(root / "Character Presets"))
    {
        if (entry.path().extension() == ".cpmfolder") bundle = entry.path().filename().string();
        if (entry.path().extension() == ".cpmbackup") backup = entry.path().filename().string();
    }
    call("bundle_preview", bundle); call("bundle_import", bundle);
    call("backup_preview", backup); call("backup_import", backup);
    call("bundle_trash", bundle);
    std::string trashedBundle;
    for (const auto& entry : fs::directory_iterator(root / "Data/Recovery/Trash")) if (entry.path().extension() == ".cpmfolder") trashedBundle = entry.path().filename().string();
    Check(!trashedBundle.empty(), "Shared file was not moved to Trash.");
    call("bundle_restore", trashedBundle);
    call("config_save", "modified"); call("config_read");
    call("keys_save", "70", "editor"); call("keys_save", "71", "panel");
    Check(cpm::editorKey == 70 && cpm::panelKey == 71, "Native bindings were not saved.");
    call("select", "My Looks/Legacy");
    Check(call("force_load", "", "", Options(0))["kind"] == "start_load", "CET command did not use the native controller.");
    Check(service.Status().at("session") == session, "A technical command restarted the session.");
    call("cancel_load");
    call("delete"); call("delete");
    auto trash = call("trash_query")["payload"].get<std::string>();
    const auto start = trash.find("ROW\tTRASH\t");
    Check(start != std::string::npos, "Trash listing omitted the deleted preset.");
    const auto begin = start + 10, end = trash.find('\t', begin);
    call("trash_restore", trash.substr(begin, end - begin));
    call("history"); call("restore_previous", "", "", Options(2)); call("cancel_load");
    call("log"); call("diagnostics", "", "", Options(2));
    Write(root / "Character Presets/Missing.preset", "# CPM Preset\n# Format: 8\nLocKey#1:2\n# Saved choice: options:absent\n");
    call("refresh"); call("select", "Missing"); call("force_load", "", "", Options(0));
    bool refused = false;
    for (int index = 0; index < 12; ++index) {
        const auto reply = call("step", "", "", Options(0));
        Check(reply["kind"] != "change", "Force loading replaced a missing named custom choice.");
        if (reply["kind"] == "failed" || reply["kind"] == "partial") { refused = true; break; }
    }
    Check(refused, "Missing named choice did not reach a bounded result.");
    call("cancel_load");
    call("select", "My Looks/Legacy"); call("load", "", "", Options(0));
    bool partial = false, applied = false;
    for (int index = 0; index < 12; ++index) {
        const auto reply = call("step", "", "", Options(0), false, applied);
        if (reply["kind"] == "change") { Check(!applied, "An unconfirmed choice was applied twice."); applied = true; }
        if (reply["kind"] == "partial") { partial = true; break; }
    }
    Check(partial && applied, "Unconfirmed choices did not produce a partial result.");
    call("cancel_load");
    call("history_clear", "", "", Json::array(), true);
    call("trash_empty", "", "", Json::array(), true);
    service.CloseSession(session);
    Check(!service.SubmitRaw(session, "native_ui", "{}").value("accepted", false), "Closed editor accepted work.");
    Check(fs::exists(old / "Character Presets/Legacy.preset"), "Controller migration removed original files.");
}
}
int main()
{
    const auto root = fs::temp_directory_path() / ("cpm-native-controller-" + std::to_string(GetCurrentProcessId()));
    try
    {
        Migration(root / "migration");
        Controller(root / "game");
        fs::remove_all(root);
        std::cout << "Native controller workflows and migration passed.\n";
        return 0;
    }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; fs::remove_all(root); return 1; }
}
