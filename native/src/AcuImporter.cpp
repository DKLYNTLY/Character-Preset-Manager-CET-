#include "AcuImporter.hpp"

namespace cpm
{
bool CopyPreset(const fs::path& source, const fs::path& destination,
                const std::uintmax_t expectedSize,
                const fs::file_time_type expectedModified)
{
    std::error_code error;
    fs::create_directories(destination.parent_path(), error);
    if (error)
        return false;
    auto temporary = destination;
    temporary += L".importing";
    fs::remove(temporary, error);
    error.clear();
    if (!fs::copy_file(source, temporary, fs::copy_options::overwrite_existing, error) || error)
        return false;
    const auto copiedSize = fs::file_size(temporary, error);
    if (error || copiedSize != expectedSize)
    {
        fs::remove(temporary, error);
        return false;
    }
    const auto currentSize = fs::file_size(source, error);
    if (error || currentSize != expectedSize || fs::last_write_time(source, error) != expectedModified || error)
    {
        fs::remove(temporary, error);
        return false;
    }
    if (MoveFileExW(temporary.c_str(), destination.c_str(),
                    MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) == FALSE)
    {
        fs::remove(temporary, error);
        return false;
    }
    return true;
}

void Scan(const Paths& paths)
{
    std::error_code error;
    if (!fs::is_directory(paths.source, error) || error)
    {
        WriteResults(paths.results, {}, 0);
        WriteNativeCatalog(paths);
        return;
    }

    auto records = ReadRecords(paths.record);
    std::vector<std::string> changed;
    std::size_t skipped = 0;
    fs::recursive_directory_iterator iterator(paths.source,
        fs::directory_options::skip_permission_denied, error);
    const fs::recursive_directory_iterator end;
    while (!error && iterator != end)
    {
        const auto entry = *iterator;
        const auto reparsePoint = IsReparsePoint(entry.path());
        if (reparsePoint)
            iterator.disable_recursion_pending();
        iterator.increment(error);
        std::error_code entryError;
        if (reparsePoint || entry.is_symlink(entryError) || !entry.is_regular_file(entryError) ||
            entryError || !HasPresetSuffix(entry.path()))
            continue;
        const auto relative = entry.path().lexically_relative(paths.source);
        if (!SafeRelativePath(relative))
        {
            ++skipped;
            continue;
        }
        const auto size = entry.file_size(entryError);
        if (entryError || size == 0 || size > kMaximumPresetBytes)
        {
            ++skipped;
            continue;
        }
        const auto modifiedTime = entry.last_write_time(entryError);
        if (entryError)
        {
            ++skipped;
            continue;
        }
        const auto sourceKey = relative.generic_string();
        const auto destinationRelative = (fs::path(L"ACU Presets") / relative).generic_string();
        const auto modified = ModifiedValue(modifiedTime);
        const auto found = records.find(sourceKey);
        const auto destination = paths.destination / relative;
        const auto destinationReady = fs::is_regular_file(destination, entryError) && !entryError &&
            fs::file_size(destination, entryError) == size && !entryError;
        if (found != records.end() && found->second.size == size &&
            found->second.modified == modified && found->second.destination == destinationRelative &&
            destinationReady)
            continue;
        if (!CopyPreset(entry.path(), destination, size, modifiedTime))
        {
            ++skipped;
            continue;
        }
        records[sourceKey] = Record{size, modified, destinationRelative};
        changed.push_back(destinationRelative);
    }
    if (error)
        ++skipped;
    WriteRecords(paths.record, records);
    WriteResults(paths.results, changed, skipped);
    WriteNativeCatalog(paths);
    LogInfo("Character Preset Manager: finished checking ACU files for import.");
}
}
