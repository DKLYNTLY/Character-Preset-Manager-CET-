#include "Library.hpp"
#include "FileTransaction.hpp"
#include "Archive.hpp"
#include "Service.hpp"
#include "DirectoryWatch.hpp"

#include <Windows.h>

#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>

namespace
{
using namespace std::chrono_literals;
using cpm::Json;
void Check(bool value, const char* message)
{
    if (!value) throw std::runtime_error(message);
}
Json Await(cpm::Service& service, std::uint64_t session, std::uint64_t operation, bool consume = true)
{
    const auto deadline = std::chrono::steady_clock::now() + 5s;
    while (std::chrono::steady_clock::now() < deadline)
    {
        auto result = service.Poll(session, operation, false);
        if (!result.value("accepted", false)) return result;
        const auto status = result.value("status", "");
        if (status == "complete" || status == "failed" || status == "canceled")
            return service.Poll(session, operation, consume);
        std::this_thread::sleep_for(1ms);
    }
    throw std::runtime_error("Operation timed out.");
}
Json Submit(cpm::Service& service, std::uint64_t session, Json request)
{
    request["protocol"] = cpm::Service::Protocol;
    request["session"] = session;
    auto result = service.Submit(request.dump());
    Check(result.value("accepted", false), "Request was rejected.");
    return result;
}
void Write(const std::filesystem::path& path, const std::string& text)
{
    std::filesystem::create_directories(path.parent_path());
    std::ofstream stream(path, std::ios::binary);
    stream << text;
    stream.close();
    Check(static_cast<bool>(stream), "Fixture could not be written.");
}
std::string Read(const std::filesystem::path& path)
{
    std::ifstream stream(path, std::ios::binary);
    return {std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>()};
}
void WatchTests(const std::filesystem::path& root)
{
    const auto manager = root / "Character Preset Manager (CET)";
    std::filesystem::create_directories(manager / "Character Presets");
    std::atomic_int changes = 0;
    {
        cpm::DirectoryWatch watch(manager, [&] { ++changes; });
        std::this_thread::sleep_for(100ms);
        Write(manager / "Character Presets/New.preset", "LocKey#1:1\n");
        const auto deadline = std::chrono::steady_clock::now() + 4s;
        while (changes.load() == 0 && std::chrono::steady_clock::now() < deadline) std::this_thread::sleep_for(10ms);
        Check(changes.load() > 0, "Production folder watcher did not report a changed preset.");
    }
}

void QueueTests()
{
    std::atomic_int entered = 0;
    std::atomic_bool release = false;
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) {
        if (request.at("action") == "wait" || request.at("action") == "plan_load" || request.at("action") == "load_step")
        {
            ++entered;
            while (!release.load()) { context.CheckCanceled(); std::this_thread::sleep_for(1ms); }
        }
        context.Progress(1, 1);
        return Json{{"copied", request}};
    });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    Check(!service.Submit("{}").value("accepted", true), "Malformed request accepted.");
    Check(!service.Submit(std::string(cpm::Service::MaximumRequestBytes + 1, ' ')).value("accepted", true), "Oversized request accepted.");
    auto operation = Submit(service, session, {{"action", "wait"}}).at("operation").get<std::uint64_t>();
    Check(service.Cancel(session, operation).value("accepted", false), "Cancellation rejected.");
    Check(Await(service, session, operation).at("status") == "canceled", "Canceled work ran.");
    Check(!service.Poll(session, operation, false).value("accepted", true), "Consumed result remained available.");
    operation = Submit(service, session, {{"action", "plan_load"}}).at("operation").get<std::uint64_t>();
    Check(!service.Submit(Json{{"protocol", 1}, {"session", session}, {"action", "plan_load"}}.dump()).value("accepted", true), "Two appearance operations accepted.");
    const auto replacement = service.BeginSession().at("session").get<std::uint64_t>();
    Check(replacement > session, "Session ID reused.");
    Check(!service.Poll(session, operation, false).value("accepted", true), "Stale result returned.");
    Check(!service.Submit(Json{{"protocol", 1}, {"session", session}, {"action", "read"}}.dump()).value("accepted", true), "Stale session request accepted.");
    release = true;
    operation = Submit(service, replacement, {{"action", "plan_load"}}).at("operation").get<std::uint64_t>();
    Check(Await(service, replacement, operation).at("status") == "complete", "Appearance plan did not complete.");
    Check(!service.Submit(Json{{"protocol", 1}, {"session", replacement}, {"action", "plan_load"}}.dump()).value("accepted", true), "Consuming the plan allowed overlapping appearance loads.");
    Check(!service.EndAppearance(replacement, operation + 1).value("accepted", true), "An unrelated operation ended the appearance load.");
    auto step = Submit(service, replacement, {{"action", "load_step"}, {"loadId", operation + 1}}).at("operation").get<std::uint64_t>();
    Check(Await(service, replacement, step).at("status") == "failed", "An unrelated load ID was accepted for an appearance step.");
    release = false;
    step = Submit(service, replacement, {{"action", "load_step"}, {"loadId", operation}}).at("operation").get<std::uint64_t>();
    Check(!service.SubmitRaw(replacement, "load_step", Json{{"loadId", operation}}.dump()).value("accepted", true), "Two appearance steps were accepted together.");
    Check(!service.EndAppearance(replacement, operation).value("accepted", true), "Appearance load ended before its pending step.");
    Check(service.Cancel(replacement, step).value("accepted", false), "Appearance step cancellation failed.");
    Check(Await(service, replacement, step).at("status") == "canceled", "Canceled appearance step completed.");
    release = true;
    Check(service.EndAppearance(replacement, operation).value("accepted", false), "Finished appearance load did not release its slot.");
    for (std::size_t index = 0; index < cpm::Service::MaximumOperations; ++index)
        Submit(service, replacement, {{"action", "echo"}, {"index", index}});
    Check(!service.Submit(Json{{"protocol", 1}, {"session", replacement}, {"action", "echo"}}.dump()).value("accepted", true), "Queue bound ignored.");
    Check(service.CloseSession(replacement).value("accepted", false), "Session did not close.");
    Check(!service.Submit(Json{{"protocol", 1}, {"session", replacement}, {"action", "echo"}}.dump()).value("accepted", true), "Closed session accepted a request.");
    release = false;
    const auto finalSession = service.BeginSession().at("session").get<std::uint64_t>();
    Submit(service, finalSession, {{"action", "wait"}});
    service.Shutdown();
    Check(!service.Status().value("available", true), "Stopped service reported available.");
}
void LibraryTests(const std::filesystem::path& root)
{
    const auto preset = root / "Character Presets/Physical/Old.preset";
    const auto catalog = root / "Data/Catalog/Virtual Folders.txt";
    Write(preset, "LocKey#1:3\n");
    Write(catalog, "P\tPhysical/Old\tVirtual/Named\nF\tEmpty\nX\tPhysical\n");
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto result = call({{"action", "query"}});
    Check(result.at("result").at("total") == 0, "Query scanned before refresh.");
    result = call({{"action", "refresh"}});
    Check(result.at("status") == "complete" && result.at("result").at("count") == 1, "Library scan failed.");
    auto revision = result.at("result").at("revision");
    result = call({{"action", "query"}, {"query", "named"}});
    Check(result.at("result").at("rows").at(0).at("name") == "Virtual/Named", "Virtual assignment was lost.");
    result = call({{"action", "folders"}});
    Check(result.at("result").at("folders").contains("Empty"), "Empty virtual folder was lost.");
    Check(!result.at("result").at("folders").contains("Physical"), "Ignored physical folder returned.");
    auto view = call({{"action", "view"}, {"query", "  NAMED  "}, {"limit", 1}}).at("result");
    Check(view.at("rows").size() == 1 && view.at("rows").at(0).at("matches") == true && view.at("query") == "named", "Library view search did not match.");
    Check(view.at("folderTotal") == 2 && view.at("folderRows").size() == 1 && view.at("folderRows").at(0).at("name") == "Empty", "Library view did not page sorted folders.");
    view = call({{"action", "view"}, {"query", "named"}, {"offset", 1}, {"folderOffset", 1}, {"limit", 1}, {"revision", revision}}).at("result");
    Check(view.at("rows").empty() && view.at("folderRows").at(0).at("count") == 1 && view.at("folderRows").at(0).at("matching") == 1, "Library view folder totals are wrong.");
    Check(view.at("folderRows").at(0).at("matches") == false, "Folder name matched unrelated search text.");
    Check(call({{"action", "read"}, {"name", "Virtual/Named"}}).at("result").at("preset").at("entries").at(0).at("index") == 3, "Read changed saved choice.");
    Check(Read(preset) == "LocKey#1:3\n", "Reading rewrote an older preset.");
    Check(Read(catalog) == "P\tPhysical/Old\tVirtual/Named\nF\tEmpty\nX\tPhysical\n", "Refreshing rewrote the folder catalog.");
    Check(call({{"action", "refresh"}}).at("result").at("revision") == revision, "Unchanged refresh invalidated the revision.");
    Write(catalog, "P\tPhysical/Old\tVirtual/Named\nF\tEmpty\nX\tPhysical\nX\tUnseen\n");
    const auto previousRevision = revision;
    revision = call({{"action", "refresh"}}).at("result").at("revision");
    Check(revision > previousRevision, "A changed folder record retained a stale library revision.");
    Check(call({{"action", "view"}, {"revision", previousRevision}}).at("status") == "failed", "A changed folder record accepted an older view page.");
    Write(root / "Character Presets/Second.preset", "LocKey#2:4\n");
    Check(call({{"action", "query"}}).at("result").at("total") == 1, "Query performed an unexpected scan.");
    Check(call({{"action", "refresh"}}).at("result").at("revision") > revision, "Changed library did not increment revision.");
    Check(call({{"action", "view"}, {"revision", revision}}).at("status") == "failed", "Library view mixed pages from different revisions.");
    view = call({{"action", "view"}, {"query", "empty"}}).at("result");
    Check(view.at("total") == 2 && view.at("folderRows").at(0).at("matches") == true, "Library view lost empty folder search results.");
    result = call({{"action", "query"}, {"offset", 1}, {"limit", 1}});
    Check(result.at("result").at("total") == 2 && result.at("result").at("rows").size() == 1, "Query paging failed.");
    Write(catalog, "P\t../outside\tInvalid\n");
    Check(call({{"action", "refresh"}}).at("status") == "failed", "Unsafe catalog accepted.");
    Check(call({{"action", "query"}}).at("result").at("total") == 2, "Failed refresh discarded the last library.");
    Check(call({{"action", "read"}, {"name", "../outside"}}).at("status") == "failed", "Unsafe read accepted.");
}

