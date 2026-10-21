#include "Service.hpp"

#include <stdexcept>

namespace cpm
{
namespace
{
class Canceled final : public std::exception {};
Json Failure(const std::string& message)
{
    return {{"protocol", Service::Protocol}, {"accepted", false}, {"error", message}};
}
bool Finished(const std::string& status)
{
    return status == "complete" || status == "failed" || status == "canceled";
}
}

void OperationContext::CheckCanceled() const
{
    if (canceled_.load() && !committed_.load()) throw Canceled{};
}

void OperationContext::Progress(std::uint32_t completed, std::uint32_t total)
{
    CheckCanceled();
    completed_ = completed;
    total_ = total;
}

void OperationContext::Commit(const std::function<void()>& action)
{
    std::lock_guard lock(commitMutex_);
    CheckCanceled();
    committing_ = true;
    try
    {
        action();
        committed_ = true;
        committing_ = false;
    }
    catch (...)
    {
        committing_ = false;
        throw;
    }
}

Service::Service(Executor executor) : executor_(std::move(executor)),
    worker_([this](std::stop_token stop) { Run(stop); }) {}

Service::~Service() { Shutdown(); }

Json Service::Status()
{
    std::lock_guard lock(mutex_);
    return {{"protocol", Protocol}, {"version", "3.1.4"}, {"available", accepting_},
        {"session", session_}, {"sessionOpen", sessionOpen_}, {"pending", operations_.size()}, {"changes", changes_.load()}};
}

void Service::NotifyChange() { ++changes_; }

void Service::CancelAll()
{
    for (const auto& [id, operation] : operations_)
    {
        static_cast<void>(id);
        operation->context.canceled_ = true;
    }
    operations_.clear();
    queue_.clear();
    appearanceId_ = 0;
}

Json Service::BeginSession()
{
    std::lock_guard lock(mutex_);
    if (!accepting_) return Failure("The preset service is shutting down.");
    CancelAll();
    ++session_;
    sessionOpen_ = true;
    return {{"protocol", Protocol}, {"accepted", true}, {"session", session_}};
}

Json Service::CloseSession(std::uint64_t session)
{
    std::lock_guard lock(mutex_);
    if (session != session_ || !sessionOpen_) return Failure("That editor session has closed.");
    CancelAll();
    sessionOpen_ = false;
    return {{"protocol", Protocol}, {"accepted", true}, {"session", session}};
}

Json Service::Submit(const std::string& request)
{
    if (request.size() > MaximumRequestBytes) return Failure("The request exceeds the size limit.");
    Json data;
    try
    {
        data = Json::parse(request, [](int depth, Json::parse_event_t, Json&) {
            if (depth > 24) throw std::runtime_error("The request is too deeply nested.");
            return true;
        });
        if (!data.is_object() || !data.contains("protocol") || !data["protocol"].is_number_unsigned() ||
            data["protocol"] != Protocol || !data.contains("session") || !data["session"].is_number_unsigned() ||
            !data.contains("action") || !data["action"].is_string())
            return Failure("Update all Character Preset Manager files together.");
    }
    catch (const std::exception&) { return Failure("The preset request could not be read."); }
    const auto session = data["session"].get<std::uint64_t>();
    const auto action = data["action"].get<std::string>();
    data.erase("session");
    data.erase("protocol");
    data.erase("action");
    return SubmitRaw(session, action, data.dump());
}

Json Service::SubmitRaw(std::uint64_t session, const std::string& action, const std::string& payload)
{
    if (payload.size() > MaximumRequestBytes || action.empty() || action.size() > 64)
        return Failure("The request exceeds the size limit.");
    std::lock_guard lock(mutex_);
    if (!accepting_) return Failure("The preset service is shutting down.");
    if (!sessionOpen_ || session != session_)
        return Failure("That editor session has closed.");
    if (operations_.size() >= MaximumOperations) return Failure("The preset service is busy. Wait for the queued actions to finish before trying again.");
    const bool appearance = action == "plan_load";
    if (appearance && appearanceId_ != 0) return Failure("Another appearance load is already in progress.");
    if (action == "load_step" && appearanceId_ == 0) return Failure("Start an appearance load before requesting its next change.");
    if (action == "load_step") for (const auto& [id, pending] : operations_)
    {
        static_cast<void>(id);
        if (pending->appearance || pending->request.value("action", "") == "load_step")
            return Failure("Wait for the current appearance result before requesting another change.");
    }
    auto operation = std::make_shared<Operation>();
    operation->id = ++nextId_;
    operation->session = session_;
    operation->request = {{"action", action}, {"session", session}, {"protocol", Protocol}};
    operation->payload = payload;
    operation->appearance = appearance;
    if (appearance) appearanceId_ = operation->id;
    operations_[operation->id] = operation;
    queue_.push_back(operation);
    condition_.notify_one();
    return {{"protocol", Protocol}, {"accepted", true}, {"session", session_}, {"operation", operation->id}};
}

std::string Service::PollText(std::uint64_t session, std::uint64_t operationId, bool consume)
{
    std::lock_guard lock(mutex_);
    const auto found = operations_.find(operationId);
    if (session != session_ || !sessionOpen_ || found == operations_.end() || found->second->session != session)
        return Failure("That action is no longer current.").dump();
    const auto& operation = found->second;
    if (Finished(operation->status))
    {
        auto result = operation->resultText;
        if (consume)
        {
            if (appearanceId_ == operationId && operation->status != "complete") appearanceId_ = 0;
            operations_.erase(found);
        }
        return result;
    }
    return Json{{"protocol", Protocol}, {"accepted", true}, {"session", session},
        {"operation", operationId}, {"status", operation->status},
        {"completed", operation->context.completed_.load()}, {"total", operation->context.total_.load()}}.dump();
}

Json Service::Poll(std::uint64_t session, std::uint64_t operationId, bool consume)
{
    std::lock_guard lock(mutex_);
    const auto found = operations_.find(operationId);
    if (session != session_ || !sessionOpen_ || found == operations_.end() || found->second->session != session)
        return Failure("That action is no longer current.");
    const auto& operation = found->second;
    Json result = {{"protocol", Protocol}, {"accepted", true}, {"session", session},
        {"operation", operationId}, {"status", operation->status},
        {"completed", operation->context.completed_.load()}, {"total", operation->context.total_.load()}};
    if (Finished(operation->status))
    {
        result["result"] = operation->result;
        if (consume)
        {
            if (appearanceId_ == operationId && operation->status != "complete") appearanceId_ = 0;
            operations_.erase(found);
        }
    }
    return result;
}

Json Service::Cancel(std::uint64_t session, std::uint64_t operationId)
{
    std::lock_guard lock(mutex_);
    const auto found = operations_.find(operationId);
    if (session != session_ || !sessionOpen_ || found == operations_.end())
        return Failure("That action is no longer current.");
    auto& operation = *found->second;
    std::unique_lock commitLock(operation.context.commitMutex_, std::try_to_lock);
    if (!commitLock.owns_lock() || operation.context.committed_)
        return Failure("The file change is being saved and can no longer be canceled.");
    if (!Finished(operation.status)) operation.context.canceled_ = true;
    return {{"protocol", Protocol}, {"accepted", true}, {"operation", operationId}};
}

Json Service::EndAppearance(std::uint64_t session, std::uint64_t operation)
{
    std::lock_guard lock(mutex_);
    if (!sessionOpen_ || session != session_ || appearanceId_ == 0 || operation != appearanceId_)
        return Failure("That appearance load is no longer current.");
    const auto found = operations_.find(operation);
    if (found != operations_.end() && !Finished(found->second->status))
        return Failure("Cancel the pending appearance request before ending the load.");
    for (const auto& [id, pending] : operations_)
    {
        static_cast<void>(id);
        if (pending->request.value("action", "") == "load_step" && !Finished(pending->status))
            return Failure("Cancel the pending appearance step before ending the load.");
    }
    appearanceId_ = 0;
    return {{"protocol", Protocol}, {"accepted", true}, {"operation", operation}};
}

void Service::Run(std::stop_token stop)
{
    while (!stop.stop_requested())
    {
        std::shared_ptr<Operation> operation;
        {
            std::unique_lock lock(mutex_);
            condition_.wait(lock, [&] { return stop.stop_requested() || !queue_.empty(); });
            if (stop.stop_requested()) break;
            operation = queue_.front();
            queue_.pop_front();
            operation->status = "running";
        }
        Json result;
        std::string status = "complete";
        try
        {
            operation->context.CheckCanceled();
            auto request = Json::parse(operation->payload, [](int depth, Json::parse_event_t, Json&) {
                if (depth > 24) throw std::runtime_error("The request is too deeply nested.");
                return true;
            });
            if (!request.is_object()) throw std::runtime_error("The preset request could not be read.");
            request.update(operation->request);
            if (operation->appearance) request["loadId"] = operation->id;
            if (request.value("action", "") == "load_step")
            {
                std::lock_guard lock(mutex_);
                if (operation->session != session_ || !sessionOpen_ || request.value("loadId", std::uint64_t{}) != appearanceId_)
                    throw std::runtime_error("That appearance load is no longer current.");
            }
            result = executor_(request, operation->context);
            operation->context.CheckCanceled();
            if (result.dump().size() > MaximumResultBytes) throw std::runtime_error("The result exceeds the size limit. Narrow the search.");
        }
        catch (const Canceled&)
        {
            status = "canceled";
            result = {{"message", "Action canceled."}};
        }
        catch (const std::exception& error)
        {
            status = "failed";
            result = {{"error", error.what()}};
        }
        catch (...)
        {
            status = "failed";
            result = {{"error", "The preset action could not finish safely."}};
        }
        {
            auto resultText = Json{{"protocol", Protocol}, {"accepted", true}, {"session", operation->session},
                {"operation", operation->id}, {"status", status}, {"result", result},
                {"completed", operation->context.completed_.load()}, {"total", operation->context.total_.load()}}.dump(-1, ' ', false, Json::error_handler_t::replace);
            std::lock_guard lock(mutex_);
            operation->status = status;
            operation->result = std::move(result);
            operation->resultText = std::move(resultText);
            operation->payload.clear();
        }
    }
}

void Service::Shutdown()
{
    {
        std::lock_guard lock(mutex_);
        accepting_ = false;
        sessionOpen_ = false;
        CancelAll();
        worker_.request_stop();
    }
    condition_.notify_all();
    if (worker_.joinable()) worker_.join();
}
}
