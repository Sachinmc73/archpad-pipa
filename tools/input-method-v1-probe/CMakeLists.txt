cmake_minimum_required(VERSION 3.20)
project(input-method-v1-probe C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED wayland-client)
pkg_check_modules(LIBSYSTEMD REQUIRED libsystemd)

find_program(WAYLAND_SCANNER_EXECUTABLE wayland-scanner REQUIRED)

# Protocol XML
set(IM_PROTOCOL_XML "/usr/share/wayland-protocols/unstable/input-method/input-method-unstable-v1.xml" CACHE FILEPATH "Path to input-method-unstable-v1.xml")

if(NOT EXISTS "${IM_PROTOCOL_XML}")
    message(FATAL_ERROR "Protocol XML not found at ${IM_PROTOCOL_XML}")
endif()

set(GEN_HEADER "${CMAKE_CURRENT_BINARY_DIR}/input-method-unstable-v1-client-protocol.h")
set(GEN_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/input-method-unstable-v1-protocol.c")

add_custom_command(
    OUTPUT "${GEN_HEADER}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" client-header "${IM_PROTOCOL_XML}" "${GEN_HEADER}"
    DEPENDS "${IM_PROTOCOL_XML}"
    COMMENT "Generating ${GEN_HEADER}"
    VERBATIM
)

add_custom_command(
    OUTPUT "${GEN_SOURCE}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" private-code "${IM_PROTOCOL_XML}" "${GEN_SOURCE}"
    DEPENDS "${IM_PROTOCOL_XML}"
    COMMENT "Generating ${GEN_SOURCE}"
    VERBATIM
)

add_executable(input-method-v1-probe
    main.c
    "${GEN_HEADER}"
    "${GEN_SOURCE}"
)

target_include_directories(input-method-v1-probe PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    ${WAYLAND_CLIENT_INCLUDE_DIRS}
    ${LIBSYSTEMD_INCLUDE_DIRS}
)

target_link_libraries(input-method-v1-probe PRIVATE
    ${WAYLAND_CLIENT_LIBRARIES}
    ${LIBSYSTEMD_LIBRARIES}
)

target_compile_options(input-method-v1-probe PRIVATE
    -Wall -Wextra -Wno-unused-parameter
)
