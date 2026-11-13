#include "PresetOperations.hpp"

namespace cpm
{
PresetOperations::PresetOperations(std::size_t capacity) : capacity_(capacity),
    worker_([this](std::stop_token stop) { Run(stop); }) {}

PresetOperations::~PresetOperations() { Stop(); }

bool PresetOperations::Submit(std::uint64_t id, std::uint64_t session, Work work)
{
    std::lock_guard lock(mutex_);
    if (stopped_ || !work || outstanding_ >= capacity_) return false;
    requests_.push_back({id, session, std::move(work)});
    ++outstanding_;
    ready_.notify_one();
    return true;
}

std::optional<OperationResult> PresetOperations::Poll()
{
    std::lock_guard lock(mutex_);
    if (results_.empty()) return std::nullopt;
    auto result = std::move(results_.front());
    results_.pop_front();
    --outstanding_;
    return result;
}

void PresetOperations::Stop()
{
    {
        std::lock_guard lock(mutex_);
        stopped_ = true;
        worker_.request_stop();
        ready_.notify_all();
    }
    if (worker_.joinable()) worker_.join();
}

void PresetOperations::Run(std::stop_token stop)
{
    while (true)
    {
        Request request;
        {
            std::unique_lock lock(mutex_);
            ready_.wait(lock, stop, [this] { return !requests_.empty(); });
            if (requests_.empty()) return;
            request = std::move(requests_.front());
            requests_.pop_front();
        }
        OperationResult result;
        if (stop.stop_requested()) result.status = OperationStatus::Cancelled;
        else
        {
            try { result = request.work(stop); }
            catch (...) { result.status = OperationStatus::Failure; }
        }
        result.id = request.id;
        result.session = request.session;
        std::lock_guard lock(mutex_);
        results_.push_back(std::move(result));
    }
}
}
