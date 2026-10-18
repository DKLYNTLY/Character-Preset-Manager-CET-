#include "NativeBindings.hpp"
#include "Library.hpp"
#include "Service.hpp"
#include "DirectoryWatch.hpp"

#include <RED4ext/RED4ext.hpp>

#include <memory>
#include <mutex>
#include <utility>

namespace cpm
{
namespace
{
std::mutex serviceMutex;
std::shared_ptr<Service> service;
std::unique_ptr<DirectoryWatch> watcher;

std::shared_ptr<Service> Current()
{
    std::lock_guard lock(serviceMutex);
    return service;
}

template<typename Callback>
void StringResult(RED4ext::CString* output, Callback callback)
{
    if (!output) return;
    try
    {
        auto current = Current();
        *output = RED4ext::CString(current ? callback(*current) :
            "{\"available\":false,\"accepted\":false,\"error\":\"The native preset service is unavailable. Reinstall Character Preset Manager and restart the game.\"}");
    }
    catch (...)
    {
        *output = RED4ext::CString("{\"accepted\":false,\"error\":\"The native preset request could not finish safely.\"}");
    }
}

void Status(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* output, int64_t)
{
    ++frame->code;
    StringResult(output, [](Service& current) { return current.Status().dump(); });
}

void Begin(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, std::uint64_t* output, int64_t)
{
    ++frame->code;
    if (!output) return;
    *output = 0;
    try
    {
        auto current = Current();
        if (current) *output = current->BeginSession().value("session", std::uint64_t{});
    }
    catch (...) {}
}

void Close(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, bool* output, int64_t)
{
    std::uint64_t session = 0;
    RED4ext::GetParameter(frame, &session);
    ++frame->code;
    if (!output) return;
    *output = false;
    try
    {
        auto current = Current();
        if (current) *output = current->CloseSession(session).value("accepted", false);
    }
    catch (...) {}
}

void Submit(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* output, int64_t)
{
    std::uint64_t session = 0;
    RED4ext::CString action, payload;
    RED4ext::GetParameter(frame, &session);
    RED4ext::GetParameter(frame, &action);
    RED4ext::GetParameter(frame, &payload);
    ++frame->code;
    StringResult(output, [&](Service& current) {
        if (payload.Length() > Service::MaximumRequestBytes || action.Length() > 64)
            return std::string("{\"accepted\":false,\"error\":\"The preset request exceeds the size limit.\"}");
        return current.SubmitRaw(session, std::string(action.c_str(), action.Length()),
            std::string(payload.c_str(), payload.Length())).dump();
    });
}

void Poll(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* output, int64_t)
{
    std::uint64_t session = 0, operation = 0;
    bool consume = false;
    RED4ext::GetParameter(frame, &session);
    RED4ext::GetParameter(frame, &operation);
    RED4ext::GetParameter(frame, &consume);
    ++frame->code;
    StringResult(output, [&](Service& current) { return current.PollText(session, operation, consume); });
}

void Cancel(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* output, int64_t)
{
    std::uint64_t session = 0, operation = 0;
    RED4ext::GetParameter(frame, &session);
    RED4ext::GetParameter(frame, &operation);
    ++frame->code;
    StringResult(output, [&](Service& current) { return current.Cancel(session, operation).dump(); });
}

template<typename Callback>
RED4ext::CGlobalFunction* Function(const char* name, Callback callback, const char* result)
{
    auto function = RED4ext::CGlobalFunction::Create(name, name, callback);
    function->flags = {.isNative = true, .isStatic = true};
    function->SetReturnType(result);
    return function;
}

void EndAppearance(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, RED4ext::CString* output, int64_t)
{
    std::uint64_t session = 0, operation = 0;
    RED4ext::GetParameter(frame, &session);
    RED4ext::GetParameter(frame, &operation);
    ++frame->code;
    StringResult(output, [&](Service& current) { return current.EndAppearance(session, operation).dump(); });
}

void RegisterFunctions()
{
    auto rtti = RED4ext::CRTTISystem::Get();
    rtti->RegisterFunction(Function("CPMNativeStatus", &Status, "String"));
    rtti->RegisterFunction(Function("CPMNativeBegin", &Begin, "Uint64"));
    auto close = Function("CPMNativeClose", &Close, "Bool");
    close->AddParam("Uint64", "session");
    rtti->RegisterFunction(close);
    auto submit = Function("CPMNativeSubmit", &Submit, "String");
    submit->AddParam("Uint64", "session");
    submit->AddParam("String", "action");
    submit->AddParam("String", "payload");
    rtti->RegisterFunction(submit);
    auto poll = Function("CPMNativePoll", &Poll, "String");
    poll->AddParam("Uint64", "session");
    poll->AddParam("Uint64", "operation");
    poll->AddParam("Bool", "consume");
    rtti->RegisterFunction(poll);
    auto cancel = Function("CPMNativeCancel", &Cancel, "String");
    cancel->AddParam("Uint64", "session");
    cancel->AddParam("Uint64", "operation");
    rtti->RegisterFunction(cancel);
    auto endAppearance = Function("CPMNativeEndAppearance", &EndAppearance, "String");
    endAppearance->AddParam("Uint64", "session");
    endAppearance->AddParam("Uint64", "operation");
    rtti->RegisterFunction(endAppearance);
}
}

void RegisterNativeService()
{
    RED4ext::CRTTISystem::Get()->AddPostRegisterCallback(RegisterFunctions);
}

void StartNativeService(const std::filesystem::path& manager)
{
    auto library = std::make_shared<Library>(manager);
    auto next = std::make_shared<Service>([library](const Json& request, OperationContext& context) {
        return library->Execute(request, context);
    });
    std::lock_guard lock(serviceMutex);
    service = next;
    watcher = std::make_unique<DirectoryWatch>(manager, [weak = std::weak_ptr<Service>(next)] {
        if (const auto current = weak.lock()) current->NotifyChange();
    });
}

void StopNativeService()
{
    std::shared_ptr<Service> previous;
    std::unique_ptr<DirectoryWatch> previousWatcher;
    {
        std::lock_guard lock(serviceMutex);
        previous = std::exchange(service, {});
        previousWatcher = std::move(watcher);
    }
    previousWatcher.reset();
    if (previous) previous->Shutdown();
}
}
