# Resident Evil Code: Veronica X HD - ReXGlue recompiled project

cmake_minimum_required(VERSION 3.25)
project(recvx LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

set(RECVX_SOURCES
    src/main.cpp
)

if(WIN32)
    add_executable(recvx WIN32 ${RECVX_SOURCES})
else()
    add_executable(recvx ${RECVX_SOURCES})
endif()

rexglue_setup_target(recvx GPU_PLUGINS xenos)
