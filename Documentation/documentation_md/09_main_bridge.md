# Chapter 9 — main.cpp: Wiring Everything Together

`main.cpp` is the entry point of the application. It is intentionally short — its only job is to **create the backend objects, connect them to each other, expose them to QML, and launch the engine**.

## 9.1 The Full main.cpp — Annotated

```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtNetwork/QLocalServer>
#include <QtNetwork/QLocalSocket>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"

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
    // args.mid(1) skips argv[0] (the executable name itself)
    QStringList args = QCoreApplication::arguments();
    QStringList filepath = args.mid(1);

    // ─── Step 6: Single-Instance IPC Interception ───────────────────────────
    // Every launch probes the named socket. If another instance is already
    // running, it responds immediately. The secondary process sends its
    // file paths and exits — no second window is ever created.
    QLocalSocket socket;
    socket.connectToServer("MLP_MusicPlayerIPC");
    if (socket.waitForConnected(500)) {
        if (!filepath.isEmpty()) {
            socket.write(filepath.join('\n').toUtf8());
            socket.waitForBytesWritten(1000);
        }
        return 0;   // Exit: the primary instance will handle these files
    }

    // ─── Step 7: Determine launch mode ──────────────────────────────────────
    // Library:  no file args    → full window + database load
    // Minimal:  single file arg → compact 700x350 window
    // Queue:    multiple args   → compact window, all files queued
    QString launchMode;
    if (filepath.isEmpty())       launchMode = "Library";
    else if (filepath.size() == 1) launchMode = "Minimal";
    else                           launchMode = "Queue";

    // ─── Step 8: Register Equalizer with QML type system ────────────────────
    qmlRegisterUncreatableType<Equalizer>(
        "com.musicplayer", 1, 0,
        "Equalizer",
        "Equalizer cannot be created in QML"
    );

    // ─── Step 9: Create backend instances on the stack ──────────────────────
    AudioEngine    audioEngine;
    LibraryScanner libraryScanner;
    TrackModel     trackModel;

    // ─── Step 10: Wire scanner → model connections ──────────────────────────
    // tracksAdded:    full replace (library load / initial scan)
    // tracksAppended: append-only (IPC new files added to running instance)
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                     &trackModel,     &TrackModel::setTracks);
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAppended,
                     &trackModel,     &TrackModel::addTracks);

    // ─── Step 11: Load initial data based on launch mode ────────────────────
    if (launchMode == "Library") {
        libraryScanner.loadDatabase();          // Read full SQLite library
    } else {
        libraryScanner.loadSpecificFiles(filepath); // Parse only the given files
    }

    // ─── Step 12: Bind IPC server to accept future secondary launches ────────
    QLocalServer::removeServer("MLP_MusicPlayerIPC");  // Clean up any stale socket
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

    // ─── Step 13: Create QML engine ─────────────────────────────────────────
    QQmlApplicationEngine engine;
    engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

    // ─── Step 14: Expose backend objects + launchMode to QML ────────────────
    engine.rootContext()->setContextProperty("launchMode",    launchMode);
    engine.rootContext()->setContextProperty("audioEngine",   &audioEngine);
    engine.rootContext()->setContextProperty("libraryScanner",&libraryScanner);
    engine.rootContext()->setContextProperty("trackModel",    &trackModel);

    // ─── Step 15: Load root QML and start event loop ─────────────────────────
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

## 9.2 Why Stack Allocation?

```cpp
AudioEngine   audioEngine;     // Stack
LibraryScanner libraryScanner; // Stack
TrackModel    trackModel;      // Stack
```

All three backend objects are created on the stack (no `new`). This means:
- When `main()` returns, they are automatically destroyed in reverse order
- miniaudio and SQLite are properly cleaned up in destructors
- No risk of memory leaks

If they were heap-allocated (`new AudioEngine()`), we'd need `delete` or a smart pointer.

---

## 9.3 The Two Signal Connections in main.cpp

```cpp
// Connection 1: full model replace (library load, directory scan)
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);

// Connection 2: append-only (IPC — secondary instance sends new files)
QObject::connect(&libraryScanner, &LibraryScanner::tracksAppended,
                 &trackModel,     &TrackModel::addTracks);
```

There are now **two** inter-object connections:
- `tracksAdded → setTracks`: clears the model and repopulates (used at startup and after full scans)
- `tracksAppended → addTracks`: inserts rows at the end without resetting the model (used when the IPC server receives new files from a secondary process)

Both objects remain completely ignorant of each other — the coupling lives only here, at the composition root. This is the **Hollywood principle**: "Don't call us. We'll call you."

---

## 9.4 Context Properties vs. qmlRegisterType

There are two ways to expose C++ to QML:

| Method | What It Does | Example |
|--------|-------------|---------|
| `setContextProperty` | Exposes a **single instance** as a global name | `audioEngine.play()` |
| `qmlRegisterType` | Lets QML **create new instances** of a type | `MyType { }` in QML |
| `qmlRegisterUncreatableType` | Lets QML **hold a pointer** to a type but not create one | Used for `Equalizer*` |

We use `setContextProperty` for all three backend objects because there should be exactly **one** audio engine and **one** track model. QML doesn't need to create its own — it uses the single shared instance.

---

## 9.5 qputenv — Theme Configuration

```cpp
qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");
```

These **must** be set before `QApplication` is constructed. The Qt Quick Controls style system reads them during initialization. Setting them afterward has no effect.

Without these, if the user's OS is set to a Light theme, Qt would override the app's dark appearance. The `Dark` override ensures consistent appearance regardless of system theme.

---

## 9.6 The `launchMode` Context Property

`launchMode` is a plain `QString` ("Library", "Minimal", or "Queue") exposed using the same `setContextProperty` pattern:

```cpp
engine.rootContext()->setContextProperty("launchMode", launchMode);
```

In QML, this becomes a global constant that controls window size and which UI component is displayed:

```qml
width:  launchMode === "Library" ? 1260 : 700
height: launchMode === "Library" ? 768  : 350

// Show Library view or Minimal view depending on launch mode
Item { visible: launchMode === "Library";  LibraryView { ... } }
Item { visible: launchMode !== "Library";  MinimalView { ... } }
```

> **Note:** `launchMode` is a constant — it does not change after the app starts. It is not a `Q_PROPERTY`, so QML does not need to notify on it. A plain `setContextProperty` string is sufficient.
