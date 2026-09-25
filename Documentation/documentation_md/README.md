# Modern Music Player — Complete Project Handbook

Welcome to the complete, from-scratch developer handbook for the **Modern Music Player**.

This handbook is written for someone who knows basic C++ and wants to fully understand every piece of this application — from the build system, through the C++ backend, all the way to the QML frontend.

## Table of Contents

### Part I — Foundations

| Chapter | File | Topic |
|---------|------|-------|
| 1 | [01_introduction.md](01_introduction.md) | Project Overview, Goals, Technology Stack |
| 2 | [02_build_system.md](02_build_system.md) | CMake, Qt5, SDL2, DBus, Linking Libraries |
| 3 | [03_cpp_foundations.md](03_cpp_foundations.md) | Qt Basics: QObject, Signals & Slots, Q_PROPERTY |

### Part II — C++ Backend

| Chapter | File | Topic |
|---------|------|-------|
| 4 | [04_data_layer.md](04_data_layer.md) | Track struct, TrackModel, QAbstractListModel |
| 5 | [05_library_scanner.md](05_library_scanner.md) | LibraryScanner, TagLib, SQLite, Play-Time Tracking |
| 6 | [06_audio_engine.md](06_audio_engine.md) | AudioEngine, miniaudio, Node Graph, EQ Chain |
| 7 | [07_equalizer.md](07_equalizer.md) | Equalizer class, Presets, QSettings |
| 8 | [08_cover_art.md](08_cover_art.md) | CoverArtProvider, extractImageFromTag |
| 9 | [09_playlist_system.md](09_playlist_system.md) | PlaylistManager, SQLite Schema, CRUD Operations |
| 10 | [10_mpris_integration.md](10_mpris_integration.md) | MPRIS2 D-Bus, Cover Art to Desktop |
| 11 | [11_gamepad_control.md](11_gamepad_control.md) | GamepadController, SDL2 Polling, Zone Navigation |

### Part III — The Bridge

| Chapter | File | Topic |
|---------|------|-------|
| 12 | [12_main_bridge.md](12_main_bridge.md) | main.cpp: Wiring All Backends to QML |

### Part IV — QML Frontend

| Chapter | File | Topic |
|---------|------|-------|
| 13 | [13_qml_fundamentals.md](13_qml_fundamentals.md) | QML Language Crash Course for C++ Devs |
| 14 | [14_qml_main_window.md](14_qml_main_window.md) | main.qml: Root Window, Playback Bar |
| 15 | [15_qml_library_view.md](15_qml_library_view.md) | LibraryView.qml: Tabs, Tiles, Filtering |
| 16 | [16_qml_equalizer_view.md](16_qml_equalizer_view.md) | EqualizerView.qml and NowPlayingView.qml |
| 17 | [17_qml_minimal_view.md](17_qml_minimal_view.md) | MinimalView: Compact Now Playing Window |
| 18 | [18_qml_playlist_views.md](18_qml_playlist_views.md) | PlaylistsView, PlaylistDetailsView, PlaylistPopup |
| 19 | [19_qml_popup_architecture.md](19_qml_popup_architecture.md) | AppPopups.qml: Centralized Popup Management |

### Part V — System Integration & Deployment

| Chapter | File | Topic |
|---------|------|-------|
| 20 | [20_launch_modes_and_ipc.md](20_launch_modes_and_ipc.md) | Launch Modes, Single-Instance IPC, Multi-Instance Library |
| 21 | [21_os_integration.md](21_os_integration.md) | Desktop File, MIME Registration, Icon |
| 22 | [22_dataflow.md](22_dataflow.md) | Full End-to-End Dataflow Diagrams (capstone) |
| 23 | [23_building_and_packaging.md](23_building_and_packaging.md) | Build Steps, Install, AppImage |

> **Tip:** Read the chapters in order on your first pass. Each chapter builds on the previous. Part I–II covers all C++ backend code, Part III shows how it all wires together, Part IV covers the QML UI, and Part V covers system-level integration and deployment.
