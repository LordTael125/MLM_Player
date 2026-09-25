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
