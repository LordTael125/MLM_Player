# Chapter 14 — Complete System Dataflow

This chapter ties everything together with detailed data flow diagrams covering the three major user journeys.

---

## 14.1 Application Startup Flow

- **Program starts** &rarr; `main()` runs
  - `[TagLib]` Silence debug output
  - `[Qt]` Set Material Dark theme env vars
  - `QApplication` app constructed
  - Parse command-line arguments (`argv`)
    - `filepath = args.mid(1)` (list of files passed by file manager)
  - IPC probe: `QLocalSocket` &rarr; `MLP_MusicPlayerIPC`
    - **Socket connects** &rarr; primary instance is running
      - Send filepath over socket and `return 0` (process ends here)
    - **Socket fails** &rarr; we ARE the primary instance, continue
  - Determine `launchMode`
    - `filepath` empty &rarr; `"Library"`
    - `filepath` size == 1 &rarr; `"Minimal"`
    - `filepath` size > 1 &rarr; `"Queue"`
  - `qmlRegisterUncreatableType<Equalizer>`
  - `AudioEngine` (`audioEngine`) constructed
    - `ma_engine_init()` &rarr; opens system audio device (PulseAudio/WASAPI)
    - `Equalizer *eq = new Equalizer(this)`
    - 10 &times; `ma_peak_node_init()` &rarr; EQ filter chain created
    - 10 &times; `ma_node_attach()` &rarr; chain linked: sound &rarr; EQ0 &rarr; &hellip; &rarr; EQ9 &rarr; speaker
    - `QTimer` starts (250ms interval)
  - `LibraryScanner` (`libraryScanner`) constructed
    - `initializeDatabase()` &rarr; opens/creates `tracks.db` SQLite file
  - `TrackModel` (`trackModel`) constructed
  - `connect(libraryScanner.tracksAdded &rarr; trackModel.setTracks)`
  - `connect(libraryScanner.tracksAppended &rarr; trackModel.addTracks)`
  - Load initial data:
    - `launchMode == "Library"` &rarr; `libraryScanner.loadDatabase()`
    - otherwise &rarr; `libraryScanner.loadSpecificFiles(filepath)`
  - Bind `QLocalServer` to `"MLP_MusicPlayerIPC"`
  - `QQmlApplicationEngine` `engine` constructed
  - `engine.addImageProvider("musiccover", new CoverArtProvider)`
  - `engine.rootContext()->setContextProperty` &times; 4
    - `"launchMode"`, `"audioEngine"`, `"libraryScanner"`, `"trackModel"` in QML scope
  - `engine.load("qrc:/qml/main.qml")`
    - Qt parses `main.qml`, creates `ApplicationWindow`
    - `launchMode === "Library"`:
      - `LibraryView` created (full window)
    - `launchMode !== "Library"`:
      - `MinimalView` created (compact 700x350 window)
  - `app.exec()` &rarr; Event loop begins
    - `QTimer` fires (from loadDatabase's singleShot):
      - `tracksAdded(allTracks)` &rarr; `trackModel.setTracks(allTracks)`
      - &rarr; `beginResetModel` &rarr; `endResetModel`
      - &rarr; `LibraryView` `GridView` refreshes (shows all cached tracks)

---

## 14.2 "Scan Directory" Flow

```
User: clicks hamburger menu → "Scan Directory"
│
- **User clicks hamburger menu &rarr; "Scan Directory"**
  - `[QML]` `mainMenuPopup.close()`
  - `[QML]` `folderDialog.open()`
  - *(User selects `/home/user/music` in the OS folder picker)*
  - `[QML]` `folderDialog.onAccepted:`
    - `libraryScanner.scanDirectory(folderDialog.folder)` &bull; *(C++ slot called from QML)*
    - `[C++]` `LibraryScanner::scanDirectory(path)`
      - `emit scanStarted()`
        - `[QML]` `Connections.onScanStarted`
        - `scanningPopup.open()` (shows spinner)
      - `QtConcurrent::run` *(BACKGROUND THREAD)*
        - `QDirIterator` walks every subdir
        - For each `.mp3/.flac/.wav/.m4a` found:
          - `TagLib::FileRef` reads tags
          - Check cover art (format-specific code)
          - Build `Track` struct
          - `newTracks.append(track)`
          - `filesProcessed++`
          - `if (filesProcessed % 10 == 0):`
            - `emit scanProgress(filesProcessed)`
              - `[QML]` `Connections.onScanProgress`
              - `scanningLabel.text = "Found N tracks..."`
        - Write `newTracks` to `tracks.db` (SQLite transaction)
        - `QMetaObject::invokeMethod(Qt::QueuedConnection):`
          - *(jumps back to main thread)*
          - `loadDatabase()`
            - reads all rows from DB
            - `emit tracksAdded(allTracks)`
              - *(connect in main.cpp)*
              - `trackModel.setTracks(allTracks)`
                - `beginResetModel`
                - sort by artist/album/disc/track
                - rebuild `displayIndices`
                - `endResetModel`
                - `LibraryView` `GridView` refreshes automatically
          - `emit scanFinished(total)`
            - `[QML]` `Connections.onScanFinished`
            - `scanningPopup.close()`

---

## 14.3 "Play a Song" Flow

```
User: clicks a track tile in LibraryView
- **User clicks a track tile in LibraryView**
  - `[QML]` `MouseArea.onClicked:`
    - `window.playTrackAtIndex(index, "All Tracks")`
  - `[QML function]` `playTrackAtIndex(5, "All Tracks")`
    - `contextCategory` is set &rarr; rebuild queue
      - `for (i = 0..trackModel.rowCount()-1):`
        - `playbackQueue.push(trackModel.get(i))`
      - `currentQueueIndex = 5`
    - `var track = playbackQueue[5]`
    - `window.currentPlayingTitle = track.title`
    - `window.currentPlayingArtist = track.artist`
    - `window.currentPlayingPath = track.filePath`
      - *(all QML text bound to these auto-updates)*
    - `audioEngine.loadFile(track.filePath)` &bull; *(calls C++ slot AudioEngine::loadFile)*
      - `ma_sound_uninit` (previous)
      - `ma_sound_init_from_file` (new file, ASYNC decode)
      - `ma_node_attach(sound &rarr; eqNodes[0])`
      - `emit durationChanged(length)` &rarr; `QML Slider.to` updates
      - `emit positionChanged(0)` &rarr; `QML Slider.value` resets
    - `audioEngine.play()` &bull; *(calls C++ slot AudioEngine::play)*
      - `ma_sound_start(&m_sound)`
      - `emit playingChanged(true)` &bull; *(Q_PROPERTY NOTIFY)*
        - `[QML]` `audioEngine.isPlaying = true`
        - Play/Pause button icon changes to "pause.svg"
  - **[250ms timer fires repeatedly while playing]**
    - `AudioEngine` timer callback:
      - `ma_sound_at_end?` &rarr; `emit playbackFinished()` &rarr; auto-advance
      - `isPlaying?` &rarr; `emit positionChanged(cursor)` &bull; *(Q_PROPERTY NOTIFY)*
        - `[QML]` `Slider.value = audioEngine.position`
        - `[QML]` Time labels update

---

## 14.4 "Seek to Position" Flow

- **User drags the progress slider to new position**
  - `[QML Slider.onMoved]`
    - `audioEngine.position = value` &bull; *(Q_PROPERTY WRITE: calls setPosition)*
  - `[C++ AudioEngine::setPosition(newPos)]`
    - `ma_engine_get_sample_rate` &rarr; `sampleRate`
    - `targetFrame = newPos &times; sampleRate`
    - `ma_sound_seek_to_pcm_frame(&m_sound, targetFrame)`
    - `emit positionChanged(newPos)` &bull; *(Q_PROPERTY NOTIFY)*
      - `[QML]` `Slider.value` and time labels update to confirm the seek

---

## 14.5 "Change EQ Band" Flow

- **User moves EQ slider for band 5 (1kHz)**
  - `[QML EqualizerView Slider.onMoved]`
    - `eq.setBandGain(5, newValue)` &bull; *(Q_INVOKABLE direct call)*
  - `[C++ Equalizer::setBandGain(5, newValue)]`
    - `clampedValue = clamp(newValue, -12, 12)`
    - `m_gains[5] = clampedValue`
    - `emit bandGainChanged(5, clampedValue)` &bull; *(connect in AudioEngine constructor)*
  - `[C++ AudioEngine::onEqualizerBandGainChanged(5, clampedValue)]`
    - `actualGain = eq->isEnabled() ? clampedValue : 0.0f`
    - `ma_peak2_config cfg = ma_peak2_config_init(..., actualGain, ...)`
    - `ma_peak_node_reinit(&m_eqNodes[5], &cfg)`
    - Audio pipeline filter coefficients update instantly
    - Users hears the frequency change in real time
  - `[QML EqualizerView gain label]`
    - `text: eq.bandGain(5)` &rarr; reads new value &rarr; shows "+3.0 dB"
    - (updates because `Slider.onMoved` triggers re-read via binding)

---

## 14.6 Class Dependency Map

- `main.cpp`
  - creates: `AudioEngine`
    - owns: `Equalizer` (child QObject)
    - uses: `miniaudio` (`ma_engine`, `ma_sound`, `ma_peak_node[10]`)
    - uses: `QTimer` (250ms heartbeat)
  - creates: `LibraryScanner`
    - uses: `TagLib` (reads tags)
    - uses: `QSqlDatabase` (SQLite persistence)
    - uses: `QtConcurrent` (background threads)
    - uses: `QDirIterator` (filesystem walk)
  - creates: `TrackModel`
    - contains: `QVector<Track>` (all tracks in memory)
    - contains: `QVector<int>` (display filter indices)
  - connects: `LibraryScanner.tracksAdded` &rarr; `TrackModel.setTracks`
  - connects: `LibraryScanner.tracksAppended` &rarr; `TrackModel.addTracks`
  - creates: `QLocalServer` (`"MLP_MusicPlayerIPC"`)
    - receives: file paths from secondary instances
    - calls: `LibraryScanner.appendSpecificFiles()`
  - exposes via `setContextProperty`:
    - `"launchMode"` &rarr; `QString` constant (`"Library"`/`"Minimal"`/`"Queue"`)
    - `"audioEngine"` &rarr; `AudioEngine*`
    - `"libraryScanner"` &rarr; `LibraryScanner*`
    - `"trackModel"` &rarr; `TrackModel*`
  - registers: `CoverArtProvider` under `"musiccover"`
    - uses: `TagLib` (reads embedded images)
    - uses: `QImage` (decodes JPEG/PNG bytes)

---

## 14.7 IPC — Secondary Launch → Queue Update Flow

- **User selects 3 audio files in file manager and double-clicks to open**
  - OS spawns `Process 2` (and possibly 3, 4...) with file paths as `argv`
  - **Process 2**: `main()` starts
    - `QLocalSocket.connectToServer("MLP_MusicPlayerIPC")`
      - **Success!** Primary instance is running
        - `socket.write("track_b.mp3\ntrack_c.mp3")`
        - `return 0` &bull; *(Process 2 exits immediately)*
      - **Failure**: no primary instance yet (first ever launch)
        - continue with normal startup ...
  - **Primary instance** (already running) — `QLocalServer` event:
    - `newConnection` signal fires
    - `clientSocket->readAll()` &rarr; `"track_b.mp3\ntrack_c.mp3"`
    - `libraryScanner.appendSpecificFiles(["track_b.mp3", "track_c.mp3"])`
      - Parses tags with `TagLib` (lightweight, no SQLite)
      - `m_tracks.append(newTracks)` *(does NOT clear existing tracks)*
      - `emit tracksAppended(newTracks)`
        - *(connect in main.cpp)* &rarr; `trackModel.addTracks(newTracks)`
        - `beginInsertRows` / `endInsertRows` (no reset)
        - QML queue `ListView` appends items
    - `[QML]` `Connections.onTracksAppended` fires:
      - `let newQueue = rebuild from trackModel`
      - `window.playbackQueue = newQueue`
      - `if (was empty) window.playTrackAtIndex(0, "IPC")` *(autoplay)*
    - Existing playback continues undisturbed if queue was not empty
