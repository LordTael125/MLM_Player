# Modern Music Player — Complete Project Handbook

Welcome to the complete, from-scratch developer handbook for the **Modern Music Player**.

This handbook is written for someone who knows basic C++ and wants to fully understand every piece of this application — from the build system, through the C++ backend, all the way to the QML frontend.

## Table of Contents

### Part I — Foundations

| Chapter | File | Topic |
|---------|------|-------|
| 1 | [01_introduction.md](#01_introduction.md) | Project Overview, Goals, Technology Stack |
| 2 | [02_build_system.md](#02_build_system.md) | CMake, Qt5, SDL2, DBus, Linking Libraries |
| 3 | [03_cpp_foundations.md](#03_cpp_foundations.md) | Qt Basics: QObject, Signals & Slots, Q_PROPERTY |

### Part II — C++ Backend

| Chapter | File | Topic |
|---------|------|-------|
| 4 | [04_data_layer.md](#04_data_layer.md) | Track struct, TrackModel, QAbstractListModel |
| 5 | [05_library_scanner.md](#05_library_scanner.md) | LibraryScanner, TagLib, SQLite, Play-Time Tracking |
| 6 | [06_audio_engine.md](#06_audio_engine.md) | AudioEngine, miniaudio, Node Graph, EQ Chain |
| 7 | [07_equalizer.md](#07_equalizer.md) | Equalizer class, Presets, QSettings |
| 8 | [08_cover_art.md](#08_cover_art.md) | CoverArtProvider, extractImageFromTag |
| 9 | [09_playlist_system.md](#09_playlist_system.md) | PlaylistManager, SQLite Schema, CRUD Operations |
| 10 | [10_mpris_integration.md](#10_mpris_integration.md) | MPRIS2 D-Bus, Cover Art to Desktop |
| 11 | [11_gamepad_control.md](#11_gamepad_control.md) | GamepadController, SDL2 Polling, Zone Navigation |

### Part III — The Bridge

| Chapter | File | Topic |
|---------|------|-------|
| 12 | [12_main_bridge.md](#12_main_bridge.md) | main.cpp: Wiring All Backends to QML |

### Part IV — QML Frontend

| Chapter | File | Topic |
|---------|------|-------|
| 13 | [13_qml_fundamentals.md](#13_qml_fundamentals.md) | QML Language Crash Course for C++ Devs |
| 14 | [14_qml_main_window.md](#14_qml_main_window.md) | main.qml: Root Window, Playback Bar |
| 15 | [15_qml_library_view.md](#15_qml_library_view.md) | LibraryView.qml: Tabs, Tiles, Filtering |
| 16 | [16_qml_equalizer_view.md](#16_qml_equalizer_view.md) | EqualizerView.qml and NowPlayingView.qml |
| 17 | [17_qml_minimal_view.md](#17_qml_minimal_view.md) | MinimalView: Compact Now Playing Window |
| 18 | [18_qml_playlist_views.md](#18_qml_playlist_views.md) | PlaylistsView, PlaylistDetailsView, PlaylistPopup |
| 19 | [19_qml_popup_architecture.md](#19_qml_popup_architecture.md) | AppPopups.qml: Centralized Popup Management |

### Part V — System Integration & Deployment

| Chapter | File | Topic |
|---------|------|-------|
| 20 | [20_launch_modes_and_ipc.md](#20_launch_modes_and_ipc.md) | Launch Modes, Single-Instance IPC, Multi-Instance Library |
| 21 | [21_os_integration.md](#21_os_integration.md) | Desktop File, MIME Registration, Icon |
| 22 | [22_dataflow.md](#22_dataflow.md) | Full End-to-End Dataflow Diagrams (capstone) |
| 23 | [23_building_and_packaging.md](#23_building_and_packaging.md) | Build Steps, Install, AppImage |

> **Tip:** Read the chapters in order on your first pass. Each chapter builds on the previous. Part I–II covers all C++ backend code, Part III shows how it all wires together, Part IV covers the QML UI, and Part V covers system-level integration and deployment.


<div class="page-break"></div>

<a id="01_introduction.md"></a>

# Chapter 1 — Introduction & Technology Stack

## 1.1 What is this project?

**Modern Music Player** is a cross-platform, local-library music player built entirely in **C++ with a Qt 5 / QML frontend**. It can:

- Scan a folder (and all sub-folders) for audio files
- Read metadata (artist, album, title, track number, disc number, genre) from audio tags
- Display artwork embedded in audio files
- Play music using a high-performance audio engine
- Adjust sound using a 10-band graphic equalizer
- Maintain a playback queue with skip, repeat (Off/Track/All), seek functionality
- Launch in three distinct modes depending on how it is invoked (Library, Minimal, Queue)
- Detect and redirect secondary instances via IPC to prevent duplicate window spawning (Minimal/Queue modes only — Library mode allows multiple windows)
- Display a compact 700×350 Minimal Now Playing view when opened from a file manager
- Register itself with the OS as a handler for all common audio MIME types
- Create and manage playlists with add, remove, reorder, and sort operations
- Track per-song play time and provide a "Most Played" filter
- Integrate with the Linux desktop via MPRIS2 D-Bus (KDE Plasma, GNOME media controls, lock screen widgets) with full metadata and cover art
- Accept gamepad/controller input for hands-free navigation via SDL2
- Automatically remove deleted files from the library during rescan

The project is structured so that the **business logic lives in C++** and the **UI is written in QML** (Qt's declarative UI language). These two worlds communicate through Qt's signal-slot mechanism and context properties.

---

## 1.2 Technology Stack at a Glance

| Technology | Role | Why |
|---|---|---|
| **C++ 17** | Core language | Performance, type safety, rich ecosystem |
| **Qt 5** | Framework glue (widgets, threading, SQL, networking, D-Bus) | Comprehensive cross-platform framework |
| **QML / Qt Quick 2** | Declarative UI language | Fast, smooth, modern UI without Qt Widgets verbosity |
| **miniaudio** (header-only) | Audio playback engine | Tiny, zero-dependency, powerful node graph |
| **TagLib** | Audio tag reading (ID3, Vorbis, MP4) | Mature, reliable library for music metadata |
| **SQLite via Qt Sql** | Persistent library database | Lightweight embedded database, ships with Qt |
| **QtConcurrent** | Background threading | Safe Qt-aware thread pool |
| **Qt Network (QLocalServer/Socket)** | Single-instance IPC | Unix domain socket communication between processes |
| **Qt D-Bus** | MPRIS2 media integration | Exposes playback controls and metadata to the Linux desktop |
| **SDL2** | Gamepad/controller input | Cross-platform gamepad polling and button/axis mapping |
| **Qt Labs Settings** | Session persistence | Cross-platform key-value store for queue/position restore |
| **CMake 3.16+** | Build system | Industry standard, cross-platform build tool |

---

## 1.3 How This App Is Different From a "Hello World" Qt App

Most Qt tutorials show:
```cpp
QLabel *label = new QLabel("Hello");
label->show();
```

This app is a full production-grade application with:
- **Separations of concern**: Each class has exactly one job
- **Asynchronous operations**: File scanning happens on a background thread
- **Custom Qt Model**: `TrackModel` extends `QAbstractListModel` so QML can bind to it natively
- **Node-graph audio pipeline**: Sound → EQ Band 1 → EQ Band 2 → … → Speaker
- **Custom image provider**: Album art is fetched on-demand by URL through `CoverArtProvider`

---

## 1.4 Directory Layout

```
Music Player/
├── CMakeLists.txt              ← Build script
├── include/                    ← All .h header files
│   ├── track.h                 ← Plain data struct: a single song's info
│   ├── track_model.h           ← Qt model bridging Track data to QML
│   ├── library_scanner.h       ← Scans folders, reads tags, writes to DB
│   ├── audio_engine.h          ← Plays audio, controls volume/seek
│   ├── equalizer.h             ← 10-band EQ with presets
│   ├── cover_art_provider.h    ← Converts file paths to QImages for QML
│   ├── playlist_manager.h      ← Playlist CRUD operations via SQLite
│   ├── mpris_manager.h         ← MPRIS2 D-Bus integration for Linux desktops
│   └── gamepad_controller.h    ← SDL2-based gamepad input handling
├── src/                        ← All .cpp implementation files
│   ├── main.cpp                ← App entry point, wires everything together
│   ├── track_model.cpp
│   ├── library_scanner.cpp
│   ├── audio_engine.cpp
│   ├── equalizer.cpp
│   ├── cover_art_provider.cpp
│   ├── playlist_manager.cpp
│   ├── mpris_manager.cpp
│   └── gamepad_controller.cpp
├── qml/                        ← All QML (UI) files
│   ├── main.qml                ← Root window, playback bar, shortcuts, mode routing
│   ├── AppPopups.qml           ← Centralized popup management (all popups live here)
│   ├── LibraryView.qml         ← The main tabbed library browser (7 view modes)
│   ├── EqualizerView.qml       ← The EQ slider UI with preset management
│   ├── NowPlayingView.qml      ← Full-screen now playing overlay
│   ├── MinimalView.qml         ← Compact 700x350 now playing window for file-explorer launches
│   ├── PlaylistsView.qml       ← Grid of playlist tiles
│   ├── PlaylistDetailsView.qml ← Track list for a single playlist (with edit mode)
│   ├── PlaylistPopup.qml       ← Add-to-playlist, create, right-click menu popups
│   ├── GamepadControl.qml      ← Zone-based gamepad navigation logic
│   ├── components/             ← Reusable QML components
│   └── icons/                  ← SVG icons used in the UI
├── third_party/                ← Bundled header-only libraries
│   └── miniaudio.h             ← The entire audio engine in one file
├── qml.qrc                     ← Qt resource file listing QML files
└── icons.qrc                   ← Qt resource file listing icon SVGs
```

---

## 1.5 The "Two Worlds" Mental Model

The most important concept in this project is understanding how C++ talks to QML.

```
┌─────────────────────────────────────────┐
│                 C++ World               │
│                                         │
│   AudioEngine   LibraryScanner          │
│   TrackModel    Equalizer               │
│   CoverArtProvider                      │
│   PlaylistManager  MprisManager         │
│   GamepadController                     │
│                                         │
│   These live in memory as QObject       │
│   subclasses.                           │
└───────────────┬─────────────────────────┘
                │  exposed via
                │  setContextProperty()
                │  and signals/slots
┌───────────────▼─────────────────────────┐
│                QML World                │
│                                         │
│   main.qml         AppPopups.qml        │
│   LibraryView.qml  PlaylistsView.qml    │
│   EqualizerView.qml  GamepadControl.qml │
│                                         │
│   These access C++ objects like         │
│   JavaScript objects using the names    │
│   given in setContextProperty.          │
└─────────────────────────────────────────┘
```

When QML calls:
```qml
audioEngine.play()
```

It is actually calling the `AudioEngine::play()` C++ slot through Qt's meta-object system. This magic is covered in detail in Chapter 12.

---

## 1.6 Prerequisites

Before reading this handbook, you should know:
- Basic C++ (classes, methods, pointers, `#include`)
- What a `.h` (header) vs `.cpp` (source) file is

You do NOT need to know:
- Qt (we teach it from scratch)
- QML (we teach it from scratch)
- Audio programming (we explain every concept)

Let's begin!


<div class="page-break"></div>

<a id="02_build_system.md"></a>

# Chapter 2 — The Build System (CMake)

## 2.1 What is a Build System?

When you write C++ code, it lives in `.h` and `.cpp` text files. These **cannot run directly**. A **build system** automates the steps:

```
Source Code (.cpp) → Compiler → Object Files (.o) → Linker → Executable
```

This project uses **CMake**, the industry-standard cross-platform build tool. CMake itself does not compile code — it generates the instructions (Makefiles or Ninja scripts) that tools like `g++` then use.

---

## 2.2 Full CMakeLists.txt with Line-by-Line Explanation

```cmake
cmake_minimum_required(VERSION 3.16)
```
> Declares the minimum CMake version required. 3.16 introduced `qt5_add_resources` improvements.

```cmake
project(MusicPlayer VERSION 1.3.2 LANGUAGES CXX)
```
> Declares the project name `MusicPlayer`, version `1.3.2`, and that only C++ code is used.

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```
> Forces C++ 17 features. We need C++17 for `std::function`, structured bindings, and lambdas with captures.

```cmake
set(CMAKE_INCLUDE_CURRENT_DIR ON)
```
> Tells the compiler to also look for headers in the current directory. Simplifies include paths.

```cmake
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
```
> These three lines are **Qt-specific magic**:
> - `AUTOMOC`: Automatically runs Qt's **Meta-Object Compiler** (moc) on any header that contains `Q_OBJECT`. This is what makes signals, slots, and properties work.
> - `AUTORCC`: Automatically packages `.qrc` resource files (QML scripts, icons) into the binary.
> - `AUTOUIC`: Auto-processes `.ui` files (we don't use these, but it's good practice to enable).

```cmake
find_package(Qt5 COMPONENTS Core Gui Widgets Qml Quick Sql Concurrent Network DBus REQUIRED)
```
> Finds the Qt5 installation on your system and enables the specified **modules**:
>
> | Module | Purpose |
> |--------|---------|
> | `Core` | QString, QTimer, QObject, signals/slots |
> | `Gui` | QImage (for album art) |
> | `Widgets` | QApplication (needed for Qt Quick apps too) |
> | `Qml` | QQmlApplicationEngine, context properties |
> | `Quick` | QQuickImageProvider (for cover art) |
> | `Sql` | QSqlDatabase, QSqlQuery (SQLite) |
> | `Concurrent` | QtConcurrent::run() — background threads |
> | `Network` | QLocalServer, QLocalSocket — single-instance IPC |
> | `DBus` | QDBusConnection, QDBusAbstractAdaptor — MPRIS2 integration |

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED taglib)
pkg_check_modules(SDL2 REQUIRED sdl2)
```
> Finds **TagLib** and **SDL2** using the system's `pkg-config` tool. This sets `TAGLIB_INCLUDE_DIRS`, `TAGLIB_LIBRARIES`, `SDL2_INCLUDE_DIRS`, and `SDL2_LIBRARIES` variables.

```cmake
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party
    ${TAGLIB_INCLUDE_DIRS}
    ${SDL2_INCLUDE_DIRS}
)
```
> Tells the compiler where to find `.h` headers:
> - `include/` — our own headers
> - `third_party/` — where `miniaudio.h` lives
> - TagLib's and SDL2's system headers

```cmake
set(SOURCES
    src/main.cpp
    src/audio_engine.cpp     include/audio_engine.h
    src/equalizer.cpp        include/equalizer.h
    src/library_scanner.cpp  include/library_scanner.h
    include/track.h
    src/track_model.cpp      include/track_model.h
    src/cover_art_provider.cpp include/cover_art_provider.h
    src/gamepad_controller.cpp include/gamepad_controller.h
    src/playlist_manager.cpp include/playlist_manager.h
    src/mpris_manager.cpp    include/mpris_manager.h
)
```
> Lists every source file. **Note**: headers are listed here too. This is not strictly required for compilation, but it helps IDE tools (like Qt Creator) discover and show them.

```cmake
qt5_add_resources(RESOURCES qml.qrc icons.qrc)
```
> Packs our QML files and SVG icons **into the binary** so they travel with the executable. The files become accessible at runtime via `qrc:/` URLs.

```cmake
add_executable(MusicPlayer ${SOURCES} ${RESOURCES})
```
> Creates the final executable named `MusicPlayer`.

```cmake
target_link_libraries(MusicPlayer PRIVATE
    Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick Qt5::Sql
    Qt5::Concurrent Qt5::Network Qt5::DBus
    ${TAGLIB_LIBRARIES}
    ${SDL2_LIBRARIES}
    dl pthread m
)
```
> Links the executable against:
> - All Qt5 modules including `Qt5::Network` (IPC) and `Qt5::DBus` (MPRIS2)
> - TagLib (audio tag reading)
> - SDL2 (gamepad input)
> - `dl` (dynamic linker, needed by miniaudio for `dlopen`)
> - `pthread` (POSIX threads, needed by miniaudio)
> - `m` (math library, `libm`, for `sin`, `cos`, `fmaxf` in the equalizer)

---

## 2.3 The Qt Resource System (`.qrc` files)

Normal file paths like `"/home/user/qml/main.qml"` only work on that one machine. The `.qrc` resource system embeds files directly **inside the compiled binary**.

**qml.qrc** (simplified) looks like:
```xml
<RCC>
  <qresource prefix="/qml">
    <file>qml/main.qml</file>
    <file>qml/LibraryView.qml</file>
    <file>qml/EqualizerView.qml</file>
    <file>qml/NowPlayingView.qml</file>
    <file>qml/MinimalView.qml</file>
  </qresource>
</RCC>
```

At runtime, you access these as:
```
qrc:/qml/main.qml
qrc:/qml/icons/play.svg
```

In `main.cpp` we load the root QML file like this:
```cpp
const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
engine.load(url);
```

---

## 2.4 How to Build the Project

### On Linux (Ubuntu/Debian):

**Step 1: Install dependencies**
```bash
sudo apt install cmake build-essential qt5-default \
     libqt5qml5 libqt5sql5-sqlite qtconcurrent5 \
     libtaglib-dev pkg-config
```

**Step 2: Create a build directory (out-of-source build)**
```bash
cd "Music Player"
mkdir build && cd build
```
*Always build in a separate directory — keeps source clean.*

**Step 3: Configure with CMake**
```bash
cmake ..
```
CMake reads `CMakeLists.txt`, finds Qt5 and TagLib, and generates a `Makefile`.

**Step 4: Compile**
```bash
make -j$(nproc)
```
`-j$(nproc)` uses all CPU cores in parallel. This produces the `MusicPlayer` executable.

**Step 5: Run**
```bash
./MusicPlayer
```

---

## 2.5 What `AUTOMOC` Does — The Secret Behind Qt

This is crucial to understand. When you write:
```cpp
class AudioEngine : public QObject {
    Q_OBJECT           // <-- This macro
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingChanged)
    ...
signals:
    void playingChanged(bool isPlaying);
};
```

`Q_OBJECT` is a magic macro that tells CMake's `AUTOMOC` to run the **`moc` tool** on this header. `moc` (the Meta-Object Compiler) **generates extra C++ code** that enables:
- Signals and Slots connectivity
- Property system (read/write/notify)
- Runtime type information

The generated file is named something like `moc_audio_engine.cpp` and is automatically compiled alongside your code. You never write it — Qt generates it automatically.

---

## 2.6 Summary

```
Your Source Code
    ↓ moc (AUTOMOC)
Qt meta-object code generated
    ↓ rcc (AUTORCC)
.qrc files → embedded binary blobs
    ↓ g++ / clang++
Object files (.o)
    ↓ linker (ld)
MusicPlayer (final executable, ~20-40 MB)
```

---

## 2.7 User-Space Installation Rules

Unlike system-wide installs (which need `sudo`), this app installs entirely into the current user's home directory:

```cmake
# Installation Targets for Local User Integration
install(TARGETS MusicPlayer RUNTIME DESTINATION "$ENV{HOME}/.var/app/com.musicplayer.mlmPlayer")
install(FILES "Dist/Linux/MusicPlayer.desktop" DESTINATION "$ENV{HOME}/.local/share/applications")
install(FILES "Dist/Linux/AppIcon.png" DESTINATION "$ENV{HOME}/.local/share/icons/hicolor/512x512/apps" RENAME MusicPlayer.png)
```

After `make install`, run:
```bash
update-desktop-database ~/.local/share/applications
```
This registers the MIME type associations without requiring a reboot or root privileges.


<div class="page-break"></div>

<a id="03_cpp_foundations.md"></a>

# Chapter 3 — Qt C++ Foundations

Before reading the individual class chapters, you must understand the four pillars of Qt programming that this project relies on heavily.

---

## 3.1 Pillar 1: QObject — The Base of Everything

Every meaningful class in this project inherits from `QObject`. This is not optional — `QObject` is what gives a class access to signals, slots, and properties.

```cpp
// A minimal QObject subclass
#include <QObject>

class MyClass : public QObject {
    Q_OBJECT   // MANDATORY macro — must be the first line inside the class
public:
    explicit MyClass(QObject *parent = nullptr);  // parent pointer: memory management
};
```

### The Parent-Child Memory Model
Qt uses a **parent-child ownership tree**. When a parent `QObject` is destroyed, it automatically destroys all its children:

```cpp
AudioEngine audioEngine;                    // parent = nullptr (stack-allocated)
Equalizer *eq = new Equalizer(&audioEngine); // eq's parent = &audioEngine
// When audioEngine is destroyed, eq is automatically deleted too
```

This means you rarely call `delete` manually in Qt code. **Always pass a parent** when heap-allocating a `QObject`.

---

## 3.2 Pillar 2: Signals and Slots

This is Qt's event system. It lets completely unrelated objects communicate **without knowing about each other directly**.

### Declaring Signals
```cpp
class AudioEngine : public QObject {
    Q_OBJECT
signals:
    void playingChanged(bool isPlaying);   // "something happened"
    void positionChanged(float position);   // "my state changed"
    void playbackFinished();               // "event occurred"
};
```
Signals are **declared** but **never defined** — Qt's `moc` tool generates the implementation automatically.

### Declaring Slots
```cpp
class TrackModel : public QAbstractListModel {
    Q_OBJECT
public slots:
    void setTracks(const QVector<Track> &tracks);   // can be connected to a signal
    void filterByArtist(const QString &artist);
};
```

### Connecting Them
```cpp
// In main.cpp:
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
```

Now whenever `libraryScanner` emits `tracksAdded(someVector)`, Qt automatically calls `trackModel.setTracks(someVector)`. The two objects don't know each other — they are loosely coupled.

### Emitting a Signal
```cpp
void AudioEngine::play() {
    ma_sound_start(&m_sound);
    emit playingChanged(true);  // "emit" keyword triggers all connected slots
}
```

### Thread Safety
Qt signals and slots are thread-safe when the objects involved live on different threads. Qt automatically queues the call across thread boundaries using `Qt::QueuedConnection`. This is used in `LibraryScanner` — scanning happens on a background thread, but `tracksAdded` is safely delivered to the main thread.

---

## 3.3 Pillar 3: Q_PROPERTY — The Bridge to QML

`Q_PROPERTY` is what makes a C++ class member accessible from QML as if it were a JavaScript property.

```cpp
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying          NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)
```

Each `Q_PROPERTY` declares:
- **Type** — `bool`, `float`, pointer, etc.
- **Name** — the name visible in QML (e.g., `audioEngine.isPlaying`)
- **READ** — which C++ getter to call
- **WRITE** *(optional)* — which C++ setter to call (makes it writable from QML)
- **NOTIFY** — which signal fires when the value changes (enables QML data binding)
- **CONSTANT** *(optional)* — no setter, no notify needed (value never changes)

In QML you can then write:
```qml
// Binding: this text updates automatically whenever positionChanged fires
Text { text: audioEngine.position.toFixed(1) + " sec" }

// Write through the WRITE setter
Slider { onMoved: audioEngine.position = value }

// Read a CONSTANT property
audioEngine.equalizer.bandGain(0)
```

---

## 3.4 Pillar 4: Q_INVOKABLE — Calling C++ Functions from QML

`Q_PROPERTY` lets QML read/write values. But sometimes QML needs to **call a function**:

```cpp
class Equalizer : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE int          bandCount() const;
    Q_INVOKABLE float        bandGain(int index) const;
    Q_INVOKABLE float        bandFrequency(int index) const;
    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
};
```

Adding `Q_INVOKABLE` before a method makes it callable from QML:
```qml
// In EqualizerView.qml:
var freq = audioEngine.equalizer.bandFrequency(0)   // calls C++ directly
audioEngine.equalizer.loadPreset("Rock")
```

Public slots can also be called from QML without `Q_INVOKABLE`. `Q_INVOKABLE` is preferred for const functions or ones that don't need slot semantics.

---

## 3.5 QString — Qt's String Class

Qt programs almost never use `std::string`. They use `QString`:

```cpp
QString name = "Unknown Artist";
QString path = filePath.toUtf8();   // convert to UTF-8 QByteArray

// Concatenation
QString display = track.title + " - " + track.artist;

// Check contents
if (track.title.isEmpty()) { ... }
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) { ... }
if (filePath.startsWith("file://")) { ... }

// Convert between Qt and standard types
std::string std_str = qtString.toStdString();
QString fromStd = QString::fromStdString(std_str);
QString fromWide = QString::fromStdWString(wideStr);  // used for TagLib
```

---

## 3.6 QVector — Qt's Dynamic Array

Like `std::vector` but Qt-flavored:

```cpp
QVector<Track> m_allTracks;    // holds Track structs
QVector<int>   m_displayIndices; // integer indices into m_allTracks

m_allTracks.append(newTrack);
m_allTracks.size();            // number of elements
m_allTracks[i];                // element access (same as std::vector)
m_allTracks.clear();           // remove all

// Range-based for loop
for (const Track &t : qAsConst(m_allTracks)) {
    // qAsConst prevents detach (copy-on-write optimization)
}
```

---

## 3.7 Lambda Functions in Qt

Modern Qt (C++11 and above) uses lambdas extensively for one-off callbacks:

```cpp
// Timer callback
connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
    if (m_soundLoaded && isPlaying()) {
        emit positionChanged(position());  // update QML every 250ms
    }
});

// QtConcurrent background task
QtConcurrent::run([this, path]() {
    // This runs on a background thread
    // "this" and "path" are captured by value/reference
    QDirIterator it(path, ...);
    ...
});
```

`[this, path]` is the **capture list** — variables from the outer scope that the lambda can use:
- `[this]` — capture the object pointer so you can call `emit`, access members
- `[=]` — capture everything by value (copy)
- `[&]` — capture everything by reference (dangerous if the lambda outlives the scope)


<div class="page-break"></div>

<a id="04_data_layer.md"></a>

# Chapter 4 — The Data Layer: Track, TrackModel, QAbstractListModel

## 4.1 The `Track` Struct — The Atom of the Music Library

Everything in this app revolves around one simple plain-data struct:

```cpp
// include/track.h
#ifndef TRACK_H
#define TRACK_H

#include <QString>

struct Track {
    QString filePath;       // Absolute path: "/home/user/music/song.mp3"
    QString title;          // "Bohemian Rhapsody"
    QString artist;         // "Queen"
    QString album;          // "A Night at the Opera"
    QString genre;          // "Rock"
    int duration{0};        // Duration in seconds (e.g., 354)
    bool hasCoverArt{false};// Does the file have an embedded album image?
    int trackNumber{0};     // Track # on disc (1, 2, 3...)
    int discNumber{0};      // Disc number for multi-disc albums
    int totalPlayTime{0};   // Cumulative seconds this track has been played
};

#endif // TRACK_H
```

This is a **plain struct** — no QObject, no signals, no methods. It is a pure data container. The `{0}` and `{false}` are **in-class member initializers** (C++11), meaning the values default to zero/false if not set.

The `totalPlayTime` field tracks how many total seconds a user has spent listening to this track. It is persisted in the SQLite database and updated in real-time by the `AudioEngine::playTimeAccumulated` signal (see Chapter 12).

`QVector<Track>` is then the fundamental collection: the entire music library is a vector of these structs.

---

## 4.2 Why We Need a Custom Qt Model

QML's `ListView` and `Repeater` need data to come from a **Qt Model**. You can't just hand QML a raw `QVector<Track>` — it wouldn't know how to read from it.

Qt provides `QAbstractListModel` as the base class for list data models. You subclass it and override three methods, and QML can automatically bind to it.

---

## 4.3 TrackModel — The Full Class

### Header: `include/track_model.h`

```cpp
#include "track.h"
#include <QAbstractListModel>
#include <QVector>

class TrackModel : public QAbstractListModel {
    Q_OBJECT

public:
    // Step 1: Define "roles" — these are like column names in a table
    enum TrackRoles {
        TitleRole    = Qt::UserRole + 1,  // Qt::UserRole = 256, so TitleRole = 257
        ArtistRole,                        // 258
        AlbumRole,                         // 259
        GenreRole,                         // 260
        DurationRole,                      // 261
        FilePathRole,                      // 262
        HasCoverArtRole,                   // 263
        TotalPlayTimeRole                  // 264
    };

    explicit TrackModel(QObject *parent = nullptr);

    // Step 2: Override the three mandatory virtual methods
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Step 3: Add useful extras
    Q_INVOKABLE QVariantMap get(int row) const;   // Get a whole row as a JS object
    void setTracks(const QVector<Track> &tracks); // Replace all tracks
    void addTracks(const QVector<Track> &tracks); // Append tracks

public slots:
    void filterAll();
    void filterByArtist(const QString &artist);
    void filterByAlbum(const QString &album);
    void filterByFolder(const QString &folder);
    void filterByCollection(const QString &collection);
    void filterByMostPlayed(int limit = 50);
    void filterByPlaylist(const QString &playlistName, const QStringList &playlistTracks);
    void updateTrackPlayTime(const QString &filePath, int addedTime);

    Q_INVOKABLE QVariantList getAllTracks() const;
    Q_INVOKABLE QVariantMap getTrackByPath(const QString &filePath) const;
    Q_INVOKABLE QVariantList getArtistTiles() const;
    Q_INVOKABLE QVariantList getAlbumTiles() const;
    Q_INVOKABLE QVariantList getFolderTiles() const;
    Q_INVOKABLE QVariantList getCollectionTiles() const;

private:
    QString getCommonRootPath() const;
    void updateDisplayIndices(std::function<bool(const Track &)> predicate);

    QVector<Track> m_allTracks;        // ALL tracks ever loaded
    QVector<int>   m_displayIndices;   // INDICES of tracks currently shown
};
```

### The Two-Array Design Explained

The key architectural decision is the separation of `m_allTracks` and `m_displayIndices`:

```
m_allTracks:       [ Track0, Track1, Track2, Track3, Track4 ]
                      idx=0   idx=1   idx=2   idx=3   idx=4

filterByArtist("Queen"):
m_displayIndices:  [ 1, 3 ]    ← only tracks at index 1 and 3 are "Queen"

QML sees a list of 2 items:
  - Row 0 → m_allTracks[1]
  - Row 1 → m_allTracks[3]
```

This design means **filtering is free** — we never copy or delete tracks, just change which indices are visible. The full library is always in memory.

---

## 4.4 Implementing the Three Mandatory Methods

### `rowCount` — How Many Rows?

```cpp
int TrackModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid())   // For a list (not tree), parent is always invalid
        return 0;
    return m_displayIndices.count();  // Only show filtered items
}
```

### `data` — What Is In Row N?

```cpp
QVariant TrackModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_displayIndices.count())
        return QVariant();  // Invalid row → return empty

    // Translate display index → actual track index
    int actualIndex = m_displayIndices[index.row()];
    const Track &track = m_allTracks[actualIndex];

    switch (role) {
    case TitleRole:      return track.title;
    case ArtistRole:     return track.artist;
    case AlbumRole:      return track.album;
    case GenreRole:      return track.genre;
    case DurationRole:   return track.duration;
    case FilePathRole:   return track.filePath;
    case HasCoverArtRole: return track.hasCoverArt;
    }

    return QVariant();
}
```

`QVariant` is Qt's universal value type — it can hold a string, int, bool, list, or map. QML knows how to automatically unpack them.

### `roleNames` — The Mapping from ID to Name

```cpp
QHash<int, QByteArray> TrackModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TitleRole]      = "title";
    roles[ArtistRole]     = "artist";
    roles[AlbumRole]      = "album";
    roles[GenreRole]      = "genre";
    roles[DurationRole]   = "duration";
    roles[FilePathRole]   = "filePath";
    roles[HasCoverArtRole] = "hasCoverArt";
    return roles;
}
```

This mapping is the bridge to QML. After this, in QML you can write:
```qml
ListView {
    model: trackModel    // the C++ TrackModel exposed via context property
    delegate: Text {
        text: title + " - " + artist   // "title" maps to TitleRole automatically
    }
}
```

---

## 4.5 Filtering — How It Works

```cpp
// Generic helper: takes a function that returns true/false for each track
void TrackModel::updateDisplayIndices(std::function<bool(const Track &)> predicate) {
    beginResetModel();           // Tell QML: "about to change everything"
    m_displayIndices.clear();
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (predicate(m_allTracks[i])) {
            m_displayIndices.append(i);
        }
    }
    endResetModel();             // Tell QML: "done, re-read everything"
}

// Show all tracks
void TrackModel::filterAll() {
    updateDisplayIndices([](const Track &) { return true; });
}

// Show only tracks by a specific artist
void TrackModel::filterByArtist(const QString &artist) {
    updateDisplayIndices([artist](const Track &t) { return t.artist == artist; });
}
```

`beginResetModel()` / `endResetModel()` are critical — they tell any attached QML `ListView` to stop reading data, wait for the update, then refresh itself. Without these, the UI would show stale or corrupt data.

---

## 4.6 The `get()` Method — Exporting a Full Row to QML

```cpp
QVariantMap TrackModel::get(int row) const {
    QVariantMap map;
    QModelIndex idx = index(row, 0);
    if (!idx.isValid()) return map;

    QHash<int, QByteArray> roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return map;
}
```

This converts a row into a `QVariantMap`, which QML sees as a JavaScript object:
```qml
// In main.qml, building the playback queue:
for (var i = 0; i < trackModel.rowCount(); i++) {
    newQueue.push(trackModel.get(i));  // push JS objects into queue array
}
// Then access: queue[0].title, queue[0].filePath, queue[0].hasCoverArt
```

---

## 4.7 Sorting Logic in `setTracks`

When tracks are first loaded, they are sorted:

```cpp
std::sort(m_allTracks.begin(), m_allTracks.end(),
          [](const Track &a, const Track &b) {
              if (a.artist == b.artist) {
                  if (a.album == b.album) {
                      if (a.discNumber != b.discNumber)
                          return a.discNumber < b.discNumber;
                      if (a.trackNumber != b.trackNumber)
                          return a.trackNumber < b.trackNumber;
                      return a.title < b.title;
                  }
                  return a.album < b.album;
              }
              return a.artist < b.artist;
          });
```

Priority: **Artist → Album → Disc → Track Number → Title**. This ensures albums appear in the natural CD track order.

---

## 4.8 Tile Queries — Getting Unique Artists/Albums

The UI shows "Artist Tiles" (one tile per unique artist). `getArtistTiles()` produces this:

```cpp
QVariantList TrackModel::getArtistTiles() const {
    QVariantList list;
    QSet<QString> seenArtists;          // Set ensures uniqueness
    for (const auto &t : qAsConst(m_allTracks)) {
        if (t.artist.isEmpty() || seenArtists.contains(t.artist))
            continue;
        seenArtists.insert(t.artist);
        QVariantMap map;
        map["name"]       = t.artist;
        map["hasCoverArt"] = t.hasCoverArt;
        map["filePath"]   = t.filePath;  // Use this track's art to represent the artist
        list.append(map);
    }
    return list;
}
```

QML receives a JavaScript array of objects: `[ {name: "Queen", hasCoverArt: true, filePath: "..."}, ... ]`.

---

## 4.9 New Filter Methods

### `filterByMostPlayed` — Sort by Play Time

```cpp
void TrackModel::filterByMostPlayed(int limit) {
    beginResetModel();
    m_displayIndices.clear();

    // Collect indices with non-zero play time
    QVector<QPair<int, int>> indexAndTime;
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (m_allTracks[i].totalPlayTime > 0)
            indexAndTime.append({i, m_allTracks[i].totalPlayTime});
    }

    // Sort descending by play time
    std::sort(indexAndTime.begin(), indexAndTime.end(),
              [](const auto &a, const auto &b) { return a.second > b.second; });

    for (int i = 0; i < qMin(limit, indexAndTime.size()); ++i)
        m_displayIndices.append(indexAndTime[i].first);

    endResetModel();
}
```

This filters and sorts the display to show only tracks with recorded play time, ordered by most-played first. The `limit` parameter caps the results (default: 50).

### `filterByPlaylist` — Show Playlist Contents

```cpp
void TrackModel::filterByPlaylist(const QString &playlistName, const QStringList &playlistTracks) {
    updateDisplayIndices([&playlistTracks](const Track &t) {
        return playlistTracks.contains(t.filePath);
    });
}
```

Filters the display to show only tracks whose file paths appear in the provided playlist track list.

### `updateTrackPlayTime` — Live Play-Time Updates

```cpp
void TrackModel::updateTrackPlayTime(const QString &filePath, int addedTime) {
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (m_allTracks[i].filePath == filePath) {
            m_allTracks[i].totalPlayTime += addedTime;
            break;
        }
    }
}
```

This slot is connected to `AudioEngine::playTimeAccumulated` in `main.cpp`. It keeps the in-memory model in sync with database updates, so the "Most Played" filter reflects current play counts without requiring a restart.

### `getAllTracks` — Full Track List for Popups

```cpp
Q_INVOKABLE QVariantList getAllTracks() const;
```

Returns every track in the library as a JavaScript array. Used by the playlist "Add Content" popup to display all available tracks regardless of the current filter.

### `getTrackByPath` — Lookup a Single Track

```cpp
Q_INVOKABLE QVariantMap getTrackByPath(const QString &filePath) const;
```

Returns metadata for a specific track given its file path. Used to populate the queue and playback UI when only a file path is known.



<div class="page-break"></div>

<a id="05_library_scanner.md"></a>

# Chapter 5 — LibraryScanner: Tags, Database, and Background Threads

## 5.1 What LibraryScanner Does

`LibraryScanner` is the engine that:
1. Walks a directory tree looking for audio files (`.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.ogg`)
2. Reads metadata (tags) from each file using **TagLib**
3. Checks if each file has embedded cover art
4. Saves everything to an **SQLite database** for persistence
5. Emits signals so the rest of the app knows the library has changed

It does all of this **on a background thread** using `QtConcurrent::run` so the UI never freezes.

---

## 5.2 TagLib — Reading Music Metadata

A music file like an `.mp3` contains two things:
- The **audio data** (the actual sound, compressed with MP3/AAC/FLAC codec)
- **Tags** (metadata): artist, title, album, genre, track number, cover art, etc.

**TagLib** is a C++ library that can read (and write) these tags across all formats.

### Basic TagLib Usage
```cpp
#include <taglib/fileref.h>
#include <taglib/tag.h>

TagLib::FileRef f("/path/to/song.mp3");

if (!f.isNull() && f.tag()) {
    TagLib::Tag *tag = f.tag();
    QString title  = QString::fromStdWString(tag->title().toWString());
    QString artist = QString::fromStdWString(tag->artist().toWString());
    QString album  = QString::fromStdWString(tag->album().toWString());
    QString genre  = QString::fromStdWString(tag->genre().toWString());
}

if (f.audioProperties()) {
    int durationSeconds = f.audioProperties()->lengthInSeconds();
}
```

`TagLib::String` uses a wide-character encoding internally. We convert through `toWString()` then `QString::fromStdWString()` to safely handle Unicode characters (é, ü, 中文, etc.).

### Reading Track/Disc Numbers via PropertyMap

The simple `tag->track()` method may not always work for all formats. The `PropertyMap` is more reliable:

```cpp
TagLib::PropertyMap properties = f.file()->properties();

if (properties.contains("TRACKNUMBER") && !properties["TRACKNUMBER"].isEmpty()) {
    track.trackNumber = properties["TRACKNUMBER"].front().toInt();
} else {
    track.trackNumber = tag->track();  // fallback
}

if (properties.contains("DISCNUMBER") && !properties["DISCNUMBER"].isEmpty()) {
    track.discNumber = properties["DISCNUMBER"].front().toInt();
}
```

### Checking for Cover Art (Format-Specific)

Cover art detection requires format-specific TagLib classes:

```cpp
// MP3: looks for APIC (Attached Picture) ID3v2 frame
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
    TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
    if (mpegFile.hasID3v2Tag()) {
        auto frameList = mpegFile.ID3v2Tag()->frameListMap()["APIC"];
        if (!frameList.isEmpty()) hasArt = true;
    }
}
// FLAC: has its own picture list
else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
    TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
    if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) hasArt = true;
}
// M4A/AAC: uses "covr" item in the MP4 tag
else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
    TagLib::MP4::File mp4File(filePath.toUtf8().constData());
    if (mp4File.isValid() && mp4File.tag()) {
        if (mp4File.tag()->itemMap().contains("covr")) hasArt = true;
    }
}
```

---

## 5.3 SQLite via Qt Sql — The Persistent Library Database

Without a database, every time you launch the app it would have to re-scan all your music. The database lets us remember what we already scanned.

### Database Initialization

```cpp
void LibraryScanner::initializeDatabase() {
    // Find a writable location on this platform (Linux: ~/.local/share/AppName/)
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);   // Create the directory if it doesn't exist

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");   // Use SQLite driver
    db.setDatabaseName(dataDir + "/tracks.db");               // File path for the .db file

    if (db.open()) {
        QSqlQuery query;
        // CREATE TABLE IF NOT EXISTS means this is safe to run on every launch
        query.exec(
            "CREATE TABLE IF NOT EXISTS tracks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "title TEXT, artist TEXT, album TEXT, genre TEXT, "
            "duration INTEGER, filePath TEXT UNIQUE, "   // UNIQUE prevents duplicate paths
            "hasCoverArt INTEGER, trackNumber INTEGER, discNumber INTEGER, "
            "totalPlayTime INTEGER DEFAULT 0)"
        );
        // Migration patches — safe to run even if column already exists
        query.exec("ALTER TABLE tracks ADD COLUMN trackNumber INTEGER DEFAULT 0");
        query.exec("ALTER TABLE tracks ADD COLUMN discNumber INTEGER DEFAULT 0");
        query.exec("ALTER TABLE tracks ADD COLUMN totalPlayTime INTEGER DEFAULT 0");

        // Playlist tables (see Chapter 9)
        query.exec("CREATE TABLE IF NOT EXISTS playlists ("
                   "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                   "name TEXT UNIQUE)");
        query.exec("CREATE TABLE IF NOT EXISTS playlist_tracks ("
                   "playlist_id INTEGER, "
                   "track_path TEXT, "
                   "position INTEGER, "
                   "FOREIGN KEY(playlist_id) REFERENCES playlists(id))");
    }
}
```

`QStandardPaths::AppDataLocation` returns the correct platform path:
- Linux: `~/.local/share/MusicPlayer/`
- Windows: `C:\Users\<user>\AppData\Roaming\MusicPlayer\`

### Loading the Database on Startup

```cpp
void LibraryScanner::loadDatabase() {
    QVector<Track> loadedTracks;
    QSqlQuery query("SELECT title, artist, album, genre, duration, filePath, "
                    "hasCoverArt, trackNumber, discNumber, totalPlayTime FROM tracks");

    while (query.next()) {          // Iterate over rows
        Track t;
        t.title         = query.value(0).toString();
        t.artist        = query.value(1).toString();
        // ... etc
        t.totalPlayTime = query.value(9).toInt();
        loadedTracks.append(t);
    }

    if (!loadedTracks.isEmpty()) {
        // QTimer::singleShot(0, ...) defers the emit to the next event loop iteration
        // Needed because this may be called from the constructor, before anyone
        // has connected to the signal yet
        QTimer::singleShot(0, this, [this, loadedTracks]() {
            emit tracksAdded(loadedTracks);
        });
    }
}
```

### Inserting Scanned Tracks with a Transaction

```cpp
db.transaction();     // Begin a batch — much faster than individual INSERTs
QSqlQuery insertQuery(db);
insertQuery.prepare(
    "INSERT OR REPLACE INTO tracks "
    "(title, artist, album, genre, duration, filePath, hasCoverArt, "
    "trackNumber, discNumber, totalPlayTime) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, "
    "COALESCE((SELECT totalPlayTime FROM tracks WHERE filePath = ?), 0))"
);

for (const Track &t : newTracks) {
    insertQuery.bindValue(0, t.title);
    insertQuery.bindValue(1, t.artist);
    // ...
    insertQuery.bindValue(5, t.filePath);
    insertQuery.bindValue(9, t.filePath);  // For the COALESCE subquery
    insertQuery.exec();
}
db.commit();   // Commit all at once — 10x - 100x faster than commit per row
```

`INSERT OR REPLACE` means: if a row with this `filePath` already exists (UNIQUE constraint), replace it. This makes re-scanning idempotent.

The `COALESCE` subquery preserves the existing `totalPlayTime` value when a track is re-inserted during rescan. Without it, re-scanning a directory would reset all play counts to zero.

---

## 5.4 Background Threading with QtConcurrent

File scanning can take seconds for a large library. Blocking the main (UI) thread would freeze the window. `QtConcurrent::run` sends the work to a thread pool:

```cpp
void LibraryScanner::scanDirectory(const QString &directoryPath) {
    emit scanStarted();   // Tell the UI to show a progress spinner

    QtConcurrent::run([this, path]() {
        // ⚠️ This lambda runs on a BACKGROUND THREAD
        // Do NOT call Qt UI functions here
        // Do NOT emit signals directly to QML-bound slots across threads (safe here because Qt queues them)

        QDirIterator it(path,
                        QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",
                        QDir::Files, QDirIterator::Subdirectories);  // Recursive!

        int filesProcessed = 0;
        QVector<Track> newTracks;

        while (it.hasNext()) {
            QString filePath = it.next();
            // ... read tags, detect art ...
            newTracks.append(track);
            filesProcessed++;

            if (filesProcessed % 10 == 0) {
                emit scanProgress(filesProcessed);  // Update progress counter in UI
            }
        }

        // Write to database (uses a separate DB connection named "scanner_conn")
        // ...

        // When done, jump BACK to the main thread to emit the final signal
        QMetaObject::invokeMethod(this, [this, filesProcessed]() {
            loadDatabase();                          // Reload the clean database
            emit scanFinished(filesProcessed);       // Tell UI we're done
        }, Qt::QueuedConnection);                    // QueuedConnection = cross-thread safe
    });
}
```

### Why a Separate Database Connection?

SQLite is not thread-safe by default. If the background thread used the same `QSqlDatabase` connection as the main thread, it could corrupt data. The solution:

```cpp
// On background thread: create a named connection just for this thread
QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "scanner_conn");
db.setDatabaseName(dataDir + "/tracks.db");
// ... use it ...

// After the background thread finishes with it:
QSqlDatabase::removeDatabase("scanner_conn");  // Clean up the named connection
```

---

## 5.5 The `QDirIterator` — Recursive File Walk

```cpp
QDirIterator it(
    path,                                           // Root directory
    QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",  // Name filters
    QDir::Files,                                    // Only find regular files (not dirs)
    QDirIterator::Subdirectories                    // Recurse into sub-folders
);

while (it.hasNext()) {
    QString filePath = it.next();   // Gets next matching file's full path
    // process filePath...
}
```

---

## 5.6 Signal Flow of a Complete Scan

```
User clicks "Scan Directory" in UI
         ↓
  QML calls: libraryScanner.scanDirectory(folderPath)
         ↓
  LibraryScanner::scanDirectory() emits scanStarted()
         ↓ (QML shows spinner popup)
  QtConcurrent::run launches background thread
         ↓ (background thread)
  Every 10 files: emit scanProgress(count)
         ↓ (QML updates "Found N tracks..." label)
  All files processed, inserted into DB
         ↓
  QMetaObject::invokeMethod → back to main thread
         ↓
  loadDatabase() → emit tracksAdded(allTracks)
         ↓ (connected to TrackModel::setTracks)
  TrackModel updates, QML ListView refreshes
         ↓
  emit scanFinished(total)
         ↓ (QML closes spinner popup)
```

---

## 5.7 Deleted File Cleanup on Rescan

When a user deletes music files from their filesystem and then rescans the directory, those deleted tracks would previously remain in the database forever — appearing as ghost entries in the library that could no longer be played.

The scanner now automatically detects and removes these orphaned entries:

```cpp
// After inserting all found tracks into the DB, within the same transaction:
QSqlQuery cleanupQuery(db);
QString searchPath = path;
if (!searchPath.endsWith('/')) searchPath += '/';

cleanupQuery.prepare("SELECT filePath FROM tracks WHERE filePath LIKE ?");
cleanupQuery.bindValue(0, searchPath + "%");
cleanupQuery.exec();

QStringList toDelete;
while (cleanupQuery.next()) {
    QString fp = cleanupQuery.value(0).toString();
    if (!QFile::exists(fp)) {
        toDelete.append(fp);
    }
}

if (!toDelete.isEmpty()) {
    QSqlQuery deleteQuery(db);
    deleteQuery.prepare("DELETE FROM tracks WHERE filePath = ?");
    for (const QString &fp : toDelete) {
        deleteQuery.bindValue(0, fp);
        deleteQuery.exec();
    }
}
```

The cleanup is scoped to the directory being scanned (`WHERE filePath LIKE '/scanned/path/%'`). This means:
- Only tracks under the rescanned directory are checked
- Tracks from other directories remain untouched
- The `QFile::exists()` check runs on the background thread, so the UI stays responsive

---

## 5.8 Play-Time Tracking: `updatePlayTime`

The `updatePlayTime` slot is called by `AudioEngine::playTimeAccumulated` (wired in `main.cpp`) to persist listening time:

```cpp
void LibraryScanner::updatePlayTime(const QString &filePath, int secondsAdded) {
    if (secondsAdded <= 0 || filePath.isEmpty()) return;

    // Update in memory
    for (int i = 0; i < m_tracks.size(); ++i) {
        if (m_tracks[i].filePath == filePath) {
            m_tracks[i].totalPlayTime += secondsAdded;
            break;
        }
    }

    // Update in DB
    QSqlDatabase db = QSqlDatabase::database();
    if (db.isOpen()) {
        QSqlQuery query(db);
        query.prepare("UPDATE tracks SET totalPlayTime = totalPlayTime + ? WHERE filePath = ?");
        query.bindValue(0, secondsAdded);
        query.bindValue(1, filePath);
        query.exec();
    }
}
```

This dual update (memory + database) ensures:
- The in-memory model stays current for the "Most Played" filter
- The database is durable across restarts
- The `totalPlayTime` column is atomically incremented using SQL (`totalPlayTime + ?`), avoiding race conditions



<div class="page-break"></div>

<a id="06_audio_engine.md"></a>

# Chapter 6 — AudioEngine: Playing Sound with miniaudio

## 6.1 What is miniaudio?

**miniaudio** is a single-header C audio library (`third_party/miniaudio.h`). It handles:
- Audio device discovery and opening
- Audio format conversion (PCM, floating point, etc.)
- Loading and decoding audio files (mp3, flac, wav, ogg, etc.)
- A **node graph** for audio processing (equalizer, effects, mixing)
- Cross-platform: works on Linux (PulseAudio/ALSA), Windows (WASAPI), macOS (CoreAudio)

Because it's a **header-only** library, you include it in exactly **one** `.cpp` file with an implementation macro:

```cpp
// ONLY in audio_engine.cpp — defines all miniaudio function bodies
#define MINIAUDIO_IMPLEMENTATION
#include "audio_engine.h"   // which in turn includes miniaudio.h
```

All other files that use miniaudio types just `#include "audio_engine.h"` without the macro.

---

## 6.2 The AudioEngine Class Interface

```cpp
// include/audio_engine.h
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)

public:
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool  isPlaying() const;
    float position() const;   // seconds since start
    float duration() const;   // total track length in seconds
    float volume()   const;   // 0.0 = silent, 1.0 = full
    Equalizer *equalizer() const { return m_equalizer; }

public slots:
    void loadFile(const QString &filePath);
    void play();
    void pause();
    void stop();
    void setPosition(float pos);
    void setVolume(float vol);

signals:
    void playingChanged(bool isPlaying);
    void positionChanged(float position);
    void durationChanged(float duration);
    void volumeChanged(float volume);
    void playbackFinished();
    void errorOccurred(const QString &message);

private:
    ma_engine     m_engine;          // The miniaudio engine (device + graph)
    ma_sound      m_sound;           // The currently loaded audio file
    bool          m_isInitialized{false};
    bool          m_soundLoaded{false};
    float         m_volume{1.0f};
    Equalizer    *m_equalizer{nullptr};
    ma_peak_node  m_eqNodes[10];     // 10 equalizer filter nodes
    QTimer        m_progressTimer;   // Fires every 250ms to update position
};
```

---

## 6.3 Initialization: Building the Audio Pipeline

The constructor sets up the entire audio processing chain:

```cpp
AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent), m_equalizer(new Equalizer(this))
{
    // Step 1: Initialize the miniaudio engine (opens the audio device)
    ma_result result = ma_engine_init(nullptr, &m_engine);
    if (result != MA_SUCCESS) {
        qWarning() << "Failed to initialize miniaudio engine.";
        return;
    }
    m_isInitialized = true;

    // Step 2: Connect Equalizer signals so we can react to EQ changes
    connect(m_equalizer, &Equalizer::enabledChanged,  this, &AudioEngine::onEqualizerEnabledChanged);
    connect(m_equalizer, &Equalizer::bandGainChanged,  this, &AudioEngine::onEqualizerBandGainChanged);

    // Step 3: Set up the 250ms progress timer
    connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
        if (m_soundLoaded) {
            if (ma_sound_at_end(&m_sound)) {
                stop();
                emit playbackFinished();   // Auto-advance to next track
            } else if (isPlaying()) {
                emit positionChanged(position()); // Update progress bar
            }
        }
    });
    m_progressTimer.start(250);

    // Step 4: Build the 10-band EQ filter node chain
    ma_node_graph *pGraph    = ma_engine_get_node_graph(&m_engine);
    ma_uint32 channels       = ma_engine_get_channels(&m_engine);   // Usually 2 (stereo)
    ma_uint32 sampleRate     = ma_engine_get_sample_rate(&m_engine); // e.g., 44100 or 48000

    for (int i = 0; i < 10; ++i) {
        float freq = m_equalizer->bandFrequency(i);  // 31Hz, 62Hz, 125Hz, ..., 16kHz
        ma_peak_node_config config =
            ma_peak_node_config_init(channels, sampleRate, 0.0, 1.414, freq);
            //                        channels  sampleRate  gainDb  Q-factor  centerFreq
        ma_peak_node_init(pGraph, &config, nullptr, &m_eqNodes[i]);

        // Chain: connect output of node[i-1] into input of node[i]
        if (i > 0) {
            ma_node_attach_output_bus(&m_eqNodes[i-1], 0, &m_eqNodes[i], 0);
        }
    }

    // Connect last EQ node → speaker endpoint
    ma_node_attach_output_bus(&m_eqNodes[9], 0, ma_engine_get_endpoint(&m_engine), 0);
}
```

### The Audio Node Graph Visualized

```
Sound Source (ma_sound)
        │
        ▼
  [EQ Node: 31 Hz]        ← Peak filter at 31 Hz, gain = 0 dB initially
        │
        ▼
  [EQ Node: 62 Hz]
        │
        ▼
  [EQ Node: 125 Hz]
        │
       ...
        ▼
  [EQ Node: 16,000 Hz]
        │
        ▼
  Engine Endpoint (speakers / audio device)
```

Each `ma_peak_node` is a **peaking EQ filter** — it can boost or cut a narrow band of frequencies. The "Q-factor" (1.414 ≈ √2) controls how wide the boost/cut is.

---

## 6.4 Loading a File

```cpp
void AudioEngine::loadFile(const QString &filePath) {
    if (!m_isInitialized) return;

    // Unload any previously loaded sound
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);
        m_soundLoaded = false;
    }

    // Load the new file (decoded = decompressed to raw PCM in memory, ASYNC = non-blocking)
    ma_result result = ma_sound_init_from_file(
        &m_engine,
        filePath.toUtf8().constData(),       // C string path
        MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_ASYNC,
        nullptr, nullptr,
        &m_sound
    );

    if (result != MA_SUCCESS) {
        emit errorOccurred("Failed to load audio file: " + filePath);
        return;
    }

    // Redirect the sound's output to the EQ chain instead of directly to speakers
    ma_node_attach_output_bus(&m_sound, 0, &m_eqNodes[0], 0);

    m_soundLoaded = true;
    ma_sound_set_volume(&m_sound, m_volume);  // Apply current volume

    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    emit durationChanged(len);   // Tell QML the total length
    emit positionChanged(0.0f);  // Reset progress bar
}
```

**`MA_SOUND_FLAG_DECODE`**: Pre-decodes the entire audio file to raw PCM. This avoids stuttering — decoding on-the-fly while playing can cause gaps.

**`MA_SOUND_FLAG_ASYNC`**: The file loading starts on a background thread immediately. The sound won't be ready instantly, but the UI thread isn't blocked.

---

## 6.5 Play, Pause, Stop

```cpp
void AudioEngine::play() {
    if (!m_soundLoaded) return;
    ma_sound_start(&m_sound);       // Begin audio output
    emit playingChanged(true);      // Update the Play/Pause button icon in QML
}

void AudioEngine::pause() {
    if (!m_soundLoaded) return;
    ma_sound_stop(&m_sound);        // Pause (keeps position)
    emit playingChanged(false);
}

void AudioEngine::stop() {
    if (m_soundLoaded) {
        ma_sound_stop(&m_sound);
        ma_sound_seek_to_pcm_frame(&m_sound, 0);  // Rewind to beginning
        emit playingChanged(false);
    }
    emit positionChanged(0.0f);     // Reset progress bar to 0
}
```

---

## 6.6 Seeking — Jumping to a Position

```cpp
void AudioEngine::setPosition(float pos) {
    if (!m_soundLoaded) return;
    if (pos < 0.0f) pos = 0.0f;

    float len = duration();
    if (len > 0.0f && pos >= len) {
        emit playbackFinished();  // Seeked past the end — treat as finished
        return;
    }

    // Convert seconds → PCM frame number
    // PCM frame = one sample per channel. At 44100 Hz, 1 second = 44100 frames.
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    ma_uint64 targetFrame = static_cast<ma_uint64>(pos * sampleRate);
    ma_sound_seek_to_pcm_frame(&m_sound, targetFrame);
    emit positionChanged(pos);
}
```

### Why PCM Frames?

miniaudio works in **PCM frames** (Pulse Code Modulation samples), not seconds. To seek to 30 seconds into a 44100 Hz song:
```
targetFrame = 30 * 44100 = 1,323,000
```

---

## 6.7 Querying State

```cpp
bool AudioEngine::isPlaying() const {
    if (!m_soundLoaded) return false;
    return ma_sound_is_playing(&m_sound);  // Ask miniaudio directly
}

float AudioEngine::position() const {
    if (!m_soundLoaded) return 0.0f;
    float cursor = 0.0f;
    ma_sound_get_cursor_in_seconds(&m_sound, &cursor);
    return cursor;
}

float AudioEngine::duration() const {
    if (!m_soundLoaded) return 0.0f;
    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    return len;
}

float AudioEngine::volume() const { return m_volume; }
```

---

## 6.8 Applying EQ Changes Dynamically

When the user moves an EQ slider, `Equalizer::setBandGain(index, gainDb)` is called, which emits `bandGainChanged`. `AudioEngine` catches this:

```cpp
void AudioEngine::onEqualizerBandGainChanged(int index, float gainDb) {
    if (index < 0 || index >= 10) return;

    ma_uint32 channels   = ma_engine_get_channels(&m_engine);
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    float freq           = m_equalizer->bandFrequency(index);

    // If EQ is globally disabled, apply 0 dB gain (flat response) regardless
    float actualGain = m_equalizer->isEnabled() ? gainDb : 0.0f;

    // Reinitialize the specific peak node with the new gain
    ma_peak2_config config = ma_peak2_config_init(
        ma_format_f32, channels, sampleRate, actualGain, 1.414, freq
    );
    ma_peak_node_reinit((const ma_peak_config *)&config, &m_eqNodes[index]);
}
```

`ma_peak_node_reinit` rebuilds the filter coefficients on-the-fly. The audio pipeline adjusts **instantly without any clicking or popping** because miniaudio smoothly transitions the coefficients.

---

## 6.9 Cleanup

```cpp
AudioEngine::~AudioEngine() {
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);     // Release audio file resources
    }
    if (m_isInitialized) {
        ma_engine_uninit(&m_engine);   // Close audio device
    }
}
```

Always clean up in reverse order of initialization. The `ma_peak_node` instances are attached to the node graph, which is part of `m_engine`, so they are cleaned up when `ma_engine_uninit` is called.


<div class="page-break"></div>

<a id="07_equalizer.md"></a>

# Chapter 7 — The Equalizer: Presets and QSettings

## 7.1 What is a Graphic Equalizer?

A **10-band graphic equalizer** lets users boost or cut 10 specific frequency bands:

| Band | Frequency | What it affects |
|------|-----------|-----------------|
| 1 | 31 Hz | Sub-bass (rumble, kick drum body) |
| 2 | 62 Hz | Bass (bass guitar, bass drum) |
| 3 | 125 Hz | Upper bass / low midrange (warmth) |
| 4 | 250 Hz | Low midrange (body of vocals) |
| 5 | 500 Hz | Midrange (nasal quality) |
| 6 | 1000 Hz | Upper midrange (presence) |
| 7 | 2000 Hz | High midrange (edge/bite) |
| 8 | 4000 Hz | Presence (clarity, articulation) |
| 9 | 8000 Hz | High frequency (air, brightness) |
| 10 | 16000 Hz | Ultra-high (shimmer, sizzle) |

Each band's gain can be adjusted from **-12 dB** (quieter) to **+12 dB** (louder) in that frequency range.

---

## 7.2 The Equalizer Class

```cpp
// include/equalizer.h
class Equalizer : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit Equalizer(QObject *parent = nullptr);

    bool isEnabled() const;

    Q_INVOKABLE int          bandCount() const;           // Returns 10
    Q_INVOKABLE float        bandGain(int index) const;   // -12.0 to +12.0 dB
    Q_INVOKABLE float        bandFrequency(int index) const; // e.g., 31.25 Hz

    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);

public slots:
    void setEnabled(bool enabled);
    void setBandGain(int index, float gainDb);

signals:
    void enabledChanged(bool enabled);
    void bandGainChanged(int index, float gainDb);

private:
    bool           m_enabled{false};
    QVector<float> m_frequencies;   // [31.25, 62.5, 125.0, ..., 16000.0]
    QVector<float> m_gains;         // [0.0, 0.0, 0.0, ..., 0.0] — all flat initially
};
```

---

## 7.3 Initialization

```cpp
Equalizer::Equalizer(QObject *parent) : QObject(parent), m_enabled(false) {
    // Standard ISO 1/3-octave equalizer center frequencies (starting at 31.25 Hz)
    m_frequencies = {31.25f, 62.5f, 125.0f, 250.0f, 500.0f,
                     1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
    m_gains.fill(0.0f, m_frequencies.size()); // All bands start at 0 dB (flat)
}
```

---

## 7.4 Band Gain: Read and Write

```cpp
float Equalizer::bandGain(int index) const {
    if (index >= 0 && index < m_gains.size())
        return m_gains[index];
    return 0.0f;
}

void Equalizer::setBandGain(int index, float gainDb) {
    // Clamp to -12 to +12 dB range — hard limit
    float clampedGain = fmaxf(-12.0f, fminf(12.0f, gainDb));

    if (index >= 0 && index < m_gains.size()) {
        if (m_gains[index] != clampedGain) {   // Only emit if actually changed
            m_gains[index] = clampedGain;
            emit bandGainChanged(index, clampedGain);  // AudioEngine catches this
        }
    }
}
```

`fmaxf` and `fminf` are C standard library `<math.h>` functions for `float` clamping:
```
fminf(12.0f, 15.0f) → 12.0f   (clip to max)
fmaxf(-12.0f, -20.0f) → -12.0f (clip to min)
```

---

## 7.5 Factory Presets

Built-in presets are defined as a static function (not a member variable) to avoid initialization order issues:

```cpp
static QMap<QString, QVector<float>> getFactoryPresets() {
    QMap<QString, QVector<float>> presets;
    //                              31  62  125 250 500 1k  2k  4k  8k  16k
    presets["Flat"]         = {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 };
    presets["Acoustic"]     = {  5,  5,  4,  1,  1,  1,  3,  4,  3,  2 };
    presets["Bass Booster"] = {  6,  5,  4,  2,  1,  0,  0,  0,  0,  0 };
    presets["Classical"]    = {  5,  4,  3,  2, -1, -1,  0,  2,  3,  4 };
    presets["Dance"]        = {  4,  6,  5,  0,  2,  3,  5,  4,  3,  0 };
    presets["Electronic"]   = {  4,  3,  1, -2, -3,  1,  3,  5,  4,  5 };
    presets["Pop"]          = { -1, -1,  0,  2,  4,  4,  2,  0, -1, -2 };
    presets["Rock"]         = {  5,  4,  3,  1, -1, -1,  1,  2,  3,  4 };
    return presets;
}
```

`QMap<K, V>` is Qt's sorted associative container (like `std::map`). Keys are sorted alphabetically, so `getPresetNames()` returns a naturally sorted list.

---

## 7.6 Custom Presets with QSettings

`QSettings` is Qt's cross-platform way to store user preferences. On Linux it writes INI files to `~/.config/ModernMusicPlayer/EqualizerPresets.ini`. On Windows it uses the registry.

### Saving a Custom Preset

```cpp
void Equalizer::saveCustomPreset(const QString &name) {
    if (name.isEmpty() || getFactoryPresets().contains(name))
        return;  // Can't overwrite factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);          // Creates a [name] section in the INI
    settings.beginWriteArray("bands");  // Creates an indexed list
    for (int i = 0; i < m_gains.size(); ++i) {
        settings.setArrayIndex(i);
        settings.setValue("gain", m_gains[i]);
    }
    settings.endArray();
    settings.endGroup();
}
```

The resulting INI file looks like:
```ini
[MyPreset]
bands\size=10
bands\1\gain=6
bands\2\gain=4
...
```

### Loading a Preset (Factory or Custom)

```cpp
void Equalizer::loadPreset(const QString &name) {
    // Check factory presets first
    auto factory = getFactoryPresets();
    if (factory.contains(name)) {
        const auto &gains = factory[name];
        for (int i = 0; i < gains.size() && i < m_gains.size(); ++i) {
            setBandGain(i, gains[i]);   // Each call emits bandGainChanged → AudioEngine updates
        }
        return;
    }

    // Otherwise load from QSettings (user-saved)
    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    if (settings.childGroups().contains(name)) {
        settings.beginGroup(name);
        int size = settings.beginReadArray("bands");
        for (int i = 0; i < size && i < m_gains.size(); ++i) {
            settings.setArrayIndex(i);
            float gain = settings.value("gain").toFloat();
            setBandGain(i, gain);
        }
        settings.endArray();
        settings.endGroup();
    }
}
```

### Deleting a Custom Preset

```cpp
void Equalizer::deleteCustomPreset(const QString &name) {
    if (!isCustomPreset(name)) return;  // Safety: can't delete factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);
    settings.remove("");   // Empty string = remove everything under this group
    settings.endGroup();
}
```

---

## 7.7 Getting All Preset Names (Factory + Custom)

```cpp
QStringList Equalizer::getPresetNames() const {
    QStringList names = getFactoryPresets().keys();   // ["Acoustic", "Bass Booster", ...]

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    names.append(settings.childGroups());             // Add custom preset names

    names.removeDuplicates();  // Safety: no duplicates
    names.sort();              // Alphabetical order

    return names;
}
```

In QML, this method is called to populate the preset dropdown:
```qml
ComboBox {
    model: audioEngine.equalizer.getPresetNames()
    onActivated: audioEngine.equalizer.loadPreset(currentText)
}
```

---

## 7.8 The Enable/Disable Toggle

When the user turns the EQ on or off:
```cpp
void Equalizer::setEnabled(bool enabled) {
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged(m_enabled);
    }
}
```

`AudioEngine::onEqualizerEnabledChanged` catches this and re-applies all bands:
```cpp
void AudioEngine::onEqualizerEnabledChanged(bool enabled) {
    for (int i = 0; i < 10; ++i) {
        onEqualizerBandGainChanged(i, m_equalizer->bandGain(i));
        // This function reads m_equalizer->isEnabled() to decide whether to
        // apply the stored gain or force 0 dB
    }
}
```

If EQ is disabled, `actualGain = 0.0f` regardless of stored values — the filter is flat.


<div class="page-break"></div>

<a id="08_cover_art.md"></a>

# Chapter 8 — CoverArtProvider: On-Demand Album Art

## 8.1 The Problem

QML's `Image` element can display images from files or URLs. But album art is **embedded inside audio files** — it's not a separate `.jpg` on disk. We need a way for QML to request album art using a track's file path and get back a `QImage`.

Qt solves this with `QQuickImageProvider` — a class you register with the QML engine. When QML requests an image with the `image://` scheme, Qt routes the request to your provider.

---

## 8.2 How the URL Scheme Works

```qml
// In QML — request album art for a specific track:
Image {
    source: "image://musiccover/" + track.filePath
    //       ↑ scheme+id  ↑ provider name  ↑ the "id" passed to requestImage()
}
```

The URL `image://musiccover/home/user/music/song.mp3` tells Qt:
- Use the image provider registered as `"musiccover"`
- Pass `"/home/user/music/song.mp3"` as the `id` parameter

---

## 8.3 The CoverArtProvider Class

```cpp
// include/cover_art_provider.h
#include <QQuickImageProvider>
#include <QImage>

class CoverArtProvider : public QQuickImageProvider {
public:
    CoverArtProvider();
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;

    static QImage extractImageFromTag(const QString &filePath);
};
```

Note: `CoverArtProvider` does **not** inherit from `QObject`. It inherits from `QQuickImageProvider` instead. It therefore has **no signals or slots** and does not use `Q_OBJECT`.

The `static extractImageFromTag()` method was added so that other C++ classes (specifically `MprisManager`, see Chapter 10) can extract album art from audio files without needing access to the QML image provider system.

---

## 8.4 Full Implementation

The `requestImage` method now delegates the actual TagLib extraction to the static helper:

```cpp
QImage CoverArtProvider::requestImage(const QString &id, QSize *size,
                                       const QSize &requestedSize)
{
    QString filePath = id;   // id is exactly the path after "image://musiccover/"
    QImage image;

    // Helper lambda: scale and report size before returning
    auto returnImage = [&]() {
        if (size) *size = image.size();
        if (requestedSize.width() > 0 && requestedSize.height() > 0) {
            image = image.scaled(requestedSize, Qt::KeepAspectRatio,
                                 Qt::SmoothTransformation);
        }
        return image;
    };

    // Delegate to the static extraction method
    image = extractImageFromTag(filePath);

    // Fallback: if no art found (or null image), return a dark placeholder
    if (image.isNull()) {
        image = QImage(200, 200, QImage::Format_RGB32);
        image.fill(QColor("#33333b"));  // dark neutral gray
    }

    return returnImage();
}
```

---

## 8.5 The Static Extraction Method

`extractImageFromTag` contains the format-specific TagLib logic to pull cover art from audio files. It returns a `QImage` — either the decoded art, or a null `QImage` if none was found:

```cpp
QImage CoverArtProvider::extractImageFromTag(const QString &filePath) {
    QImage image;

    // --- MP3: Read APIC (Attached Picture) frame from ID3v2 tag ---
    if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
        TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
        if (mpegFile.hasID3v2Tag()) {
            TagLib::ID3v2::Tag *id3v2tag = mpegFile.ID3v2Tag();
            if (id3v2tag) {
                auto frameList = id3v2tag->frameListMap()["APIC"];
                if (!frameList.isEmpty()) {
                    auto frame = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(
                        frameList.front());
                    image.loadFromData(
                        (const uchar *)frame->picture().data(),
                        frame->picture().size()
                    );
                }
            }
        }
    }
    // --- FLAC: Read from FLAC picture list ---
    else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
        TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
        if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) {
            auto picture = flacFile.pictureList().front();
            image.loadFromData(
                (const uchar *)picture->data().data(),
                picture->data().size()
            );
        }
    }
    // --- M4A: Read "covr" item from MP4 tag ---
    else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
        TagLib::MP4::File mp4File(filePath.toUtf8().constData());
        if (mp4File.isValid() && mp4File.tag()) {
            auto itemList = mp4File.tag()->itemMap();
            if (itemList.contains("covr")) {
                auto covrList = itemList["covr"].toCoverArtList();
                if (!covrList.isEmpty()) {
                    auto picture = covrList.front();
                    image.loadFromData(
                        (const uchar *)picture.data().data(),
                        picture.data().size()
                    );
                }
            }
        }
    }

    return image;  // Returns null QImage if no art was found
}
```

This method is `static` so it can be called without an instance of `CoverArtProvider`:
```cpp
// From MprisManager (Chapter 10):
QImage cover = CoverArtProvider::extractImageFromTag(filePath);
```

The key design decision: `extractImageFromTag` does **not** apply a fallback placeholder. Only the QML-facing `requestImage` method does that. This way, callers like `MprisManager` can distinguish "no art found" (null image) from a real image and handle it accordingly.

---

## 8.6 Registering the Provider in main.cpp

```cpp
QQmlApplicationEngine engine;
engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);
```

This registers the provider under the name `"musiccover"`, which matches the `image://musiccover/` URL scheme in QML. After this line, any QML `Image` with a matching source URL will automatically call `CoverArtProvider::requestImage()`.

---

## 8.7 Optimizing: sourceSize in QML

In the queue drawer and track list, album art is shown at small sizes (40×40 px). Without a `sourceSize`, Qt would load the full 500×500 JPEG and scale it in the GPU. With it:

```qml
Image {
    source: "image://musiccover/" + modelData.filePath
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40
    fillMode: Image.PreserveAspectCrop
    asynchronous: true          // Load on background thread so list stays smooth
    sourceSize: Qt.size(100, 100) // Ask provider to pre-scale to 100x100
}
```

`sourceSize` is passed as `requestedSize` to `requestImage()`. The `returnImage` lambda scales the decoded image to this size before returning — saving GPU memory and improving render performance.



<div class="page-break"></div>

<a id="09_playlist_system.md"></a>

# Chapter 9 — The Playlist System

## 9.1 What the Playlist System Does

The playlist system allows users to:
1. Create named playlists
2. Add tracks from the library to playlists
3. Remove individual tracks from a playlist
4. Reorder tracks within a playlist via drag-and-drop
5. Sort playlist contents by title, artist, or track number
6. Delete entire playlists

All playlist data is stored in the same SQLite database as the music library (see Chapter 5), using two dedicated tables.

---

## 9.2 SQLite Schema

### The `playlists` Table

```sql
CREATE TABLE IF NOT EXISTS playlists (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE
);
```

Each playlist is simply a named entry. The `UNIQUE` constraint prevents duplicate names.

### The `playlist_tracks` Table

```sql
CREATE TABLE IF NOT EXISTS playlist_tracks (
    playlist_id INTEGER,
    track_path  TEXT,
    position    INTEGER,
    FOREIGN KEY(playlist_id) REFERENCES playlists(id)
);
```

Tracks belong to a playlist via `playlist_id`. The `position` column maintains ordering — this is what allows manual reordering without changing the data itself. The `track_path` stores the absolute file path, linking back to the `tracks.filePath` column.

---

## 9.3 PlaylistManager — The C++ Backend

### Header: `include/playlist_manager.h`

```cpp
class PlaylistManager : public QObject {
    Q_OBJECT
public:
    explicit PlaylistManager(QObject *parent = nullptr);

    Q_INVOKABLE QStringList getPlaylists() const;
    Q_INVOKABLE QStringList getPlaylistTracks(const QString &playlistName) const;

    Q_INVOKABLE void createPlaylist(const QString &name);
    Q_INVOKABLE void deletePlaylist(const QString &name);
    Q_INVOKABLE void addTrack(const QString &playlistName, const QString &trackPath);
    Q_INVOKABLE void removeTrack(const QString &playlistName, const QString &trackPath);
    Q_INVOKABLE void moveTrack(const QString &playlistName, int fromIndex, int toIndex);
    Q_INVOKABLE void sortPlaylist(const QString &playlistName, const QString &sortType);

signals:
    void playlistsChanged();
    void playlistTracksChanged(const QString &playlistName);

private:
    int getPlaylistId(const QString &name) const;
};
```

Every public method is `Q_INVOKABLE`, making them callable directly from QML:
```qml
playlistManager.createPlaylist("Road Trip Jams")
playlistManager.addTrack("Road Trip Jams", track.filePath)
```

### The Two Signals

| Signal | Emitted When | QML Response |
|---|---|---|
| `playlistsChanged()` | A playlist is created or deleted | PlaylistsView refreshes its grid |
| `playlistTracksChanged(name)` | A track is added, removed, moved, or sorted | PlaylistDetailsView refreshes its track list |

---

## 9.4 Key Operations

### Creating a Playlist

```cpp
void PlaylistManager::createPlaylist(const QString &name) {
    if (name.isEmpty()) return;
    QSqlQuery query;
    query.prepare("INSERT INTO playlists (name) VALUES (?)");
    query.bindValue(0, name);
    if (query.exec()) {
        emit playlistsChanged();
    }
}
```

### Adding a Track (With Duplicate Prevention)

```cpp
void PlaylistManager::addTrack(const QString &playlistName, const QString &trackPath) {
    int pid = getPlaylistId(playlistName);
    if (pid == -1) return;

    // Check if already exists
    QSqlQuery checkQuery;
    checkQuery.prepare("SELECT position FROM playlist_tracks WHERE playlist_id = ? AND track_path = ?");
    checkQuery.bindValue(0, pid);
    checkQuery.bindValue(1, trackPath);
    if (checkQuery.exec() && checkQuery.next()) return;  // Already in playlist

    // Find next position
    int maxPos = 0;
    QSqlQuery posQuery;
    posQuery.prepare("SELECT MAX(position) FROM playlist_tracks WHERE playlist_id = ?");
    posQuery.bindValue(0, pid);
    if (posQuery.exec() && posQuery.next())
        maxPos = posQuery.value(0).toInt() + 1;

    QSqlQuery query;
    query.prepare("INSERT INTO playlist_tracks (playlist_id, track_path, position) VALUES (?, ?, ?)");
    query.bindValue(0, pid);
    query.bindValue(1, trackPath);
    query.bindValue(2, maxPos);
    if (query.exec()) emit playlistTracksChanged(playlistName);
}
```

### Reordering Tracks

Track reordering works by fetching all paths in order, performing an in-memory list move, then rewriting all positions in a transaction:

```cpp
void PlaylistManager::moveTrack(const QString &playlistName, int fromIndex, int toIndex) {
    QStringList tracks = getPlaylistTracks(playlistName);
    QString track = tracks.takeAt(fromIndex);
    tracks.insert(toIndex, track);

    // Rewrite all positions in a transaction
    db.transaction();
    // DELETE all rows for this playlist
    // INSERT them back with new position values
    db.commit();
    emit playlistTracksChanged(playlistName);
}
```

### Sorting a Playlist

Sorting uses a SQL `JOIN` with the `tracks` table to access metadata:

```cpp
// Sort by title:
"SELECT pt.track_path FROM playlist_tracks pt "
"JOIN tracks t ON pt.track_path = t.filePath "
"WHERE pt.playlist_id = ? ORDER BY t.title ASC"

// Sort by artist:
"... ORDER BY t.artist ASC, t.title ASC"

// Sort by track number:
"... ORDER BY t.trackNumber ASC, t.title ASC"
```

The joined result is then written back with updated position values, just like `moveTrack`.

---

## 9.5 QML Views

### PlaylistsView.qml — The Playlist Grid

Displays a grid of playlist tiles. Each tile shows the playlist name and can be right-clicked for a context menu (rename, delete). Clicking a tile navigates to `PlaylistDetailsView`.

### PlaylistDetailsView.qml — Track List

Shows all tracks in a single playlist with:
- Track metadata (title, artist, cover art)
- "Add Content" button to open the add-to-playlist popup
- Track removal on right-click
- Reordering support

### PlaylistPopup.qml — Centralized Popups

Contains three popups managed as a single component:

| Popup | Purpose |
|---|---|
| `addPopup` | Shows all library tracks with "Add" buttons next to each |
| `createPlaylistPopup` | Text field + "Create" button to make a new playlist |
| `playlistMenuPopup` | Right-click context menu (Open, Add Songs, Rename, Delete) |

These are instantiated inside `AppPopups.qml` and exposed globally via aliases in `main.qml` (see Chapter 19).

---

## 9.6 Signal Flow: Creating and Populating a Playlist

```
User clicks "Create" button in PlaylistsView
         ↓
QML calls: playlistManager.createPlaylist("My Playlist")
         ↓
PlaylistManager::createPlaylist() inserts into DB
         ↓
emit playlistsChanged()
         ↓
PlaylistsView.qml listens for playlistsChanged → refreshes grid
         ↓
User clicks tile → opens PlaylistDetailsView
         ↓
User clicks "Add Content" → opens addPopup
         ↓
User clicks "Add" next to a track
         ↓
QML calls: playlistManager.addTrack("My Playlist", track.filePath)
         ↓
emit playlistTracksChanged("My Playlist")
         ↓
PlaylistDetailsView refreshes its track list
```


<div class="page-break"></div>

<a id="10_mpris_integration.md"></a>

# Chapter 10 — MPRIS2 Integration: Desktop Media Controls

## 10.1 What Is MPRIS?

**MPRIS** (Media Player Remote Interfacing Specification) is a D-Bus protocol that lets Linux desktop environments control media players. When you see the media widget in KDE Plasma's system tray — showing album art, track title, and play/pause/next buttons — that widget is talking to the player via MPRIS over D-Bus.

Without MPRIS:
- The OS doesn't know any audio is playing
- Hardware media keys (play/pause, next, previous) don't work
- Lock screen widgets can't show "Now Playing" information
- KDE Plasma's media integration panel is empty

---

## 10.2 The D-Bus Service

MPRIS requires registering a D-Bus service with a specific naming convention:

```cpp
QDBusConnection dbus = QDBusConnection::sessionBus();
dbus.registerObject("/org/mpris/MediaPlayer2", this,
                    QDBusConnection::ExportAdaptors);
dbus.registerService("org.mpris.MediaPlayer2.MLMPlayer");
```

The service name must begin with `org.mpris.MediaPlayer2.` followed by a unique player name. The object is registered at the standard MPRIS path `/org/mpris/MediaPlayer2`.

---

## 10.3 Architecture: Manager + Two Adaptors

The MPRIS implementation uses Qt's D-Bus adaptor pattern:

```
┌──────────────────────────────────────────────────────────────┐
│                   MprisManager (QObject)                      │
│   - Holds state: m_playbackStatus, m_metadata, m_position    │
│   - Has slots: setPlaybackStatus(), setMetadata()            │
│   - Has signals: playRequested(), pauseRequested(), etc.     │
│                                                              │
│   ┌─────────────────────────┐ ┌────────────────────────────┐ │
│   │   MprisRootAdaptor      │ │   MprisPlayerAdaptor       │ │
│   │   (QDBusAbstractAdaptor)│ │   (QDBusAbstractAdaptor)   │ │
│   │                         │ │                            │ │
│   │   Interface:            │ │   Interface:               │ │
│   │   org.mpris.             │ │   org.mpris.               │ │
│   │     MediaPlayer2        │ │     MediaPlayer2.Player    │ │
│   │                         │ │                            │ │
│   │   Properties:           │ │   Properties:              │ │
│   │   - Identity            │ │   - PlaybackStatus         │ │
│   │   - CanQuit             │ │   - Metadata               │ │
│   │   - CanRaise            │ │   - Position               │ │
│   │   - DesktopEntry        │ │   - CanGoNext/Previous     │ │
│   │                         │ │   - CanPlay/Pause/Seek     │ │
│   │   Methods:              │ │                            │ │
│   │   - Quit()              │ │   Methods:                 │ │
│   │   - Raise()             │ │   - Play(), Pause()        │ │
│   └─────────────────────────┘ │   - Next(), Previous()     │ │
│                               │   - Seek(), SetPosition()  │ │
│                               └────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

Qt's `QDBusAbstractAdaptor` automatically exports `Q_PROPERTY` declarations and `Q_SLOT` methods over D-Bus. The `Q_CLASSINFO("D-Bus Interface", "...")` macro maps the class to the correct MPRIS interface name.

---

## 10.4 The Root Adaptor

```cpp
class MprisRootAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ CanQuit)
    Q_PROPERTY(bool CanRaise READ CanRaise)
    Q_PROPERTY(bool HasTrackList READ HasTrackList)
    Q_PROPERTY(QString Identity READ Identity)
    Q_PROPERTY(QString DesktopEntry READ DesktopEntry)

public:
    bool CanQuit() const { return false; }
    bool CanRaise() const { return false; }
    bool HasTrackList() const { return false; }
    QString Identity() const { return "MLM Player"; }
    QString DesktopEntry() const { return "MusicPlayer"; }

public slots:
    void Quit() {}
    void Raise() {}
};
```

The `DesktopEntry` property must match the `.desktop` file name (without the `.desktop` extension). This is how the OS associates the D-Bus service with the correct application icon.

---

## 10.5 The Player Adaptor

```cpp
class MprisPlayerAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ PlaybackStatus)
    Q_PROPERTY(QVariantMap Metadata READ Metadata)
    Q_PROPERTY(qlonglong Position READ Position)
    // ... CanGoNext, CanPlay, CanPause, CanSeek, etc.

public:
    QString PlaybackStatus() const { return m_manager->m_playbackStatus; }
    QVariantMap Metadata() const { return m_manager->m_metadata; }
    qlonglong Position() const {
        return static_cast<qlonglong>(m_manager->m_positionSeconds) * 1000000LL;
    }

public slots:
    void Play() { emit m_manager->playRequested(); }
    void Pause() { emit m_manager->pauseRequested(); }
    void PlayPause() { emit m_manager->playPauseRequested(); }
    void Next() { emit m_manager->nextRequested(); }
    void Previous() { emit m_manager->previousRequested(); }
    void Seek(qlonglong Offset) {
        emit m_manager->seekRequested(m_manager->m_positionSeconds + Offset / 1000000LL);
    }
    void SetPosition(const QDBusObjectPath &, qlonglong Position) {
        emit m_manager->seekRequested(Position / 1000000LL);
    }
};
```

**Important:** MPRIS uses **microseconds** for position and length. Our `AudioEngine` uses **seconds**. The conversions (`* 1000000LL` and `/ 1000000LL`) happen at the MPRIS boundary.

---

## 10.6 Broadcasting Metadata with Cover Art

When a track starts playing, QML calls `mprisManager.setMetadata(...)`. The implementation constructs a D-Bus-compliant metadata map and extracts cover art:

```cpp
void MprisManager::setMetadata(const QString &id, const QString &title,
                               const QString &artist, const QString &album,
                               const QString &artUrl, int lengthSeconds) {
    QVariantMap metadata;
    metadata["mpris:trackid"] = QVariant::fromValue(
        QDBusObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack"));
    metadata["xesam:title"]  = title;
    metadata["xesam:artist"] = QStringList() << artist;
    metadata["xesam:album"]  = album;

    // Cover art extraction
    QString finalArtUrl = artUrl;
    if (finalArtUrl.isEmpty() && !id.isEmpty()) {
        QImage cover = CoverArtProvider::extractImageFromTag(id);
        if (!cover.isNull()) {
            QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
            QString hash = QCryptographicHash::hash(id.toUtf8(), QCryptographicHash::Md5).toHex();
            QString tempFile = tempDir + "/mlm_mpris_cover_" + hash + ".png";
            cover.save(tempFile, "PNG");
            finalArtUrl = "file://" + tempFile;
        }
    }

    if (!finalArtUrl.isEmpty()) {
        metadata["mpris:artUrl"] = finalArtUrl;
    }
    metadata["mpris:length"] = static_cast<qlonglong>(lengthSeconds) * 1000000LL;

    m_metadata = metadata;
    updateProperties("org.mpris.MediaPlayer2.Player", {{"Metadata", m_metadata}});
}
```

### Why Per-Track Hash Filenames?

Desktop environments (especially KDE Plasma) **cache cover art aggressively** based on the `mpris:artUrl` value. If every track's art is saved to the same filename (`/tmp/mlm_cover.png`), the URL doesn't change between tracks, and Plasma shows stale artwork.

The solution: generate a unique filename per track using an MD5 hash of the file path:
```
/tmp/mlm_mpris_cover_38f29e4a1b7c...png
```

When the track changes, a new URL is emitted → Plasma drops its cache → fresh art appears.

---

## 10.7 Property Change Notifications

D-Bus properties don't auto-notify. We must manually emit the `org.freedesktop.DBus.Properties.PropertiesChanged` signal:

```cpp
void MprisManager::updateProperties(const QString &interface,
                                    const QVariantMap &changed) {
    QDBusMessage msg = QDBusMessage::createSignal(
        "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties",
        "PropertiesChanged");
    msg << interface << changed << QStringList();
    QDBusConnection::sessionBus().send(msg);
}
```

The third argument (empty `QStringList`) is the list of invalidated properties — we always send the new values directly, so this is empty.

---

## 10.8 Signal Flow: QML → MPRIS → Desktop

```
Track starts playing in QML
         ↓
QML calls: mprisManager.setMetadata(track.filePath, track.title, track.artist, ...)
         ↓
MprisManager::setMetadata():
  - Builds QVariantMap with xesam:title, xesam:artist, xesam:album
  - Extracts cover art via CoverArtProvider::extractImageFromTag()
  - Saves art to /tmp/mlm_mpris_cover_<hash>.png
  - Sets mpris:artUrl = "file:///tmp/mlm_mpris_cover_<hash>.png"
  - Emits PropertiesChanged over D-Bus
         ↓
KDE Plasma receives PropertiesChanged
         ↓
Media widget updates: shows title, artist, album art
```

```
User presses Play/Pause media key on keyboard
         ↓
KDE Plasma sends D-Bus call to org.mpris.MediaPlayer2.Player.PlayPause()
         ↓
MprisPlayerAdaptor::PlayPause() → emit m_manager->playPauseRequested()
         ↓
(Wired in main.cpp) → audioEngine.play() or audioEngine.pause()
         ↓
QML receives isPlaying change → updates UI
```

---

## 10.9 Testing MPRIS

```bash
# Check if the service is registered
qdbus org.mpris.MediaPlayer2.MLMPlayer

# Read current metadata
qdbus org.mpris.MediaPlayer2.MLMPlayer /org/mpris/MediaPlayer2 \
      org.freedesktop.DBus.Properties.Get \
      org.mpris.MediaPlayer2.Player Metadata

# Send a PlayPause command
qdbus org.mpris.MediaPlayer2.MLMPlayer /org/mpris/MediaPlayer2 \
      org.mpris.MediaPlayer2.Player.PlayPause
```


<div class="page-break"></div>

<a id="11_gamepad_control.md"></a>

# Chapter 11 — Gamepad Control

## 11.1 What the Gamepad System Does

The gamepad system allows users to navigate the entire application using a game controller (Xbox, PlayStation, or any SDL2-compatible gamepad). This enables a "lean-back" or "couch mode" experience where the keyboard and mouse are not required.

Features:
- Full D-pad and left-stick navigation through library grids, queues, and menus
- A/B/X/Y button mapping for confirm, back, and context actions
- Trigger-based volume control (hold L/R trigger to decrease/increase volume)
- Automatic hot-plug detection (connect/disconnect a controller at any time)
- Zone-based input routing so buttons do different things depending on which UI element is active

---

## 11.2 Architecture: C++ Polling + QML Routing

The system is split into two layers:

```
┌─────────────────────────────────────────────────────────┐
│  GamepadController (C++ / SDL2)                          │
│  - Initializes SDL2 gamepad subsystem                    │
│  - Polls for button/axis events every 16ms (~60 Hz)      │
│  - Emits Qt signals: buttonA(), dpadUp(), volumeChange() │
│  - Handles hot-plug (device added/removed)               │
└──────────────────────────┬──────────────────────────────┘
                           │ Qt signals
┌──────────────────────────▼──────────────────────────────┐
│  GamepadControl.qml (QML)                                │
│  - Receives signals via Connections { target: gamepad }  │
│  - Maintains a "currentZone" string                      │
│  - Routes each signal to the correct UI action           │
│    based on which zone is currently active                │
└─────────────────────────────────────────────────────────┘
```

---

## 11.3 The C++ Layer: `GamepadController`

### Initialization

```cpp
GamepadController::GamepadController(QObject *parent) : QObject(parent) {
    SDL_Init(SDL_INIT_GAMECONTROLLER);

    // Start a 16ms poll timer (~60 Hz)
    connect(&m_pollTimer, &QTimer::timeout, this, &GamepadController::pollEvents);
    m_pollTimer.start(16);
}
```

SDL2 does not use callbacks like Qt — it uses a polling model. We bridge this with a `QTimer` that calls `pollEvents()` every frame.

### Button and Axis Signals

The controller emits one signal per logical input:

| Signal | Triggered By |
|---|---|
| `buttonA()` | A / Cross button |
| `buttonB()` | B / Circle button |
| `buttonX()` | X / Square button |
| `buttonY()` | Y / Triangle button |
| `dpadUp/Down/Left/Right()` | D-pad directions |
| `leftStickUp/Down/Left/Right()` | Left analog stick (with deadzone) |
| `triggerLeft/Right()` | L2/R2 triggers |
| `leftShoulder/rightShoulder()` | L1/R1 bumpers |
| `buttonStart/Select()` | Start/Select (Menu/View) |
| `volumeChange(delta)` | Continuous trigger hold |

### Deadzone Handling

Analog sticks produce continuous values even when "at rest" due to hardware imprecision. A deadzone of 8000 (out of 32768 max) prevents phantom inputs:

```cpp
int m_deadzone = 8000;

// In pollEvents():
Sint16 axisX = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTX);
if (axisX > m_deadzone && !m_axisX_positive) {
    m_axisX_positive = true;
    emit leftStickRight();
} else if (axisX < m_deadzone) {
    m_axisX_positive = false;
}
```

The boolean tracking (`m_axisX_positive`) ensures the signal fires once when the stick crosses the threshold, not continuously every 16ms.

### Hot-Plug Detection

```cpp
case SDL_CONTROLLERDEVICEADDED:
    handleDeviceAdded(event.cdevice.which);
    break;
case SDL_CONTROLLERDEVICEREMOVED:
    handleDeviceRemoved(event.cdevice.which);
    break;
```

When a controller is plugged in, `handleDeviceAdded` opens it and emits `connectionChanged(true)`. When unplugged, `handleDeviceRemoved` closes it and emits `connectionChanged(false)`. QML can bind to `gamepad.isConnected` to show/hide gamepad UI hints.

---

## 11.4 The QML Layer: `GamepadControl.qml`

### Zone-Based Navigation

The central concept is the **zone** — a string that identifies which part of the UI is currently active:

```qml
property string currentZone: "LibraryGrid"

function evaluateZone() {
    if (eqPopup && eqPopup.opened)           currentZone = "EqPopup";
    else if (mainMenuPopup && mainMenuPopup.opened)  currentZone = "MainMenu";
    else if (queueDrawer && queueDrawer.opened)      currentZone = "QueueDrawer";
    else if (nowPlayingPopup && nowPlayingPopup.opened) currentZone = "NowPlaying";
    else if (launchMode === "Library")       currentZone = "LibraryGrid";
    else                                     currentZone = "NowPlaying";
}
```

The zone is re-evaluated whenever a popup opens or closes, or when the user navigates between views. Each signal handler then switches on the zone:

```qml
function onDpadUp() {
    evaluateZone();
    if (currentZone === "LibraryGrid")
        navigateGrid(-columnsCount);      // Move up one row
    else if (currentZone === "QueueDrawer")
        navigateQueue(-1);                // Move up one item
    else if (currentZone === "EqPopup")
        adjustSlider(+1);                 // Increase EQ band
}
```

### Button Mapping

| Button | Zone: LibraryGrid | Zone: QueueDrawer | Zone: NowPlaying |
|---|---|---|---|
| **A** | Select tile / Play track | Play selected track | Toggle play/pause |
| **B** | Close filter / Back | Close drawer | Close overlay |
| **X** | Open queue | — | — |
| **Y** | Open now playing | — | Open EQ |
| **Start** | Open main menu | — | — |
| **D-pad** | Navigate grid | Navigate list | Seek / Volume |

### Volume Control via Triggers

Holding a trigger continuously adjusts volume:

```qml
Connections {
    target: gamepad
    function onVolumeChange(delta) {
        audioEngine.setVolume(Math.max(0, Math.min(1, audioEngine.volume + delta)));
    }
}
```

The C++ side emits `volumeChange(delta)` with small increments (~0.02) while the trigger is held, providing smooth volume ramping.

---

## 11.5 Dependencies

The gamepad system requires:
- **SDL2 development library**: `pkg_check_modules(SDL2 REQUIRED sdl2)` in CMakeLists.txt
- **Linking**: `${SDL2_LIBRARIES}` and `dl pthread m` in `target_link_libraries`

SDL2 is used only for gamepad input — audio playback uses miniaudio (Chapter 6).


<div class="page-break"></div>

<a id="12_main_bridge.md"></a>

# Chapter 12 — main.cpp: Wiring Everything Together

`main.cpp` is the entry point of the application. It is intentionally short — its only job is to **create the backend objects, connect them to each other, expose them to QML, and launch the engine**.

## 12.1 The Full main.cpp — Annotated

```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"
#include "gamepad_controller.h"
#include "playlist_manager.h"
#include "mpris_manager.h"

#include <QtNetwork/QLocalServer>
#include <QtNetwork/QLocalSocket>
#include <taglib/tdebuglistener.h>

// ─── Step 1: Silence TagLib debug output ────────────────────────────────────
class SilentTagLibListener : public TagLib::DebugListener {
public:
    void printMessage(const TagLib::String &msg) override {
        // Intentionally empty
    }
};

int main(int argc, char *argv[]) {
    static SilentTagLibListener silentListener;
    TagLib::setDebugListener(&silentListener);

    // ─── Step 2: High DPI support ────────────────────────────────────────────
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    // ─── Step 3: Force Material Dark theme ──────────────────────────────────
    qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");

    // ─── Step 4: App metadata (used by QSettings) ────────────────────────────
    QCoreApplication::setOrganizationName("LordTael");
    QCoreApplication::setOrganizationDomain("lordtael.com");
    QCoreApplication::setApplicationName("MLP Player");

    QApplication app(argc, argv);

    // ─── Step 5: Parse command-line arguments ────────────────────────────────
    QStringList args = QCoreApplication::arguments();
    QStringList filepath = args.mid(1);

    // ─── Step 6: Determine launch mode ──────────────────────────────────────
    QString launchMode;
    if (filepath.isEmpty())        launchMode = "Library";
    else if (filepath.size() == 1) launchMode = "Minimal";
    else                           launchMode = "Queue";

    // ─── Step 7: Single-Instance IPC (Conditional) ──────────────────────────
    // Only Minimal/Queue modes are single-instanced.
    // Library mode always opens a new window.
    bool isIpcServerRunning = false;
    QLocalSocket socket;
    socket.connectToServer("MLP_MusicPlayerIPC");
    if (socket.waitForConnected(500)) {
        isIpcServerRunning = true;
        if (launchMode != "Library") {
            // Secondary Minimal/Queue instance — send files and exit
            if (!filepath.isEmpty()) {
                socket.write(filepath.join('\n').toUtf8());
                socket.waitForBytesWritten(1000);
            }
            return 0;   // Exit: the primary instance will handle these files
        }
        socket.disconnectFromServer();
    }

    // ─── Step 8: Register Equalizer with QML type system ────────────────────
    qmlRegisterUncreatableType<Equalizer>(
        "com.musicplayer", 1, 0,
        "Equalizer",
        "Equalizer cannot be created in QML"
    );

    // ─── Step 9: Create backend instances on the stack ──────────────────────
    AudioEngine       audioEngine;
    LibraryScanner    libraryScanner;
    TrackModel        trackModel;
    GamepadController gamepad;
    PlaylistManager   playlistManager;
    MprisManager      mprisManager;

    // ─── Step 10: Wire scanner → model connections ──────────────────────────
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                     &trackModel,     &TrackModel::setTracks);
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAppended,
                     &trackModel,     &TrackModel::addTracks);

    // ─── Step 11: Wire play-time tracking ───────────────────────────────────
    // AudioEngine accumulates listening time and broadcasts it.
    // Both LibraryScanner (DB persistence) and TrackModel (in-memory)
    // receive the signal to stay in sync.
    QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                     &libraryScanner, &LibraryScanner::updatePlayTime);
    QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                     &trackModel, &TrackModel::updateTrackPlayTime);

    // ─── Step 12: Wire MPRIS ↔ AudioEngine ──────────────────────────────────
    // Desktop media controls (KDE Plasma, GNOME) send commands via D-Bus.
    // MprisManager translates them into AudioEngine actions.
    QObject::connect(&mprisManager, &MprisManager::playRequested,
                     &audioEngine, &AudioEngine::play);
    QObject::connect(&mprisManager, &MprisManager::pauseRequested,
                     &audioEngine, &AudioEngine::pause);
    QObject::connect(&mprisManager, &MprisManager::playPauseRequested,
                     &audioEngine, [&audioEngine]() {
        if (audioEngine.isPlaying()) audioEngine.pause();
        else audioEngine.play();
    });
    QObject::connect(&mprisManager, &MprisManager::stopRequested,
                     &audioEngine, &AudioEngine::stop);
    QObject::connect(&mprisManager, &MprisManager::seekRequested,
                     &audioEngine, [&audioEngine](int pos) {
        audioEngine.setPosition(pos);
    });

    // ─── Step 13: Load initial data based on launch mode ────────────────────
    if (launchMode == "Library") {
        libraryScanner.loadDatabase();
    } else {
        libraryScanner.loadSpecificFiles(filepath);
    }

    // ─── Step 14: Bind IPC server (only if no existing server) ──────────────
    if (!isIpcServerRunning) {
        QLocalServer::removeServer("MLP_MusicPlayerIPC");
        QLocalServer *server = new QLocalServer(&app);
        server->listen("MLP_MusicPlayerIPC");
        QObject::connect(
            server, &QLocalServer::newConnection, [&libraryScanner, server]() {
                QLocalSocket *clientSocket = server->nextPendingConnection();
                QObject::connect(clientSocket, &QLocalSocket::readyRead,
                    [&libraryScanner, clientSocket]() {
                        QByteArray data = clientSocket->readAll();
                        QStringList newFiles = QString::fromUtf8(data)
                            .split('\n', Qt::SkipEmptyParts);
                        if (!newFiles.isEmpty())
                            libraryScanner.appendSpecificFiles(newFiles);
                    });
                QObject::connect(clientSocket, &QLocalSocket::disconnected,
                                 clientSocket, &QLocalSocket::deleteLater);
            });
    }

    // ─── Step 15: Create QML engine ─────────────────────────────────────────
    QQmlApplicationEngine engine;
    engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

    // ─── Step 16: Expose backend objects + launchMode to QML ────────────────
    engine.rootContext()->setContextProperty("launchMode",      launchMode);
    engine.rootContext()->setContextProperty("audioEngine",     &audioEngine);
    engine.rootContext()->setContextProperty("libraryScanner",  &libraryScanner);
    engine.rootContext()->setContextProperty("trackModel",      &trackModel);
    engine.rootContext()->setContextProperty("gamepad",         &gamepad);
    engine.rootContext()->setContextProperty("playlistManager", &playlistManager);
    engine.rootContext()->setContextProperty("mprisManager",    &mprisManager);

    // ─── Step 17: Load root QML and start event loop ─────────────────────────
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
```

---

## 12.2 Why Stack Allocation?

```cpp
AudioEngine       audioEngine;
LibraryScanner    libraryScanner;
TrackModel        trackModel;
GamepadController gamepad;
PlaylistManager   playlistManager;
MprisManager      mprisManager;
```

All six backend objects are created on the stack (no `new`). This means:
- When `main()` returns, they are automatically destroyed in reverse order
- miniaudio, SQLite, SDL2, and D-Bus are properly cleaned up in destructors
- No risk of memory leaks

If they were heap-allocated (`new AudioEngine()`), we'd need `delete` or a smart pointer.

---

## 12.3 The Signal Connections in main.cpp

There are now **six** groups of inter-object connections:

### Scanner → Model (Data flow)
```cpp
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
QObject::connect(&libraryScanner, &LibraryScanner::tracksAppended,
                 &trackModel,     &TrackModel::addTracks);
```

- `tracksAdded → setTracks`: clears the model and repopulates (startup and full scans)
- `tracksAppended → addTracks`: inserts rows at the end (IPC new files)

### AudioEngine → Scanner + Model (Play-time tracking)
```cpp
QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                 &libraryScanner, &LibraryScanner::updatePlayTime);
QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                 &trackModel, &TrackModel::updateTrackPlayTime);
```

The `playTimeAccumulated(filePath, seconds)` signal fans out to both:
- `LibraryScanner::updatePlayTime` — persists to SQLite
- `TrackModel::updateTrackPlayTime` — updates in-memory model for live "Most Played" filter

### MPRIS → AudioEngine (Desktop control)
```cpp
QObject::connect(&mprisManager, &MprisManager::playRequested, ...);
QObject::connect(&mprisManager, &MprisManager::pauseRequested, ...);
QObject::connect(&mprisManager, &MprisManager::playPauseRequested, ...);
QObject::connect(&mprisManager, &MprisManager::stopRequested, ...);
QObject::connect(&mprisManager, &MprisManager::seekRequested, ...);
```

When the user presses media keys or uses the KDE Plasma media widget, D-Bus commands arrive at `MprisManager`, which emits these signals. The connections above route them directly to `AudioEngine`.

All objects remain completely ignorant of each other — the coupling lives only here, at the composition root. This is the **Hollywood principle**: "Don't call us. We'll call you."

---

## 12.4 Context Properties — The Complete List

| Context Property | C++ Type | QML Usage |
|---|---|---|
| `launchMode` | `QString` | Controls window size and which UI is shown |
| `audioEngine` | `AudioEngine*` | `audioEngine.play()`, `.pause()`, `.volume`, etc. |
| `libraryScanner` | `LibraryScanner*` | `libraryScanner.scanDirectory(path)` |
| `trackModel` | `TrackModel*` | Bound to `ListView.model` and grid views |
| `gamepad` | `GamepadController*` | Gamepad button/axis events for QML navigation |
| `playlistManager` | `PlaylistManager*` | `playlistManager.createPlaylist(name)`, etc. |
| `mprisManager` | `MprisManager*` | `mprisManager.setMetadata(...)`, `.setPlaybackStatus(...)` |

---

## 12.5 Conditional IPC: Library Mode Multi-Instance

The IPC logic has been refined so that **Library mode always opens a new window**, while Minimal/Queue modes redirect to the existing instance:

```cpp
if (socket.waitForConnected(500)) {
    isIpcServerRunning = true;
    if (launchMode != "Library") {
        // Minimal/Queue: send files to primary, exit
        socket.write(filepath.join('\n').toUtf8());
        return 0;
    }
    socket.disconnectFromServer();
    // Library mode: fall through → create a new window
}
```

The IPC server is only bound if no server is already running (`!isIpcServerRunning`), preventing socket conflicts between multiple Library windows.

---

## 12.6 qputenv — Theme Configuration

```cpp
qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");
```

These **must** be set before `QApplication` is constructed. The Qt Quick Controls style system reads them during initialization. Setting them afterward has no effect.

Without these, if the user's OS is set to a Light theme, Qt would override the app's dark appearance. The `Dark` override ensures consistent appearance regardless of system theme.


<div class="page-break"></div>

<a id="13_qml_fundamentals.md"></a>

# Chapter 13 — QML Language Fundamentals for C++ Developers

QML (Qt Modeling Language) is a **declarative language** for building UIs. Instead of writing imperative code that says "create a button, then set its color, then position it", you declare what the UI should look like as a **tree of nested objects**.

---

## 13.1 Your First QML File

```qml
import QtQuick 2.15        // Core QML types (Rectangle, Text, MouseArea, etc.)
import QtQuick.Controls 2.15  // Button, Slider, ComboBox, etc.

// Root Item — every QML file has exactly one root item
Rectangle {
    width: 400
    height: 300
    color: "#1a1a2e"        // Dark blue background

    Text {
        anchors.centerIn: parent  // Center inside the Rectangle
        text: "Hello, QML!"
        color: "white"
        font.pixelSize: 24
    }
}
```

Key observations:
- **No semicolons** — QML uses newlines and braces
- **Properties** are set with `property: value` (not `setProperty(value)`)
- **Hierarchy** is expressed by nesting — `Text` is a child of `Rectangle`
- **`parent`** refers to the immediate parent item
- `anchors` is a powerful layout system that positions items relative to their parent

---

## 13.2 Types You'll See in This Project

| QML Type | Purpose |
|----------|---------|
| `Rectangle` | Colored, rounded, or bordered box |
| `Text`, `Label` | Displays text |
| `Image` | Displays images (including `image://` custom providers) |
| `Item` | Invisible container (no visual) |
| `RowLayout`, `ColumnLayout`, `GridLayout` | Automatic layout managers |
| `ListView` | Scrollable list bound to a model |
| `Repeater` | Creates N items from a model (for fixed grids) |
| `Button`, `ToolButton`, `RoundButton` | Clickable buttons |
| `Slider` | Draggable value input |
| `ComboBox` | Dropdown selector |
| `Popup` | Floating overlay (modal or non-modal) |
| `Drawer` | Sliding panel from a screen edge |
| `TabBar`, `TabButton` | Tabbed navigation |
| `ScrollView`, `Flickable` | Scrollable content |
| `BusyIndicator` | Spinning loading animation |
| `Shortcut` | Maps keyboard sequences to actions |

---

## 13.3 Properties: Built-in and Custom

Every QML item has built-in properties (`width`, `height`, `color`, `visible`, etc.). You can define your own:

```qml
Rectangle {
    // Custom property definition
    property string currentArtist: "Unknown"
    property bool isSidebarVisible: true
    property int repeatCount: 0

    // Usage: properties are accessed by name
    Text { text: parent.currentArtist }
}
```

**Property binding** — when a property references another, it automatically updates:
```qml
Rectangle {
    width: 200
    height: width * 0.5    // height is always half of width — auto-updates!
}
```

---

## 13.4 id — Addressing Items by Name

Every item can have a unique `id` that lets other items reference it:

```qml
ApplicationWindow {
    id: window    // Other items refer to this as "window"

    Slider {
        id: progressSlider
        value: audioEngine.position   // Binds to C++ property
    }

    Text {
        // Reads the slider's value
        text: "Position: " + Math.floor(progressSlider.value)
    }
}
```

`id` is **not** a property. It is a compile-time binding name scoped to the current QML document.

---

## 13.5 Signals and Handlers in QML

C++ signals become `on<SignalName>` handlers in QML:

```qml
// C++ signal: void playingChanged(bool isPlaying)
// QML handler: onPlayingChanged
Button {
    onClicked: {    // Built-in MouseArea signal "clicked"
        if (audioEngine.isPlaying)
            audioEngine.pause()
        else
            audioEngine.play()
    }
}
```

For signals from objects that aren't the direct parent, use `Connections`:

```qml
Connections {
    target: libraryScanner          // Which C++ object to watch
    function onScanStarted() {      // Modern Qt5.15+ syntax
        scanningPopup.open()
    }
    function onScanProgress(count) {
        scanningLabel.text = "Found " + count + " Tracks..."
    }
    function onScanFinished(total) {
        scanningPopup.close()
    }
}
```

---

## 13.6 Functions in QML

JavaScript functions live inside QML items:

```qml
Rectangle {
    id: playbackBar

    // A helper function — called like JS: playbackBar.formatTime(354)
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds)) return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Text { text: playbackBar.formatTime(audioEngine.duration) }
}
```

---

## 13.7 ListView and Delegates

`ListView` displays a scrollable list from a model. The `delegate` defines what each row looks like:

```qml
ListView {
    width: 400
    height: 600
    model: trackModel       // C++ QAbstractListModel — roles become JS vars

    delegate: Rectangle {
        width: ListView.view.width
        height: 60
        color: "#22222b"

        Column {
            Text {
                text: title    // "title" role from TrackModel::roleNames()
                color: "white"
            }
            Text {
                text: artist   // "artist" role
                color: "#aaa"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: window.playTrackAtIndex(index, "songs")
            //                                 ↑ built-in "index" in delegate
        }
    }
}
```

Inside a delegate:
- `index` — the row number (0-based)
- `model` — the data for this row (rarely used directly)
- Role names (e.g., `title`, `artist`) — available as plain variables

---

## 13.8 Anchors — The Layout System

`anchors` is how you position items relative to their parent or siblings:

```qml
Item {
    width: 400; height: 400

    Rectangle {
        anchors.fill: parent         // Fill the parent completely
        color: "red"
    }

    Rectangle {
        width: 100; height: 100
        anchors.centerIn: parent     // Center in parent
        color: "blue"
    }

    Rectangle {
        width: 50; height: 50
        anchors.top: parent.top      // Stick to top
        anchors.right: parent.right  // Stick to right
        anchors.margins: 10          // 10px gap from edges
        color: "green"
    }
}
```

You can anchor to `parent.top`, `parent.bottom`, `parent.left`, `parent.right`, `parent.horizontalCenter`, `parent.verticalCenter`, or to another item's edges.

---

## 13.9 Layouts vs Anchors

For multiple children that need to be arranged together, use `RowLayout` / `ColumnLayout`:

```qml
RowLayout {
    anchors.fill: parent
    spacing: 10

    Button { text: "Prev";  Layout.preferredWidth: 40 }
    Button { text: "Play";  Layout.fillWidth: true }  // This one takes remaining space
    Button { text: "Next";  Layout.preferredWidth: 40 }
}
```

`Layout.fillWidth: true` — expand to fill remaining space.
`Layout.preferredWidth: N` — request a specific size.
`Layout.alignment: Qt.AlignHCenter` — align within cell.

---

## 13.10 Animations and Behaviors

QML makes animation very easy:

```qml
Rectangle {
    color: mouseArea.containsMouse ? "#2a2a35" : "transparent"
    radius: 6

    // Whenever "color" changes, animate the transition over 250ms
    Behavior on color {
        ColorAnimation { duration: 250 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true        // Enable containsMouse
    }
}
```

`NumberAnimation`, `ColorAnimation`, `OpacityAnimator` — all work the same way. Wrap a property change in a `Behavior` and it animates automatically.

---

## 13.11 Importing Other QML Files

When `main.qml` uses `LibraryView { ... }`, it imports `LibraryView.qml` from the same directory. No explicit `import` statement is needed — **all `.qml` files in the same directory are automatically available by their filename** (minus `.qml`).

```qml
// In main.qml — these are loaded from qml/LibraryView.qml, qml/NowPlayingView.qml
LibraryView {
    anchors.fill: parent
}

NowPlayingView {
    anchors.fill: parent
}
```


<div class="page-break"></div>

<a id="14_qml_main_window.md"></a>

# Chapter 14 — main.qml: The Root Window

`main.qml` is the root of the entire UI. It is over 1300 lines and contains:
- The `ApplicationWindow` (the OS window)
- A custom frameless title bar (Library mode only)
- Global playback state (current track, queue, queue index, repeat mode)
- Session persistence (queue and position survive restarts via `Qt.labs.settings`)
- The playback bar (bottom controls, Library mode only)
- All popups: equalizer, volume, now-playing, shortcuts, about, scanning progress
- The queue drawer
- Keyboard shortcuts (12 application-wide shortcuts)

---

## 14.1 ApplicationWindow and Frameless Mode

```qml
ApplicationWindow {
    id: window
    // Window size adapts to launch mode
    width:  launchMode === "Library" ? 1260 : 700
    height: launchMode === "Library" ?  768 : 350
    visible: true
    visibility: launchMode === "Library" ? Window.Maximized : Window.Windowed
    title: qsTr("Modern Music Player")

    // Frameless: no OS title bar — we draw our own
    flags: Qt.Window | Qt.FramelessWindowHint

    Material.theme: Material.Dark
    Material.accent: Material.Purple
    color: "#0a0a0c"
```

In **Library mode**, the window starts maximised at 1260×768. In **Minimal** or **Queue** mode it opens as a 700×350 compact window. The title bar is only rendered in Library mode (`visible: launchMode === "Library"`).

---

## 14.2 Global State Properties

```qml
// These are visible to ALL child QML files (LibraryView, NowPlayingView, MinimalView etc.)
property string currentPlayingTitle:       "No Song Playing"
property string currentPlayingArtist:      ""
property string currentPlayingPath:        ""
property bool   currentPlayingHasCoverArt: false
property var    playbackQueue:             []   // Array of track JS objects
property int    currentQueueIndex:         -1   // -1 means nothing playing
property int    repeatMode:                0    // 0=Off, 1=Repeat Track, 2=Repeat All
property bool   isFullScreen:              false
property string applicationVersion:        "1.2alpha"
```

Note that `repeatMode` is an **integer with three states**, not a boolean:
- `0` — Off: advance to next track only when queue is not at the end
- `1` — Repeat Track: seek to 0 and replay the same song
- `2` — Repeat All: advance normally, but loop back to index 0 at the end

---

## 14.3 playTrackAtIndex — The Core Playback Function

```qml
function playTrackAtIndex(idx, contextCategory) {
    if (idx < 0) return;

    // If a category context is provided, rebuild the queue from the current
    // visible trackModel rows (so "All Songs", "Artist: Queen", etc. each
    // generate their own queue)
    if (contextCategory) {
        let newQueue = [];
        for (var i = 0; i < trackModel.rowCount(); i++) {
            newQueue.push(trackModel.get(i));   // Returns a JS object per row
        }
        playbackQueue = newQueue;
        currentQueueIndex = idx;
    } else {
        currentQueueIndex = idx;  // Navigation within existing queue
    }

    if (currentQueueIndex < 0 || currentQueueIndex >= playbackQueue.length) return;

    var track = playbackQueue[currentQueueIndex];
    if (!track) return;

    // Update the "Now Playing" display state
    currentPlayingTitle  = track.title;
    currentPlayingArtist = track.artist;
    currentPlayingPath   = track.filePath;

    // Tell the audio engine to load and play
    audioEngine.loadFile(track.filePath);
    audioEngine.play();
}
```

**Two modes:**
1. `playTrackAtIndex(5, "songs")` — rebuild queue from current view, play row 5
2. `playTrackAtIndex(6)` — navigate to position 6 in the **existing** queue (used by Prev/Next)

---

## 14.4 Auto-Advance on Track End

```qml
Connections {
    target: audioEngine
    function onPlaybackFinished() {
        if (repeatMode === 1) {          // Repeat Track
            audioEngine.setPosition(0);
            audioEngine.play();
        } else if (repeatMode === 2) {   // Repeat All
            if (currentQueueIndex < playbackQueue.length - 1) {
                playTrackAtIndex(currentQueueIndex + 1);
            } else {
                playTrackAtIndex(0);     // Loop back to first track
            }
        } else {                         // Repeat Off
            if (currentQueueIndex < playbackQueue.length - 1) {
                playTrackAtIndex(currentQueueIndex + 1);
            }
            // else: stay at end, do nothing
        }
    }
}
```

This runs every time miniaudio signals that a track has ended (the 250ms timer in `AudioEngine` detects `ma_sound_at_end`).

---

## 14.5 The Custom Title Bar

```qml
Rectangle {
    id: titleBar
    Layout.fillWidth: true
    Layout.preferredHeight: 35
    color: "transparent"

    // Makes the window draggable (required because we removed the OS title bar)
    DragHandler {
        onActiveChanged: if (active) window.startSystemMove()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15; anchors.rightMargin: 10

        // App title text
        Label {
            text: window.title
            color: "white"
            font.bold: true; font.pixelSize: 14
            Layout.fillWidth: true
        }

        // Window control buttons
        ToolButton {
            icon.source: "qrc:/qml/icons/minimize.svg"
            onClicked: window.showMinimized()
        }
        ToolButton {
            icon.source: "qrc:/qml/icons/maximize.svg"
            onClicked: {
                if (window.visibility === Window.Maximized)
                    window.showNormal()
                else
                    window.showMaximized()
            }
        }
        ToolButton {
            icon.source: "qrc:/qml/icons/close.svg"
            onClicked: window.close()
        }
    }
}
```

`window.startSystemMove()` — tells the OS to handle dragging the window. This is more reliable than manually tracking mouse positions.

---

## 14.6 The Keyboard Shortcut System

```qml
// All shortcuts use Qt.ApplicationShortcut — they fire even when
// focus is inside a text field or button.
Shortcut { sequence: "Space";       context: Qt.ApplicationShortcut
           onActivated: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play() }

Shortcut { sequence: "Ctrl+Left";   context: Qt.ApplicationShortcut
           onActivated: {
               if (audioEngine.position > 2.0) audioEngine.setPosition(0.0);
               else if (currentQueueIndex > 0) playTrackAtIndex(currentQueueIndex - 1);
           }}

Shortcut { sequence: "Ctrl+Right";  context: Qt.ApplicationShortcut
           onActivated: playTrackAtIndex(currentQueueIndex + 1) }

Shortcut { sequence: "Left";        context: Qt.ApplicationShortcut
           onActivated: audioEngine.setPosition(audioEngine.position - 10.0) }

Shortcut { sequence: "Right";       context: Qt.ApplicationShortcut
           onActivated: audioEngine.setPosition(audioEngine.position + 10.0) }

Shortcut { sequence: "Up";          context: Qt.ApplicationShortcut
           onActivated: audioEngine.volume = Math.min(1.0, audioEngine.volume + 0.1) }

Shortcut { sequence: "Down";        context: Qt.ApplicationShortcut
           onActivated: audioEngine.volume = Math.max(0.0, audioEngine.volume - 0.1) }

Shortcut { sequence: "Ctrl+M";      context: Qt.ApplicationShortcut
           onActivated: {
               // Smart mute: remembers previous volume
               if (audioEngine.volume > 0.01) {
                   previousVolume = audioEngine.volume;
                   audioEngine.volume = 0.0;
               } else {
                   audioEngine.volume = previousVolume > 0.01 ? previousVolume : 1.0;
               }
           }}

Shortcut { sequence: "Ctrl+P";      context: Qt.ApplicationShortcut
           onActivated: queueDrawer.visible = !queueDrawer.visible }

Shortcut { sequence: "F";           context: Qt.ApplicationShortcut
           onActivated: libraryViewMain.isSidebarVisible = !libraryViewMain.isSidebarVisible }

Shortcut { sequence: "Ctrl+Shift+F"; context: Qt.ApplicationShortcut
           onActivated: toggleFullScreen() }

Shortcut { sequence: "Backspace";   context: Qt.ApplicationShortcut
           onActivated: libraryViewMain.goBack() }

Shortcut { sequence: StandardKey.Back; context: Qt.ApplicationShortcut
           onActivated: libraryViewMain.goBack() }

Shortcut { sequence: "Ctrl+Q";      context: Qt.ApplicationShortcut
           onActivated: Qt.quit() }
```

| Key | Action |
|---|---|
| `Space` | Play / Pause |
| `Ctrl+Left` | Previous track (or restart if >2s played) |
| `Ctrl+Right` | Next track |
| `Left` / `Right` | Seek ±10 seconds |
| `Up` / `Down` | Volume ±10% |
| `Ctrl+M` | Mute / Unmute (preserves volume) |
| `Ctrl+P` | Toggle Queue Drawer |
| `F` | Toggle Library Sidebar |
| `Ctrl+Shift+F` | Toggle Fullscreen |
| `Backspace` | Navigate back in Library |
| `Ctrl+Q` | Quit |

---

## 14.7 The Bottom Playback Bar

The bottom playback bar is **only visible in Library mode** (hidden in Minimal/Queue modes where `MinimalView` handles its own controls). It uses a three-section layout inside a `Rectangle` (90px tall):

```html
<div style="display: flex; border: 2px solid #ccc; border-radius: 8px; font-family: monospace; text-align: center; background: #fafafa; margin: 20px 0;">
  <div style="flex: 1; border-right: 1px solid #ccc; padding: 15px;">
    <strong>LEFT</strong><br/>[Art] [Title / Artist]
  </div>
  <div style="flex: 2; border-right: 1px solid #ccc; padding: 15px;">
    <strong>CENTER</strong><br/>[Prev] [Play] [Next] [Repeat] <span style="margin-left:20px;">00:00 ─────── 03:37</span>
  </div>
  <div style="flex: 1; padding: 15px;">
    <strong>RIGHT</strong><br/>[Vol] [EQ] [Queue]
  </div>
</div>
```

- **Left section**: 80×80 cover art thumbnail (tapping toggles `nowPlayingPopup`) + title + artist
- **Center section**: Prev / Play+Pause / Next / Repeat buttons + seek `Slider` with timestamps
- **Right section**: Volume button + EQ button + Queue button

The play button has a special guard:
```qml
onClicked: {
    // If nothing is queued to play yet, auto-start from index 0
    if (currentQueueIndex === -1 && playbackQueue.length > 0)
        playTrackAtIndex(0)
    else
        audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
}
```

---

## 14.8 The Queue Drawer

```qml
Drawer {
    id: queueDrawer
    edge: Qt.RightEdge        // Slides in from the right
    width: Math.min(window.width * 0.4, 400)
    height: parent.height

    ListView {
        model: window.playbackQueue    // The JS array of track objects

        delegate: ItemDelegate {
            // Only show tracks at or after the current position
            property bool isVisibleItem: index >= window.currentQueueIndex
            height: isVisibleItem ? 60 : 0
            opacity: isVisibleItem ? 1.0 : 0.0

            // Smooth height/opacity animation as items enter/leave view
            Behavior on height  { NumberAnimation { duration: 300 } }
            Behavior on opacity { NumberAnimation { duration: 250 } }

            // Highlight the currently playing track with a blue left border
            background: Rectangle {
                color: index === window.currentQueueIndex ? "#2a2a35" : "transparent"
                Rectangle {
                    width: 4; height: parent.height
                    anchors.left: parent.left
                    color: "#0078d7"
                    visible: index === window.currentQueueIndex
                }
            }

            onClicked: window.playTrackAtIndex(index)
        }
    }
}
```

---

## 14.9 Session Persistence

`main.qml` uses `Qt.labs.settings` (`QSettings` under the hood) to remember the user's listening state across restarts:

```qml
Settings {
    id: sessionSettings
    category: "MediaPlayer"
    property string savedQueue:        "[]"   // JSON array of file paths
    property int    savedQueueIndex:   -1
    property real   savedPosition:     0.0
    property int    savedRepeatMode:   0
    property real   savedVolume:       1.0
}
```

**Saving** happens in `Component.onDestruction` (called when the window is closed):
```qml
Component.onDestruction: {
    let paths = [];
    for (let i = 0; i < playbackQueue.length; i++) {
        paths.push(playbackQueue[i].filePath);
    }
    sessionSettings.savedQueue = JSON.stringify(paths);
    sessionSettings.savedQueueIndex = currentQueueIndex;
    sessionSettings.savedPosition   = audioEngine.position;
    sessionSettings.savedVolume     = audioEngine.volume;
    sessionSettings.savedRepeatMode = repeatMode;
}
```

**Restoring** requires a two-timer pattern because the model is populated asynchronously:

1. `startupRestoreTimer` (200ms, repeating) — polls `trackModel.rowCount()`. Once > 0, the library data is available, so it rebuilds the queue from saved file paths and seeks to `savedQueueIndex`.
2. `restorePosTimer` (200ms, one-shot) — started after `audioEngine.loadFile()`. Waits for miniaudio to finish its async file-open before calling `audioEngine.setPosition(savedPosition)`.

This two-stage approach is necessary because:
- The model is populated via a deferred QTimer signal from C++
- miniaudio decodes files asynchronously; seeking before decoding is ready is silently ignored
```


<div class="page-break"></div>

<a id="15_qml_library_view.md"></a>

# Chapter 15 — LibraryView.qml: The Main Library Browser

## 15.1 Overview

`LibraryView.qml` is the heart of the application's UI. It shows the user's music library in a tiled grid layout with a collapsible left sidebar for category filtering. It has 5 view modes:

| Mode | What it shows | How it navigates |
|------|--------------|-----------------|
| **Tracks** | Every song as a tile | Click → play immediately |
| **Artists** | One circular tile per artist | Click → drill down to artist's songs |
| **Albums** | One square tile per album | Click → drill down to album's songs |
| **Folders** | One tile per filesystem folder | Click → drill down to folder's songs |
| **Collections** | Top-level folder groupings | Click → drill down to collection's songs |

---

## 15.2 The Component Layout

```
┌─────────────────────────────────────────────────────┐
│  RowLayout (fills entire LibraryView area)          │
│                                                     │
│  ┌──────────────┐  ┌────────────────────────────┐  │
│  │  Sidebar     │  │  Content Area               │  │
│  │  (200px)     │  │                             │  │
│  │  - Tracks    │  │  [Breadcrumb / Title Bar]   │  │
│  │  - Artists   │  │                             │  │
│  │  - Albums    │  │  StackView                  │  │
│  │  - Folders   │  │  ┌──────────────────────┐  │  │
│  │  - Collections│ │  │ GridView (tiles)      │  │  │
│  │              │  │  │ (track/artist/album/  │  │  │
│  └──────────────┘  │  │  folder/collection)   │  │  │
│  (animates to 0    │  └──────────────────────┘  │  │
│   width when       └────────────────────────────┘  │
│   hidden)                                           │
└─────────────────────────────────────────────────────┘
```

---

## 15.3 State Properties

```qml
Item {
    id: libraryView
    property string activeCategoryName: "All Tracks"  // Displayed in the breadcrumb
    property string categoryContext:    "All Tracks"  // "All Tracks"|"Artists"|"Albums"|"Folders"|"Collections"
    property bool   isSidebarVisible:   true          // Controlled by "F" shortcut and toggle button
```

These three properties drive the entire view. When `categoryContext` changes, the correct grid component is pushed onto the `StackView`.

---

## 15.4 The Collapsible Sidebar

```qml
Rectangle {
    id: sidebarRect
    // When isSidebarVisible is false, width animates to 0 pixels
    Layout.preferredWidth: isSidebarVisible ? 200 : 0
    Layout.fillHeight: true
    color: "#18181c"
    radius: 12
    clip: true   // IMPORTANT: clips children during animation so they don't overflow
    visible: Layout.preferredWidth > 0

    // Smooth 250ms animation whenever width changes
    Behavior on Layout.preferredWidth {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    // Category buttons built from a model (no duplicated code!)
    Repeater {
        model: [
            { name: "Tracks",      ctx: "All Tracks"   },
            { name: "Artists",     ctx: "Artists"      },
            { name: "Albums",      ctx: "Albums"       },
            { name: "Folders",     ctx: "Folders"      },
            { name: "Collections", ctx: "Collections"  }
        ]
        delegate: ItemDelegate {
            property bool isActive: libraryView.categoryContext === modelData.ctx

            // Active item gets blue left bar + bolder text
            background: Rectangle {
                color: parent.isActive ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")
                Rectangle {
                    width: 4; height: parent.height
                    anchors.left: parent.left
                    color: "#0078d7"
                    visible: parent.parent.isActive
                }
            }

            onClicked: {
                libraryView.categoryContext = modelData.ctx
                mainStack.clear()  // Remove any drilled-down views

                if      (modelData.name === "Tracks")      mainStack.push(trackGridComponent)
                else if (modelData.name === "Artists")     mainStack.push(artistGridComponent)
                else if (modelData.name === "Albums")      mainStack.push(albumGridComponent)
                else if (modelData.name === "Folders")     mainStack.push(folderGridComponent)
                else if (modelData.name === "Collections") mainStack.push(collectionGridComponent)
            }
        }
    }
}
```

---

## 15.5 StackView — Navigation

`StackView` provides the drill-down navigation. Think of it as a stack of pages: push to go deeper, pop to go back.

```qml
StackView {
    id: mainStack
    Layout.fillWidth: true
    Layout.fillHeight: true
    initialItem: trackGridComponent   // Start on the tracks view
}
```

When the user clicks an Artist tile:
```qml
onClicked: {
    libraryView.activeCategoryName = modelData.name  // "Queen"
    trackModel.filterByArtist(modelData.name)        // Filter C++ model
    mainStack.push(trackGridComponent)               // Push song grid on stack
}
```

The back button pops this:
```qml
ToolButton {
    visible: mainStack.depth > 1   // Only show when there is something to pop back to
    onClicked: {
        mainStack.pop()
        libraryView.activeCategoryName = libraryView.categoryContext
    }
}
```

---

## 15.6 The Track Grid (trackGridComponent)

```qml
Component {
    id: trackGridComponent
    GridView {
        model: trackModel   // The C++ QAbstractListModel
        cellWidth: 160
        cellHeight: 200
        clip: true
        cacheBuffer: 1000   // Pre-render items 1000px outside visible area for smooth scrolling

        delegate: Item {
            width: 160; height: 200

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                color: "#202025"; radius: 8

                Rectangle {
                    id: artRect
                    width: parent.width - 20; height: width
                    color: "#33333b"; radius: 8; clip: true

                    // Cover art with fallback "?" placeholder
                    Image {
                        anchors.fill: parent
                        // "image://musiccover/" prefix routes to CoverArtProvider
                        source: model.hasCoverArt ? "image://musiccover/" + model.filePath : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: model.hasCoverArt
                        asynchronous: true       // Don't block UI thread while loading
                        sourceSize: Qt.size(200, 200)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "?"; color: "#555"; font.pixelSize: 40
                        visible: !model.hasCoverArt   // Show when no art
                    }
                }

                Text { text: model.title;  color: "white"; elide: Text.ElideRight }
                Text { text: model.artist; color: "#aaa";  elide: Text.ElideRight }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // contextCategory causes playTrackAtIndex to rebuild the queue
                        window.playTrackAtIndex(index, libraryView.activeCategoryName)
                    }
                }
            }
        }
    }
}
```

---

## 15.7 The Artist Grid — Circular Tiles

Artists use circular images (a design convention for artist portraits):

```qml
Rectangle {
    id: artArt
    radius: 100   // Large radius makes a square into a circle when width == height
    clip: true    // Clips the image to the circle
    Image {
        source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
        fillMode: Image.PreserveAspectCrop
    }
}
```

Drill-down on artist click:
```qml
onClicked: {
    libraryView.activeCategoryName = modelData.name
    trackModel.filterByArtist(modelData.name)   // calls C++ TrackModel::filterByArtist
    mainStack.push(trackGridComponent)
}
```

---

## 15.8 `model` vs `modelData` Explained

Inside a delegate that uses a **C++ QAbstractListModel**, you access roles by name directly:
```qml
GridView {
    model: trackModel   // QAbstractListModel
    delegate: Text { text: model.title }   // or just: text: title
}
```

Inside a delegate that uses a **JavaScript array** (from `getAlbumTiles()` etc.), you access the current element via `modelData`:
```qml
GridView {
    model: trackModel.getAlbumTiles()   // Returns QVariantList → JS array
    delegate: Text { text: modelData.name }   // modelData = the current JS object
}
```

This distinction is a common source of confusion in QML.

---

## 15.9 Navigation Flow Summary

```
User selects "Artists" in sidebar
    → categoryContext = "Artists"
    → mainStack.push(artistGridComponent)
    → artistGridComponent.model = trackModel.getArtistTiles()

User clicks "Queen" tile
    → trackModel.filterByArtist("Queen")   (C++ model updates)
    → mainStack.push(trackGridComponent)
    → trackGridComponent.model = trackModel (now filtered to Queen only)

User clicks a song
    → window.playTrackAtIndex(index, "Queen")
    → Builds queue from current filtered model (only Queen songs)
    → audioEngine.loadFile() + audioEngine.play()

User clicks Back button
    → mainStack.pop()
    → Goes back to artistGridComponent
```


<div class="page-break"></div>

<a id="16_qml_equalizer_view.md"></a>

# Chapter 16 — EqualizerView.qml and NowPlayingView.qml

## 16.1 EqualizerView.qml

The Equalizer view is hosted in a `Popup` in `main.qml`. It provides:
- 10 vertical sliders (one per EQ band)
- Band frequency labels
- Gain readout per band (e.g., "+6 dB")
- An Enable/Disable toggle switch
- A preset combo box (loads factory + custom presets)
- Save/Delete custom preset controls

### Architecture

The EQ view communicates entirely through the `audioEngine.equalizer` object (a C++ `Equalizer*` exposed as `CONSTANT` Q_PROPERTY):

```qml
// EqualizerView.qml structure
Item {
    // Access the equalizer via the audioEngine context property
    property var eq: audioEngine.equalizer   // Shorthand alias

    // Enable switch
    Switch {
        checked: eq.enabled
        onToggled: eq.enabled = checked   // Calls Equalizer::setEnabled via Q_PROPERTY WRITE
    }

    // Preset selector
    ComboBox {
        id: presetBox
        model: eq.getPresetNames()    // Q_INVOKABLE — returns QStringList → JS array
        onActivated: eq.loadPreset(currentText)  // Q_INVOKABLE call directly from QML
    }

    // Save custom preset
    TextField {
        id: presetNameField
        placeholderText: "Save as..."
    }
    Button {
        text: "Save"
        onClicked: {
            if (presetNameField.text.length > 0) {
                eq.saveCustomPreset(presetNameField.text)  // Q_INVOKABLE
                presetBox.model = eq.getPresetNames()      // Refresh dropdown
            }
        }
    }

    // 10 band sliders (Repeater builds 10 columns)
    Repeater {
        model: 10    // 10 iterations
        delegate: Column {
            // Band label (31Hz, 62Hz, etc.)
            Text {
                text: {
                    var freq = eq.bandFrequency(index)   // Q_INVOKABLE
                    return freq >= 1000 ? (freq/1000).toFixed(0) + "k" : freq.toFixed(0)
                }
                color: "#aaa"
            }

            // Gain readout text (+6dB, -3dB, etc.)
            Text {
                text: {
                    var g = eq.bandGain(index)   // Q_INVOKABLE — reads current gain
                    return (g >= 0 ? "+" : "") + g.toFixed(1) + " dB"
                }
                color: "white"
            }

            // Vertical slider for this band
            Slider {
                orientation: Qt.Vertical
                from: -12.0; to: 12.0    // Signal range: -12dB to +12dB
                value: eq.bandGain(index) // Initial value from C++

                onMoved: {
                    eq.setBandGain(index, value)  // Public slot — triggers bandGainChanged signal
                    // bandGainChanged → AudioEngine::onEqualizerBandGainChanged
                    // → ma_peak_node_reinit → instant EQ change in audio pipeline
                }
            }
        }
    }
}
```

### Data Flow for Moving an EQ Slider

```
User drags slider for 1kHz band
         ↓
  Slider.onMoved fires in QML
         ↓
  eq.setBandGain(5, newValue) — calls Equalizer::setBandGain(5, newValue)
         ↓ (C++ Equalizer)
  m_gains[5] = clampedValue
  emit bandGainChanged(5, clampedValue)
         ↓ (signal-slot connection in AudioEngine constructor)
  AudioEngine::onEqualizerBandGainChanged(5, newValue)
         ↓
  ma_peak_node_reinit(&m_eqNodes[5], newConfig)
         ↓
  miniaudio applies new filter coefficients to the audio stream instantly
```

---

## 16.2 NowPlayingView.qml

This is a full-screen overlay (shown when you click the expand button in the playback bar). It provides a cinematic "Now Playing" experience:

```qml
// NowPlayingView.qml structure
Item {
    // Large blurred background using the album art
    Image {
        anchors.fill: parent
        source: window.currentPlayingPath !== "" ?
                "image://musiccover/" + window.currentPlayingPath : ""
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: FastBlur { radius: 64 }   // Frosted glass blur effect
        opacity: 0.4
    }

    Column {
        // Large album art, centered
        Rectangle {
            width: 300; height: 300
            radius: 12
            Image {
                source: window.currentPlayingPath !== "" ?
                        "image://musiccover/" + window.currentPlayingPath : ""
                fillMode: Image.PreserveAspectCrop
            }
        }

        // Song title and artist
        Text { text: window.currentPlayingTitle;  font.pixelSize: 36; color: "white" }
        Text { text: window.currentPlayingArtist; font.pixelSize: 20; color: "#aaa" }

        // Progress slider
        Row {
            Text { text: formatTime(audioEngine.position); color: "white" }
            Slider {
                from: 0; to: audioEngine.duration
                value: audioEngine.position
                onMoved: audioEngine.position = value
            }
            Text { text: formatTime(audioEngine.duration); color: "white" }
        }

        // Playback controls (same as bottom bar)
        Row {
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex - 1) }
            RoundButton {
                icon.source: audioEngine.isPlaying ? "pause.svg" : "play.svg"
                onClicked: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
            }
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex + 1) }
        }

        // Repeat toggle
        ToolButton {
            icon.source: window.repeatMode ? "repeat_on.svg" : "repeat.svg"
            onClicked: window.repeatMode = !window.repeatMode
        }
    }
}
```

Key concept: `NowPlayingView` reads from `window.currentPlayingTitle`, `window.currentPlayingArtist`, and `window.currentPlayingPath` — all declared in `main.qml` (the root). Any child QML file can access the root by its `id: window`.

---

## 16.3 The `Connections` Pattern — Updating the EQ Sliders

When the user selects a preset like "Rock", `Equalizer::loadPreset("Rock")` calls `setBandGain(i, value)` for all 10 bands. Each call emits `bandGainChanged`. The QML sliders need to reflect these changes.

The cleanest way is to bind the slider `value` to `eq.bandGain(index)`:

```qml
Slider {
    value: eq.bandGain(index)   // This is a binding — updates whenever bandGain changes
    onMoved: eq.setBandGain(index, value)
}
```

BUT: When the user drags the slider, `value` changes and triggers `onMoved` → `setBandGain` → `bandGainChanged` → `value` tries to update again (circular). Qt handles this correctly — it only updates if the new value differs from the current, breaking the cycle.

---

## 16.4 Avoiding Binding Loops

A **binding loop** would be:
```qml
// DANGEROUS
width: parent.width   // width = parent.width
// Then somewhere else:
// parent.width: child.width ← circular!
```

Qt detects these at runtime and prints a warning. In the Equalizer, the pattern `value: eq.bandGain(index)` is safe because:
1. `onMoved` only fires when the **user** drags (not on programmatic value changes)
2. `setBandGain` only emits if the value actually changed (the `!=` check in C++)


<div class="page-break"></div>

<a id="17_qml_minimal_view.md"></a>

# Chapter 17 — MinimalView: The Compact Now Playing Window

`MinimalView.qml` is the UI displayed when the application is launched in **Minimal** or **Queue** mode (i.e., when audio files are opened directly from a file manager rather than from the app icon). It is a purpose-built, self-contained compact playback interface.

---

## 17.1 Why a Separate Component?

The full Library UI (`LibraryView` + `main.qml` playback bar) is designed for a 1260px-wide maximised window. Trying to squeeze it into a 700×350 window would produce layout overflows and visual chaos.

`MinimalView` was therefore built from scratch as a standalone `Item` optimised for the compact window size. It shares global state (queue, track info, audioEngine) but manages its own layout entirely.

---

## 17.2 Layout Overview

```html
<div style="width: 100%; max-width: 600px; border: 1px solid #ddd; border-radius: 8px; overflow: hidden; background-color: #f9f9f9; font-family: sans-serif; display: flex; flex-direction: column;">
  <!-- Title Bar -->
  <div style="background-color: #eee; padding: 5px 10px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #ddd;">
    <span style="font-size: 14px; color: #555;">[Draggable Area]</span>
    <div>
      <span style="margin-right: 10px; cursor: pointer;">[ – ]</span>
      <span style="cursor: pointer;">[ × ]</span>
    </div>
  </div>
  <!-- Main Content -->
  <div style="display: flex; padding: 20px; align-items: center;">
    <!-- Cover Art (Left) -->
    <div style="width: 150px; height: 150px; background-color: #202025; border-radius: 10px; display: flex; align-items: center; justify-content: center; color: #555; font-size: 48px; margin-right: 20px; flex-shrink: 0;">
      ♪
    </div>
    <!-- Details & Controls (Right) -->
    <div style="flex-grow: 1; display: flex; flex-direction: column;">
      <h2 style="margin: 0; font-size: 32px; color: #333;">Song Title</h2>
      <h3 style="margin: 5px 0 10px 0; font-size: 18px; color: #666;">Artist Name</h3>
      <span style="font-size: 15px; color: #999; margin-bottom: 15px;">Now Playing</span>
      
      <!-- Seek Bar -->
      <div style="display: flex; align-items: center; justify-content: space-between; font-size: 12px; color: #555; margin-bottom: 15px;">
        <span>00:00</span>
        <div style="flex-grow: 1; height: 4px; background-color: #ddd; margin: 0 10px; position: relative;">
            <div style="width: 30%; height: 100%; background-color: #007bff;"></div>
        </div>
        <span>03:37</span>
      </div>

      <!-- Controls -->
      <div style="display: flex; align-items: center; padding-left: 20px; font-size: 18px; color: #444;">
        <span style="margin-right: 15px;">[⟲]</span>
        <span style="margin-right: 15px;">[⏮]</span>
        <span style="margin-right: 15px; border: 1px solid #ccc; padding: 5px 15px; border-radius: 5px;">[▶ / ⏸]</span>
        <span style="margin-right: 30px;">[⏭]</span>
        <span style="margin-right: 15px;">[🔊]</span>
        <span>[≡]</span>
      </div>
    </div>
  </div>
</div>
```

The window is split horizontally into two sections anchored to the root `Item`:
- **Left**: a square cover art image (height constrained to `parent.height - 40`)
- **Right**: a `ColumnLayout` with title, artist, "Now Playing" label, seek row, controls row

---

## 17.3 The Cover Art Area

```qml
Rectangle {
    id: coverArtRect
    width: parent.height - titleBarHeight - bottomPadding
    height: width   // Always square
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.verticalCenter: parent.verticalCenter
    radius: 10
    color: "#202025"
    clip: true

    Image {
        anchors.fill: parent
        source: window.currentPlayingHasCoverArt
            ? "image://musiccover/" + window.currentPlayingPath
            : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(300, 300)
    }

    Text {
        anchors.centerIn: parent
        text: "♪"
        color: "#555"
        font.pixelSize: 48
        visible: !window.currentPlayingHasCoverArt
    }
}
```

Using `sourceSize: Qt.size(300, 300)` ensures that heavy cover art images are downscaled before being decoded into RAM, which keeps memory usage low for the compact view.

---

## 17.4 Frameless Window Management

Because the window uses `Qt.FramelessWindowHint`, `MinimalView` must provide its own drag, minimize, and close controls:

```qml
// Drag the entire window by dragging the empty area
DragHandler {
    target: null
    onActiveChanged: if (active) window.startSystemMove()
}

// Title bar row (top-right corner)
RowLayout {
    anchors.top:   parent.top
    anchors.right: parent.right
    anchors.margins: 8

    ToolButton {
        icon.source: "qrc:/qml/icons/minimize.svg"
        onClicked: window.showMinimized()
    }
    ToolButton {
        icon.source: "qrc:/qml/icons/close.svg"
        onClicked: window.close()
    }
}
```

There is no Maximize button in the Minimal view — the compact window is intentionally fixed in size.

---

## 17.5 Playback Controls

The controls in `MinimalView` call the same `window.playTrackAtIndex()` function as the full Library UI:

```qml
RowLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: 12

    // Repeat cycle button (Off → Track → All → Off)
    ToolButton {
        icon.source: window.repeatMode === 1
            ? "qrc:/qml/icons/repeat_one.svg"
            : "qrc:/qml/icons/repeat.svg"
        onClicked: window.repeatMode = (window.repeatMode + 1) % 3
    }

    // Previous — smart: restarts if > 2 seconds elapsed, else goes back
    ToolButton {
        icon.source: "qrc:/qml/icons/prev.svg"
        onClicked: {
            if (audioEngine.position > 2.0) {
                audioEngine.setPosition(0.0);
            } else if (window.currentQueueIndex > 0) {
                window.playTrackAtIndex(window.currentQueueIndex - 1);
            }
        }
    }

    // Play / Pause
    ToolButton {
        icon.source: audioEngine.isPlaying
            ? "qrc:/qml/icons/pause.svg"
            : "qrc:/qml/icons/play.svg"
        onClicked: {
            if (audioEngine.isPlaying) audioEngine.pause();
            else audioEngine.play();
        }
    }

    // Next
    ToolButton {
        icon.source: "qrc:/qml/icons/next.svg"
        onClicked: {
            if (window.currentQueueIndex < window.playbackQueue.length - 1) {
                window.playTrackAtIndex(window.currentQueueIndex + 1);
            }
        }
    }
}
```

---

## 17.6 Shared Popups

`MinimalView` does not define its own volume popup or queue drawer. It reuses the ones defined in `main.qml` (which is the parent `ApplicationWindow`):

```qml
// Volume popup — defined in main.qml, opened from MinimalView
ToolButton {
    icon.source: audioEngine.volume <= 0.01
        ? "qrc:/qml/icons/volume_off.svg"
        : "qrc:/qml/icons/volume.svg"
    onClicked: window.showVolumePopup(this)   // Calls main.qml function
}

// Queue drawer — also defined in main.qml
ToolButton {
    icon.source: "qrc:/qml/icons/queue.svg"
    onClicked: queueDrawer.open()   // queueDrawer is in main.qml scope
}
```

This works because all items inside an `ApplicationWindow` share the same QML scope — `main.qml`'s `Drawer`, `Popup` and functions are accessible from child components.

---

## 17.7 Initial Queue Playback

When `MinimalView` loads (i.e., `launchMode !== "Library"`), `main.qml` fires `Component.onCompleted` to start playing immediately:

```qml
Component.onCompleted: {
    if (launchMode !== "Library") {
        let newQueue = [];
        for (let i = 0; i < trackModel.rowCount(); i++) {
            newQueue.push(trackModel.get(i));
        }
        window.playbackQueue = newQueue;
        if (newQueue.length > 0) {
            window.playTrackAtIndex(0, "CLI");
        }
    }
}
```

This fires after the QML engine finishes loading, by which time `loadSpecificFiles()` has already populated `trackModel` synchronously.

---

## 17.8 Why MinimalView Is in Its Own File

Keeping the compact view isolated in its own file rather than as a conditional layout inside `main.qml` provides several benefits:

1. **No layout collisions** — the Library layout's `ColumnLayout` anchors don't interfere
2. **Independent sizing** — the component can define its own proportions freely
3. **Readability** — the 1300+ line main.qml would be even harder to navigate with embedded dual-mode logic
4. **Testability** — the file can be previewed in Qt Quick Designer independently


<div class="page-break"></div>

<a id="18_qml_playlist_views.md"></a>

# Chapter 18 — QML Playlist Views

## 18.1 Overview

The playlist UI consists of three QML files that work together:

| File | Purpose |
|------|---------|
| `PlaylistsView.qml` | Grid of playlist tiles (browse all playlists) |
| `PlaylistDetailsView.qml` | Track list for a single playlist (with edit mode) |
| `PlaylistPopup.qml` | Centralized popup container for add/create/menu popups |

These views rely on `PlaylistManager` (Chapter 9) for all data operations and on `TrackModel` for displaying track metadata.

---

## 18.2 PlaylistsView.qml — The Playlist Grid

This view displays all playlists as a grid of tiles, similar to how the library shows artist or album tiles.

### Data Loading

```qml
Item {
    id: playlistsViewRoot

    property var modelList: playlistManager.getPlaylists()

    Connections {
        target: playlistManager
        function onPlaylistsChanged() {
            playlistsViewRoot.modelList = playlistManager.getPlaylists();
        }
    }
}
```

The playlist list is fetched once at load time via `getPlaylists()`, then automatically refreshed whenever `playlistsChanged()` fires (after a create or delete operation).

### The Grid Layout

```qml
GridView {
    model: playlistsViewRoot.modelList
    cellWidth: 200
    cellHeight: 200

    delegate: Item {
        // Each tile: a dark rectangle with an icon and playlist name
        Rectangle {
            color: "#202025"
            radius: 8

            // Playlist icon placeholder
            Image { source: "qrc:/qml/icons/view_list.svg" }

            // Playlist name
            Text { text: modelData; color: "white" }

            MouseArea {
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: {
                    if (mouse.button == Qt.LeftButton) {
                        // Navigate into the playlist
                        trackModel.filterByPlaylist(modelData,
                            playlistManager.getPlaylistTracks(modelData));
                        mainStack.push("qrc:/qml/PlaylistDetailsView.qml",
                            { playlistName: modelData });
                    } else if (mouse.button == Qt.RightButton) {
                        // Open context menu
                        playlistMenuPopup.playlistName = modelData;
                        playlistMenuPopup.open();
                    }
                }
            }
        }
    }
}
```

Left-click navigates into the playlist. Right-click opens the context menu popup (Open, Add Songs, Rename, Delete).

---

## 18.3 PlaylistDetailsView.qml — Track List

When a user clicks a playlist tile, the `StackView` pushes `PlaylistDetailsView` with the playlist name as a property.

### Key Properties

```qml
Item {
    id: playlistDetailsRoot
    property string playlistName: ""
    property bool isEditMode: false
}
```

- `playlistName`: Set when the view is pushed onto the stack
- `isEditMode`: Toggles between browse mode and edit mode (shows remove/reorder controls)

### Live Updates via Signal

```qml
Connections {
    target: playlistManager
    function onPlaylistTracksChanged(pName) {
        if (pName === playlistName) {
            trackModel.filterByPlaylist(playlistName,
                playlistManager.getPlaylistTracks(playlistName));
        }
    }
}
```

When tracks are added, removed, moved, or sorted in the current playlist, the `playlistTracksChanged` signal triggers a refresh. The filter is scoped to only update when the signal matches the current playlist name.

### Toolbar

The top of the view shows action buttons:

| Button | Action |
|--------|--------|
| **Add Content** | Opens the `addPopup` (shows all library tracks) |
| **Edit Playlist / Done Editing** | Toggles edit mode (show remove buttons, reorder handles) |
| **Sort by Title** | Calls `playlistManager.sortPlaylist(name, "title")` |
| **Sort by Artist** | Calls `playlistManager.sortPlaylist(name, "artist")` |
| **Sort by Track #** | Calls `playlistManager.sortPlaylist(name, "trackNumber")` |

### Edit Mode

In edit mode, each track row shows:
- A **remove button** that calls `playlistManager.removeTrack(playlistName, filePath)`
- Visual indicators for reordering (calls `playlistManager.moveTrack(...)`)

---

## 18.4 PlaylistPopup.qml — Centralized Popup Container

`PlaylistPopup` is an `Item` that bundles three related popups into a single, reusable component:

```qml
Item {
    id: root
    property var playlistManager: null

    property alias addPopup: addPopup
    property alias playlistMenuPopup: playlistMenuPopup
    property alias createPlaylistPopup: createPlaylistPopup

    function openAddPopup(manager, name) { ... }
    function openCreatePlaylistPopup(manager) { ... }
}
```

### The Three Popups

#### `addPopup` — Add Tracks to a Playlist

A large popup (800×650) that displays the entire library as a scrollable list. Each track has an "Add" button that:
1. Calls `playlistManager.addTrack(playlistName, filePath)`
2. Changes the button text to "Added" and disables it

The search/filter within this popup operates independently of the main library filter — it iterates over `trackModel.getAllTracks()` to always show the full library.

#### `createPlaylistPopup` — Create a New Playlist

A compact popup (600×200) with:
- A `TextField` for the playlist name
- "Cancel" and "Create" buttons
- On create: calls `playlistManager.createPlaylist(name)`, clears the field, and closes

#### `playlistMenuPopup` — Right-Click Context Menu

A small popup showing the playlist name and a column of action buttons:

| Button | Action |
|--------|--------|
| **Open** | Navigates into the playlist |
| **Add Songs** | Opens the `addPopup` for this playlist |
| **Rename** | (Placeholder for rename functionality) |
| **Delete** | Calls `playlistManager.deletePlaylist(name)` |

---

## 18.5 How the Popups Are Exposed Globally

`PlaylistPopup` is instantiated inside `AppPopups.qml` (Chapter 19), which is loaded by `main.qml`. The popup functions are exposed as global aliases so any view can open them:

```qml
// In main.qml:
property alias addPopup: appPopups.addPopup
property alias playlistMenuPopup: appPopups.playlistMenuPopup

function openAddPopup(manager, name) {
    appPopups.playlistPopups.openAddPopup(manager, name);
}
function openCreatePlaylistPopup(manager) {
    appPopups.playlistPopups.openCreatePlaylistPopup(manager);
}
```

This architecture means `PlaylistDetailsView`, `LibraryView`, and any other view can call `openAddPopup()` or `openCreatePlaylistPopup()` without needing a direct reference to the popup component.


<div class="page-break"></div>

<a id="19_qml_popup_architecture.md"></a>

# Chapter 19 — AppPopups: Centralized Popup Architecture

## 19.1 The Problem This Solves

Before `AppPopups.qml` existed, popups were defined inline in whichever QML file needed them — volume controls in `main.qml`, settings in `LibraryView.qml`, playlist popups in `PlaylistDetailsView.qml`, and so on. This led to:

- **Duplication**: The same popup (e.g., queue drawer) was needed from multiple views
- **Access issues**: A popup defined in `LibraryView.qml` couldn't be opened from `MinimalView.qml`
- **Z-order bugs**: Popups nested inside views would render behind other views
- **Maintenance pain**: Changing a popup's behavior required hunting through multiple files

The solution: extract **all popups** into a single file (`AppPopups.qml`) that lives at the root level of the QML scene graph. Individual views access popups through global aliases.

---

## 19.2 Architecture

```
main.qml
  ├── AppPopups { id: appPopups }     ← All popups live here
  │     ├── volumeOSDPopup
  │     ├── mainMenuPopup
  │     ├── settingsPopup
  │     ├── eqPopup
  │     ├── volumePopup
  │     ├── nowPlayingPopup
  │     ├── shortcutsPopup
  │     ├── supportPopup
  │     ├── scanningPopup
  │     ├── queueDrawer
  │     └── PlaylistPopup (addPopup, createPlaylistPopup, playlistMenuPopup)
  │
  ├── LibraryView { }                 ← Opens popups via root aliases
  ├── MinimalView { }                 ← Opens popups via root aliases
  └── GamepadControl { }              ← References popups via root aliases
```

### How Aliases Work

`AppPopups.qml` exposes each popup via `property alias`:

```qml
// AppPopups.qml
Item {
    id: root
    anchors.fill: parent

    // Exposed aliases
    property alias volumeOSDPopup: volumeOSDPopup
    property alias mainMenuPopup: mainMenuPopup
    property alias settingsPopup: settingsPopup
    property alias eqPopup: eqPopup
    property alias volumePopup: volumePopup
    property alias nowPlayingPopup: nowPlayingPopup
    property alias shortcutsPopup: shortcutsPopup
    property alias supportPopup: supportPopup
    property alias scanningPopup: scanningPopup
    property alias queueDrawer: queueDrawer
    property alias queueListView: queueListView

    // ... popup definitions below ...
}
```

`main.qml` then re-exports these to the root window:

```qml
ApplicationWindow {
    id: root

    AppPopups {
        id: appPopups
        window: root
    }

    // Root-level aliases: any child view can access these
    property alias volumeOSDPopup: appPopups.volumeOSDPopup
    property alias mainMenuPopup: appPopups.mainMenuPopup
    // ... etc
}
```

Any QML view anywhere in the scene tree can then call:
```qml
mainMenuPopup.open()
nowPlayingPopup.open()
queueDrawer.open()
```

---

## 19.3 Dependency Injection

`AppPopups` needs access to several objects from the main window context. These are passed in as properties:

```qml
AppPopups {
    id: appPopups
    window: root                           // For window state (fullscreen, close, etc.)
    globalGamepadManager: gamepadControl   // For gamepad zone evaluation
    folderDialog: folderDialogInstance      // For settings → add folder
    sessionSettings: sessionSettingsObj     // For session persistence
}
```

Inside `AppPopups.qml`, convenience properties map window state:

```qml
property string launchMode: window && window.launchMode ? window.launchMode : "Library"
property string applicationVersion: window && window.applicationVersion
    ? window.applicationVersion : "1.3-beta"
```

---

## 19.4 Complete Popup Inventory

| # | Popup ID | Type | Size | Modal | Purpose |
|---|----------|------|------|-------|---------|
| 1 | `volumeOSDPopup` | Popup | 250×60 | No | Transient volume level indicator (auto-closes) |
| 2 | `mainMenuPopup` | Popup | 520×520 | Yes | App main menu (Library, Now Playing, Queue, EQ, Settings, etc.) |
| 3 | `settingsPopup` | Popup | 600×500 | Yes | Library folder management, rescanning |
| 4 | `eqPopup` | Popup | 600×520 | Yes | Wraps `EqualizerView.qml` inside a popup |
| 5 | `volumePopup` | Popup | 200×300 | No | Vertical volume slider popup |
| 6 | `nowPlayingPopup` | Popup | Full window | Yes | Full-screen overlay wrapping `NowPlayingView.qml` |
| 7 | `shortcutsPopup` | Popup | 550×540 | Yes | Keyboard/gamepad shortcut reference table |
| 8 | `supportPopup` | Popup | 500×440 | Yes | About/support information |
| 9 | `scanningPopup` | Popup | 300×180 | Yes | Scanning progress indicator (shown during directory scan) |
| 10 | `queueDrawer` | Drawer | 350×full | No | Side drawer showing the playback queue |
| 11 | `playlistPopups` | Item | various | Yes | Bundles `addPopup`, `createPlaylistPopup`, `playlistMenuPopup` |

### Modal vs. Non-Modal

- **Modal popups** (`modal: true`) dim the background and capture all input until closed. Used for popups that require focus (settings, EQ, shortcuts).
- **Non-modal popups** (`modal: false`) allow the user to continue interacting with the main UI. Used for transient indicators (volume OSD) and supplementary panels (queue drawer, volume slider).

---

## 19.5 Volume OSD — Pattern for Transient Popups

The Volume OSD is a good example of a transient, self-closing popup:

```qml
Popup {
    id: volumeOSDPopup
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose   // We control closing ourselves

    Timer {
        id: volumeOSDTimer
        interval: 1500
        onTriggered: volumeOSDPopup.close()
    }

    // Called externally:
    function show() {
        volumeOSDPopup.open();
        volumeOSDTimer.restart();   // Reset the auto-close timer
    }
}
```

Key design choices:
- `focus: false` — the OSD must not steal keyboard focus from the player
- `closePolicy: Popup.NoAutoClose` — we manage closing via the timer, not clicks
- `Timer.restart()` — if the user keeps adjusting volume, the popup stays open and the timer resets each time

---

## 19.6 Queue Drawer — The Side Panel

The `queueDrawer` uses Qt Quick Controls' `Drawer` type instead of `Popup`:

```qml
Drawer {
    id: queueDrawer
    edge: Qt.RightEdge
    width: 350
    height: parent.height
    modal: false          // User can still interact with the player

    ListView {
        id: queueListView
        model: root.window ? root.window.playbackQueue : []
        // ... track delegates with cover art, title, artist
    }
}
```

The drawer slides in from the right edge and displays the current playback queue. It is non-modal, so the user can keep the queue visible while browsing the library.

---

## 19.7 Scanning Progress Popup — Signal Integration

The scanning popup demonstrates how a popup can react to C++ signals:

```qml
Popup {
    id: scanningPopup
    modal: true
    closePolicy: Popup.NoAutoClose   // Cannot close while scanning

    Connections {
        target: libraryScanner
        function onScanFinished(count) {
            scanningPopup.close();
        }
    }

    BusyIndicator { running: scanningPopup.opened }
    Text { text: "Scanning for music..." }
}
```

The popup opens when the user clicks "Rescan" in settings, and automatically closes when the C++ `LibraryScanner` emits `scanFinished()`. The `NoAutoClose` policy prevents the user from dismissing it prematurely.


<div class="page-break"></div>

<a id="20_launch_modes_and_ipc.md"></a>

# Chapter 20 — Launch Modes and Single-Instance IPC

When a user double-clicks an audio file in a file manager, or selects multiple files and opens them, the OS spawns the application with those file paths as command-line arguments. This chapter explains how MLP Player handles these situations correctly — launching the right UI, and preventing multiple windows from opening.

---

## 20.1 The Problem: Multiple File Selections

When a user selects five `.mp3` files and double-clicks them in Nautilus or Dolphin, the file manager typically:

1. Reads the `MimeType=` field from `MusicPlayer.desktop`
2. Confirms our app handles `audio/mpeg`
3. **Spawns one process per file**, each with one file path as `argv[1]`

Without any protection, this results in five separate application windows. This is the problem the IPC system solves.

> **Note:** Since v1.3, the IPC behaviour is **mode-dependent**. Minimal and Queue mode instances are single-instanced (redirected to the primary window). Library mode instances always open a new, independent window.

---

## 20.2 The Three Launch Modes

`main.cpp` reads `argv` immediately after app construction and classifies the launch into one of three modes:

```cpp
QStringList args     = QCoreApplication::arguments();
QStringList filepath = args.mid(1);   // argv[0] is the executable

QString launchMode;
if (filepath.isEmpty())        launchMode = "Library";
else if (filepath.size() == 1) launchMode = "Minimal";
else                           launchMode = "Queue";
```

| Mode | Trigger | Window | Data Source |
|---|---|---|---|
| **Library** | Launched via app icon or launcher (no args) | 1260×768 Maximised | SQLite database via `loadDatabase()` |
| **Minimal** | One audio file opened via file manager | 700×350 Windowed | Single file via `loadSpecificFiles([file])` |
| **Queue** | Multiple audio files opened at once | 700×350 Windowed | All files via `loadSpecificFiles(files)` |

`launchMode` is then exposed to QML as a context property:
```cpp
engine.rootContext()->setContextProperty("launchMode", launchMode);
```

---

## 20.3 Impact on QML Layout

The `launchMode` string drives the entire UI layout from a single root decision in `main.qml`:

```qml
ApplicationWindow {
    width:      launchMode === "Library" ? 1260 : 700
    height:     launchMode === "Library" ?  768 : 350
    visibility: launchMode === "Library" ? Window.Maximized : Window.Windowed

    // Library mode: show full browser UI
    Item {
        visible: launchMode === "Library"
        LibraryView { id: libraryViewMain; anchors.fill: parent }
    }

    // Minimal/Queue mode: show compact now-playing view
    Item {
        visible: launchMode !== "Library"
        MinimalView { id: minimalViewMain; anchors.fill: parent }
    }

    // Bottom playback bar and title bar are Library-only
    Rectangle { id: titleBar;    visible: launchMode === "Library" ... }
    Rectangle { id: playbackBar; visible: launchMode === "Library" ... }
}
```

> **Key design principle:** `launchMode` is evaluated **at startup only** and never changes while the app is running. It is a constant string, not a reactive property.

---

## 20.4 `loadSpecificFiles` vs `loadDatabase`

In Library mode, `LibraryScanner::loadDatabase()` reads from the SQLite database (which may contain thousands of tracks). This is appropriate because the full grid browser needs all tracks.

In Minimal/Queue mode, there is no need to open a database at all:

```cpp
// Parses metadata from the provided file list only — no SQLite
void LibraryScanner::loadSpecificFiles(const QStringList &filePaths) {
    QVector<Track> tracks;
    for (const QString &filePath : filePaths) {
        Track track;
        track.filePath = filePath;
        TagLib::FileRef f(filePath.toUtf8().constData());
        if (!f.isNull() && f.tag()) {
            TagLib::Tag *tag = f.tag();
            track.title  = QString::fromStdWString(tag->title().toWString());
            track.artist = QString::fromStdWString(tag->artist().toWString());
            // ... cover art detection ...
        }
        tracks.append(track);
    }
    m_tracks = tracks;
    emit tracksAdded(tracks);
}
```

This approach is intentional:
- **Faster startup** — no SQL connection, no disk I/O beyond the files themselves
- **No pollution** — these files are not stored in the library database
- **Isolation** — the Minimal view is completely independent of the library state

---

## 20.5 Single-Instance IPC: The Socket Mechanism

To prevent five windows from spawning when a user selects five files, we use a Unix domain socket named `MLP_MusicPlayerIPC`.

**Every launch** (primary or secondary) starts by probing the socket:

```cpp
bool isIpcServerRunning = false;
QLocalSocket socket;
socket.connectToServer("MLP_MusicPlayerIPC");

if (socket.waitForConnected(500)) {
    isIpcServerRunning = true;
    if (launchMode != "Library") {
        // Secondary Minimal/Queue instance — send files and exit
        if (!filepath.isEmpty()) {
            socket.write(filepath.join('\n').toUtf8());
            socket.waitForBytesWritten(1000);
        }
        return 0;   // Exit — no window created
    }
    // Library mode — disconnect and continue as a new instance
    socket.disconnectFromServer();
}

// No server running, or Library mode fell through — continue as primary instance
```

The key difference from a traditional single-instance guard: **Library mode never exits early**. If a user explicitly opens the app from the launcher, a new full Library window is always created, even if another Library window is already open.

The 500ms timeout is generous enough to handle a slow primary startup but short enough not to make the OS file association feel laggy.

---

## 20.6 The IPC Server (Primary Instance)

Once the primary instance passes the socket probe, it binds the server socket to accept future connections — but **only if no server is already running**:

```cpp
if (!isIpcServerRunning) {
    QLocalServer::removeServer("MLP_MusicPlayerIPC");  // Clean stale socket file
    QLocalServer *server = new QLocalServer(&app);
    server->listen("MLP_MusicPlayerIPC");

    QObject::connect(server, &QLocalServer::newConnection,
        [&libraryScanner, server]() {
            QLocalSocket *clientSocket = server->nextPendingConnection();

            QObject::connect(clientSocket, &QLocalSocket::readyRead,
                [&libraryScanner, clientSocket]() {
                    QByteArray data = clientSocket->readAll();
                    QStringList newFiles = QString::fromUtf8(data)
                        .split('\n', Qt::SkipEmptyParts);
                    if (!newFiles.isEmpty()) {
                        libraryScanner.appendSpecificFiles(newFiles);
                    }
                });

            QObject::connect(clientSocket, &QLocalSocket::disconnected,
                             clientSocket, &QLocalSocket::deleteLater);
        });
}
```

The `!isIpcServerRunning` guard prevents a Library mode instance from trying to bind a socket that a Minimal/Queue instance already owns. This avoids `listen()` failures due to address-in-use errors.

`QLocalServer::removeServer()` removes the socket file from the filesystem if a previous crash left it behind. Without this, the listen call would fail.

---

## 20.7 `appendSpecificFiles` — Append Without Reset

When the primary instance receives new file paths over the socket, it calls `appendSpecificFiles` (not `loadSpecificFiles`):

```cpp
void LibraryScanner::appendSpecificFiles(const QStringList &filePaths) {
    QVector<Track> newTracks;

    for (const QString &filePath : filePaths) {
        // parse tags from filePath...
        newTracks.append(track);
    }

    // Append to existing track list — do NOT clear it
    m_tracks.append(newTracks);

    // Emit the append signal (not tracksAdded)
    emit tracksAppended(newTracks);
}
```

The critical difference between `tracksAdded` and `tracksAppended`:

| Signal | TrackModel handler | Effect |
|---|---|---|
| `tracksAdded` | `setTracks()` → `beginResetModel` | Clears the model entirely, repopulates |
| `tracksAppended` | `addTracks()` → `beginInsertRows` | Adds rows at the end without disturbing existing data |

Using `beginInsertRows` instead of `beginResetModel` means:
- The existing queue is not lost
- Currently playing track continues uninterrupted
- QML animations (e.g., queue drawer add transition) fire correctly

---

## 20.8 QML Response: `onTracksAppended`

`main.qml` listens for both signals on `libraryScanner`:

```qml
Connections {
    target: libraryScanner

    function onTracksAdded(tracks) {
        // Full replacement: update queue from entire model
        // Used at startup (Library mode) and after directory scans
        if (!startupRestoreTimer.running && trackModel.rowCount() > 0) {
            let newQueue = [];
            for (let i = 0; i < trackModel.rowCount(); i++) {
                newQueue.push(trackModel.get(i));
            }
            window.playbackQueue = newQueue;
            window.playTrackAtIndex(0, "IPC");
        }
    }

    function onTracksAppended(tracks) {
        // Append-only: add new tracks to the existing queue
        // Used when secondary instances send their files via IPC
        if (window.visibility !== Window.Hidden) {
            let newQueue = [];
            for (let i = 0; i < trackModel.rowCount(); i++) {
                newQueue.push(trackModel.get(i));
            }

            let wasEmpty = window.playbackQueue.length === 0;
            window.playbackQueue = newQueue;

            if (wasEmpty) {
                window.playTrackAtIndex(0, "IPC");  // Autoplay if nothing was playing
            }
            // If already playing: new tracks are in queue but playback continues
        }
    }
}
```

---

## 20.9 Complete Multi-File Flow Example

```
User selects 5 MP3 files in Dolphin and presses Enter

OS calls MusicPlayer.desktop → Exec %F handles 5 files:
  Spawns: MusicPlayer file1.mp3
  Spawns: MusicPlayer file2.mp3
  Spawns: MusicPlayer file3.mp3
  Spawns: MusicPlayer file4.mp3
  Spawns: MusicPlayer file5.mp3

Process 1 (file1.mp3):
  IPC probe → no server running → becomes primary instance
  launchMode = "Minimal" (one file)
  loadSpecificFiles([file1.mp3])
  Binds QLocalServer → "MLP_MusicPlayerIPC"
  Opens MinimalView window → starts playing file1.mp3

Process 2 (file2.mp3), arriving ~50ms later:
  IPC probe → connects to Process 1's server
  launchMode = "Minimal" → single-instanced → sends file and exits
  return 0 → Process 2 exits (no window)

Process 3-5, similarly:
  Each sends their filepath and exits immediately

Primary instance (Process 1):
  Receives "file2.mp3", "file3.mp3", "file4.mp3", "file5.mp3" via readyRead
  appendSpecificFiles([file2, file3, file4, file5])
  Queue: [file1*, file2, file3, file4, file5]  (* = currently playing)
```

**Result**: One window, correct queue, playback of file1 starts immediately, files 2-5 are queued.

---

## 20.10 Library Mode: Independent Windows

```
User clicks "MLP Player" in KDE launcher
  Process A: IPC probe → no server → becomes primary
  launchMode = "Library"
  Binds QLocalServer
  Opens full Library window

User clicks "MLP Player" in launcher again
  Process B: IPC probe → connects to Process A's server
  launchMode = "Library" → NOT single-instanced → disconnects
  isIpcServerRunning = true → skips binding a new server
  Opens its own full Library window

Result: Two independent Library windows, each with its own state
```

This design allows power users to have multiple Library windows open simultaneously — each browsing different artists or albums — while file-manager launches always consolidate into a single Minimal/Queue window.



<div class="page-break"></div>

<a id="21_os_integration.md"></a>

# Chapter 21 — OS Integration: Desktop File and MIME Registration

This chapter explains how MLP Player integrates with the Linux desktop environment — registering itself as an audio player, appearing in the application launcher, and receiving files from the file manager.

---

## 21.1 What Is a `.desktop` File?

A `.desktop` file is a standardised text file defined by the [freedesktop.org Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/). It tells the desktop environment:

- What the application is named and where to find its icon
- Which command to run to launch it
- Which file types (MIME types) it can open

Without a `.desktop` file, the OS application launcher and file managers don't know the app exists.

---

## 21.2 MusicPlayer.desktop — Full Contents

```desktop
[Desktop Entry]
Name=MLP Player
Comment=A modern local music player built with Qt
Type=Application
Exec=sh -c 'exec "$HOME/.var/app/com.musicplayer.mlmPlayer/MusicPlayer" "$@"' dummy %F
Icon=MusicPlayer
Categories=Audio;Player;Music;
Terminal=false
StartupNotify=true
MimeType=audio/aac;audio/x-flac;audio/flac;audio/mp4;audio/mpeg;audio/mpegurl;audio/ogg;audio/vnd.rn-realaudio;audio/vorbis;audio/x-mp3;audio/x-mpegurl;audio/x-ms-wma;audio/x-musepack;audio/x-oggflac;audio/x-pn-realaudio;audio/x-scpls;audio/x-speex;audio/x-vorbis+ogg;audio/x-wav;audio/wav;
```

---

## 21.3 The `Exec` Field — Portable Path Resolution

Hardcoding an absolute path like `Exec=/home/lordtael125/.var/...` would make the desktop file non-portable — it would break on any other machine.

Instead, the `Exec` field uses a shell wrapper:

```desktop
Exec=sh -c 'exec "$HOME/.var/app/com.musicplayer.mlmPlayer/MusicPlayer" "$@"' dummy %F
```

Breaking this down:

| Part | Meaning |
|---|---|
| `sh -c '...'` | Run the given string in a new `/bin/sh` shell |
| `exec "$HOME/..."` | Replace the shell process with the binary (no extra process left behind) |
| `"$HOME"` | Resolves to the current user's home directory at runtime (portable!) |
| `"$@"` | Passes all arguments to the binary |
| `dummy` | The `$0` (shell name) placeholder — required by `sh -c` when using `$@` |
| `%F` | Freedesktop placeholder: replaced by a list of all selected files |

### `%F` vs `%f`

| Placeholder | Behaviour |
|---|---|
| `%F` | All selected files are passed to a **single** process launch |
| `%f` | The app is launched **once per file** (creates multiple processes) |

We use `%F` so that selecting 10 files results in one process with 10 arguments — which our IPC system then handles correctly (see Chapter 20).

---

## 21.4 MIME Type List

The `MimeType=` line is what tells file managers and the OS "this app can open these file types." Our registration covers all common audio formats:

| MIME Type | Format |
|---|---|
| `audio/mpeg` | MP3 |
| `audio/x-mp3` | MP3 (alternative MIME) |
| `audio/x-flac` / `audio/flac` | FLAC lossless |
| `audio/mp4` | M4A / AAC in MP4 container |
| `audio/aac` | Raw AAC |
| `audio/ogg` | Ogg Vorbis |
| `audio/x-vorbis+ogg` | Ogg Vorbis (alternative MIME) |
| `audio/x-wav` / `audio/wav` | WAV uncompressed |
| `audio/x-ms-wma` | Windows Media Audio |
| `audio/mpegurl` / `audio/x-mpegurl` | M3U playlists |
| `audio/x-scpls` | PLS playlists |
| `audio/vorbis` | Vorbis codec |
| `audio/x-speex` | Speex codec |
| `audio/x-musepack` | Musepack |
| `audio/vnd.rn-realaudio` / `audio/x-pn-realaudio` | RealAudio |

When you right-click an audio file and choose "Open With", MLP Player will appear in the list because of these registrations.

---

## 21.5 User-Space Installation (No Root Required)

Standard application installs require root (`sudo make install`) and place files in `/usr/`, which needs admin rights. MLP Player instead installs into the user's own home directory.

### Install Destinations

| File | Destination |
|---|---|
| `MusicPlayer` binary | `~/.var/app/com.musicplayer.mlmPlayer/MusicPlayer` |
| `MusicPlayer.desktop` | `~/.local/share/applications/MusicPlayer.desktop` |
| `AppIcon.png` | `~/.local/share/icons/hicolor/512x512/apps/MusicPlayer.png` |

These paths follow the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/). All freedesktop-compliant desktops (GNOME, KDE, XFCE, etc.) check `~/.local/share/` for user-installed applications.

### CMakeLists.txt Install Rules

```cmake
install(TARGETS MusicPlayer
    RUNTIME DESTINATION "$ENV{HOME}/.var/app/com.musicplayer.mlmPlayer")

install(FILES "Dist/Linux/MusicPlayer.desktop"
    DESTINATION "$ENV{HOME}/.local/share/applications")

install(FILES "Dist/Linux/AppIcon.png"
    DESTINATION "$ENV{HOME}/.local/share/icons/hicolor/512x512/apps"
    RENAME MusicPlayer.png)
```

`$ENV{HOME}` in CMake resolves to the home directory of the user running `make install`. This ensures portability.

---

## 21.6 Registering MIME Associations

After running `make install`, the desktop file is on disk but the MIME database doesn't know about it yet. You must update it:

```bash
update-desktop-database ~/.local/share/applications
```

This reads all `.desktop` files in the user applications directory, parses their `MimeType=` declarations, and writes a binary MIME database cache (`mimeinfo.cache`).

After this command:
- Double-clicking an `.mp3` file will offer MLP Player as a handler
- `xdg-open song.flac` will launch MLP Player
- The app appears in "Open With" menus for all registered MIME types

> **Note:** On some desktops (GNOME), you may also need `update-mime-database ~/.local/share/mime` if you have custom MIME type XML files.

---

## 21.7 Icon Resolution

The icon name in the `.desktop` file is:
```desktop
Icon=MusicPlayer
```

This is a **name**, not a path. The desktop environment searches for it in the icon theme directories. Since we install to:
```
~/.local/share/icons/hicolor/512x512/apps/MusicPlayer.png
```

The `hicolor` theme (the fallback theme on all freedesktop-compliant desktops) will find it automatically. The `512x512` size folder means the system can scale it to any size (16px launcher, 48px file manager, 256px Dock).

---

## 21.8 Testing the Integration

After `make install` and `update-desktop-database`:

```bash
# Verify the desktop file is valid
desktop-file-validate ~/.local/share/applications/MusicPlayer.desktop

# Test MIME association
xdg-open /path/to/song.mp3

# Test multi-file launch (simulates file manager selection)
MusicPlayer song1.mp3 song2.mp3 song3.mp3

# Check which app handles audio/mpeg
xdg-mime query default audio/mpeg
```


<div class="page-break"></div>

<a id="22_dataflow.md"></a>

# Chapter 22 — Complete System Dataflow

This chapter ties everything together with detailed data flow diagrams covering the three major user journeys.

---

## 22.1 Application Startup Flow

- **Program starts** &rarr; `main()` runs
  - `[TagLib]` Silence debug output
  - `[Qt]` Set Material Dark theme env vars
  - `QApplication` app constructed
  - Parse command-line arguments (`argv`)
    - `filepath = args.mid(1)` (list of files passed by file manager)
  - IPC probe: `QLocalSocket` &rarr; `MLP_MusicPlayerIPC`
    - **Socket connects** &rarr; primary instance is running
      - Send filepath over socket and `return 0` (process ends here)
    - **Socket fails** &rarr; we ARE the primary instance, continue
  - Determine `launchMode`
    - `filepath` empty &rarr; `"Library"`
    - `filepath` size == 1 &rarr; `"Minimal"`
    - `filepath` size > 1 &rarr; `"Queue"`
  - `qmlRegisterUncreatableType<Equalizer>`
  - `AudioEngine` (`audioEngine`) constructed
    - `ma_engine_init()` &rarr; opens system audio device (PulseAudio/WASAPI)
    - `Equalizer *eq = new Equalizer(this)`
    - 10 &times; `ma_peak_node_init()` &rarr; EQ filter chain created
    - 10 &times; `ma_node_attach()` &rarr; chain linked: sound &rarr; EQ0 &rarr; &hellip; &rarr; EQ9 &rarr; speaker
    - `QTimer` starts (250ms interval)
  - `LibraryScanner` (`libraryScanner`) constructed
    - `initializeDatabase()` &rarr; opens/creates `tracks.db` SQLite file
  - `TrackModel` (`trackModel`) constructed
  - `connect(libraryScanner.tracksAdded &rarr; trackModel.setTracks)`
  - `connect(libraryScanner.tracksAppended &rarr; trackModel.addTracks)`
  - Load initial data:
    - `launchMode == "Library"` &rarr; `libraryScanner.loadDatabase()`
    - otherwise &rarr; `libraryScanner.loadSpecificFiles(filepath)`
  - Bind `QLocalServer` to `"MLP_MusicPlayerIPC"`
  - `QQmlApplicationEngine` `engine` constructed
  - `engine.addImageProvider("musiccover", new CoverArtProvider)`
  - `engine.rootContext()->setContextProperty` &times; 4
    - `"launchMode"`, `"audioEngine"`, `"libraryScanner"`, `"trackModel"` in QML scope
  - `engine.load("qrc:/qml/main.qml")`
    - Qt parses `main.qml`, creates `ApplicationWindow`
    - `launchMode === "Library"`:
      - `LibraryView` created (full window)
    - `launchMode !== "Library"`:
      - `MinimalView` created (compact 700x350 window)
  - `app.exec()` &rarr; Event loop begins
    - `QTimer` fires (from loadDatabase's singleShot):
      - `tracksAdded(allTracks)` &rarr; `trackModel.setTracks(allTracks)`
      - &rarr; `beginResetModel` &rarr; `endResetModel`
      - &rarr; `LibraryView` `GridView` refreshes (shows all cached tracks)

---

## 22.2 "Scan Directory" Flow

```
User: clicks hamburger menu → "Scan Directory"
│
- **User clicks hamburger menu &rarr; "Scan Directory"**
  - `[QML]` `mainMenuPopup.close()`
  - `[QML]` `folderDialog.open()`
  - *(User selects `/home/user/music` in the OS folder picker)*
  - `[QML]` `folderDialog.onAccepted:`
    - `libraryScanner.scanDirectory(folderDialog.folder)` &bull; *(C++ slot called from QML)*
    - `[C++]` `LibraryScanner::scanDirectory(path)`
      - `emit scanStarted()`
        - `[QML]` `Connections.onScanStarted`
        - `scanningPopup.open()` (shows spinner)
      - `QtConcurrent::run` *(BACKGROUND THREAD)*
        - `QDirIterator` walks every subdir
        - For each `.mp3/.flac/.wav/.m4a` found:
          - `TagLib::FileRef` reads tags
          - Check cover art (format-specific code)
          - Build `Track` struct
          - `newTracks.append(track)`
          - `filesProcessed++`
          - `if (filesProcessed % 10 == 0):`
            - `emit scanProgress(filesProcessed)`
              - `[QML]` `Connections.onScanProgress`
              - `scanningLabel.text = "Found N tracks..."`
        - Write `newTracks` to `tracks.db` (SQLite transaction)
        - `QMetaObject::invokeMethod(Qt::QueuedConnection):`
          - *(jumps back to main thread)*
          - `loadDatabase()`
            - reads all rows from DB
            - `emit tracksAdded(allTracks)`
              - *(connect in main.cpp)*
              - `trackModel.setTracks(allTracks)`
                - `beginResetModel`
                - sort by artist/album/disc/track
                - rebuild `displayIndices`
                - `endResetModel`
                - `LibraryView` `GridView` refreshes automatically
          - `emit scanFinished(total)`
            - `[QML]` `Connections.onScanFinished`
            - `scanningPopup.close()`

---

## 22.3 "Play a Song" Flow

```
User: clicks a track tile in LibraryView
- **User clicks a track tile in LibraryView**
  - `[QML]` `MouseArea.onClicked:`
    - `window.playTrackAtIndex(index, "All Tracks")`
  - `[QML function]` `playTrackAtIndex(5, "All Tracks")`
    - `contextCategory` is set &rarr; rebuild queue
      - `for (i = 0..trackModel.rowCount()-1):`
        - `playbackQueue.push(trackModel.get(i))`
      - `currentQueueIndex = 5`
    - `var track = playbackQueue[5]`
    - `window.currentPlayingTitle = track.title`
    - `window.currentPlayingArtist = track.artist`
    - `window.currentPlayingPath = track.filePath`
      - *(all QML text bound to these auto-updates)*
    - `audioEngine.loadFile(track.filePath)` &bull; *(calls C++ slot AudioEngine::loadFile)*
      - `ma_sound_uninit` (previous)
      - `ma_sound_init_from_file` (new file, ASYNC decode)
      - `ma_node_attach(sound &rarr; eqNodes[0])`
      - `emit durationChanged(length)` &rarr; `QML Slider.to` updates
      - `emit positionChanged(0)` &rarr; `QML Slider.value` resets
    - `audioEngine.play()` &bull; *(calls C++ slot AudioEngine::play)*
      - `ma_sound_start(&m_sound)`
      - `emit playingChanged(true)` &bull; *(Q_PROPERTY NOTIFY)*
        - `[QML]` `audioEngine.isPlaying = true`
        - Play/Pause button icon changes to "pause.svg"
  - **[250ms timer fires repeatedly while playing]**
    - `AudioEngine` timer callback:
      - `ma_sound_at_end?` &rarr; `emit playbackFinished()` &rarr; auto-advance
      - `isPlaying?` &rarr; `emit positionChanged(cursor)` &bull; *(Q_PROPERTY NOTIFY)*
        - `[QML]` `Slider.value = audioEngine.position`
        - `[QML]` Time labels update

---

## 22.4 "Seek to Position" Flow

- **User drags the progress slider to new position**
  - `[QML Slider.onMoved]`
    - `audioEngine.position = value` &bull; *(Q_PROPERTY WRITE: calls setPosition)*
  - `[C++ AudioEngine::setPosition(newPos)]`
    - `ma_engine_get_sample_rate` &rarr; `sampleRate`
    - `targetFrame = newPos &times; sampleRate`
    - `ma_sound_seek_to_pcm_frame(&m_sound, targetFrame)`
    - `emit positionChanged(newPos)` &bull; *(Q_PROPERTY NOTIFY)*
      - `[QML]` `Slider.value` and time labels update to confirm the seek

---

## 22.5 "Change EQ Band" Flow

- **User moves EQ slider for band 5 (1kHz)**
  - `[QML EqualizerView Slider.onMoved]`
    - `eq.setBandGain(5, newValue)` &bull; *(Q_INVOKABLE direct call)*
  - `[C++ Equalizer::setBandGain(5, newValue)]`
    - `clampedValue = clamp(newValue, -12, 12)`
    - `m_gains[5] = clampedValue`
    - `emit bandGainChanged(5, clampedValue)` &bull; *(connect in AudioEngine constructor)*
  - `[C++ AudioEngine::onEqualizerBandGainChanged(5, clampedValue)]`
    - `actualGain = eq->isEnabled() ? clampedValue : 0.0f`
    - `ma_peak2_config cfg = ma_peak2_config_init(..., actualGain, ...)`
    - `ma_peak_node_reinit(&m_eqNodes[5], &cfg)`
    - Audio pipeline filter coefficients update instantly
    - Users hears the frequency change in real time
  - `[QML EqualizerView gain label]`
    - `text: eq.bandGain(5)` &rarr; reads new value &rarr; shows "+3.0 dB"
    - (updates because `Slider.onMoved` triggers re-read via binding)

---

## 22.6 Class Dependency Map

- `main.cpp`
  - creates: `AudioEngine`
    - owns: `Equalizer` (child QObject)
    - uses: `miniaudio` (`ma_engine`, `ma_sound`, `ma_peak_node[10]`)
    - uses: `QTimer` (250ms heartbeat)
  - creates: `LibraryScanner`
    - uses: `TagLib` (reads tags)
    - uses: `QSqlDatabase` (SQLite persistence)
    - uses: `QtConcurrent` (background threads)
    - uses: `QDirIterator` (filesystem walk)
  - creates: `TrackModel`
    - contains: `QVector<Track>` (all tracks in memory)
    - contains: `QVector<int>` (display filter indices)
  - connects: `LibraryScanner.tracksAdded` &rarr; `TrackModel.setTracks`
  - connects: `LibraryScanner.tracksAppended` &rarr; `TrackModel.addTracks`
  - creates: `QLocalServer` (`"MLP_MusicPlayerIPC"`)
    - receives: file paths from secondary instances
    - calls: `LibraryScanner.appendSpecificFiles()`
  - exposes via `setContextProperty`:
    - `"launchMode"` &rarr; `QString` constant (`"Library"`/`"Minimal"`/`"Queue"`)
    - `"audioEngine"` &rarr; `AudioEngine*`
    - `"libraryScanner"` &rarr; `LibraryScanner*`
    - `"trackModel"` &rarr; `TrackModel*`
  - registers: `CoverArtProvider` under `"musiccover"`
    - uses: `TagLib` (reads embedded images)
    - uses: `QImage` (decodes JPEG/PNG bytes)

---

## 22.7 IPC — Secondary Launch → Queue Update Flow

- **User selects 3 audio files in file manager and double-clicks to open**
  - OS spawns `Process 2` (and possibly 3, 4...) with file paths as `argv`
  - **Process 2**: `main()` starts
    - `QLocalSocket.connectToServer("MLP_MusicPlayerIPC")`
      - **Success!** Primary instance is running
        - `socket.write("track_b.mp3\ntrack_c.mp3")`
        - `return 0` &bull; *(Process 2 exits immediately)*
      - **Failure**: no primary instance yet (first ever launch)
        - continue with normal startup ...
  - **Primary instance** (already running) — `QLocalServer` event:
    - `newConnection` signal fires
    - `clientSocket->readAll()` &rarr; `"track_b.mp3\ntrack_c.mp3"`
    - `libraryScanner.appendSpecificFiles(["track_b.mp3", "track_c.mp3"])`
      - Parses tags with `TagLib` (lightweight, no SQLite)
      - `m_tracks.append(newTracks)` *(does NOT clear existing tracks)*
      - `emit tracksAppended(newTracks)`
        - *(connect in main.cpp)* &rarr; `trackModel.addTracks(newTracks)`
        - `beginInsertRows` / `endInsertRows` (no reset)
        - QML queue `ListView` appends items
    - `[QML]` `Connections.onTracksAppended` fires:
      - `let newQueue = rebuild from trackModel`
      - `window.playbackQueue = newQueue`
      - `if (was empty) window.playTrackAtIndex(0, "IPC")` *(autoplay)*
    - Existing playback continues undisturbed if queue was not empty


<div class="page-break"></div>

<a id="23_building_and_packaging.md"></a>

# Chapter 23 — Building, Running, and Packaging

## 23.1 Development Build (Linux)

### Prerequisites
```bash
sudo apt update
sudo apt install -y \
    cmake build-essential \
    qt5-default qtbase5-dev qtdeclarative5-dev \
    qml-module-qt-labs-platform \
    qml-module-qt-labs-settings \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    libqt5sql5-sqlite libqt5concurrent5 \
    libqt5network5 qt5-default \
    libtag1-dev libtagc0-dev \
    pkg-config
```

### Build Steps
```bash
# From the project root:
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
./MusicPlayer
```

### Release Build (Optimized)
```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

`Release` enables `-O2` optimization and disables debug symbols, producing a much faster binary.

---

## 23.2 Common Build Errors and Fixes

### Error: `Qt5 not found`
```
CMake Error: Could not find Qt5
```
**Fix**: Install Qt5 development packages.
```bash
sudo apt install qt5-default qtbase5-dev qtdeclarative5-dev
```

### Error: `taglib not found`
```
Package 'taglib' not found
```
**Fix**:
```bash
sudo apt install libtag1-dev pkg-config
```

### Error: `moc` failing / `Q_OBJECT` not recognized
Usually means CMake didn't enable `AUTOMOC`. Check `CMakeLists.txt` has:
```cmake
set(CMAKE_AUTOMOC ON)
```

### Error: `QSqlDatabase: QSQLITE driver not loaded`
```bash
sudo apt install libqt5sql5-sqlite
```

---

## 23.3 Project File Structure for IDE (Qt Creator)

Qt Creator can open the project directly from `CMakeLists.txt`:
1. Open Qt Creator → File → Open File or Project
2. Select `Music Player/CMakeLists.txt`
3. Qt Creator auto-detects the CMake project
4. Choose a Debug kit → Configure Project
5. Press Ctrl+R to build and run

Qt Creator provides:
- QML live preview (Qt Quick Designer)
- Integrated debugger with C++ and QML stacks
- Signal/slot visualizer

---

## 23.4 Creating a Linux AppImage

An AppImage bundles all Qt dependencies into a single portable file that runs on any Linux distro.

### What the build script does

The project includes `build_appimage.sh`:
```bash
#!/bin/bash
set -e

# Step 1: Build the release binary
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
make install DESTDIR=AppDir   # Install into AppDir/

# Step 2: Use linuxdeployqt to bundle Qt libraries
../linuxdeployqt-continuous-x86_64.AppImage \
    AppDir/usr/bin/MusicPlayer \
    -qmldir=../qml \             # Let it find QML imports to include
    -appimage \                   # Package as AppImage
    -no-translations
```

`linuxdeployqt`:
1. Finds which shared libraries `MusicPlayer` needs (`ldd MusicPlayer`)
2. Copies those `.so` files into the AppDir
3. Copies the necessary Qt plugins (SQL, Image, QML plugins)
4. Creates a launcher script
5. Packages everything into a self-contained `.AppImage` file

### Running the AppImage
```bash
chmod +x MusicPlayer-x86_64.AppImage
./MusicPlayer-x86_64.AppImage
```

---

## 23.5 Building on Windows with MSYS2

### Setup
1. Install [MSYS2](https://www.msys2.org/)
2. Open "MSYS2 MinGW 64-bit" shell
3. Install dependencies:
```bash
pacman -S mingw-w64-x86_64-qt5-base \
           mingw-w64-x86_64-qt5-declarative \
           mingw-w64-x86_64-qt5-quickcontrols2 \
           mingw-w64-x86_64-taglib \
           mingw-w64-x86_64-cmake \
           mingw-w64-x86_64-gcc
```

### Build
```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
mingw32-make -j4
```

### Deploying the Windows .exe
```bash
# windeployqt copies required Qt DLLs next to the .exe
windeployqt --qmldir ../qml MusicPlayer.exe
```

Copy the resulting folder (containing MusicPlayer.exe and DLLs) to a ZIP file for distribution.

---

## 23.6 The `.qrc` Resource System — How Files Get Into the Binary

Two resource files pack content into the binary:

**qml.qrc**:
```xml
<RCC>
  <qresource prefix="/qml">
    <file>qml/main.qml</file>
    <file>qml/LibraryView.qml</file>
    <file>qml/EqualizerView.qml</file>
    <file>qml/NowPlayingView.qml</file>
    <file>qml/MinimalView.qml</file>
  </qresource>
</RCC>
```

**icons.qrc**:
```xml
<RCC>
  <qresource prefix="/qml/icons">
    <file>qml/icons/play.svg</file>
    <file>qml/icons/pause.svg</file>
    <file>qml/icons/next.svg</file>
    <file>qml/icons/prev.svg</file>
    <file>qml/icons/volume.svg</file>
    <file>qml/icons/eq.svg</file>
    <!-- ...all other icons... -->
  </qresource>
</RCC>
```

The `qt5_add_resources(RESOURCES qml.qrc icons.qrc)` CMake call runs `rcc` to embed these files. At runtime, they're accessed as:
- `qrc:/qml/main.qml` — by the engine.load() call
- `qrc:/qml/icons/play.svg` — by QML Image sources

---

## 23.7 Runtime Data Storage

The app stores data in the platform's standard application data directory:

| Platform | Path |
|---------|------|
| Linux | `~/.local/share/MusicPlayer/tracks.db` |
| Windows | `C:\Users\<user>\AppData\Roaming\MusicPlayer\tracks.db` |

EQ presets (QSettings):
| Platform | Path |
|---------|------|
| Linux | `~/.config/LordTael/MLP Player.ini` |
| Windows | Windows Registry: `HKCU\Software\LordTael\MLP Player` |

---

## 23.8 User-Space Installation (No sudo Required)

The app can be installed for the current user only — no root privileges needed:

```bash
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install   # Installs under $HOME — no sudo
```

Install targets:
| File | Destination |
|---|---|
| `MusicPlayer` binary | `~/.var/app/com.musicplayer.mlmPlayer/MusicPlayer` |
| `MusicPlayer.desktop` | `~/.local/share/applications/MusicPlayer.desktop` |
| `AppIcon.png` | `~/.local/share/icons/hicolor/512x512/apps/MusicPlayer.png` |

After install, register MIME types:
```bash
update-desktop-database ~/.local/share/applications
```

The `.desktop` file `Exec` field uses `$HOME` to be portable across any username:
```desktop
Exec=sh -c 'exec "$HOME/.var/app/com.musicplayer.mlmPlayer/MusicPlayer" "$@"' dummy %F
MimeType=audio/mpeg;audio/flac;audio/mp4;audio/ogg;audio/x-wav;...
```

`%F` tells the file manager to pass all selected files as separate arguments to a **single** process launch.

---

## 23.8 Quick Reference: Key Files

| File | Role |
|------|------|
| `CMakeLists.txt` | Build configuration |
| `src/main.cpp` | App entry point, IPC, argument parsing, wires all components |
| `include/track.h` | Plain data struct for one song |
| `include/track_model.h` | Qt model exposing tracks to QML |
| `include/library_scanner.h` | Scans folders, reads tags, writes DB, appends via IPC |
| `include/audio_engine.h` | Plays audio, volume, seek, EQ chain |
| `include/equalizer.h` | 10-band EQ with presets |
| `include/cover_art_provider.h` | Serves album art images to QML |
| `src/track_model.cpp` | Model implementation + sorting/filtering |
| `src/library_scanner.cpp` | TagLib + SQLite + QtConcurrent + appendSpecificFiles |
| `src/audio_engine.cpp` | miniaudio integration |
| `src/equalizer.cpp` | EQ band management + QSettings presets |
| `src/cover_art_provider.cpp` | TagLib image extraction → QImage |
| `qml/main.qml` | Root window, session persistence, playback bar, popups, shortcuts |
| `qml/LibraryView.qml` | Sidebar + tabbed tile grid + StackView |
| `qml/EqualizerView.qml` | 10-band EQ sliders + preset management |
| `qml/NowPlayingView.qml` | Full-screen now playing overlay |
| `qml/MinimalView.qml` | Compact 700x350 now playing for file-manager launches |
| `third_party/miniaudio.h` | Complete audio engine (single header) |
| `Dist/Linux/MusicPlayer.desktop` | OS desktop entry with MIME type declarations |
| `Dist/Linux/build_appimage.sh` | Linux AppImage packaging script |

---

## 23.9 Summary: The Mental Model

When everything is running:

```
                     ┌─────────────────────────┐
                     │      QML Frontend        │
                     │   (main.qml,             │
                     │    LibraryView.qml,       │
                     │    EqualizerView.qml)     │
                     │                          │
                     │  Reads: audioEngine.*     │
                     │  Reads: trackModel.*      │
                     │  Calls: audioEngine.play()│
                     │  Calls: trackModel.filter │
                     └──────────┬──┬────────────┘
                                │  │  (context properties + signals)
          ┌─────────────────────┘  └──────────────┐
          │                                       │
┌─────────▼──────────┐               ┌────────────▼──────────┐
│    AudioEngine     │               │      TrackModel        │
│  miniaudio engine  │               │  QAbstractListModel    │
│  EQ node graph     ◄───signal──────┤  m_allTracks[]         │
│  QTimer heartbeat  │               │  m_displayIndices[]    │
│  Equalizer child   │               └────────────▲──────────┘
└─────────┬──────────┘                            │
          │ sound output                           │ tracksAdded signal
          ▼                                        │
    Audio Device                        ┌──────────┴──────────┐
    (PulseAudio/                        │   LibraryScanner    │
     WASAPI/CoreAudio)                  │  QtConcurrent thread│
                                        │  TagLib tag reading │
                               ┌────────►  SQLite database    │
                               │        └─────────────────────┘
                               │
                         CoverArtProvider
                         (image://musiccover/)
                         TagLib image extraction
```

Every arrow is either a Qt signal/slot connection, a Q_PROPERTY binding, or a direct method call — nothing is global state, nothing is shared memory without synchronization.

Congratulations — you now understand the complete architecture of this music player from the CMake build system all the way to the QML pixels on screen!


<div class="page-break"></div>