void MutationTests(const std::filesystem::path& root)
{
    const auto oldPath = root / "Character Presets/Old.preset";
    const auto catalog = root / "Data/Catalog/Virtual Folders.txt";
    Write(oldPath, "LocKey#1:3\n");
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto revision = call({{"action", "refresh"}}).at("result").at("revision");
    auto change = [&](Json request) {
        request["revision"] = revision;
        auto result = call(std::move(request));
        if (result.at("status") != "complete") throw std::runtime_error(result.dump());
        revision = result.at("result").at("revision");
        return result;
    };
    change({{"action", "create_folder"}, {"name", "Empty/Nested"}});
    Check(call({{"action", "folders"}}).at("result").at("folders").contains("Empty/Nested"), "Empty folder was not saved.");
    change({{"action", "move"}, {"name", "Old"}, {"destination", "Empty/Nested/Old"}});
    Check(Read(oldPath) == "LocKey#1:3\n", "Moving rewrote an older preset.");
    change({{"action", "duplicate"}, {"name", "Empty/Nested/Old"}});
    Check(Read(root / "Character Presets/Old Copy.preset") == "LocKey#1:3\n", "Duplication changed old preset contents.");
    change({{"action", "rename_folder"}, {"name", "Empty"}, {"destination", "Renamed"}});
    Check(call({{"action", "read"}, {"name", "Renamed/Nested/Old"}}).at("status") == "complete", "Folder rename lost a preset.");
    Check(call({{"action", "remove_folder"}, {"name", "Missing"}, {"revision", revision}}).at("status") == "failed", "Missing folder removal accepted.");
    change({{"action", "metadata"}, {"name", "Renamed/Nested/Old"}, {"notes", "Saved notes"}, {"tags", "tag"}});
    auto preset = call({{"action", "read"}, {"name", "Renamed/Nested/Old"}}).at("result").at("preset");
    Check(preset.at("notes") == "Saved notes" && preset.at("format") == 8, "Metadata did not upgrade and preserve preset.");
    change({{"action", "favorite"}, {"name", "Renamed/Nested/Old"}});
    Check(call({{"action", "query"}, {"favoritesOnly", true}}).at("result").at("total") == 1, "Favorite change was not cached.");
    Check(call({{"action", "favorite"}, {"name", "Renamed/Nested/Old"}, {"revision", 0}}).at("status") == "failed", "Stale revision changed a preset.");
    const auto originalCatalog = Read(catalog);
    Write(catalog, originalCatalog + "F\tExternal\n");
    Check(call({{"action", "create_folder"}, {"name", "Conflict"}, {"revision", revision}}).at("status") == "failed", "External catalog change was overwritten.");
    Check(Read(catalog) == originalCatalog + "F\tExternal\n", "External catalog contents were lost.");
    revision = call({{"action", "refresh"}}).at("result").at("revision");
    Write(oldPath, "LocKey#1:7\n");
    Check(call({{"action", "metadata"}, {"name", "Renamed/Nested/Old"}, {"revision", revision}}).at("status") == "failed", "External preset change was overwritten.");
    Check(Read(oldPath) == "LocKey#1:7\n", "External preset contents were lost.");
}

