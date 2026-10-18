#pragma once

#include "PresetCodec.hpp"

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <stop_token>
#include <string>
#include <thread>

namespace cpm
{
class OperationContext
{
public:
    void CheckCanceled() const;
    void Progress(std::uint32_t completed, std::uint32_t total);
    void Commit(const std::function<void()>& action);
private:
    friend class Service;
    std::atomic_bool canceled_ = false;
    std::atomic_bool committed_ = false;
    std::atomic_bool committing_ = false;
    std::atomic_uint32_t completed_ = 0;
    std::atomic_uint32_t total_ = 0;
    std::mutex commitMutex_;
};

class Service
{
public:
    using Executor = std::function<Json(const Json&, OperationContext&)>;
    static constexpr std::uint32_t Protocol = 1;
    static constexpr std::size_t MaximumOperations = 64;
    static constexpr std::size_t MaximumRequestBytes = 2097152;
    static constexpr std::size_t MaximumResultBytes = 2097152;
    explicit Service(Executor executor);
    ~Service();
    Service(const Service&) = delete;
    Service& operator=(const Service&) = delete;
    Json Status();
    void NotifyChange();
    Json BeginSession();
    Json CloseSession(std::uint64_t session);
    Json Submit(const std::string& request);
    Json SubmitRaw(std::uint64_t session, const std::string& action, const std::string& payload);
    Json Poll(std::uint64_t session, std::uint64_t operation, bool consume);
    std::string PollText(std::uint64_t session, std::uint64_t operation, bool consume);
    Json Cancel(std::uint64_t session, std::uint64_t operation);
    Json EndAppearance(std::uint64_t session, std::uint64_t operation);
    void Shutdown();
private:
    struct Operation
    {
        std::uint64_t id = 0;
        std::uint64_t session = 0;
        std::string status = "queued";
        Json request;
        Json result;
        std::string payload;
        std::string resultText;
        bool appearance = false;
        OperationContext context;
    };
    void Run(std::stop_token stop);
    void CancelAll();
    std::mutex mutex_;
    std::condition_variable condition_;
    Executor executor_;
    std::deque<std::shared_ptr<Operation>> queue_;
    std::map<std::uint64_t, std::shared_ptr<Operation>> operations_;
    std::uint64_t nextId_ = 0;
    std::uint64_t session_ = 0;
    std::uint64_t appearanceId_ = 0;
    bool accepting_ = true;
    bool sessionOpen_ = false;
    std::atomic_uint64_t changes_ = 0;
    std::jthread worker_;
};
}
