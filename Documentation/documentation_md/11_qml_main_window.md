# Chapter 11 — main.qml: The Root Window

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

## 11.1 ApplicationWindow and Frameless Mode

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

## 11.2 Global State Properties

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

## 11.3 playTrackAtIndex — The Core Playback Function

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

## 11.4 Auto-Advance on Track End

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

## 11.5 The Custom Title Bar

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

## 11.6 The Keyboard Shortcut System

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

## 11.7 The Bottom Playback Bar

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

## 11.8 The Queue Drawer

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

## 11.9 Session Persistence

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
