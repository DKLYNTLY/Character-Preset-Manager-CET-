#include "PresetCodec.hpp"
#include "Appearance.hpp"
#include "Archive.hpp"

#include <iostream>
#include <string>

int main()
{
    std::string line;
    while (std::getline(std::cin, line))
    {
        try
        {
            const auto request = cpm::Json::parse(line);
            if (request.value("operation", "parse") == "write")
                std::cout << cpm::Json(cpm::WritePreset(request.at("preset"))).dump() << std::endl;
            else if (request.value("operation", "parse") == "compare")
                std::cout << cpm::CompareAppearance(request.at("preset"), request.at("options")).dump() << std::endl;
            else if (request.value("operation", "parse") == "plan")
                std::cout << cpm::PlanAppearance(request).dump() << std::endl;
            else if (request.value("operation", "parse") == "archive_read")
            {
                const auto archive = cpm::ReadArchive(request.at("contents"), request.value("backup", false));
                cpm::Json result = {{"root", archive.root}, {"folders", archive.folders}, {"presets", archive.presets}};
                if (archive.config) result["config"] = *archive.config;
                std::cout << result.dump() << std::endl;
            }
            else
                std::cout << cpm::ParsePreset(request.at("contents").get<std::string>(),
                    request.value("metadataOnly", false)).dump() << std::endl;
        }
        catch (const std::exception& error)
        {
            std::cout << cpm::Json({{"error", error.what()}}).dump() << std::endl;
        }
    }
}
