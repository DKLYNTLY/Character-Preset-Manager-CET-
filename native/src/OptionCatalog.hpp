#pragma once

#include <RED4ext/Scripting/Natives/Generated/game/ui/AppearanceInfo.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/ui/CharacterCustomizationOption.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/ui/MorphInfo.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/ui/SwitcherInfo.hpp>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <string>
#include <unordered_map>

namespace CPMOptions
{
using Info = RED4ext::game::ui::CharacterCustomizationInfo;
using Option = RED4ext::game::ui::CharacterCustomizationOption;
using OptionHandle = RED4ext::Handle<Option>;

struct Entry
{
    RED4ext::CName name;
    RED4ext::CName slot;
    std::uint32_t count = 0;
    std::uint32_t next = 0;
    int kind = 0;
    int off = 0;
    bool foundOff = false;
    std::unordered_map<std::string, std::int32_t> choices;
};

inline std::unordered_map<Info*, Entry> entries;
inline std::uint32_t cursor = 0;
inline std::uint64_t builds = 0;
inline std::uint64_t hits = 0;
inline std::size_t choiceCount = 0;

inline std::pair<int, std::uint32_t> Shape(Info* info)
{
    if (!info || !info->GetType()) return {};
    auto rtti = RED4ext::CRTTISystem::Get();
    const auto is = [&](const char* name) {
        auto parent = rtti->GetClass(name);
        return parent && info->GetType()->IsA(parent);
    };
    if (is("gameuiSwitcherInfo"))
        return {1, static_cast<RED4ext::game::ui::SwitcherInfo*>(info)->options.Size()};
    if (is("gameuiAppearanceInfo"))
        return {2, static_cast<RED4ext::game::ui::AppearanceInfo*>(info)->definitions.Size()};
    if (is("gameuiMorphInfo"))
        return {3, static_cast<RED4ext::game::ui::MorphInfo*>(info)->morphNames.Size()};
    return {};
}

inline std::string Choice(Info* info, int kind, std::uint32_t index)
{
    const char* prefix = "";
    const char* value = nullptr;
    if (kind == 1)
    {
        prefix = "options:";
        value = static_cast<RED4ext::game::ui::SwitcherInfo*>(info)->options[index].localizedName.c_str();
    }
    else if (kind == 2)
    {
        prefix = "definitions:";
        value = static_cast<RED4ext::game::ui::AppearanceInfo*>(info)->definitions[index].name.ToString();
    }
    else if (kind == 3)
    {
        prefix = "morphNames:";
        value = static_cast<RED4ext::game::ui::MorphInfo*>(info)->morphNames[index].morphName.ToString();
    }
    return value && *value ? std::string(prefix) + value : std::string{};
}

inline bool IsOff(std::string choice)
{
    const auto colon = choice.find(':');
    if (colon != std::string::npos) choice.erase(0, colon + 1);
    for (auto& character : choice)
        if (character >= 'A' && character <= 'Z') character += 'a' - 'A';
    return choice == "off" || choice == "common-off" || choice == "none" || choice == "common-none";
}

inline Entry& Get(Info* info)
{
    const auto [kind, count] = Shape(info);
    auto [position, inserted] = entries.try_emplace(info);
    auto& entry = position->second;
    if (inserted || entry.name != info->name || entry.slot != info->uiSlot ||
        entry.kind != kind || entry.count != count)
    {
        choiceCount -= entry.choices.size();
        entry = Entry{};
        entry.name = info->name;
        entry.slot = info->uiSlot;
        entry.kind = kind;
        entry.count = count <= 16384 ? count : 0;
    }
    return entry;
}

inline void Step(Info* info, Entry& entry)
{
    const auto index = entry.next++;
    auto choice = Choice(info, entry.kind, index);
    if (entry.kind == 1 && !entry.foundOff && IsOff(choice))
    {
        entry.off = static_cast<int>(index);
        entry.foundOff = true;
    }
    if (choiceCount >= 65536)
    {
        for (auto& [otherInfo, other] : entries)
        {
            if (otherInfo == info) continue;
            choiceCount -= other.choices.size();
            decltype(other.choices){}.swap(other.choices);
            other.next = 0;
            other.off = 0;
            other.foundOff = false;
        }
    }
    auto [position, inserted] = entry.choices.try_emplace(std::move(choice), static_cast<std::int32_t>(index));
    if (!inserted) position->second = -1;
    else ++choiceCount;
    if (entry.next == entry.count) ++builds;
}

inline Info* GetInfo(const OptionHandle& option)
{
    return option && option->info ? option->info.instance : nullptr;
}

struct Catalog : RED4ext::IScriptable
{
    RED4ext::CClass* GetNativeType() override;
};
inline RED4ext::TTypedClass<Catalog> catalogClass("CPMOptionCatalog");
inline RED4ext::CClass* Catalog::GetNativeType() { return &catalogClass; }

inline void Ready(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    ++frame->code;
    if (output) *static_cast<std::int32_t*>(output) = 1;
}

inline void Clear(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void*, std::int64_t)
{
    ++frame->code;
    decltype(entries){}.swap(entries);
    cursor = 0;
    builds = 0;
    hits = 0;
    choiceCount = 0;
}

inline void Invalidate(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void*, std::int64_t)
{
    OptionHandle option;
    RED4ext::GetParameter(frame, &option);
    ++frame->code;
    if (auto info = GetInfo(option))
    {
        if (auto found = entries.find(info); found != entries.end())
        {
            choiceCount -= found->second.choices.size();
            entries.erase(found);
        }
    }
}

inline void Warm(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    RED4ext::DynArray<OptionHandle> options;
    std::int32_t budget = 64;
    RED4ext::GetParameter(frame, &options);
    RED4ext::GetParameter(frame, &budget);
    ++frame->code;
    const auto started = std::chrono::steady_clock::now();
    int work = 0;
    std::uint32_t inspected = 0;
    while (!options.IsEmpty() && work < std::clamp(budget, 1, 4096) && choiceCount < 65536 && inspected < options.Size() &&
        std::chrono::steady_clock::now() - started < std::chrono::milliseconds(2))
    {
        cursor %= options.Size();
        auto info = GetInfo(options[cursor]);
        if (!info) { ++cursor; ++inspected; continue; }
        auto& entry = Get(info);
        if (!options[cursor]->isActive || !options[cursor]->isEditable) { ++cursor; ++inspected; }
        else if (entry.next < entry.count) { Step(info, entry); ++work; }
        else { ++cursor; ++inspected; }
    }
    if (output) *static_cast<std::int32_t*>(output) = work;
}

inline void Match(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    OptionHandle option;
    RED4ext::CString choice;
    RED4ext::GetParameter(frame, &option);
    RED4ext::GetParameter(frame, &choice);
    ++frame->code;
    std::int32_t result = -1;
    if (auto info = GetInfo(option))
    {
        const auto [kind, count] = Shape(info);
        if (count > 16384)
        {
            for (std::uint32_t index = 0; index < count && index < 2147483647; ++index)
            {
                if (Choice(info, kind, index) != choice.c_str()) continue;
                if (result >= 0) { result = -1; break; }
                result = static_cast<std::int32_t>(index);
            }
            if (output) *static_cast<std::int32_t*>(output) = result;
            return;
        }
        auto& entry = Get(info);
        const bool cached = entry.next == entry.count;
        while (entry.next < entry.count) Step(info, entry);
        auto found = entry.choices.find(choice.c_str());
        if (found != entry.choices.end()) result = found->second;
        if (result >= 0 && Choice(info, entry.kind, static_cast<std::uint32_t>(result)) != choice.c_str())
        {
            choiceCount -= entry.choices.size();
            entries.erase(info);
            auto& fresh = Get(info);
            while (fresh.next < fresh.count) Step(info, fresh);
            found = fresh.choices.find(choice.c_str());
            result = found == fresh.choices.end() ? -1 : found->second;
        }
        if (cached) ++hits;
    }
    if (output) *static_cast<std::int32_t*>(output) = result;
}

inline void Matches(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    OptionHandle option;
    RED4ext::CString choice;
    std::int32_t index = -1;
    RED4ext::GetParameter(frame, &option);
    RED4ext::GetParameter(frame, &choice);
    RED4ext::GetParameter(frame, &index);
    ++frame->code;
    bool result = false;
    if (auto info = GetInfo(option); info && index >= 0)
    {
        const auto [kind, count] = Shape(info);
        result = static_cast<std::uint32_t>(index) < count &&
            Choice(info, kind, static_cast<std::uint32_t>(index)) == choice.c_str();
    }
    if (output) *static_cast<bool*>(output) = result;
}

inline void Cleanup(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    OptionHandle option;
    RED4ext::GetParameter(frame, &option);
    ++frame->code;
    int result = 0;
    if (auto info = GetInfo(option))
    {
        const auto [kind, count] = Shape(info);
        if (kind != 1)
        {
            if (output) *static_cast<std::int32_t*>(output) = 0;
            return;
        }
        if (count > 16384)
        {
            for (std::uint32_t index = 0; index < count && index < 2147483647; ++index)
            {
                if (!IsOff(Choice(info, kind, index))) continue;
                result = static_cast<std::int32_t>(index);
                break;
            }
            if (output) *static_cast<std::int32_t*>(output) = result;
            return;
        }
        auto& entry = Get(info);
        while (entry.next < entry.count) Step(info, entry);
        if (entry.foundOff && !IsOff(Choice(info, entry.kind, static_cast<std::uint32_t>(entry.off))))
        {
            choiceCount -= entry.choices.size();
            entries.erase(info);
            auto& fresh = Get(info);
            while (fresh.next < fresh.count) Step(info, fresh);
            result = fresh.off;
        }
        else result = entry.off;
    }
    if (output) *static_cast<std::int32_t*>(output) = result;
}

inline void Role(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    OptionHandle option;
    RED4ext::GetParameter(frame, &option);
    ++frame->code;
    int result = -1;
    if (auto info = GetInfo(option); info && info->link != RED4ext::CName{} && info->link != RED4ext::CName("None"))
        result = info->linkController ? 0 : 1;
    if (output) *static_cast<std::int32_t*>(output) = result;
}

inline void Statistics(RED4ext::IScriptable*, RED4ext::CStackFrame* frame, void* output, std::int64_t)
{
    ++frame->code;
    const auto text = "native profiles=" + std::to_string(entries.size()) + " lists=" +
        std::to_string(builds) + " hits=" + std::to_string(hits) + " keys=" + std::to_string(choiceCount);
    if (output) *static_cast<RED4ext::CString*>(output) = RED4ext::CString(text.c_str());
}

inline void Register()
{
    RED4ext::CNamePool::Add("CPMOptionCatalog");
    catalogClass.flags = {.isNative = true};
    RED4ext::CRTTISystem::Get()->RegisterType(&catalogClass);
}

inline void PostRegister()
{
    catalogClass.parent = RED4ext::CRTTISystem::Get()->GetClass("IScriptable");
    const auto add = [](const char* name, RED4ext::ScriptingFunction_t<void*> callback, const char* result) {
        auto function = RED4ext::CClassStaticFunction::Create(&catalogClass, name, name, callback);
        function->flags = {.isNative = true, .isStatic = true};
        if (result) function->SetReturnType(result);
        catalogClass.RegisterFunction(function);
        return function;
    };
    add("Ready", Ready, "Int32");
    add("Clear", Clear, nullptr);
    add("Invalidate", Invalidate, nullptr)->AddParam("handle:gameuiCharacterCustomizationOption", "option");
    auto warm = add("Warm", Warm, "Int32");
    warm->AddParam("array:handle:gameuiCharacterCustomizationOption", "options");
    warm->AddParam("Int32", "budget");
    auto match = add("Match", Match, "Int32");
    match->AddParam("handle:gameuiCharacterCustomizationOption", "option");
    match->AddParam("String", "choice");
    auto matches = add("Matches", Matches, "Bool");
    matches->AddParam("handle:gameuiCharacterCustomizationOption", "option");
    matches->AddParam("String", "choice");
    matches->AddParam("Int32", "index");
    add("Cleanup", Cleanup, "Int32")->AddParam("handle:gameuiCharacterCustomizationOption", "option");
    add("Role", Role, "Int32")->AddParam("handle:gameuiCharacterCustomizationOption", "option");
    add("Statistics", Statistics, "String");
}
}
