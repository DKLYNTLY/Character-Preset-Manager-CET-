#pragma once

#include "Library.hpp"
#include <atomic>

namespace cpm
{
inline std::atomic_int editorKey = 0;
inline std::atomic_int panelKey = 0;
class NativeController
{
public:
    explicit NativeController(std::filesystem::path root);
    Json Execute(const Json& request, OperationContext& context);
private:
    Json Call(Json request, OperationContext& context);
    Json List(OperationContext& context, const std::string& message = "");
    Json Capture(const Json& options);
    void Log(const std::string& message);
    Library library_;
    std::filesystem::path root_;
    Json preset_, state_ = Json::object(), previousChange_;
    std::string selected_, query_, location_, sort_ = "name", migration_, lastMessage_;
    std::string pendingConfirmation_, confirmationFingerprint_;
    Json marked_ = Json::array();
    std::map<std::string, std::string> previews_;
    std::uint64_t revision_ = 0;
    std::size_t offset_ = 0;
    bool initialized_ = false;
};
}
