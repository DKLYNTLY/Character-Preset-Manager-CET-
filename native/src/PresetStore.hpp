#pragma once

#include "PresetOperations.hpp"
#include "PresetSave.hpp"

namespace cpm
{
class PresetStore
{
public:
    explicit PresetStore(std::filesystem::path root, std::size_t capacity = 16);
    bool Read(std::uint64_t id, std::uint64_t session, std::string relative);
    bool Save(std::uint64_t id, std::uint64_t session, std::string relative,
        document9::Preset preset, std::optional<std::string> expectedFingerprint);
    std::optional<OperationResult> Poll();
    void Stop();
private:
    static std::optional<std::filesystem::path> Resolve(const std::filesystem::path& root, const std::string& relative);
    std::filesystem::path root_;
    PresetOperations operations_;
};
}
