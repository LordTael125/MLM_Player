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