void RecoveryTests(const std::filesystem::path& root)
{
    const auto directory = root / "Data/Recovery/Native Transaction";
    cpm::FileTransaction transaction([&](const std::string& path) { return root / path; });
    Write(root / "Character Presets/A.preset", "first");
    Write(root / "Character Presets/B.preset", "second");
    Write(directory / "keep.txt", "unrelated");
    cpm::OperationContext context;
    transaction.Apply({{"Character Presets/A.preset", "updated"}, {"Character Presets/B.preset", std::nullopt},
        {"Character Presets/C.preset", "new"}}, context);
    Check(Read(root / "Character Presets/A.preset") == "updated", "Transaction replacement failed.");
    Check(!std::filesystem::exists(root / "Character Presets/B.preset"), "Transaction removal failed.");
    Check(Read(root / "Character Presets/C.preset") == "new", "Transaction creation failed.");
    Check(Read(directory / "keep.txt") == "unrelated", "Transaction removed an unrelated file.");
    bool changedRejected = false;
    try { transaction.Apply({{"Character Presets/A.preset", "lost", "outdated", true}}, context); }
    catch (const std::exception&) { changedRejected = true; }
    Check(changedRejected && Read(root / "Character Presets/A.preset") == "updated", "An outdated write overwrote a current file.");
    Json manifest = {{"version", 1}, {"changes", Json::array({
        {{"path", "Character Presets/A.preset"}, {"before", true}, {"after", true}},
        {{"path", "Character Presets/C.preset"}, {"before", true}, {"after", true}}})}};
    Write(directory / "before-0", "first");
    Write(directory / "after-0", "updated");
    Write(directory / "before-1", "new");
    Write(directory / "after-1", "recovered");
    Write(directory / "manifest.json", manifest.dump());
    transaction.Recover();
    Check(Read(root / "Character Presets/C.preset") == "recovered", "Interrupted transaction did not finish.");
    Check(!std::filesystem::exists(directory / "manifest.json"), "Completed recovery retained its journal.");
    Write(directory / "before-0", "updated");
    Write(directory / "after-0", "next");
    manifest["changes"].erase(1);
    Write(directory / "manifest.json", manifest.dump());
    Write(root / "Character Presets/A.preset", "external");
    bool rejected = false;
    try { transaction.Recover(); } catch (const std::exception&) { rejected = true; }
    Check(rejected && Read(root / "Character Presets/A.preset") == "external", "Recovery overwrote an external change.");
    Check(std::filesystem::exists(directory / "manifest.json") && Read(directory / "before-0") == "updated", "Failed recovery lost its working copies.");
}

