cmake_minimum_required(VERSION 3.21)
project(CharacterPresetManagerNative VERSION 3.1.3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

if(NOT RED4EXT_SDK_PATH)
  message(FATAL_ERROR "Set RED4EXT_SDK_PATH to the RED4ext.SDK folder")
endif()

set(RED4EXT_HEADER_ONLY OFF CACHE BOOL "" FORCE)
set(RED4EXT_USE_PCH OFF CACHE BOOL "" FORCE)
add_subdirectory("${RED4EXT_SDK_PATH}" RED4ext.SDK)

set(CPM_JSON_INCLUDE "${CMAKE_CURRENT_BINARY_DIR}/dependencies")
file(MAKE_DIRECTORY "${CPM_JSON_INCLUDE}/nlohmann")
file(DOWNLOAD
  "https://raw.githubusercontent.com/nlohmann/json/v3.11.3/single_include/nlohmann/json.hpp"
  "${CPM_JSON_INCLUDE}/nlohmann/json.hpp"
  EXPECTED_HASH SHA256=9bea4c8066ef4a1c206b2be5a36302f8926f7fdc6087af5d20b417d0cf103ea6
  TLS_VERIFY ON
)
add_library(CharacterPresetManagerCore STATIC src/PresetCodec.cpp src/Service.cpp src/Library.cpp src/FileTransaction.cpp src/Appearance.cpp src/Archive.cpp src/Migration.cpp src/NativeController.cpp)
target_include_directories(CharacterPresetManagerCore PUBLIC "${CPM_JSON_INCLUDE}" src)
target_compile_definitions(CharacterPresetManagerCore PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_compile_options(CharacterPresetManagerCore PRIVATE /W4 /permissive- /EHsc)

add_library(CharacterPresetManagerNative SHARED src/Main.cpp src/NativeBindings.cpp src/TypedBindings.cpp src/DirectoryWatch.cpp)
target_link_libraries(CharacterPresetManagerNative PRIVATE RED4ext::SDK)
target_link_libraries(CharacterPresetManagerNative PRIVATE CharacterPresetManagerCore)
target_compile_definitions(CharacterPresetManagerNative PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_compile_options(CharacterPresetManagerNative PRIVATE /W4 /permissive- /EHsc)

set_target_properties(CharacterPresetManagerNative PROPERTIES
  OUTPUT_NAME "CharacterPresetManager"
  PREFIX ""
)

option(CPM_BUILD_TESTS "Build the native file service tests" OFF)
if(CPM_BUILD_TESTS)
  enable_testing()
  add_executable(CharacterPresetManagerControllerTests verification/NativeControllerTest.cpp)
  target_link_libraries(CharacterPresetManagerControllerTests PRIVATE CharacterPresetManagerCore)
  target_compile_definitions(CharacterPresetManagerControllerTests PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
  add_test(NAME native_controller COMMAND CharacterPresetManagerControllerTests)
  add_executable(CharacterPresetManagerServiceTests verification/ServiceTest.cpp src/DirectoryWatch.cpp)
  target_link_libraries(CharacterPresetManagerServiceTests PRIVATE CharacterPresetManagerCore)
  target_compile_definitions(CharacterPresetManagerServiceTests PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
  add_test(NAME service COMMAND CharacterPresetManagerServiceTests)
  add_executable(CharacterPresetManagerCodecTests verification/CodecTest.cpp)
  target_link_libraries(CharacterPresetManagerCodecTests PRIVATE CharacterPresetManagerCore)
  add_executable(CharacterPresetManagerOperationServer verification/OperationServer.cpp)
  target_link_libraries(CharacterPresetManagerOperationServer PRIVATE CharacterPresetManagerCore)
  add_executable(CharacterPresetManagerNativeTests verification/ImporterTest.cpp src/NativeBindings.cpp src/TypedBindings.cpp src/DirectoryWatch.cpp)
  target_link_libraries(CharacterPresetManagerNativeTests PRIVATE RED4ext::SDK CharacterPresetManagerCore)
  target_compile_definitions(CharacterPresetManagerNativeTests PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
  target_compile_options(CharacterPresetManagerNativeTests PRIVATE /W4 /permissive- /EHsc)
  add_test(NAME importer COMMAND CharacterPresetManagerNativeTests)
endif()
