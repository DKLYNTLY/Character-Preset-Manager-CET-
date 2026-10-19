#pragma once

#include <filesystem>
#include <string>

namespace cpm
{
std::string MigrateStorage(const std::filesystem::path& source, const std::filesystem::path& destination);
}
