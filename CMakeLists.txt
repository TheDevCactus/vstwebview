cmake_minimum_required(VERSION 3.21.0)

set(CMAKE_CXX_STANDARD 20)
set(ABSL_PROPAGATE_CXX_STD ON)

# Add compiler flag to ignore unused variable warnings in VST3 SDK
if(APPLE)
    add_compile_options(-Wno-error=unused-but-set-variable)
endif()

project(vstwebview)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

# Third party packages are pulled in via FetchContent
include(FetchContent)

# ================================
# VST3 SDK
# ================================
FetchContent_Declare(
        vst3sdk
        GIT_REPOSITORY https://github.com/steinbergmedia/vst3sdk.git
        GIT_SHALLOW 1
)
FetchContent_MakeAvailable(vst3sdk)

set(SMTG_ADD_VSTGUI OFF)
set(SMTG_ENABLE_VST3_PLUGIN_EXAMPLES OFF)
set(SMTG_ENABLE_VST3_HOSTING_EXAMPLES OFF)

smtg_enable_vst3_sdk()

# ================================
# json
# ================================
FetchContent_Declare(json URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz)
FetchContent_MakeAvailable(json)


# Platform specific sources and compile options.
IF (WIN32)
    set(WEBVIEW_PLATFORM_SOURCES
            src/vstwebview/win32/webview_win32.h
            src/vstwebview/win32/webview_win32.cc
            src/vstwebview/win32/webview_edge_chromium.h
            src/vstwebview/win32/webview_edge_chromium.cc)

    # Needed to shut MSVC up about experimental/coroutine and experimental/resumable even though
    # we are not directly using them and they're coming through somehow from Edge
    add_compile_options(/await)
elseif (UNIX)
    if (NOT APPLE)
        set(WEBVIEW_PLATFORM_SOURCES src/vstwebview/gtk/webview_gtk.cc)
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
        pkg_check_modules(WEBKIT2GTK REQUIRED webkit2gtk-4.1)
    else()
        # TODO any package checking for OSX
        add_compile_options(-Wno-suggest-override)
        set(WEBVIEW_PLATFORM_SOURCES src/vstwebview/osx/webview_osx.mm)
    endif ()
endif ()

add_library(vstwebview
        ${WEBVIEW_PLATFORM_SOURCES}
        src/vstwebview/webview_controller_bindings.cc
        src/vstwebview/webview_message_listener.cc
        src/vstwebview/webview_pluginview.cc
        src/vstwebview/webview.cc)

target_compile_options(vstwebview PUBLIC "$<$<CONFIG:DEBUG>:-DDEVELOPMENT>")
target_compile_options(vstwebview PUBLIC "$<$<CONFIG:RELEASE>:-DRELEASE>")
target_include_directories(vstwebview PRIVATE ./src ${vstsdk_SOURCE_DIR} ${json_SOURCE_DIR}/include)
target_include_directories(vstwebview PUBLIC ./include)
add_dependencies(vstwebview nlohmann_json::nlohmann_json)

# Needed for webview2.h & friends on Win32.
if (WIN32)

    option(WIL_BUILD_PACKAGING "" OFF)
    option(WIL_BUILD_TESTS "" OFF)
    FetchContent_Declare(wil GIT_REPOSITORY "https://github.com/microsoft/wil")
    FetchContent_MakeAvailable(wil)

    include(NuGet)

    nuget_add(WebView2 "Microsoft.Web.WebView2" 1.0.1150.38)
    nuget_add(CppWinRT "Microsoft.Windows.CppWinRT" 2.0.220315.1)

    target_compile_definitions(vstwebview PRIVATE UNICODE=1 _UNICODE=1)
    target_include_directories(vstwebview PRIVATE ${WebView2_PATH}/build/native/include)

    if (CMAKE_SIZEOF_VOID_P EQUAL 8)
        target_link_libraries(vstwebview PRIVATE ${WebView2_PATH}/build/native/x64/WebView2LoaderStatic.lib)
    else ()
        target_link_libraries(vstwebview PRIVATE ${WebView2_PATH}/build/native/x86/WebView2LoaderStatic.lib)
    endif ()

    target_link_libraries(vstwebview PRIVATE WIL::WIL Dwmapi Shlwapi)

elseif(UNIX)

    # GTK on Linux
    if (NOT APPLE)
        target_include_directories(vstwebview PRIVATE ${GTK3_INCLUDE_DIRS} ${WEBKIT2GTK_INCLUDE_DIRS} ${GTKMM3_INCLUDE_DIRS})
        target_link_libraries(vstwebview PRIVATE ${GTK3_LIBRARIES} ${WEBKIT2GTK_LIBRARIES} ${GTKMM3_LIBRARIES})
    else()
        target_link_libraries(vstwebview "-framework Foundation")
    endif()
endif ()

option(BUILD_DEMO "Build demos" OFF)
if(BUILD_DEMO)
    add_subdirectory(demo/panner)
endif()
