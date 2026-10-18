#pragma once

#include <map>
#include <optional>
#include <set>
#include <string>

namespace cpm
{
struct Archive
{
    bool backup = false;
    std::string root;
    std::optional<std::string> config;
    std::set<std::string> folders;
    std::map<std::string, std::string> presets;
};

Archive ReadArchive(const std::string& contents, bool backup);
std::string WriteArchive(const Archive& archive);
}
