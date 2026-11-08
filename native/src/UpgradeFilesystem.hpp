#pragma once
#include "FileFormats.hpp"
namespace cpm
{
bool PrepareUpgradeDirectories(const fs::path& manager, const std::string& batch, const std::string& storage);
class UpgradeFilesystem
{
public:
    explicit UpgradeFilesystem(fs::path manager);
    void Poll();
private:
    fs::path manager_;
    std::string previous_;
};
}
