cmake_minimum_required(VERSION 3.20)
project(archpad-keyboard VERSION 1.0.0 LANGUAGES CXX)

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

add_executable(archpad-keyboard
    main.cpp
    keyboardmanager.h
    keyboardmanager.cpp
    swipeengineworker.h
    swipeengineworker.cpp
    resources.qrc
)

target_include_directories(archpad-keyboard PRIVATE
    ${CANBERRA_INCLUDE_DIRS}
    ${FUTO_SWIPE_INCLUDE_DIRS}
)

target_link_libraries(archpad-keyboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    ${CANBERRA_LIBRARIES}
    ${FUTO_SWIPE_LIBRARIES}
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
