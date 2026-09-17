cmake_minimum_required(VERSION 3.20)
project(archpad-keyboard VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# Optimization flags
set(CMAKE_BUILD_TYPE Release)
add_compile_options(-O3 -flto -fvisibility=hidden -fvisibility-inlines-hidden)
add_link_options(-flto -Wl,--as-needed -Wl,--gc-sections)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml DBus)
find_package(LayerShellQt REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CANBERRA REQUIRED libcanberra)
pkg_check_modules(FUTO_SWIPE REQUIRED archpad-futo-swipe)
pkg_check_modules(WAYLAND_CLIENT REQUIRED wayland-client)
find_program(WAYLAND_SCANNER_EXECUTABLE wayland-scanner REQUIRED)

# Protocol XML
set(IM_PROTOCOL_XML "/usr/share/wayland-protocols/unstable/input-method/input-method-unstable-v1.xml" CACHE FILEPATH "Path to input-method-unstable-v1.xml")
if(NOT EXISTS "${IM_PROTOCOL_XML}")
    message(FATAL_ERROR "Protocol XML not found at ${IM_PROTOCOL_XML}")
endif()

set(GEN_IM_HEADER "${CMAKE_CURRENT_BINARY_DIR}/input-method-unstable-v1-client-protocol.h")
set(GEN_IM_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/input-method-unstable-v1-protocol.c")

add_custom_command(
    OUTPUT "${GEN_IM_HEADER}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" client-header "${IM_PROTOCOL_XML}" "${GEN_IM_HEADER}"
    DEPENDS "${IM_PROTOCOL_XML}"
    COMMENT "Generating ${GEN_IM_HEADER}"
    VERBATIM
)

add_custom_command(
    OUTPUT "${GEN_IM_SOURCE}"
    COMMAND "${WAYLAND_SCANNER_EXECUTABLE}" private-code "${IM_PROTOCOL_XML}" "${GEN_IM_SOURCE}"
    DEPENDS "${IM_PROTOCOL_XML}"
    COMMENT "Generating ${GEN_IM_SOURCE}"
    VERBATIM
)

add_executable(archpad-keyboard
    main.cpp
    keyboardmanager.h
    keyboardmanager.cpp
    swipeengineworker.h
    swipeengineworker.cpp
    gesturetrailitem.h
    gesturetrailitem.cpp
    textcommitbackend.h
    waylandinputmethodv1backend.h
    waylandinputmethodv1backend.cpp
    "${GEN_IM_HEADER}"
    "${GEN_IM_SOURCE}"
    resources.qrc
)

target_include_directories(archpad-keyboard PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}"
    ${CANBERRA_INCLUDE_DIRS}
    ${FUTO_SWIPE_INCLUDE_DIRS}
    ${WAYLAND_CLIENT_INCLUDE_DIRS}
)

target_link_libraries(archpad-keyboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    ${CANBERRA_LIBRARIES}
    ${FUTO_SWIPE_LIBRARIES}
    ${WAYLAND_CLIENT_LIBRARIES}
    LayerShellQt::Interface
)

add_executable(test_swipe_worker
    test_swipe_worker.cpp
    swipeengineworker.h
    swipeengineworker.cpp
)

target_include_directories(test_swipe_worker PRIVATE
    ${FUTO_SWIPE_INCLUDE_DIRS}
)

target_link_libraries(test_swipe_worker PRIVATE
    Qt6::Core
    ${FUTO_SWIPE_LIBRARIES}
)

add_executable(archpad-keyboard-settings
    settings/main.cpp
    settings/settingscontroller.h
    settings/settingscontroller.cpp
    settings/resources_settings.qrc
)

target_link_libraries(archpad-keyboard-settings PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
)

include(GNUInstallDirs)

install(TARGETS archpad-keyboard archpad-keyboard-settings DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/../archpad-keyboard.desktop
    ${CMAKE_CURRENT_SOURCE_DIR}/../archpad-keyboard-settings.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)
install(FILES
    sounds/keypress-standard.ogg
    sounds/keypress-soft.ogg
    sounds/keypress-crisp.ogg
    sounds/keypress-deep.ogg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/archpad-keyboard/sounds
)
