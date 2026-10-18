#pragma once

#include "Service.hpp"

#include <filesystem>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace cpm
{
struct FileChange
{
    std::string path;
    std::optional<std::string> contents;
    std::optional<std::string> expected;
    bool checkExpected = false;
};

class FileTransaction
{
public:
    using Resolver = std::function<std::filesystem::path(const std::string&)>;
    explicit FileTransaction(Resolver resolver);
    void Recover();
    void Apply(const std::vector<FileChange>& changes, OperationContext& context);
private:
    void Finish(const Json& manifest);
    void CleanStages();
    Resolver resolve_;
};
}
