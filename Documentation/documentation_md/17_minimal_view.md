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
