#include "Migration.hpp"
#include "PresetCodec.hpp"
#include <Windows.h>
#include <fstream>
#include <iterator>
#include <stdexcept>

namespace cpm
{
namespace
{
namespace fs = std::filesystem;
void Safe(const fs::path& path)
{
    auto current = path.root_path();
    for (const auto& part : path.relative_path())
    {
        current /= part;
        const auto flags = GetFileAttributesW(current.c_str());
        if (flags != INVALID_FILE_ATTRIBUTES && (flags & FILE_ATTRIBUTE_REPARSE_POINT))
            throw std::runtime_error("A linked folder prevents moving the preset library safely. Original files were kept.");
    }
}
std::string Contents(const fs::path& path)
{
    Safe(path);
    if (fs::file_size(path) > 268435456) throw std::runtime_error("A migration file exceeds the size limit. Original files were kept.");
    std::ifstream stream(path, std::ios::binary);
    if (!stream) throw std::runtime_error("A migration file could not be opened. Original files were kept.");
    std::string result((std::istreambuf_iterator<char>(stream)), {});
    if (stream.bad()) throw std::runtime_error("A migration file could not be read completely.");
    return result;
}
void Copy(const fs::path& source, const fs::path& target, const std::string& contents)
{
    Safe(target);
    fs::create_directories(target.parent_path());
    auto temporary = target;
    temporary += L".migration-tmp";
    Safe(temporary);
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        output.write(contents.data(), static_cast<std::streamsize>(contents.size()));
        output.flush();
        if (!output) throw std::runtime_error("The library copy could not be saved. Original files were kept.");
    }
    if (Contents(temporary) != contents || Contents(source) != contents)
        throw std::runtime_error("A file changed during migration. Retry after closing other preset tools.");
    if (!MoveFileExW(temporary.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH))
        throw std::runtime_error("The verified library copy could not be installed. Original files were kept.");
    if (Contents(target) != contents) throw std::runtime_error("A copied preset file failed verification.");
}
}

std::string MigrateStorage(const fs::path& source, const fs::path& destination)
{
    Safe(source); Safe(destination);
    const auto marker = destination / L"Data/Migration/Completed.txt";
    Safe(marker);
    if (fs::exists(marker)) return "";
    std::size_t visited = 0, conflicts = 0;
    for (const auto* folder : {L"Character Presets", L"Data"})
    {
        const auto root = source / folder;
        if (!fs::exists(root)) continue;
        for (auto iterator = fs::recursive_directory_iterator(root); iterator != fs::recursive_directory_iterator(); ++iterator)
        {
            if (++visited > 100000 || iterator.depth() > 16) throw std::runtime_error("The old library exceeds the migration limits.");
            Safe(iterator->path());
            if (iterator->is_directory()) continue;
            if (!iterator->is_regular_file()) throw std::runtime_error("The old library contains an unsupported file.");
            const auto relative = iterator->path().lexically_relative(source);
            if (*relative.begin() == L"Data" && relative.generic_string().starts_with("Data/Migration/")) continue;
            const auto contents = Contents(iterator->path());
            auto target = destination / relative;
            Safe(target);
            if (fs::exists(target))
            {
                if (Contents(target) == contents) continue;
                ++conflicts;
                target = destination / L"Data/Migration/Conflicts" / relative;
                Safe(target);
                if (fs::exists(target))
                {
                    if (Contents(target) != contents) throw std::runtime_error("A saved migration conflict changed. Original files were kept for review.");
                    continue;
                }
            }
            Copy(iterator->path(), target, contents);
        }
    }
    if (conflicts) return "Some old files differ from the native library. Both copies were kept. Review Data/Migration/Conflicts before retrying migration. The active library was not replaced.";
    fs::create_directories(marker.parent_path());
    const auto temporary = marker.parent_path() / L"Completed.tmp";
    Safe(temporary);
    { std::ofstream stream(temporary); stream << "3.1.3\n"; stream.flush(); if (!stream) throw std::runtime_error("The migration completion record could not be saved."); }
    if (!MoveFileExW(temporary.c_str(), marker.c_str(), MOVEFILE_WRITE_THROUGH)) throw std::runtime_error("Migration completion could not be recorded.");
    return "";
}
}
