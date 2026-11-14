#include "StorageBinding.hpp"
#include "PresetStore.hpp"
#include "FileService.hpp"
#include <RED4ext/RED4ext.hpp>

namespace cpm
{
namespace
{
std::unique_ptr<PresetStore> store;
std::optional<OperationResult> collected;
bool enabled = true;

bool EnsureStore()
{
    if (!enabled) return false;
    if (!store)
    {
        const auto root = GameRoot();
        if (!root) return false;
        store = std::make_unique<PresetStore>(*root / "red4ext/plugins/CharacterPresetManager/Character Presets");
    }
    return true;
}

void SubmitRead(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* result, int64_t)
{
    std::uint64_t id = 0, session = 0;
    RED4ext::CString relative;
    RED4ext::GetParameter(frame, &id); RED4ext::GetParameter(frame, &session); RED4ext::GetParameter(frame, &relative);
    frame->Step();
    *result = false;
    try { *result = EnsureStore() && store->Read(id, session, std::string(relative.c_str(), relative.Length())); }
    catch (...) {}
}

void SubmitSave(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* result, int64_t)
{
    std::uint64_t id = 0, session = 0;
    RED4ext::CString relative, contents, fingerprint;
    RED4ext::GetParameter(frame, &id); RED4ext::GetParameter(frame, &session);
    RED4ext::GetParameter(frame, &relative); RED4ext::GetParameter(frame, &contents); RED4ext::GetParameter(frame, &fingerprint);
    frame->Step();
    *result = false;
    try
    {
        const auto preset = document9::Decode(std::string_view(contents.c_str(), contents.Length()));
        if (!preset || !EnsureStore()) return;
        const auto expected = fingerprint.Length() ? std::optional<std::string>(std::string(fingerprint.c_str(), fingerprint.Length())) : std::nullopt;
        *result = store->Save(id, session, std::string(relative.c_str(), relative.Length()), *preset, expected);
    }
    catch (...) {}
}

void Poll(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* result, int64_t)
{
    frame->Step();
    *result = false;
    try { collected = enabled && store ? store->Poll() : std::nullopt; *result = collected.has_value(); }
    catch (...) { collected.reset(); }
}

void Text(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* result, int64_t)
{
    RED4ext::CString field;
    RED4ext::GetParameter(frame, &field); frame->Step();
    *result = RED4ext::CString("");
    if (!enabled || !collected) return;
    if (field == "contents") *result = RED4ext::CString(collected->payload);
    else if (field == "fingerprint") *result = RED4ext::CString(collected->fingerprint);
    else if (field == "id") *result = RED4ext::CString(std::to_string(collected->id));
    else if (field == "session") *result = RED4ext::CString(std::to_string(collected->session));
    else if (field == "status")
    {
        const char* names[] = {"success", "partial", "conflict", "cancelled", "failure"};
        *result = RED4ext::CString(names[static_cast<std::size_t>(collected->status)]);
    }
}
}

void RegisterStorageBinding()
{
    if (!enabled) return;
    auto rtti = RED4ext::CRTTISystem::Get();
    auto read = RED4ext::CGlobalFunction::Create("CPMStorageRead", "CPMStorageRead", &SubmitRead);
    read->flags = {.isNative = true, .isStatic = true}; read->SetReturnType("Bool");
    read->AddParam("Uint64", "id"); read->AddParam("Uint64", "session"); read->AddParam("String", "relative");
    rtti->RegisterFunction(read);
    auto save = RED4ext::CGlobalFunction::Create("CPMStorageSave", "CPMStorageSave", &SubmitSave);
    save->flags = {.isNative = true, .isStatic = true}; save->SetReturnType("Bool");
    save->AddParam("Uint64", "id"); save->AddParam("Uint64", "session"); save->AddParam("String", "relative");
    save->AddParam("String", "contents"); save->AddParam("String", "fingerprint"); rtti->RegisterFunction(save);
    auto poll = RED4ext::CGlobalFunction::Create("CPMStoragePoll", "CPMStoragePoll", &Poll);
    poll->flags = {.isNative = true, .isStatic = true}; poll->SetReturnType("Bool"); rtti->RegisterFunction(poll);
    auto text = RED4ext::CGlobalFunction::Create("CPMStorageResult", "CPMStorageResult", &Text);
    text->flags = {.isNative = true, .isStatic = true}; text->SetReturnType("String"); text->AddParam("String", "field");
    rtti->RegisterFunction(text);
}

void StopStorageBinding()
{
    enabled = false;
    if (store) store->Stop();
    store.reset(); collected.reset();
}
}
