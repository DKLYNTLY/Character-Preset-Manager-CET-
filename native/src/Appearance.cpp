#include "Appearance.hpp"

#include <cmath>
#include <map>
#include <optional>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

namespace cpm
{
namespace
{
std::optional<std::uint32_t> Index(const Json& value)
{
    if (!value.is_number()) return std::nullopt;
    const auto number = value.get<double>();
    if (!std::isfinite(number) || number < 0 || number > 4294967295.0 || std::floor(number) != number) return std::nullopt;
    return static_cast<std::uint32_t>(number);
}

std::optional<std::uint32_t> ChoiceIndex(const Json& option, const std::string& choice)
{
    const auto colon = choice.find(':');
    if (colon == std::string::npos || colon + 1 == choice.size()) return std::nullopt;
    const auto field = choice.substr(0, colon);
    if (field != "definitions" && field != "options" && field != "morphNames") return std::nullopt;
    if (!option.contains("choices") || !option["choices"].contains(field)) return std::nullopt;
    const auto& choices = option["choices"][field];
    if (!choices.is_array() || choices.size() > 65536) throw std::runtime_error("An appearance option has too many choices.");
    std::optional<std::uint32_t> match;
    for (std::size_t index = 0; index < choices.size(); ++index)
    {
        if (choices[index] == choice.substr(colon + 1))
        {
            if (match) return std::nullopt;
            match = static_cast<std::uint32_t>(index);
        }
    }
    return match;
}

struct Entry
{
    const Json* value;
    std::string label;
    std::string slot;
    std::string key;
    std::string slotKey;
    std::size_t occurrence;
    std::size_t position;
    std::size_t slotOccurrence;
};

std::vector<Entry> Prepare(const Json& values, bool live, std::map<std::string, std::size_t>& counts,
    std::map<std::string, std::size_t>& slots)
{
    if (!values.is_array() || values.size() > 4096) throw std::runtime_error("The appearance exceeds the option limit.");
    std::vector<Entry> entries;
    std::size_t position = 0;
    for (const auto& value : values)
    {
        ++position;
        const auto label = value.value("key", std::string{});
        if (label.empty() || (live && (!value.value("isActive", false) || !value.value("isEditable", false)))) continue;
        const auto slot = value.value("slot", std::string{});
        if (label.size() > 256 || slot.size() > 256) throw std::runtime_error("An appearance option name exceeds the size limit.");
        const auto occurrence = ++counts[label];
        const auto slotKey = slot.empty() ? "" : slot + '\x1f' + std::to_string(++slots[slot]);
        entries.push_back({&value, label, slot, label + '\x1f' + std::to_string(occurrence), slotKey, occurrence, live ? position : entries.size() + 1, slot.empty() ? 0 : slots[slot]});
    }
    return entries;
}
}

Json PlanAppearance(const Json& request)
{
    std::map<std::string, std::size_t> savedCounts, savedSlots, liveCounts, liveSlots;
    const auto saved = Prepare(request.at("preset").at("entries"), false, savedCounts, savedSlots);
    const auto live = Prepare(request.at("options"), true, liveCounts, liveSlots);
    if (saved.empty()) throw std::runtime_error("The preset has no saved appearance choices.");
    auto state = request.value("state", Json::object());
    if (state.is_array() && state.empty()) state = Json::object();
    if (!state.is_object()) throw std::runtime_error("The appearance load state is invalid.");
    for (const auto* key : {"satisfied", "unconfirmed", "forcedKeys", "cleanupSkipped", "dependencyRemaps"})
    {
        if (!state.contains(key) || (state[key].is_array() && state[key].empty())) state[key] = Json::object();
        if (!state[key].is_object() || state[key].size() > 4096) throw std::runtime_error("The appearance load state exceeds its limits.");
    }
    const auto phase = state.value("phase", "precleanup");
    if (phase != "precleanup" && phase != "apply" && phase != "cleanup" && phase != "verify")
        throw std::runtime_error("The appearance load phase is invalid.");
    state["phase"] = phase;
    state["stalled"] = false;
    std::map<std::string, const Entry*> byKey, bySlot, savedByKey, savedBySlot;
    for (const auto& entry : live) { byKey[entry.key] = &entry; if (!entry.slotKey.empty()) bySlot[entry.slotKey] = &entry; }
    for (const auto& entry : saved) { savedByKey[entry.key] = &entry; if (!entry.slotKey.empty()) savedBySlot[entry.slotKey] = &entry; }
    auto marked = [&](const char* map, const std::string& key) { return state[map].value(key, false); };
    auto clearVisible = [&] {
        for (const auto& entry : live) if (!marked("unconfirmed", entry.key)) state["satisfied"].erase(entry.key);
        state["previousUnresolvedSignature"] = "";
        state["unresolvedRepeatCount"] = 0;
    };
    Json details = Json::array();
    auto result = [&](const std::string& outcome) {
        return Json{{"outcome", outcome}, {"state", state}, {"details", details},
            {"loadId", request.value("loadId", std::uint64_t{})}, {"snapshot", request.value("snapshot", std::uint64_t{})}};
    };
    auto change = [&](const Entry& candidate, std::uint32_t target, const std::string& kind, const std::string& trackingKey, bool forced) {
        auto output = result("change");
        output["change"] = {{"position", candidate.position}, {"label", candidate.label}, {"key", candidate.key},
            {"slot", candidate.slot}, {"occurrence", candidate.occurrence}, {"slotOccurrence", candidate.slotOccurrence}, {"target", target},
            {"current", Index(candidate.value->value("currIndex", Json{})).value_or(0)}, {"kind", kind},
            {"trackingKey", trackingKey}, {"forced", forced}};
        return output;
    };
    if (phase == "precleanup" || phase == "cleanup")
    {
        for (const auto& candidate : live)
        {
            const auto current = Index(candidate.value->value("currIndex", Json{})).value_or(0);
            const Entry* slot = nullptr;
            if (!candidate.slot.empty() && liveSlots[candidate.slot] == savedSlots[candidate.slot] && savedBySlot.contains(candidate.slotKey)) slot = savedBySlot.at(candidate.slotKey);
            bool keep = false;
            if (state["dependencyRemaps"].contains(candidate.key))
            {
                const auto& remap = state["dependencyRemaps"][candidate.key];
                keep = marked("satisfied", remap.value("savedKey", "")) && remap.value("label", "") == candidate.label &&
                    remap.value("position", std::size_t{}) == candidate.position && remap.value("slot", "") == candidate.slot &&
                    remap.value("slotOccurrence", std::size_t{}) == candidate.slotOccurrence &&
                    remap.value("occurrence", std::size_t{}) == candidate.occurrence && remap.value("target", std::uint32_t{}) == current &&
                    (candidate.slot.empty() || remap.value("slotCount", std::size_t{}) == liveSlots[candidate.slot]);
                if (keep && remap.contains("choice")) keep = ChoiceIndex(*candidate.value, remap["choice"]) == current;
                if (!keep) state["dependencyRemaps"].erase(candidate.key);
            }
            if (candidate.occurrence > savedCounts[candidate.label] && (!slot || Index(slot->value->at("index")) == 0u) &&
                current != 0 && !keep && !marked("cleanupSkipped", candidate.key))
                return change(candidate, 0, phase, candidate.key, false);
        }
        state["phase"] = phase == "precleanup" ? "apply" : "verify";
        state["remaining"] = saved.size();
        state["needsContinue"] = true;
        if (phase == "cleanup") { state["resetBefore"] = false; state["returnToCleanup"] = false; clearVisible(); }
        return result("continue");
    }
    std::set<std::string> seen, claimed, deferred, unresolved;
    std::size_t applied = 0, missing = 0, ambiguous = 0, invalid = 0;
    auto issue = [&](const Entry& entry, const std::string& reason, const std::string& category) {
        details.push_back({{"key", entry.key}, {"label", entry.label}, {"reason", reason}});
        unresolved.insert(category + ':' + entry.key);
    };
    for (const auto& candidate : live)
    {
        if (!savedByKey.contains(candidate.key)) continue;
        const auto& entry = *savedByKey.at(candidate.key);
        seen.insert(entry.key); claimed.insert(candidate.key);
        auto target = Index(entry.value->at("index"));
        if (entry.value->contains("choice")) target = ChoiceIndex(*candidate.value, entry.value->at("choice"));
        if (!target && entry.value->contains("choice")) { ++missing; issue(entry, "The saved custom choice is unavailable or repeated.", "unavailable-choice"); }
        else if (liveCounts[entry.label] != savedCounts[entry.label]) { ++ambiguous; issue(entry, "The number of repeated options differs from the preset.", "ambiguous"); }
        else if (!target) { ++invalid; issue(entry, "The saved choice number is outside the supported range.", "invalid-index"); }
        else
        {
            const auto current = Index(candidate.value->value("currIndex", Json{})).value_or(0);
            if (current == *target) { state["satisfied"][entry.key] = true; state["unconfirmed"].erase(entry.key); ++applied; }
            else if (marked("satisfied", entry.key) && marked("unconfirmed", entry.key)) ++applied;
            else if (marked("satisfied", entry.key)) { deferred.insert(entry.key); ++missing; issue(entry, "The editor changed this choice after applying it.", "reverted"); }
            else return change(candidate, *target, "apply", entry.key, false);
        }
    }
    for (const auto& entry : saved)
        if (!byKey.contains(entry.key) && Index(entry.value->at("index")) == 0u) state["satisfied"][entry.key] = true;
    auto remap = [&](const Entry& entry, const Entry& candidate, std::uint32_t target, bool forced) -> std::optional<Json> {
        seen.insert(entry.key); claimed.insert(candidate.key);
        Json mapping = {{"savedKey", entry.key}, {"label", candidate.label}, {"position", candidate.position},
            {"slot", candidate.slot}, {"slotCount", liveSlots[candidate.slot]}, {"occurrence", candidate.occurrence},
            {"slotOccurrence", candidate.slotOccurrence}, {"target", target}};
        if (entry.value->contains("choice")) mapping["choice"] = entry.value->at("choice");
        state["dependencyRemaps"][candidate.key] = mapping;
        const auto current = Index(candidate.value->value("currIndex", Json{})).value_or(0);
        if (current == target) { state["satisfied"][entry.key] = true; state["unconfirmed"].erase(entry.key); if (forced) state["forcedKeys"][entry.key] = true; else ++applied; }
        else if (marked("satisfied", entry.key) && marked("unconfirmed", entry.key)) { if (forced) state["forcedKeys"][entry.key] = true; else ++applied; }
        else if (marked("satisfied", entry.key)) { state["forcedKeys"].erase(entry.key); deferred.insert(entry.key); ++missing; issue(entry, "The editor changed a matched choice after applying it.", "reverted-remap"); }
        else return change(candidate, target, "apply", entry.key, forced);
        return std::nullopt;
    };
    for (const auto& entry : saved)
    {
        if (seen.contains(entry.key) || entry.slot.empty() || !entry.value->contains("choice") ||
            savedSlots[entry.slot] != liveSlots[entry.slot] || !bySlot.contains(entry.slotKey)) continue;
        const auto& candidate = *bySlot.at(entry.slotKey);
        if (claimed.contains(candidate.key)) continue;
        const auto target = ChoiceIndex(*candidate.value, entry.value->at("choice"));
        if (target) if (auto output = remap(entry, candidate, *target, false)) return *output;
    }
    if (state.value("forceFull", false)) for (std::size_t index = 0; index < saved.size(); ++index)
    {
        const auto& entry = saved[index];
        if (seen.contains(entry.key) || !Index(entry.value->at("index"))) continue;
        const Entry* candidate = nullptr;
        if (!entry.slot.empty() && savedSlots[entry.slot] == liveSlots[entry.slot] && bySlot.contains(entry.slotKey)) candidate = bySlot.at(entry.slotKey);
        else if (entry.slot.empty() && index > 0 && index + 1 < saved.size() && index + 1 < live.size() &&
            live[index - 1].key == saved[index - 1].key && live[index + 1].key == saved[index + 1].key && !savedByKey.contains(live[index].key)) candidate = &live[index];
        if (!candidate || claimed.contains(candidate->key)) continue;
        auto target = Index(entry.value->at("index"));
        if (entry.value->contains("choice")) target = ChoiceIndex(*candidate->value, entry.value->at("choice"));
        if (target) if (auto output = remap(entry, *candidate, *target, true)) return *output;
    }
    for (const auto& key : deferred) state["satisfied"].erase(key);
    std::size_t forced = 0;
    for (const auto& entry : saved)
    {
        if (!seen.contains(entry.key))
        {
            if (marked("satisfied", entry.key)) { ++applied; if (marked("forcedKeys", entry.key)) ++forced; }
            else { ++missing; issue(entry, "The saved option is unavailable in this editor or body setup.", "unavailable"); }
        }
        else if (marked("forcedKeys", entry.key)) { ++applied; ++forced; }
    }
    const auto remaining = missing + ambiguous + invalid;
    state["remaining"] = remaining;
    state["needsContinue"] = true;
    if (remaining != 0)
    {
        std::string signature;
        for (const auto& key : unresolved) signature += key + '|';
        state["unresolvedRepeatCount"] = state.value("previousUnresolvedSignature", "") == signature ? state.value("unresolvedRepeatCount", 0) + 1 : 1;
        state["previousUnresolvedSignature"] = signature;
        if (state["unresolvedRepeatCount"].get<int>() < 3) return result("continue");
        state["needsContinue"] = false; state["stalled"] = true;
        auto output = result(applied > 0 ? "partial" : "failed");
        output["applied"] = std::min(applied, saved.size());
        output["remaining"] = remaining;
        return output;
    }
    state["previousUnresolvedSignature"] = ""; state["unresolvedRepeatCount"] = 0;
    if ((phase == "apply" && state.value("resetBefore", false)) || (phase == "verify" && state.value("returnToCleanup", false)))
    {
        state["phase"] = "cleanup"; state["returnToCleanup"] = false; state["remaining"] = saved.size();
        return result("continue");
    }
    state["needsContinue"] = false; state["stalled"] = false;
    std::size_t unconfirmed = 0;
    for (const auto& entry : saved) if (marked("unconfirmed", entry.key)) ++unconfirmed;
    auto output = result(unconfirmed > 0 || !state["cleanupSkipped"].empty() ? "partial" : "complete");
    output["applied"] = std::min(applied, saved.size()); output["forced"] = forced;
    output["unconfirmed"] = unconfirmed; output["cleanupUnconfirmed"] = state["cleanupSkipped"].size();
    return output;
}

Json CompareAppearance(const Json& preset, const Json& options)
{
    std::map<std::string, std::size_t> savedCounts, savedSlots, liveCounts, liveSlots;
    const auto saved = Prepare(preset.at("entries"), false, savedCounts, savedSlots);
    const auto live = Prepare(options, true, liveCounts, liveSlots);
    std::map<std::string, const Entry*> byKey, bySlot;
    for (const auto& entry : live)
    {
        byKey[entry.key] = &entry;
        if (!entry.slotKey.empty()) bySlot[entry.slotKey] = &entry;
    }
    Json result = {{"total", saved.size()}, {"matching", 0}, {"changing", 0}, {"missing", 0},
        {"ambiguous", 0}, {"invalid", 0}, {"clearing", 0}, {"details", Json::array()}};
    auto count = [&](const std::string& key) { result[key] = result[key].get<std::size_t>() + 1; };
    std::set<std::string> claimed;
    for (const auto& entry : saved)
    {
        const Entry* candidate = nullptr;
        if (liveCounts[entry.label] == savedCounts[entry.label] && byKey.contains(entry.key)) candidate = byKey.at(entry.key);
        if (!candidate && !entry.slot.empty() && liveSlots[entry.slot] == savedSlots[entry.slot] && bySlot.contains(entry.slotKey))
            candidate = bySlot.at(entry.slotKey);
        const auto savedIndex = Index(entry.value->value("index", Json{}));
        const auto current = candidate ? Index(candidate->value->value("currIndex", Json{})) : std::nullopt;
        std::string status;
        if (!savedIndex) { status = "Invalid"; count("invalid"); }
        else if (candidate && !claimed.contains(candidate->key))
        {
            auto target = savedIndex;
            if (entry.value->contains("choice")) target = ChoiceIndex(*candidate->value, entry.value->at("choice").get<std::string>());
            if (!target) { status = "Missing"; count("missing"); }
            else
            {
                const bool matching = current && *current == *target;
                status = matching ? "Already matching" : "Will change";
                count(matching ? "matching" : "changing");
                claimed.insert(candidate->key);
            }
        }
        else if (*savedIndex == 0 && liveCounts[entry.label] == 0) { status = "Already matching"; count("matching"); }
        else if (liveCounts[entry.label] == 0) { status = "Missing"; count("missing"); }
        else { status = "Repeated or uncertain"; count("ambiguous"); }
        Json detail = {{"label", entry.label}, {"status", status}, {"target", entry.value->value("index", Json(0))}};
        if (!entry.slot.empty()) detail["slot"] = entry.slot;
        if (current) detail["current"] = *current;
        result["details"].push_back(std::move(detail));
    }
    for (const auto& entry : live)
    {
        const auto current = Index(entry.value->value("currIndex", Json{})).value_or(0);
        if (!claimed.contains(entry.key) && entry.occurrence > savedCounts[entry.label] && current != 0)
        {
            count("clearing");
            Json detail = {{"label", entry.label}, {"status", "Will clear"}, {"current", current}, {"target", 0}};
            if (!entry.slot.empty()) detail["slot"] = entry.slot;
            result["details"].push_back(std::move(detail));
        }
    }
    return result;
}
}
