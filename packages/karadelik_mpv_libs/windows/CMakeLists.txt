# Ships libmpv and ANGLE for media_kit_video, replacing media_kit_libs_video.
#
# Layout and the MEDIA_KIT_LIBS_AVAILABLE contract follow
# media_kit_libs_windows_video (MIT, (c) Hitesh Kumar Saini), so media_kit_video
# finds headers and import libraries where it expects them. What differs:
# every artifact comes from ../manifest.json and must match its SHA-256.
cmake_minimum_required(VERSION 3.19)

option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "karadelik_mpv_libs")
project(${PROJECT_NAME} LANGUAGES CXX)

add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

if(NOT FLUTTER_TARGET_PLATFORM STREQUAL "windows-x64")
  message(FATAL_ERROR "karadelik_mpv_libs: only windows-x64 is pinned so far")
endif()

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../manifest.json" KP_MANIFEST)

if(DEFINED ENV{LOCALAPPDATA})
  set(KP_NATIVE_CACHE "$ENV{LOCALAPPDATA}/KaradelikPlayer/native-cache")
else()
  set(KP_NATIVE_CACHE "${CMAKE_BINARY_DIR}/native-cache")
endif()
file(MAKE_DIRECTORY "${KP_NATIVE_CACHE}")

find_program(KP_SEVENZIP NAMES 7z 7za PATHS "$ENV{ProgramFiles}/7-Zip" "C:/Program Files/7-Zip")

# Downloads (or reuses) one manifest artifact, verifies it, and extracts it
# into DEST once per hash.
function(kp_fetch artifact dest)
  string(JSON file_name GET "${KP_MANIFEST}" windows-x64 ${artifact} file)
  string(JSON url GET "${KP_MANIFEST}" windows-x64 ${artifact} url)
  string(JSON sha256 GET "${KP_MANIFEST}" windows-x64 ${artifact} sha256)
  set(archive "${KP_NATIVE_CACHE}/${file_name}")

  if(EXISTS "${archive}")
    file(SHA256 "${archive}" have)
    if(NOT have STREQUAL sha256)
      message(STATUS "karadelik_mpv_libs: ${file_name} hash mismatch, downloading again")
      file(REMOVE "${archive}")
    endif()
  endif()
  if(NOT EXISTS "${archive}")
    message(STATUS "karadelik_mpv_libs: downloading ${url}")
    file(DOWNLOAD "${url}" "${archive}" EXPECTED_HASH SHA256=${sha256} STATUS status SHOW_PROGRESS)
    list(GET status 0 code)
    if(NOT code EQUAL 0)
      file(REMOVE "${archive}")
      message(FATAL_ERROR "karadelik_mpv_libs: download of ${file_name} failed: ${status}")
    endif()
  endif()

  set(stamp "${dest}/.sha256")
  if(EXISTS "${stamp}")
    file(READ "${stamp}" extracted)
  endif()
  if(NOT extracted STREQUAL sha256)
    file(REMOVE_RECURSE "${dest}")
    file(MAKE_DIRECTORY "${dest}")
    if(KP_SEVENZIP)
      execute_process(COMMAND "${KP_SEVENZIP}" x -y "${archive}" WORKING_DIRECTORY "${dest}"
                      RESULT_VARIABLE rc OUTPUT_QUIET)
    else()
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${archive}" WORKING_DIRECTORY "${dest}"
                      RESULT_VARIABLE rc)
    endif()
    if(NOT rc EQUAL 0)
      message(FATAL_ERROR "karadelik_mpv_libs: could not extract ${file_name}")
    endif()
    file(WRITE "${stamp}" "${sha256}")
  endif()
endfunction()

# media_kit_video reads these two fixed locations.
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

kp_fetch(libmpv "${LIBMPV_SRC}")
kp_fetch(angle "${ANGLE_SRC}")

# media_kit_video includes <client.h>, not <mpv/client.h>.
if(EXISTS "${LIBMPV_SRC}/include/mpv")
  file(GLOB mpv_headers "${LIBMPV_SRC}/include/mpv/*.h")
  file(COPY ${mpv_headers} DESTINATION "${LIBMPV_SRC}/include")
endif()

set(PLUGIN_NAME "karadelik_mpv_libs_plugin")
add_library(${PLUGIN_NAME} SHARED
  "include/karadelik_mpv_libs/karadelik_mpv_libs_plugin_c_api.h"
  "karadelik_mpv_libs_plugin_c_api.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(karadelik_mpv_libs_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
