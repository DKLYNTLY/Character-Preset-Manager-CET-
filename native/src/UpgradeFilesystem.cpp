#include "UpgradeFilesystem.hpp"
#include "FileService.hpp"
namespace cpm
{
namespace
{
std::string Encode(const std::string& value)
{
    std::string result;
    const char* hex = "0123456789ABCDEF";
    for (const auto character : value)
    {
        const auto byte = static_cast<unsigned char>(character);
        if ((byte >= 'A' && byte <= 'Z') || (byte >= 'a' && byte <= 'z')
            || (byte >= '0' && byte <= '9') || character == '-' || character == '_' || character == '.' || character == '/') result += character;
        else { result += '%'; result += hex[byte >> 4]; result += hex[byte & 15]; }
    }
    return result;
}
bool Walk(const fs::path& target, bool create)
{
    auto current = target.root_path();
    for (const auto& component : target.relative_path())
    {
        current /= component;
        auto attributes = GetFileAttributesW(current.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES)
        {
            if (!create || GetLastError() != ERROR_FILE_NOT_FOUND)
            {
                if (!create || GetLastError() != ERROR_PATH_NOT_FOUND) return false;
            }
            std::error_code error;
            fs::create_directory(current, error);
            if (error) return false;
            attributes = GetFileAttributesW(current.c_str());
        }
        if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT)
            || !(attributes & FILE_ATTRIBUTE_DIRECTORY)) return false;
    }
    return true;
}
bool SafeFile(const fs::path& path)
{
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES)
        return GetLastError() == ERROR_FILE_NOT_FOUND;
    return !(attributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY));
}
}
bool PrepareUpgradeDirectories(const fs::path& manager, const std::string& batch, const std::string& storage)
{
    try
    {
    if (!std::regex_match(batch, std::regex("[A-Za-z0-9_-]{1,64}")) || storage.size() > 3072) return false;
    const auto relative = fs::path(std::u8string(storage.begin(), storage.end()));
    if (!SafeRelativePath(relative)) return false;
    std::size_t depth = 0;
    for (const auto& component : relative)
    {
        if (++depth > 12 || !SafeComponent(component)) return false;
        auto stem = component.wstring();
        stem = stem.substr(0, stem.find(L'.'));
        while (!stem.empty() && stem.back() == L' ') stem.pop_back();
        if (std::regex_match(stem, std::wregex(L"CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]", std::regex::icase))) return false;
    }
    const auto source = manager / L"Character Presets" / relative;
    if (!Walk(manager, false) || !Walk(source.parent_path(), false)
        || !SafeFile(fs::path(source.wstring() + L".preset"))) return false;
    for (const auto& suffix : {L".preset.tmp", L".preset.bak"})
        if (!SafeFile(fs::path(source.wstring()+suffix))) return false;
    const auto recovery = manager / L"Data" / L"Recovery";
    if (!Walk(recovery, false)) return false;
    const auto destination = recovery / L"Preset Upgrades" / fs::path(std::u8string(batch.begin(), batch.end())) / relative.parent_path();
    if (!Walk(destination, true)) return false;
    const auto backup = destination / fs::path(relative.filename().wstring() + L".preset");
    const auto candidate = destination / fs::path(relative.filename().wstring() + L".candidate");
    for (const auto& path : {backup, candidate})
        if (!SafeFile(path) || !SafeFile(fs::path(path.wstring()+L".new"))) return false;
    const auto journal = recovery / L"Preset Upgrades" / L"Upgrade Journal.txt";
    return SafeFile(journal) && SafeFile(fs::path(journal.wstring()+L".tmp"))
        && SafeFile(fs::path(journal.wstring()+L".bak"));
    }
    catch (...) { return false; }
}
UpgradeFilesystem::UpgradeFilesystem(fs::path manager) : manager_(std::move(manager)) {}
void UpgradeFilesystem::Poll()
{
    try
    {
    const auto config = manager_ / L"Data" / L"Config";
    const auto requestPath = config / L"Upgrade Filesystem Request.txt";
    const auto resultPath = config / L"Upgrade Filesystem Result.txt";
    if (!Walk(config, false) || !SafeFile(requestPath) || !SafeFile(resultPath)
        || !SafeFile(fs::path(resultPath.wstring()+L".tmp"))) return;
    const auto request = ReadOverlayFile(requestPath);
    if (request == previous_ || request.size() > 4096) return;
    previous_ = request;
    std::smatch fields;
    if (!std::regex_match(request, fields, std::regex("1\t([A-Za-z0-9_-]{1,64})\t([A-Za-z0-9_-]{1,64})\t([^\r\n]+)\n"))) return;
    const auto storage = UnescapeField(fields[3]);
    const auto ready = Encode(storage) == fields[3] && PrepareUpgradeDirectories(manager_, fields[2], storage);
    AtomicWrite(resultPath, fields[1].str()+"\t"+(ready ? "ready" : "rejected"));
    }
    catch (...) { return; }
}
}
