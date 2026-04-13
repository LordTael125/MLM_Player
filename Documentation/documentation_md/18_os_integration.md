# Chapter 18 — OS Integration: Desktop File and MIME Registration

This chapter explains how MLP Player integrates with the Linux desktop environment — registering itself as an audio player, appearing in the application launcher, and receiving files from the file manager.

---

## 18.1 What Is a `.desktop` File?

A `.desktop` file is a standardised text file defined by the [freedesktop.org Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/). It tells the desktop environment:

- What the application is named and where to find its icon
- Which command to run to launch it
- Which file types (MIME types) it can open

Without a `.desktop` file, the OS application launcher and file managers don't know the app exists.

---

## 18.2 MusicPlayer.desktop — Full Contents

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

## 18.3 The `Exec` Field — Portable Path Resolution

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

We use `%F` so that selecting 10 files results in one process with 10 arguments — which our IPC system then handles correctly (see Chapter 16).

---

## 18.4 MIME Type List

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

## 18.5 User-Space Installation (No Root Required)

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

## 18.6 Registering MIME Associations

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

## 18.7 Icon Resolution

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

## 18.8 Testing the Integration

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
