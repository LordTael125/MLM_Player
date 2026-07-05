import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import Qt.labs.settings 1.0
import QtGraphicalEffects 1.15

ApplicationWindow {
    id: window
    width: launchMode === "Library" ? 1260 : 800
    height: launchMode === "Library" ? 768 : 350
    visible: true
    visibility: launchMode === "Library" ? Window.Maximized : Window.Windowed
    title: qsTr("Modern Music Player")
    flags: Qt.Window | Qt.FramelessWindowHint

    // Modern Dark Theme base
    Material.theme: Material.Dark
    Material.accent: Material.Purple
    color: "#0a0a0c" // Very deep almost black background

    // Global Now Playing State
    property string currentPlayingTitle: "No Song Playing"
    property string currentPlayingArtist: ""
    property string currentPlayingPath: ""
    property string applicationVersion: "1.3.2"
    property bool currentPlayingHasCoverArt: false
    property var playbackQueue: []
    property int currentQueueIndex: -1
    property int repeatMode: 0 // 0: Off, 1: Track, 2: All

    property bool isFullScreen: false
    property bool allowRestore: true

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

    Connections {
        target: libraryScanner
        function onTracksAdded(tracks) {
            // Used for initial startup and library loads
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
            // Appends tracks precisely when multiple files are opened randomly via OS explorer!
            if (window.visibility !== Window.Hidden) {
                let newQueue = [];
                for (let i = 0; i < trackModel.rowCount(); i++) {
                    newQueue.push(trackModel.get(i));
                }

                let wasEmpty = window.playbackQueue.length === 0;
                window.playbackQueue = newQueue;

                if (wasEmpty) {
                    window.playTrackAtIndex(0, "IPC");
                }
            }
        }
    }
    function toggleFullScreen() {
        if (isFullScreen) {
            window.showMaximized();
            isFullScreen = false;
        } else {
            window.showFullScreen();
            isFullScreen = true;
        }
    }

    Settings {
        id: sessionSettings
        category: "MediaPlayer"
        property string savedQueue: "[]"
        property int savedQueueIndex: -1
        property real savedPosition: 0.0
        property int savedRepeatMode: 0
        property real savedVolume: 1.0
        property alias savedIsFullScreen: window.isFullScreen
        property alias savedAllowRestore: window.allowRestore
        property alias savedRepeatMode: window.repeatMode
    }

    //  ========================================
    // |===      Restore Playtime            ===|
    //  ========================================

    Timer {
        id: startupRestoreTimer
        interval: 200
        repeat: true
        running: launchMode === "Library"
        onTriggered: {
            if (trackModel.rowCount() > 0) {
                running = false;
                try {
                    audioEngine.volume = sessionSettings.savedVolume;
                    repeatMode = sessionSettings.savedRepeatMode;

                    let paths = JSON.parse(sessionSettings.savedQueue);
                    if (paths && paths.length > 0 && window.playbackQueue.length === 0) {
                        let newQueue = [];
                        for (let i = 0; i < paths.length; i++) {
                            // C++ getTrackByPath returns a QVariantMap which translates to a JS object
                            let track = trackModel.getTrackByPath(paths[i]);
                            // Ensure track is valid
                            if (track && track.filePath !== undefined && track.filePath !== "") {
                                newQueue.push(track);
                            }
                        }
                        if (newQueue.length > 0) {
                            window.playbackQueue = newQueue;
                            if (sessionSettings.savedQueueIndex >= 0 && sessionSettings.savedQueueIndex < newQueue.length) {
                                window.currentQueueIndex = sessionSettings.savedQueueIndex;
                                let t = window.playbackQueue[window.currentQueueIndex];
                                window.currentPlayingTitle = t.title;
                                window.currentPlayingArtist = t.artist;
                                window.currentPlayingPath = t.filePath;
                                window.currentPlayingHasCoverArt = t.hasCoverArt;

                                audioEngine.loadFile(t.filePath);
                                mprisManager.setMetadata(t.filePath, t.title, t.artist, t.album !== undefined ? t.album : "", "", Math.floor(t.duration || 0));
                                mprisManager.setPlaybackStatus(audioEngine.isPlaying);
                                // Ensure miniaudio has enough time to initialize ASYNC load before seeking
                                if (allowRestore) {
                                    restorePosTimer.start();
                                }
                            }
                        }
                    }
                } catch (e) {
                    console.log("Error restoring session:", e);
                }
            }
        }
    }

    Timer {
        id: restorePosTimer
        interval: 200
        onTriggered: {
            audioEngine.setPosition(sessionSettings.savedPosition);
        }
    }

    Component.onDestruction: {
        let paths = [];
        for (let i = 0; i < playbackQueue.length; i++) {
            paths.push(playbackQueue[i].filePath);
        }
        sessionSettings.savedQueue = JSON.stringify(paths);
        sessionSettings.savedQueueIndex = currentQueueIndex;
        sessionSettings.savedPosition = audioEngine.position;
        sessionSettings.savedVolume = audioEngine.volume;
        sessionSettings.savedRepeatMode = repeatMode;
    }

    function playTrackAtIndex(idx, contextCategory) {
        if (idx < 0)
            return;

        // If an external category is passed, repopulate the queue
        if (contextCategory) {
            let newQueue = [];
            // Push everything from current visible model into the queue so users can skip forward
            for (var i = 0; i < trackModel.rowCount(); i++) {
                newQueue.push(trackModel.get(i));
            }
            playbackQueue = newQueue;
            currentQueueIndex = idx;
        } else {
            // Internal call (Next/Prev from Queue)
            currentQueueIndex = idx;
        }

        if (currentQueueIndex < 0 || currentQueueIndex >= playbackQueue.length)
            return;

        var track = playbackQueue[currentQueueIndex];
        if (!track)
            return;

        currentPlayingTitle = track.title;
        currentPlayingArtist = track.artist;
        currentPlayingPath = track.filePath;
        currentPlayingHasCoverArt = track.hasCoverArt;

        audioEngine.loadFile(track.filePath);
        audioEngine.play();
        
        mprisManager.setMetadata(track.filePath, track.title, track.artist, track.album !== undefined ? track.album : "", "", Math.floor(track.duration || 0));

        if (queueListView) {
            queueListView.positionViewAtIndex(currentQueueIndex, ListView.Beginning);
        }
    }

    function showVolumePopup(callerItem) {
        var pos = callerItem.mapToItem(window.contentItem, 0, 0);
        volumePopup.x = Math.max(0, Math.round(pos.x + callerItem.width / 2 - volumePopup.width / 2));
        volumePopup.y = Math.max(0, Math.round(pos.y - volumePopup.height - 25)); // Added negative offset to hover
        volumePopup.open();
    }

    Connections {
        target: audioEngine
        function onPlaybackFinished() {
            if (repeatMode === 1) { // Repeat Track
                audioEngine.setPosition(0);
                audioEngine.play();
            } else if (repeatMode === 2) { // Repeat All
                if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                    playTrackAtIndex(currentQueueIndex + 1);
                } else if (playbackQueue.length > 0) {
                    playTrackAtIndex(0); // Loop back
                }
            } else { // Repeat Off
                if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                    playTrackAtIndex(currentQueueIndex + 1);
                }
            }
        }
        function onPlayingChanged(isPlaying) {
            mprisManager.setPlaybackStatus(isPlaying);
        }
        function onPositionChanged(pos) {
            mprisManager.setPosition(Math.floor(pos));
        }
    }

    Connections {
        target: mprisManager
        function onNextRequested() {
            if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                playTrackAtIndex(currentQueueIndex + 1);
            }
        }
        function onPreviousRequested() {
            if (currentQueueIndex > 0) {
                playTrackAtIndex(currentQueueIndex - 1);
            } else if (playbackQueue.length > 0) {
                playTrackAtIndex(0);
            }
        }
    }

    Platform.FolderDialog {
        id: folderDialog
        title: "Please choose a folder with Music"
        onAccepted: {
            libraryScanner.scanDirectory(folderDialog.folder);
        }
    }

    // ======================================
    // |==== Global Keyboard Shortcuts  ====|
    // ======================================

    property real previousVolume: 1.0
    
    Shortcut {
        sequence: "Ctrl+Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.position > 2.0) {
                audioEngine.setPosition(0.0);
            } else {
                if (window.currentQueueIndex > 0) {
                    playTrackAtIndex(window.currentQueueIndex - 1);
                }
            }
        }
    }
    Shortcut {
        sequence: "Ctrl+Right"
        context: Qt.ApplicationShortcut
        onActivated: playTrackAtIndex(currentQueueIndex + 1)
    }
    Shortcut {
        sequence: "Backspace"
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.goBack()
    }
    Shortcut {
        sequence: StandardKey.Back
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.goBack()
    }
    Shortcut {
        sequence: "Ctrl+Shift+F"
        context: Qt.ApplicationShortcut
        onActivated: toggleFullScreen()
    }
    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.isPlaying)
                audioEngine.pause();
            else
                audioEngine.play();
        }
    }
    Shortcut {
        sequence: "Ctrl+M"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.volume > 0.01) {
                previousVolume = audioEngine.volume;
                audioEngine.volume = 0.0;
            } else {
                audioEngine.volume = previousVolume > 0.01 ? previousVolume : 1.0;
            }
        }
    }
    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.setPosition(audioEngine.position - 10.0)
    }
    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.setPosition(audioEngine.position + 10.0)
    }
    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            audioEngine.volume = Math.min(1.0, audioEngine.volume + 0.1);
            volumeOSDPopup.show();
        }
    }
    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            audioEngine.volume = Math.max(0.0, audioEngine.volume - 0.1);
            volumeOSDPopup.show();
        }
    }
    Shortcut {
        sequence: "Ctrl+P"
        context: Qt.ApplicationShortcut
        onActivated: queueDrawer.visible = !queueDrawer.visible
    }
    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.isSidebarVisible = !libraryViewMain.isSidebarVisible
    }
    Shortcut {
        sequence: "Ctrl+Q"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }
    Shortcut {
        sequence: "P"
        context: Qt.ApplicationShortcut
        onActivated: nowPlayingPopup.closed ? nowPlayingPopup.open() : nowPlayingPopup.close()
    }

    AppPopups {
        id: appPopups
        anchors.fill: parent
        window: window
        globalGamepadManager: globalGamepadManager
        folderDialog: folderDialog
        sessionSettings: sessionSettings
    }

    property alias volumeOSDPopup: appPopups.volumeOSDPopup
    property alias mainMenuPopup: appPopups.mainMenuPopup
    property alias settingsPopup: appPopups.settingsPopup
    property alias eqPopup: appPopups.eqPopup
    property alias volumePopup: appPopups.volumePopup
    property alias nowPlayingPopup: appPopups.nowPlayingPopup
    property alias shortcutsPopup: appPopups.shortcutsPopup
    property alias supportPopup: appPopups.supportPopup
    property alias scanningPopup: appPopups.scanningPopup
    property alias queueDrawer: appPopups.queueDrawer
    property alias queueListView: appPopups.queueListView

    // =====================================
    // |=====   Main Content Area      ====|
    // =====================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================
        // |=====   Custom Title Bar     ======|
        // =====================================

        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: window.isFullScreen ? 0 : 40
            color: '#100f14'
            visible: !window.isFullScreen && launchMode === "Library"

            // ===============================================
            // Drag Handler for moving the frameless window
            // ===============================================

            DragHandler {
                target: null
                onActiveChanged: if (active)
                    window.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                Layout.leftMargin: 15
                Layout.rightMargin: 10
                spacing: 15

                Label {
                    Layout.leftMargin: 15
                    text: window.title
                    color: "white"
                    font.bold: true
                    font.pixelSize: 14
                }

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    icon.source: "qrc:/qml/icons/minimize.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: window.showMinimized()
                }

                ToolButton {
                    icon.source: window.visibility === Window.Maximized ? "qrc:/qml/icons/unmaximize.svg" : "qrc:/qml/icons/maximize.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: {
                        if (window.visibility === Window.Maximized) {
                            window.showNormal();
                        } else {
                            window.showMaximized();
                        }
                    }
                }

                ToolButton {
                    icon.source: "qrc:/qml/icons/close.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: window.close()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: launchMode === "Library"

            LibraryView {
                id: libraryViewMain
                gamepadManager: globalGamepadManager
                anchors.fill: parent
                onMenuClicked: mainMenuPopup.open()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: launchMode !== "Library"

            MinimalView {
                id: minimalViewMain
                anchors.fill: parent
            }
        }

        // =================================================
        // |====    Persistent Bottom Playback Bar     ====|
        // =================================================

        Rectangle {
            id: playbackBar
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            visible: launchMode === "Library"
            color: "#18181c"
            border.color: "#33333b"
            border.width: 1
            radius: 10

            // Format helper function
            function formatTime(seconds) {
                if (!seconds || isNaN(seconds))
                    return "00:00";
                let m = Math.floor(seconds / 60);
                let s = Math.floor(seconds % 60);
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            }

            Item {
                anchors.fill: parent
                anchors.margins: 1

                // Section 1: Left Container (Art + Track Info)
                Item {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: centerContainer.left
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 20

                        Item {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 80
                            Layout.leftMargin: 25

                            Image {
                                id: coverArtImage
                                source: nowPlayingPopup.opened ? "qrc:/qml/icons/expand_down.svg" : (window.currentPlayingHasCoverArt ? "image://musiccover/" + window.currentPlayingPath : "qrc:/qml/icons/play.svg")
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(160, 160)
                                anchors.fill: parent
                                visible: false
                            }

                            Rectangle {
                                id: coverMask
                                anchors.fill: parent
                                radius: 8
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: coverArtImage
                                source: coverArtImage
                                maskSource: coverMask
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: nowPlayingPopup.closed ? nowPlayingPopup.open() : nowPlayingPopup.close()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: window.currentPlayingTitle
                                color: "#d9edfd"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: window.currentPlayingArtist
                                color: "#aaa"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Section 2: Center Container (Playback Controls)
                ColumnLayout {
                    id: centerContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 0
                    width: Math.max(300, Math.min(600, parent.width - 400))

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 40
                        spacing: 20

                        ToolButton {
                            icon.source: "qrc:/qml/icons/prev.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (audioEngine.position > 2.0) {
                                    audioEngine.setPosition(0.0);
                                } else {
                                    if (window.currentQueueIndex > 0) {
                                        window.playTrackAtIndex(window.currentQueueIndex - 1);
                                    } else
                                        audioEngine.setPosition(0.0);
                                }
                            }
                        }

                        ToolButton {
                            icon.source: audioEngine.isPlaying ? "qrc:/qml/icons/pause.svg" : "qrc:/qml/icons/play.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (window.currentQueueIndex === -1 && window.playbackQueue.length > 0) {
                                    window.playTrackAtIndex(0);
                                } else {
                                    if (audioEngine.isPlaying)
                                        audioEngine.pause();
                                    else
                                        audioEngine.play();
                                }
                            }
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/next.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (window.currentQueueIndex >= 0 && window.currentQueueIndex < window.playbackQueue.length - 1) {
                                    window.playTrackAtIndex(window.currentQueueIndex + 1);
                                }
                            }
                        }

                        ToolButton {
                            icon.source: window.repeatMode === 1 ? "qrc:/qml/icons/repeat_one.svg" : "qrc:/qml/icons/repeat.svg"
                            icon.color: window.repeatMode !== 0 ? Material.color(Material.Purple) : "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: window.repeatMode = (window.repeatMode + 1) % 3
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: 200
                        Layout.fillWidth: true
                        Layout.topMargin: -10
                        spacing: 15

                        Text {
                            text: playbackBar.formatTime(audioEngine.position)
                            color: "white"
                            font.pixelSize: 12
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: audioEngine.duration
                            value: audioEngine.position
                            onMoved: audioEngine.position = value
                        }

                        Text {
                            text: playbackBar.formatTime(audioEngine.duration)
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                }

                // Section 3: Right Container (Tools)
                Item {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: centerContainer.right
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 40
                        spacing: 15

                        Item {
                            Layout.fillWidth: true
                        } // Pushes tools to the right edge

                        ToolButton {
                            icon.source: audioEngine.volume <= 0.01 ? "qrc:/qml/icons/volume_off.svg" : "qrc:/qml/icons/volume.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 35
                            height: 35
                            onClicked: window.showVolumePopup(this)
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/eq.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 35
                            height: 35
                            onClicked: eqPopup.open()
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/queue.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: queueDrawer.open()
                        }
                    }
                }
            }
        }
    }

    GamepadControl {
        id: globalGamepadManager
        window: window

        libraryViewMain: libraryViewMain
        queueListView: window.queueListView
        queueDrawer: window.queueDrawer
        nowPlayingPopup: window.nowPlayingPopup
        eqPopup: window.eqPopup
        shortcutsPopup: window.shortcutsPopup
        supportPopup: window.supportPopup
        mainMenuPopup: window.mainMenuPopup
        volumePopup: window.volumePopup
        playbackBar: playbackBar
        volumeOSDPopup: window.volumeOSDPopup
    }
}
