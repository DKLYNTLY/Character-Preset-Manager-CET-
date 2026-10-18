#pragma once

#include "Service.hpp"

#include <filesystem>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace cpm
{
class Library
{
public:
    explicit Library(std::filesystem::path manager);
    Json Execute(const Json& request, OperationContext& context);
private:
    struct File
    {
        std::uintmax_t bytes = 0;
        std::filesystem::file_time_type modified;
        Json metadata;
    };
    std::filesystem::path SafePath(const std::string& relative) const;
    std::string Read(const std::string& relative, std::size_t maximum) const;
    Json Refresh(OperationContext& context);
    Json Query(const Json& request);
    Json View(const Json& request);
    Json Mutate(const Json& request, OperationContext& context);
    Json History(const Json& request, OperationContext& context);
    Json Trash(const Json& request, OperationContext& context);
    Json ArchiveAction(const Json& request, OperationContext& context);
    Json ImportAcu(OperationContext& context);
    void RecoverLegacy(OperationContext& context);
    Json Preferences(const Json& request, OperationContext& context);
    std::string Catalog(const Json& presets, const Json& folders, const Json& manual, const Json& ignored) const;
    std::string CheckedContents(const std::string& name) const;
    std::string UniqueStorage(const std::string& leaf) const;
    std::filesystem::path manager_;
    std::map<std::string, File> files_;
    Json presets_ = Json::object();
    Json folders_ = Json::object();
    Json manualFolders_ = Json::object();
    Json ignoredFolders_ = Json::object();
    std::optional<std::string> catalogContents_;
    std::uint64_t revision_ = 0;
    std::map<std::string, std::vector<std::string>> queryCache_;
    std::string viewKey_;
    Json viewFolders_ = Json::array();
    Json trashView_ = Json::object();
};
}
