cmake_minimum_required(VERSION 3.16)

project(MusicPlayer VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find Qt
find_package(Qt5 COMPONENTS Core Gui Widgets Qml Quick Sql Concurrent Network REQUIRED)

# Find TagLib
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED taglib)
pkg_check_modules(SDL2 REQUIRED sdl2)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party
    ${TAGLIB_INCLUDE_DIRS}
    ${SDL2_INCLUDE_DIRS}
)

# Source files
set(SOURCES
    src/main.cpp
    src/audio_engine.cpp
    include/audio_engine.h
    src/equalizer.cpp
    include/equalizer.h
    src/library_scanner.cpp
    include/library_scanner.h
    include/track.h
    src/track_model.cpp
    include/track_model.h
    src/cover_art_provider.cpp
    include/cover_art_provider.h
    src/gamepad_controller.cpp
    include/gamepad_controller.h
)

# QML Resources
qt5_add_resources(RESOURCES qml.qrc icons.qrc)

# Executable
add_executable(MusicPlayer
    ${SOURCES}
    ${RESOURCES}
)

# Link Libraries
target_link_libraries(MusicPlayer PRIVATE
    Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick Qt5::Sql Qt5::Concurrent Qt5::Network
    ${TAGLIB_LIBRARIES}
    ${SDL2_LIBRARIES}
    dl pthread m
)

# Installation Targets
option(USER_SPACE_INSTALL "Install to the current user's home directory instead of standard system paths" ON)

if(USER_SPACE_INSTALL)
    set(BIN_DEST "$ENV{HOME}/.var/app/com.musicplayer.mlmPlayer")
    set(APP_DEST "$ENV{HOME}/.local/share/applications")
    set(ICON_DEST "$ENV{HOME}/.local/share/icons/hicolor/512x512/apps")
else()
    set(BIN_DEST "bin")
    set(APP_DEST "share/applications")
    set(ICON_DEST "share/icons/hicolor/512x512/apps")
endif()

install(TARGETS MusicPlayer RUNTIME DESTINATION "${BIN_DEST}")
install(FILES "Dist/Linux/MusicPlayer.desktop" DESTINATION "${APP_DEST}")
install(FILES "Dist/Linux/AppIcon.png" DESTINATION "${ICON_DEST}" RENAME MusicPlayer.png)
