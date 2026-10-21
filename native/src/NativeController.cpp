#include "NativeController.hpp"
#include "Migration.hpp"
#include "Appearance.hpp"
#include <Windows.h>
#include <algorithm>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace cpm
{
namespace
{
std::string Text(const std::string& value)
{
    auto result = value;
    for (auto& character : result) if (static_cast<unsigned char>(character) < 32) character = ' ';
    return result;
}
std::string Field(const Json& data, const char* key) { return Text(data.value(key, std::string{})); }
}
NativeController::NativeController(std::filesystem::path root) : library_(root), root_(std::move(root))
{
    std::ifstream stream(root_ / "Data/Config/Native Keys.txt");
    int editor = 0, panel = 0;
    if (stream >> editor >> panel && editor >= 0 && editor < 65536 && panel >= 0 && panel < 65536) { editorKey = editor; panelKey = panel; }
}

Json NativeController::Call(Json request, OperationContext& context)
{
    if (!request.contains("revision")) request["revision"] = revision_;
    auto result = library_.Execute(request, context);
    revision_ = result.value("revision", revision_);
    return result;
}
void NativeController::Log(const std::string& message)
{
    const auto path = root_ / "Data/Logs/Activity.log";
    std::filesystem::create_directories(path.parent_path());
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
        throw std::runtime_error("The activity log is linked to another location. No log was written.");
    if (std::filesystem::exists(path) && std::filesystem::file_size(path) > 4194304)
    {
        for (int index = 9; index >= 1; --index)
        {
            const auto old = path.parent_path() / ("Activity " + std::to_string(index) + ".log");
            const auto next = path.parent_path() / ("Activity " + std::to_string(index + 1) + ".log");
            if (std::filesystem::exists(old)) { std::filesystem::remove(next); std::filesystem::rename(old, next); }
        }
        std::filesystem::rename(path, path.parent_path() / "Activity 1.log");
    }
    std::ofstream stream(path, std::ios::app);
    stream << Text(message) << '\n';
    if (!stream) throw std::runtime_error("The activity log could not be saved.");
    lastMessage_ = message;
}
Json NativeController::Capture(const Json& options)
{
    Json entries = Json::array();
    for (const auto& option : options)
    {
        if (!option.value("isActive", false) || !option.value("isEditable", false) || option.value("key", "").empty()) continue;
        Json entry = {{"key", option.at("key")}, {"index", option.at("currIndex")}, {"label", option.value("label", "")}};
        const auto slot = option.value("slot", "");
        if (!slot.empty()) entry["slot"] = slot;
        const auto current = option.at("currIndex").get<std::size_t>();
        for (const auto* field : {"definitions", "options", "morphNames"})
            if (option["choices"].contains(field) && current < option["choices"][field].size())
            {
                const auto value = option["choices"][field][current].get<std::string>();
                if (!value.empty()) { entry["choice"] = std::string(field) + ':' + value; break; }
            }
        entries.push_back(entry);
    }
    if (entries.empty()) throw std::runtime_error("Open an appearance editor before saving or loading presets.");
    return {{"entries", entries}, {"format", 8}, {"source", "Character Preset Manager"}, {"managedByCpm", true}};
}
Json NativeController::List(OperationContext& context, const std::string& message)
{
    auto page = Call({{"action", "query"}, {"query", query_}, {"sort", sort_}, {"offset", offset_}, {"limit", 96}}, context);
    auto folders = Call({{"action", "folders"}}, context);
    std::string lines = "SERVICE\t1\nSEARCH\t" + Text(query_) + "\nSELECTED_LOCATION\t" + Text(location_) + "\nLOCATION\t\tAll Presets\n";
    for (const auto& [name, value] : folders["folders"].items()) { static_cast<void>(value); lines += "LOCATION\t" + Text(name) + '\t' + Text(name) + '\n'; }
    for (const auto& row : page["rows"])
    {
        const auto name = Field(row, "name");
        const bool marked = std::find(marked_.begin(), marked_.end(), name) != marked_.end();
        lines += "ROW\tPRESET\t" + name + '\t' + (marked ? "[Selected] " : "") + (row["preset"].value("favorite", false) ? "* " : "") + name + '\n';
    }
    if (offset_ > 0) lines += "ROW\tPAGE\tprevious\tPrevious page\n";
    if (offset_ + page["rows"].size() < page["total"].get<std::size_t>()) lines += "ROW\tPAGE\tnext\tNext page\n";
    if (!selected_.empty())
    {
        const auto read = Call({{"action", "read"}, {"name", selected_}}, context);
        const auto& preset = read["preset"];
        lines += "SELECTED\t" + Text(selected_) + '\t' + Field(preset, "notes") + '\t' + Field(preset, "tags") + '\t' + std::to_string(preset["entries"].size()) + '\t' + (preset.value("favorite", false) ? "1" : "0") + '\t' + std::to_string(preset.value("format", 4)) + '\t' + Text(location_) + '\t' + (preset.value("format", 4) >= 7 ? "CPM" : "ACU") + '\n';
    }
    if (selected_.empty()) lines += "SELECTED\t\t\t\t0\t0\t8\t\tCPM\n";
    const auto history = Call({{"action", "history"}}, context);
    lines += "RECOVERY\t" + std::string(history.value("recoveryAvailable", false) ? "1" : "0") + '\n';
    lines += "CONFIRM\tSAVE\t" + std::string(pendingConfirmation_.starts_with("save:") ? "1" : "0") + "\nCONFIRM\tTRASH\t" + std::string(pendingConfirmation_.starts_with("delete:") ? "1" : "0") + '\n';
    lines += "STATUS\t0\t" + Text(message) + "\t0\t0\n";
    return {{"kind", "list"}, {"payload", lines}};
}
Json NativeController::Execute(const Json& request, OperationContext& context)
{
    const auto action = request.at("command").get<std::string>();
    const auto text = request.value("text", std::string{}), extra = request.value("extra", std::string{});
    if (!initialized_)
    {
        const auto game = root_.parent_path().parent_path().parent_path();
        migration_ = MigrateStorage(game / "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)", root_);
        if (!migration_.empty()) throw std::runtime_error(migration_);
        const auto bundled = root_ / "Bundled Presets";
        if (std::filesystem::exists(bundled))
        {
            for (const auto& entry : std::filesystem::recursive_directory_iterator(bundled))
            {
                if (!entry.is_regular_file() || entry.path().extension() != ".preset") continue;
                const auto target = root_ / "Character Presets" / entry.path().lexically_relative(bundled);
                std::filesystem::create_directories(target.parent_path());
                if (!std::filesystem::exists(target)) std::filesystem::copy_file(entry.path(), target);
            }
        }
        Call({{"action", "synchronize"}}, context);
        sort_ = Call({{"action", "config_read"}}, context)["preferences"].value("presetSort", "name");
        initialized_ = true;
        Log("Character Preset Manager 3.1.4 native session opened.");
    }
    if (action == "keys_save")
    {
        const auto key = std::stoi(text);
        if (key < 0 || key > 65535) throw std::runtime_error("Choose a valid key.");
        const auto values = Call({{"action", "keys_save"}, {"editorKey", extra == "editor" ? key : editorKey.load()}, {"panelKey", extra == "panel" ? key : panelKey.load()}}, context);
        editorKey = values.at("editorKey").get<int>(); panelKey = values.at("panelKey").get<int>();
        return {{"kind", "manager_text"}, {"payload", "Key binding saved."}};
    }
    if (action == "folder_list")
    {
        const auto result = Call({{"action", "folders"}}, context);
        std::string lines;
        for (const auto& [name, value] : result["folders"].items()) { static_cast<void>(value); lines += "ROW\tFOLDER\t" + Text(name) + '\t' + Text(name) + '\n'; }
        return {{"kind", "manager_list"}, {"payload", lines}};
    }
    if (action == "open" || action == "refresh")
    {
        Call({{"action", "synchronize"}}, context);
        preset_ = Json(); previousChange_ = Json(); selected_.clear(); offset_ = 0;
        return List(context, "Preset library ready.");
    }
    if (action == "current") return List(context);
    if (action == "list") { query_ = text; offset_ = 0; return List(context); }
    if (action == "page") { if (text == "next") offset_ += 96; else offset_ = offset_ >= 96 ? offset_ - 96 : 0; return List(context); }
    if (action == "select") { Call({{"action", "read"}, {"name", text}}, context); selected_ = text; pendingConfirmation_.clear(); return List(context); }
    if (action == "save_location") { location_ = text; return List(context); }
    if (action == "toggle_folder") { location_ = text; return List(context); }
    if (action == "cancel_save_confirmation") { pendingConfirmation_.clear(); return List(context); }
    if (action == "details" || action == "open_load_details") return {{"kind", "status"}, {"payload", lastMessage_}};
    if (action == "diagnostics")
    {
        std::string lines = "Current editor choices:\n";
        for (const auto& option : request.at("options"))
            lines += Field(option, "key") + " | slot " + Field(option, "slot") + " | choice " + std::to_string(option.at("currIndex").get<std::uint32_t>()) + (option.value("isActive", false) ? " | active" : " | inactive") + (option.value("isEditable", false) ? " | editable\n" : " | fixed\n");
        return {{"kind", "manager_text"}, {"payload", lines}};
    }
    if (action == "log")
    {
        std::ifstream stream(root_ / "Data/Logs/Activity.log");
        std::string line, output;
        while (std::getline(stream, line)) { output += line + '\n'; if (output.size() > 12000) output.erase(0, output.find('\n') + 1); }
        return {{"kind", "manager_text"}, {"payload", output}};
    }
    if (action == "mark_page" || action == "clear_marks")
    {
        if (action == "clear_marks") marked_ = Json::array();
        else {
            const auto page = Call({{"action", "query"}, {"query", query_}, {"sort", sort_}, {"offset", offset_}, {"limit", 96}}, context);
            for (const auto& row : page["rows"]) if (std::find(marked_.begin(), marked_.end(), row["name"]) == marked_.end()) marked_.push_back(row["name"]);
        }
        return List(context, std::to_string(marked_.size()) + " presets marked.");
    }
    if (action == "mark")
    {
        if (selected_.empty()) throw std::runtime_error("Select a preset first.");
        auto found = std::find(marked_.begin(), marked_.end(), selected_);
        if (found == marked_.end()) marked_.push_back(selected_); else marked_.erase(found);
        return List(context, std::to_string(marked_.size()) + " presets selected for bulk actions.");
    }
    if (action == "save")
    {
        const auto name = (location_.empty() ? "" : location_ + '/') + text;
        const auto token = "save:" + name;
        Json existing;
        try { existing = Call({{"action", "read"}, {"name", name}}, context); } catch (const std::runtime_error&) {}
        if (!existing.is_null() && pendingConfirmation_ != token)
        {
            pendingConfirmation_ = token; confirmationFingerprint_ = existing.at("fingerprint");
            return List(context, "A preset already has that name. Select Confirm Overwrite if you want to replace it.");
        }
        if (!existing.is_null() && existing.at("fingerprint") != confirmationFingerprint_) throw std::runtime_error("That preset changed. Select it again before replacing it.");
        Call({{"action", "save"}, {"name", name}, {"preset", Capture(request.at("options"))}, {"replace", !existing.is_null()}}, context);
        selected_ = name; pendingConfirmation_.clear(); Log("Saved preset: " + name);
        return List(context, "Preset saved.");
    }
    if (action == "load" || action == "force_load" || action == "restore_previous" || action == "restore_history" || action == "compare")
    {
        if (action == "restore_previous" || action == "restore_history")
        {
            const auto history = Call({{"action", "history"}}, context);
            const auto index = action == "restore_previous" ? 0 : std::stoi(text);
            preset_ = Call({{"action", "history_read"}, {"index", index}, {"fingerprint", history.at("fingerprint")}}, context).at("preset");
        }
        else
        {
            if (selected_.empty()) throw std::runtime_error("Select a preset first.");
            preset_ = Call({{"action", "read"}, {"name", selected_}}, context).at("preset");
        }
        if (action == "compare")
        {
            const auto result = CompareAppearance(preset_, request.at("options"));
            std::string payload = "SUMMARY";
            for (const auto* key : {"matching", "changing", "missing", "ambiguous", "invalid", "clearing"}) payload += '\t' + std::to_string(result.at(key).get<int>());
            for (const auto& detail : result["details"]) payload += "\nDETAIL\t" + Field(detail, "status") + '\t' + Field(detail, "label");
            Log("Compatibility checked: " + selected_);
            return {{"kind", "comparison"}, {"payload", payload}};
        }
        auto recovery = Capture(request.at("options"));
        Call({{"action", "history_save"}, {"preset", recovery}, {"description", "Before loading " + selected_}}, context);
        state_ = {{"phase", "precleanup"}, {"forceFull", action == "force_load"}, {"resetBefore", true}};
        previousChange_ = Json();
        Log("Loading preset: " + selected_);
        return {{"kind", "start_load"}, {"payload", "Preparing appearance..."}};
    }
    if (action == "step")
    {
        if (preset_.is_null()) throw std::runtime_error("Start an appearance load before continuing.");
        if (!previousChange_.is_null() && request.value("unconfirmed", false))
        {
            const auto key = previousChange_.at("trackingKey").get<std::string>();
            if (previousChange_.at("kind") == "apply") { state_["satisfied"][key] = true; state_["unconfirmed"][key] = true; }
            else state_["cleanupSkipped"][key] = true;
            Log("Could not confirm choice: " + Field(previousChange_, "label") + ". It was applied once, but the editor did not confirm the result.");
        }
        auto result = PlanAppearance({{"preset", preset_}, {"state", state_}, {"options", request.at("options")}});
        state_ = result.at("state");
        const auto outcome = result.at("outcome").get<std::string>();
        previousChange_ = result.value("change", Json());
        std::string message = outcome;
        for (const auto& detail : result["details"]) Log("Skipped " + Field(detail, "label") + ": " + Field(detail, "reason"));
        if (outcome == "complete") message = "Loaded. All saved choices were confirmed.";
        if (outcome == "partial") message = "Partially loaded. Some choices could not be matched or confirmed, so check your appearance. Read Activity Log for details.";
        if (outcome == "failed") message = "Load failed. The saved choices could not be matched safely in this editor. Read Activity Log for details.";
        if (outcome == "change") { const auto position = previousChange_.at("position").get<std::size_t>(); message = "Applying " + (position > 0 && position <= request["options"].size() ? request["options"][position - 1].value("label", Field(previousChange_, "label")) : Field(previousChange_, "label")); Log(message); }
        if (outcome == "complete" || outcome == "partial" || outcome == "failed") Log(message);
        result["snapshotHash"] = std::hash<std::string>{}(request.at("options").dump());
        result["kind"] = outcome; result["payload"] = message;
        return result;
    }
    if (action == "cancel_load") { preset_ = Json(); previousChange_ = Json(); Log("Loading canceled. The choices already applied are still visible."); return {{"kind", "status"}, {"payload", lastMessage_}}; }
    if (action == "history")
    {
        const auto result = Call({{"action", "history"}}, context);
        std::string lines;
        for (const auto& entry : result["entries"]) lines += "HISTORY\t" + std::to_string(entry["index"].get<int>()) + '\t' + Field(entry["preset"], "modified") + '\t' + std::to_string(entry["preset"]["entries"].size()) + "\tSaved appearance\n";
        if (lines.empty()) lines = "EMPTY\tNo appearance history is available yet.";
        return {{"kind", "history"}, {"payload", lines}};
    }
    Json operation = {{"action", action}, {"name", selected_}, {"destination", text}, {"confirmed", request.value("confirmed", false)}};
    if (action == "metadata") { operation["notes"] = text; operation["tags"] = extra; }
    if (action == "create_folder" || action == "remove_folder" || action == "rename_folder" || action == "duplicate_folder") operation["name"] = text;
    if (action == "rename_folder" || action == "duplicate_folder") operation["destination"] = extra;
    if (action == "move_many") { operation["name"] = text; operation["names"] = marked_; }
    if (action == "delete")
    {
        if (pendingConfirmation_ != "delete:" + selected_) { pendingConfirmation_ = "delete:" + selected_; return List(context, "Select Confirm Move to Trash to continue."); }
        operation["action"] = "trash_move"; operation["confirmed"] = true; operation["names"] = Json::array({selected_});
    }
    if (action == "trash_move" || action == "trash_folder" || action == "delete" || action == "trash_restore" || action == "restore_group" || action == "trash_empty")
    {
        const auto current = Call({{"action", "trash_query"}}, context); operation["fingerprint"] = current.at("fingerprint");
        if (action == "trash_move") operation["names"] = marked_;
        if (action == "trash_folder") { operation["action"] = "trash_move"; operation["folder"] = text; }
        if (action == "restore_group") { operation["action"] = "trash_restore"; operation["group"] = text; }
        if (action == "trash_restore") operation["filename"] = text;
    }
    if (action == "history_clear") operation["fingerprint"] = Call({{"action", "history"}}, context).at("fingerprint");
    if (action.starts_with("bundle_") || action.starts_with("backup_"))
    {
        if (action.ends_with("_export")) { operation["names"] = marked_.empty() ? Json::array({selected_}) : marked_; operation["folder"] = text; }
        else if (action == "bundle_restore") {
            operation["filename"] = text;
            const auto trash = Call({{"action", "trash_query"}}, context);
            if (!trash["bundles"].contains(text)) throw std::runtime_error("Select a shared-folder file from Trash.");
            operation["fingerprint"] = trash["bundles"][text]["fingerprint"];
        }
        else {
            operation["filename"] = text;
            if (action.ends_with("_import") || action == "backup_delete") {
                const auto key = std::string(action.starts_with("backup_") ? "backup:" : "bundle:") + text;
                if (!previews_.contains(key)) throw std::runtime_error("Preview the selected shared file or backup before continuing.");
                operation["fingerprint"] = previews_.at(key);
            } else operation["fingerprint"] = Call({{"action", action.starts_with("backup_") ? "backup_info" : "bundle_info"}, {"filename", text}}, context).at("fingerprint");
        }
    }
    if (action == "config_save")
    {
        operation["fingerprint"] = Call({{"action", "config_read"}}, context).at("fingerprint");
        operation["preferences"] = {{"presetSort", text}};
    }
    if (action == "trash_query" || action == "archive_list" || action == "config_read" || action.ends_with("_preview"))
    {
        auto result = Call(operation, context);
        std::string lines;
        if (action == "trash_query")
        {
            for (const auto& [name, item] : result["items"].items()) lines += "ROW\tTRASH\t" + Text(name) + '\t' + Field(item, "original") + '\n';
            for (const auto& name : result["groupNames"]) lines += "ROW\tGROUP\t" + name.get<std::string>() + '\t' + Field(result["groups"][name.get<std::string>()], "root") + " | Complete folder\n";
            for (const auto& name : result["bundleNames"]) lines += "ROW\tBUNDLE_TRASH\t" + name.get<std::string>() + '\t' + name.get<std::string>() + " | Shared folder\n";
        }
        if (action == "archive_list") for (const auto* group : {"bundles", "backups"}) for (const auto& name : result[group]) lines += "ROW\tFILE\t" + name.get<std::string>() + '\t' + name.get<std::string>() + '\n';
        if (action == "config_read") lines = "Preset order: " + result["preferences"].value("presetSort", "name");
        if (action.ends_with("_preview")) {
            previews_[std::string(action.starts_with("backup_") ? "backup:" : "bundle:") + text] = result.at("fingerprint").get<std::string>();
        }
        if (action.ends_with("_preview")) for (const auto& name : result["names"]) lines += Text(name.get<std::string>()) + '\n';
        return {{"kind", action == "trash_query" || action == "archive_list" ? "manager_list" : "manager_text"}, {"payload", lines.empty() ? "No items are available." : lines}};
    }
    const auto result = Call(operation, context);
    if (action == "config_save") sort_ = text;
    if (action.ends_with("_folder") || action == "move_many") selected_.clear();
    else if (result.contains("selected") && result["selected"].is_string()) selected_ = result["selected"].get<std::string>();
    else if (action == "delete" || action == "trash_move" || action == "trash_folder") selected_.clear();
    marked_ = Json::array(); pendingConfirmation_.clear();
    const auto message = result.value("message", "Changes saved."); Log(message);
    return List(context, message);
}
}
