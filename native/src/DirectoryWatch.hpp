#pragma once

#include <filesystem>
#include <functional>
#include <thread>

namespace cpm
{
class DirectoryWatch
{
public:
    DirectoryWatch(std::filesystem::path manager, std::function<void()> changed);
    ~DirectoryWatch();
private:
    void Run(std::stop_token stop);
    std::filesystem::path manager_;
    std::function<void()> changed_;
    void* stop_ = nullptr;
    std::jthread worker_;
};
}