void PreferencesTests(const std::filesystem::path& root)
{
    cpm::Library library(root);
    cpm::OperationContext context;
    auto config = library.Execute({{"action", "config_read"}}, context);
    Check(config.at("found") == false && config.at("preferences").at("presetSort") == "name", "Missing settings did not use defaults.");
    const auto path = root / "Data/Config/Config.txt";
    const std::string contents = "# Existing settings\npresetSort = modified\nhistorySize=8\nunsupported=1\n";
    Write(path, contents);
    config = library.Execute({{"action", "config_read"}}, context);
    Check(config.at("preferences").at("presetSort") == "modified" && config.at("warnings").size() == 1 && Read(path) == contents, "Settings compatibility or read preservation failed.");
    bool rejected = false;
    try { library.Execute({{"action", "config_save"}, {"preferences", {{"presetSort", "name"}}}, {"fingerprint", "outdated"}}, context); }
    catch (const std::exception&) { rejected = true; }
    Check(rejected && Read(path) == contents, "Outdated settings overwrote a current file.");
    auto saved = library.Execute({{"action", "config_save"}, {"preferences", {{"presetSort", "name"}}}, {"fingerprint", config.at("fingerprint")}}, context);
    Check(Read(path) == "presetSort=name\n" && saved.at("saved") == true, "Settings were not saved in the compatible format.");
    saved = library.Execute({{"action", "config_save"}, {"preferences", {{"presetSort", "name"}}}, {"fingerprint", saved.at("fingerprint")}}, context);
    Check(saved.at("saved") == false, "Identical settings were rewritten.");
    Write(root / "Character Presets/A.preset", "LocKey#1:3\n");
    const auto revision = library.Execute({{"action", "refresh"}}, context).at("revision");
    const auto inventory = library.Execute({{"action", "inventory"}, {"revision", revision}}, context);
    Check(inventory.at("saved") == true && Read(root / "Data/Catalog/Preset Inventory.txt").starts_with("P2\tA\t1\t"), "Compatible preset inventory was not saved.");
    Check(library.Execute({{"action", "inventory"}, {"revision", revision}}, context).at("saved") == false, "Unchanged inventory was rewritten.");
}

