# Resident Evil Code: Veronica X HD - ReXGlue recompiled project

cmake_minimum_required(VERSION 3.25)
project(recvx LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

set(RECVX_SOURCES
    src/main.cpp
)

if(ANDROID)
    # Android loads native game code as a shared library; there is no desktop main().
    add_library(recvx SHARED ${RECVX_SOURCES})
    target_compile_definitions(recvx PRIVATE REXGLUE_APP_NAME=\"recvx\")
elseif(WIN32)
    add_executable(recvx WIN32 ${RECVX_SOURCES})
else()
    add_executable(recvx ${RECVX_SOURCES})
endif()

rexglue_setup_target(recvx GPU_PLUGINS xenos)
