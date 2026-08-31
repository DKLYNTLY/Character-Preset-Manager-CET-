cmake_minimum_required(VERSION 3.21)
project(CharacterPresetManagerNative VERSION 3.0.10 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(NOT RED4EXT_SDK_PATH)
  message(FATAL_ERROR "Set RED4EXT_SDK_PATH to the RED4ext.SDK folder")
endif()

set(RED4EXT_HEADER_ONLY OFF CACHE BOOL "" FORCE)
set(RED4EXT_USE_PCH OFF CACHE BOOL "" FORCE)
add_subdirectory("${RED4EXT_SDK_PATH}" RED4ext.SDK)

add_library(CharacterPresetManagerNative SHARED src/Main.cpp)
target_link_libraries(CharacterPresetManagerNative PRIVATE RED4ext::SDK)
target_compile_definitions(CharacterPresetManagerNative PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_compile_options(CharacterPresetManagerNative PRIVATE /W4 /permissive- /EHsc)

set_target_properties(CharacterPresetManagerNative PROPERTIES
  OUTPUT_NAME "CharacterPresetManager"
  PREFIX ""
)

option(CPM_BUILD_TESTS "Build the native import service tests" OFF)
if(CPM_BUILD_TESTS)
  add_executable(CharacterPresetManagerNativeTests verification/ImporterTest.cpp)
  target_link_libraries(CharacterPresetManagerNativeTests PRIVATE RED4ext::SDK)
  target_compile_definitions(CharacterPresetManagerNativeTests PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_compile_options(CharacterPresetManagerNativeTests PRIVATE /W4 /permissive- /EHsc)
endif()
