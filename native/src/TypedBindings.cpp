#include "TypedBindings.hpp"
#include <stdexcept>

namespace cpm
{
namespace
{
template<typename T> T& Property(RED4ext::IScriptable* object, const char* name)
{
    if (!object) throw std::runtime_error("A native preset request is missing.");
    const auto property = object->GetType()->GetProperty(name);
    if (!property || property->type->GetSize() != sizeof(T)) throw std::runtime_error("Update all Character Preset Manager files together.");
    return *property->GetValuePtr<T>(object);
}
std::string String(RED4ext::IScriptable* object, const char* name)
{
    const auto& value = Property<RED4ext::CString>(object, name);
    if (value.Length() > 16384) throw std::runtime_error("The preset text exceeds the size limit.");
    return std::string(value.c_str(), value.Length());
}
Json Options(RED4ext::IScriptable* request)
{
    const auto& options = Property<RED4ext::DynArray<RED4ext::Handle<RED4ext::IScriptable>>>(request, "options");
    if (options.Size() > 4096) throw std::runtime_error("The appearance exceeds the option limit.");
    Json output = Json::array();
    std::size_t budget = 0;
    for (const auto& handle : options)
    {
        auto option = handle.GetPtr();
        Json choices = Json::object();
        for (const auto* field : {"definitions", "switches", "morphs"})
        {
            const auto& values = Property<RED4ext::DynArray<RED4ext::CString>>(option, field);
            if (values.Size() > 65536) throw std::runtime_error("An appearance option has too many choices.");
            auto& list = choices[std::string(field) == "switches" ? "options" : std::string(field) == "morphs" ? "morphNames" : field];
            list = Json::array();
            for (const auto& value : values) {
                budget += value.Length() + 4;
                if (budget > 1048576) throw std::runtime_error("The editor's appearance choices exceed the size limit.");
                list.push_back(std::string(value.c_str(), value.Length()));
            }
        }
        output.push_back({{"label", String(option, "label")}, {"key", String(option, "key")}, {"slot", String(option, "slot")},
            {"currIndex", Property<std::uint32_t>(option, "index")}, {"isActive", Property<bool>(option, "active")},
            {"isEditable", Property<bool>(option, "editable")}, {"choices", choices}});
    }
    if (output.dump().size() > 1048576) throw std::runtime_error("The editor's appearance choices exceed the size limit.");
    return output;
}
void Set(RED4ext::IScriptable* reply, const char* key, const std::string& value) { Property<RED4ext::CString>(reply, key) = RED4ext::CString(value); }
}
void Exchange(Service& service, RED4ext::IScriptable* request, RED4ext::IScriptable* reply)
{
    try
    {
        const auto command = String(request, "command");
        const auto session = Property<std::uint64_t>(request, "session"), operation = Property<std::uint64_t>(request, "operation");
        Property<bool>(reply, "accepted") = false;
        Set(reply, "version", "3.1.4");
        Json result;
        if (command == "snapshot")
        {
            Property<std::uint64_t>(reply, "snapshotHash") = std::hash<std::string>{}(Options(request).dump());
            Property<bool>(reply, "accepted") = true;
            return;
        }
        if (command == "begin") result = service.BeginSession();
        else if (command == "close") result = service.CloseSession(session);
        else if (command == "poll") result = service.Poll(session, operation, true);
        else if (command == "cancel") result = service.Cancel(session, operation);
        else
        {
            Json payload = {{"command", command}, {"text", String(request, "text")}, {"extra", String(request, "extra")},
                {"confirmed", Property<bool>(request, "confirmed")}, {"unconfirmed", Property<bool>(request, "unconfirmed")}, {"options", Options(request)}};
            result = service.SubmitRaw(session, "native_ui", payload.dump());
        }
        Property<bool>(reply, "accepted") = result.value("accepted", false);
        Property<std::uint64_t>(reply, "session") = result.value("session", session);
        Property<std::uint64_t>(reply, "operation") = result.value("operation", operation);
        Set(reply, "status", result.value("status", ""));
        Set(reply, "payload", result.value("error", ""));
        Set(reply, "kind", result.contains("error") ? "error" : "");
        if (result.contains("result"))
        {
            const auto& value = result.at("result");
            Property<std::uint64_t>(reply, "snapshotHash") = value.value("snapshotHash", std::uint64_t{});
            Set(reply, "kind", value.value("kind", value.contains("error") ? "error" : "status"));
            Set(reply, "payload", value.value("payload", value.value("error", "")));
            if (value.contains("change"))
            {
                const auto& change = value["change"];
                Property<std::int32_t>(reply, "position") = change.at("position").get<std::int32_t>() - 1;
                Property<std::uint32_t>(reply, "target") = change.at("target").get<std::uint32_t>();
                Property<std::uint32_t>(reply, "current") = change.at("current").get<std::uint32_t>();
                Set(reply, "key", change.value("label", "")); Set(reply, "slot", change.value("slot", ""));
            }
        }
    }
    catch (const std::exception& error)
    {
        Property<bool>(reply, "accepted") = false;
        Set(reply, "kind", "error"); Set(reply, "payload", error.what());
    }
}
}