void BulkLibraryTests(const std::filesystem::path& root)
{
    Write(root / "Character Presets/A.preset", "LocKey#1:3\n");
    Write(root / "Character Presets/B.preset", "LocKey#2:4\n");
    Write(root / "Data/Catalog/Virtual Folders.txt", "P\tA\tSource/One/Same\nP\tB\tSource/Two/Same\nF\tSource/Empty\nF\tDestination\n");
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto revision = call({{"action", "refresh"}}).at("result").at("revision");
    auto copy = call({{"action", "duplicate_folder"}, {"name", "Source"}, {"revision", revision}});
    Check(copy.at("status") == "complete" && copy.at("result").at("selected") == "Source Copy", "Folder duplication failed.");
    revision = copy.at("result").at("revision");
    Check(call({{"action", "folders"}}).at("result").at("folders").contains("Source Copy/Empty"), "Folder duplication lost an empty child folder.");
    auto rows = call({{"action", "query"}, {"query", "Source Copy"}}).at("result").at("rows");
    Check(rows.size() == 2 && rows.at(0).at("preset").at("storage") != rows.at(1).at("preset").at("storage"), "Folder duplication reused a storage filename.");
    for (const auto& row : rows)
    {
        const auto bytes = Read(root / ("Character Presets/" + row.at("preset").at("storage").get<std::string>() + ".preset"));
        Check(bytes == (row.at("name").get<std::string>().find("/One/") != std::string::npos ? "LocKey#1:3\n" : "LocKey#2:4\n"), "Folder duplication rewrote older preset contents.");
    }
    const auto catalog = Read(root / "Data/Catalog/Virtual Folders.txt");
    Check(call({{"action", "move_many"}, {"name", "Destination"}, {"names", Json::array({"Source/One/Same", "Source/Two/Same"})}, {"revision", revision}}).at("status") == "failed", "Bulk move accepted colliding names.");
    Check(Read(root / "Data/Catalog/Virtual Folders.txt") == catalog, "Failed bulk move changed the catalog.");
    auto moved = call({{"action", "move_many"}, {"name", ""}, {"names", Json::array({"Source/One/Same"})}, {"revision", revision}});
    Check(moved.at("status") == "complete", "Bulk move to the root failed.");
    Check(call({{"action", "read"}, {"name", "Same"}}).at("status") == "complete" && Read(root / "Character Presets/A.preset") == "LocKey#1:3\n", "Bulk move changed older preset contents or lost its assignment.");
}

void LegacyRecoveryTests(const std::filesystem::path& root)
{
    const std::string journal = "Data/Recovery/Recovery Journal.txt";
    for (const auto& operation : {std::string("trash"), std::string("restore"), std::string("rename")})
    {
        const auto folder = root / operation;
        const auto main = folder / "Character Presets/Physical/Old.preset";
        const auto other = folder / (operation == "rename" ? "Character Presets/New.preset" : "Data/Recovery/Trash/Old.preset");
        const auto contents = "LocKey#1:3\n";
        Write(operation == "restore" ? main : other, contents);
        Write(folder / "Data/Catalog/Virtual Folders.txt", "F\tUnrelated\nX\tFolder\n");
        const auto plan = operation == "rename" ? "R\tPhysical/Old\tNew\tFolder/Old\n" : "P\tPhysical/Old\tOld.preset\tFolder/Old\n";
        Write(folder / journal, "V\t1\nH\tprepared\t" + operation + '\n' + plan + "D\tFolder/Empty\t1\n");
        cpm::Library library(folder);
        cpm::OperationContext context;
        const auto result = library.Execute({{"action", "refresh"}}, context);
        Check(!std::filesystem::exists(folder / journal), "Legacy recovery did not remove its completed record.");
        Check(Read(operation == "restore" ? other : main) == contents, "Legacy recovery changed preset bytes or destination.");
        Check(!std::filesystem::exists(operation == "restore" ? main : other), "Legacy recovery left the moved copy behind.");
        const auto folders = library.Execute({{"action", "folders"}}, context).at("folders");
        Check(folders.contains("Folder/Empty") && folders.contains("Unrelated"), "Legacy recovery lost saved folders.");
        if (operation == "restore")
        {
            const auto trash = library.Execute({{"action", "trash_query"}}, context);
            Check(trash.at("items").at("Old.preset").at("original") == "Folder/Old", "Legacy recovery lost a Trash destination.");
        }
        else
        {
            const auto view = library.Execute({{"action", "query"}}, context);
            Check(view.at("rows").at(0).at("name") == "Folder/Old", "Legacy recovery lost a virtual preset assignment.");
        }
        const auto before = Read(folder / "Data/Catalog/Virtual Folders.txt");
        library.Execute({{"action", "refresh"}}, context);
        Check(Read(folder / "Data/Catalog/Virtual Folders.txt") == before, "Completed legacy recovery changed metadata again.");
    }
    const auto folder = root / "conflict";
    Write(folder / "Character Presets/Old.preset", "original");
    Write(folder / "Data/Recovery/Trash/Old.preset", "different");
    const auto record = "V\t1\nH\tprepared\ttrash\nP\tOld\tOld.preset\tOld\n";
    Write(folder / journal, record);
    cpm::Library library(folder);
    cpm::OperationContext context;
    bool rejected = false;
    try { library.Execute({{"action", "refresh"}}, context); } catch (const std::exception&) { rejected = true; }
    Check(rejected && Read(folder / journal) == record && Read(folder / "Character Presets/Old.preset") == "original" &&
        Read(folder / "Data/Recovery/Trash/Old.preset") == "different", "Legacy recovery chose between conflicting copies.");
    Write(folder / journal, "V\t1\nH\tcommitted\ttrash\nP\tOld\tOld.preset\tOld\n");
    library.Execute({{"action", "refresh"}}, context);
    Check(!std::filesystem::exists(folder / journal) && Read(folder / "Data/Recovery/Trash/Old.preset") == "different", "Committed legacy cleanup changed a preset.");
    for (const auto& invalid : {std::string("V\t1\nH\tprepared\ttrash\nP\t../outside\tOld.preset\tOld\n"),
        std::string("V\t1\nH\tprepared\ttrash\nR\tOld\tNew\tOld\n"),
        std::string("V\t1\nH\tprepared\trename\nR\tOld\tOld\tOld\n")})
    {
        Write(folder / journal, invalid);
        rejected = false;
        try { library.Execute({{"action", "refresh"}}, context); } catch (const std::exception&) { rejected = true; }
        Check(rejected && Read(folder / journal) == invalid, "Invalid legacy recovery record was accepted or removed.");
    }
}

