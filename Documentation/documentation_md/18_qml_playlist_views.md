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
