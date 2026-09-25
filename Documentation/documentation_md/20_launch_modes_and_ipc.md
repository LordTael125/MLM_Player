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