void HistoryTests(const std::filesystem::path& root)
{
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto snapshot = cpm::ParsePreset("LocKey#1:3\n");
    auto saved = call({{"action", "history_save"}, {"preset", snapshot}, {"description", "Before loading"}});
    Check(saved.at("status") == "complete" && saved.at("result").at("saved") == true, "History snapshot was not saved.");
    auto fingerprint = saved.at("result").at("fingerprint");
    auto repeated = call({{"action", "history_save"}, {"preset", snapshot}});
    Check(repeated.at("result").at("saved") == false, "Identical appearance was saved twice.");
    for (int index = 4; index <= 10; ++index)
    {
        snapshot["entries"][0]["index"] = index;
        Check(call({{"action", "history_save"}, {"preset", snapshot}}).at("status") == "complete", "History rotation failed.");
    }
    auto current = call({{"action", "history"}}).at("result");
    Check(current.at("entries").size() == 5, "History limit was not retained.");
    Check(current.at("entries").at(4).at("preset").at("entryCount") == 1, "History list lost the saved-choice count.");
    Check(call({{"action", "history_read"}, {"index", 5}, {"fingerprint", current.at("fingerprint")}}).at("result").at("preset").at("entries").at(0).at("index") == 6, "History rotation changed the saved order.");
    Check(call({{"action", "history_read"}, {"index", 1}, {"fingerprint", fingerprint}}).at("status") == "failed", "Stale history selection was accepted.");
    Check(call({{"action", "history_clear"}, {"confirmed", true}, {"fingerprint", fingerprint}}).at("status") == "failed", "Stale history clear was accepted.");
    Check(call({{"action", "history_clear"}, {"confirmed", true}, {"fingerprint", current.at("fingerprint")}}).at("status") == "complete", "History could not be cleared.");
    Check(!call({{"action", "history"}}).at("result").at("recoveryAvailable").get<bool>(), "Cleared history remained available.");
}

