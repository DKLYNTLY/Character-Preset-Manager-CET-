#pragma once

#include "FileService.hpp"

namespace cpm
{
bool CopyPreset(const fs::path& source, const fs::path& destination,
                const std::uintmax_t expectedSize,
                const fs::file_time_type expectedModified);
void Scan(const Paths& paths);
}
