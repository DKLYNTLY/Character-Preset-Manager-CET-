#pragma once
#include "Service.hpp"
#include <RED4ext/RED4ext.hpp>

namespace cpm
{
void Exchange(Service& service, RED4ext::IScriptable* request, RED4ext::IScriptable* reply);
}