void TrashTests(const std::filesystem::path& root)
{
    Write(root / "Character Presets/Physical/Old.preset", "LocKey#1:3\n");
    Write(root / "Character Presets/Other.preset", "LocKey#2:4\n");
    Write(root / "Data/Catalog/Virtual Folders.txt", "P\tPhysical/Old\tFolder/Nested/Old\nF\tFolder/Empty\nX\tPhysical\n");
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto revision = call({{"action", "refresh"}}).at("result").at("revision");
    auto trash = call({{"action", "trash_query"}}).at("result");
    auto change = [&](Json request) {
        request["revision"] = revision;
        request["fingerprint"] = trash.at("fingerprint");
        auto result = call(std::move(request));
        if (result.at("status") != "complete") throw std::runtime_error(result.dump());
        revision = result.at("result").at("revision");
        trash = call({{"action", "trash_query"}}).at("result");
        return result;
    };
    Check(call({{"action", "trash_move"}, {"folder", "Folder"}, {"revision", revision}, {"fingerprint", trash.at("fingerprint")}}).at("status") == "failed", "Unconfirmed Trash action accepted.");
    change({{"action", "trash_move"}, {"folder", "Folder"}, {"confirmed", true}});
    Check(trash.at("total") == 1 && trash.at("groups").size() == 1, "Folder Trash did not retain its group.");
    Check(!std::filesystem::exists(root / "Character Presets/Physical/Old.preset"), "Trashed preset remained in the library.");
    Check(!call({{"action", "folders"}}).at("result").at("folders").contains("Folder"), "Trashed folder remained visible.");
    const auto group = trash.at("groups").items().begin().key();
    change({{"action", "trash_restore"}, {"group", group}});
    Check(Read(root / "Character Presets/Old.preset") == "LocKey#1:3\n", "Restore changed an older preset.");
    Check(call({{"action", "folders"}}).at("result").at("folders").contains("Folder/Empty"), "Folder restore lost its empty child.");
    Check(call({{"action", "read"}, {"name", "Folder/Nested/Old"}}).at("status") == "complete", "Folder restore lost its original assignment.");
    change({{"action", "trash_move"}, {"names", Json::array({"Other"})}, {"confirmed", true}});
    Write(root / "Character Presets/Other.preset", "LocKey#9:8\n");
    revision = call({{"action", "refresh"}}).at("result").at("revision");
    change({{"action", "trash_restore"}, {"filename", "Other.preset"}});
    Check(Read(root / "Character Presets/Other.preset") == "LocKey#9:8\n", "Restore replaced an existing preset.");
    Check(call({{"action", "read"}, {"name", "Other Restored 1"}}).at("result").at("preset").at("entries").at(0).at("index") == 4, "Restore conflict lost the saved appearance.");
    change({{"action", "trash_move"}, {"names", Json::array({"Other Restored 1"})}, {"confirmed", true}});
    const auto stale = trash.at("fingerprint");
    Write(root / "Data/Recovery/Trash/Added.PRESET", "LocKey#10:2\n");
    Check(call({{"action", "trash_empty"}, {"revision", revision}, {"fingerprint", stale}, {"confirmed", true}}).at("status") == "failed", "Stale empty-Trash confirmation accepted.");
    trash = call({{"action", "trash_query"}}).at("result");
    change({{"action", "trash_empty"}, {"confirmed", true}});
    Check(trash.at("total") == 0 && trash.at("groups").empty(), "Trash was not emptied.");
}

void ArchiveTests(const std::filesystem::path& root)
{
    cpm::Archive fixture;
    fixture.root = "Shared";
    fixture.folders.insert("Empty");
    fixture.presets["Nested/Old"] = "LocKey#1:3\n";
    const auto bundle = cpm::WriteArchive(fixture);
    Check(cpm::ReadArchive(bundle, false).presets == fixture.presets, "Folder bundle round trip changed preset bytes.");
    for (const auto& invalid : {std::string("CPMFOLDER\t1\nROOT\t../Unsafe\nP\tA\t41\n"),
        std::string("CPMFOLDER\t1\nROOT\tSafe\nP\tA\t41\nP\ta\t42\n"),
        std::string("CPMFOLDER\t1\nROOT\tSafe\nP\tA\t4G\n"),
        std::string("CPMFOLDER\t1\nROOT\tSafe\nP\tA\t4\n")})
    {
        bool rejected = false;
        try { cpm::ReadArchive(invalid, false); } catch (const std::exception&) { rejected = true; }
        Check(rejected, "Invalid shared file was accepted.");
    }
    Write(root / "Character Presets/Original.preset", "LocKey#1:3\n");
    Write(root / "Data/Config/Config.txt", "presetSort=modified\n");
    Write(root / "Data/Catalog/Virtual Folders.txt", "P\tOriginal\tFolder/Original\nF\tFolder/Empty\n");
    cpm::Library library(root);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto call = [&](Json request) {
        auto submitted = Submit(service, session, std::move(request));
        return Await(service, session, submitted.at("operation").get<std::uint64_t>());
    };
    auto revision = call({{"action", "refresh"}}).at("result").at("revision");
    auto exportResult = call({{"action", "bundle_export"}, {"folder", "Folder"}, {"revision", revision}});
    if (exportResult.at("status") != "complete") throw std::runtime_error(exportResult.dump());
    auto file = exportResult.at("result").at("filename");
    auto fingerprint = exportResult.at("result").at("fingerprint");
    Check(call({{"action", "bundle_preview"}, {"filename", file}}).at("result").at("names").at(0) == "Original", "Folder export retained the wrong relative path.");
    auto imported = call({{"action", "bundle_import"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}});
    if (imported.at("status") != "complete") throw std::runtime_error(imported.dump());
    revision = imported.at("result").at("revision");
    Check(imported.at("result").at("root") == "Folder Copy 2", "Folder import did not avoid a name conflict.");
    Check(call({{"action", "bundle_import"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}}).at("result").at("imported") == 0, "An unchanged shared folder was imported twice.");
    Check(call({{"action", "read"}, {"name", "Folder Copy 2/Original"}}).at("result").at("preset").at("entries").at(0).at("index") == 3, "Folder import lost saved choices.");
    Check(call({{"action", "bundle_trash"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}}).at("status") == "complete", "Shared folder could not move to Trash.");
    Check(call({{"action", "bundle_restore"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}}).at("status") == "complete", "Shared folder could not restore from Trash.");
    auto backup = call({{"action", "backup_export"}, {"revision", revision}});
    if (backup.at("status") != "complete") throw std::runtime_error(backup.dump());
    file = backup.at("result").at("filename");
    fingerprint = backup.at("result").at("fingerprint");
    Write(root / "Data/Config/Config.txt", "presetSort=name\n");
    imported = call({{"action", "backup_import"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}});
    if (imported.at("status") != "complete") throw std::runtime_error(imported.dump());
    revision = imported.at("result").at("revision");
    Check(imported.at("result").at("root") == "Imported Library", "Backup import did not isolate colliding names.");
    Check(Read(root / "Data/Config/Config.txt") == "presetSort=modified\n", "Backup import lost saved settings.");
    Check(Read(root / "Character Presets/Original.preset") == "LocKey#1:3\n", "Archive operations rewrote an older preset.");
    Check(call({{"action", "backup_delete"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}}).at("status") == "failed", "Unconfirmed backup deletion accepted.");
    Check(call({{"action", "backup_delete"}, {"filename", file}, {"fingerprint", fingerprint}, {"revision", revision}, {"confirmed", true}}).at("status") == "complete", "Confirmed backup deletion failed.");
}

