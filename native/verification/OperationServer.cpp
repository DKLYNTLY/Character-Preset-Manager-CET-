#include "Library.hpp"
#include "Service.hpp"

#include <filesystem>
#include <iostream>
#include <string>

int wmain(int argc, wchar_t** argv)
{
    if (argc != 2) return 2;
    cpm::Library library{std::filesystem::path(argv[1])};
    cpm::Service service([&](const cpm::Json& request, cpm::OperationContext& context) {
        return library.Execute(request, context);
    });
    std::string line;
    while (std::getline(std::cin, line))
    {
        try
        {
            const auto request = cpm::Json::parse(line);
            const auto method = request.at("method").get<std::string>();
            const auto session = request.value("session", std::uint64_t{});
            const auto operation = request.value("operation", std::uint64_t{});
            cpm::Json result;
            if (method == "status") result = service.Status();
            else if (method == "begin") result = service.BeginSession();
            else if (method == "close") result = service.CloseSession(session);
            else if (method == "submit") result = service.SubmitRaw(session, request.at("action"), request.at("payload"));
            else if (method == "poll") result = service.Poll(session, operation, request.value("consume", false));
            else if (method == "cancel") result = service.Cancel(session, operation);
            else if (method == "end") result = service.EndAppearance(session, operation);
            else throw std::runtime_error("Unknown verification request.");
            std::cout << result.dump() << std::endl;
        }
        catch (const std::exception& error)
        {
            std::cout << cpm::Json{{"accepted", false}, {"error", error.what()}}.dump() << std::endl;
        }
    }
}
