#pragma once

#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

namespace cpm
{
enum class OperationStatus { Success, Partial, Conflict, Cancelled, Failure };

struct OperationResult
{
    std::uint64_t id = 0;
    std::uint64_t session = 0;
    OperationStatus status = OperationStatus::Failure;
    std::string payload;
    std::string fingerprint;
};

class PresetOperations
{
public:
    using Work = std::function<OperationResult(std::stop_token)>;
    explicit PresetOperations(std::size_t capacity);
    ~PresetOperations();
    bool Submit(std::uint64_t id, std::uint64_t session, Work work);
    std::optional<OperationResult> Poll();
    void Stop();
private:
    struct Request { std::uint64_t id; std::uint64_t session; Work work; };
    void Run(std::stop_token stop);
    std::size_t capacity_;
    std::size_t outstanding_ = 0;
    bool stopped_ = false;
    std::mutex mutex_;
    std::condition_variable_any ready_;
    std::deque<Request> requests_;
    std::deque<OperationResult> results_;
    std::jthread worker_;
};
}
