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