void AcuServiceTests(const std::filesystem::path& root)
{
    const auto manager = root / "Character Preset Manager (CET)";
    const auto source = root / "AppearanceChangeUnlocker/character-presets";
    Write(source / "Nested/First.preset", "LocKey#1:3\n");
    Write(source / "Malformed.preset", "not an appearance\n");
    Write(manager / "Character Presets/ACU Presets/Nested/First.preset", "LocKey#9:9\n");
    cpm::Library library(manager);
    cpm::Service service([&](const Json& request, cpm::OperationContext& context) { return library.Execute(request, context); });
    const auto session = service.BeginSession().at("session").get<std::uint64_t>();
    auto import = [&] {
        auto submitted = Submit(service, session, {{"action", "import_acu"}});
        auto result = Await(service, session, submitted.at("operation").get<std::uint64_t>());
        if (result.at("status") != "complete") throw std::runtime_error(result.dump());
        return result.at("result");
    };
    auto result = import();
    Check(result.at("imported") == 1 && result.at("skipped") == 1, "ACU scan did not distinguish valid and malformed presets.");
    Check(Read(manager / "Character Presets/ACU Presets/Nested/First.preset") == "LocKey#9:9\n", "ACU scan overwrote an existing preset.");
    const auto destination = manager / "Character Presets/ACU Presets/Nested/First 2.preset";
    Check(Read(destination) == "LocKey#1:3\n", "ACU import lost its nested destination or original bytes.");
    const auto modified = std::filesystem::last_write_time(destination);
    result = import();
    Check(result.at("imported") == 0 && result.at("unchanged") == 1, "Unchanged ACU preset was imported again.");
    Check(std::filesystem::last_write_time(destination) == modified, "Unchanged ACU import rewrote its destination.");
    Write(source / "Nested/First.preset", "LocKey#1:4\n");
    Check(import().at("imported") == 1 && Read(destination) == "LocKey#1:4\n", "Changed ACU source did not update the owned import.");
    Write(destination, "LocKey#1:8\n");
    Write(source / "Nested/First.preset", "LocKey#1:5\n");
    result = import();
    Check(result.at("imported") == 0 && result.at("skipped") == 2, "Edited ACU destination was not reported.");
    Check(Read(destination) == "LocKey#1:8\n", "ACU update overwrote an edited destination.");
    Check(Read(source / "Nested/First.preset") == "LocKey#1:5\n", "ACU scan changed the source file.");
}
}

int main()
{
    const auto root = std::filesystem::temp_directory_path() /
        ("cpm-service-test-" + std::to_string(GetCurrentProcessId()) + "-" + std::to_string(GetTickCount64()));
    try
    {
        QueueTests();
        WatchTests(root / "watcher");
        LibraryTests(root);
        MutationTests(root / "mutations");
        BulkLibraryTests(root / "bulk");
        PreferencesTests(root / "preferences");
        RecoveryTests(root / "recovery");
        LegacyRecoveryTests(root / "legacy-recovery");
        HistoryTests(root / "history");
        TrashTests(root / "trash");
        ArchiveTests(root / "archives");
        AcuServiceTests(root / "acu");
        std::filesystem::remove_all(root);
        std::cout << "Native service queue, sessions, cancellation, shutdown, cached library, and read safety passed.\n";
        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << "\nTest files retained at " << root << '\n';
        return 1;
    }
}
