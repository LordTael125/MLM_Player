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
