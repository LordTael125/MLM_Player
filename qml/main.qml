import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    width: 1024
    height: 768
    visible: true
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
    property int currentPlayingIndex: -1
    property bool repeatMode: false

    function playTrackAtIndex(idx) {
        if (idx < 0 || idx >= trackModel.rowCount()) return;
        currentPlayingIndex = idx;
        
        var track = trackModel.get(idx);
        if (!track) return;
        
        currentPlayingTitle = track.title;
        currentPlayingArtist = track.artist;
        currentPlayingPath = track.filePath;
        
        audioEngine.loadFile(track.filePath);
        audioEngine.play();
    }

    Connections {
        target: audioEngine
        function onPlaybackFinished() {
            if (repeatMode) {
                audioEngine.setPosition(0);
                audioEngine.play();
            } else {
                if (currentPlayingIndex >= 0 && currentPlayingIndex < trackModel.rowCount() - 1) {
                    playTrackAtIndex(currentPlayingIndex + 1);
                }
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Please choose a folder with Music"
        onAccepted: {
            libraryScanner.scanDirectory(folderDialog.folder)
        }
    }

    // Header removed per blueprint. Menu button is now floating.

    Menu {
        id: menuPopup
        MenuItem {
            text: "Scan Directory"
            onTriggered: folderDialog.open()
        }
        MenuItem {
            text: "Clear Database"
            onTriggered: {
                libraryScanner.clearDatabase()
                window.currentPlayingIndex = -1
                window.currentPlayingTitle = "No Song Playing"
                window.currentPlayingArtist = ""
                window.currentPlayingPath = ""
                audioEngine.stop()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Custom Title Bar
        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            color: "transparent"
            
            // Drag Handler for moving the frameless window
            DragHandler {
                onActiveChanged: if (active) window.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 10
                spacing: 15

                Label {
                    text: window.title
                    color: "white"
                    font.bold: true
                    font.pixelSize: 14
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
                    icon.source: "qrc:/qml/icons/maximize.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: {
                        if (window.visibility === Window.Maximized) {
                            window.showNormal()
                        } else {
                            window.showMaximized()
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

            LibraryView {
                anchors.fill: parent
                anchors.bottomMargin: playbackBar.height // Reserve space for playback bar
            }
        
        ToolButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 15
            icon.source: "qrc:/qml/icons/menu.svg"
            icon.color: "white"
            icon.width: 24
            icon.height: 24
            onClicked: menuPopup.open()
            display: AbstractButton.IconOnly
        }
        
        // Equalizer Popup
        Popup {
            id: eqPopup
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.min(window.width * 0.9, 850)
            height: Math.min(window.height * 0.8, 650)
            modal: true
            focus: true
            padding: 0
            background: Rectangle { 
                color: "#18181c" 
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            
            EqualizerView {
                anchors.fill: parent
            }
        }
        
        // Now Playing Popup Overlay
        Popup {
            id: nowPlayingPopup
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            modal: false
            focus: true
            padding: 0
            background: Rectangle { color: "#0a0a0c" }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            
            NowPlayingView {
                anchors.fill: parent
            }
        }
        
        // Queue Drawer
        Drawer {
            id: queueDrawer
            edge: Qt.RightEdge
            width: Math.min(window.width * 0.4, 400)
            height: parent.height
            background: Rectangle { color: "#18181c"; border.color: "#33333b"; border.width: 1 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Label {
                    text: "Up Next"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: trackModel
                    
                    delegate: ItemDelegate {
                        width: ListView.view.width
                        height: 60
                        
                        // Only show items after the currently playing index
                        visible: index > window.currentPlayingIndex
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15

                            Image {
                                source: model.hasCoverArt ? "image://musiccover/" + model.filePath : "qrc:/qml/icons/play.svg"
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                fillMode: Image.PreserveAspectCrop
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: model.title
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: model.artist
                                    color: "#aaa"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        
                        onClicked: {
                            window.playTrackAtIndex(index)
                        }
                    }
                }
            }
        }
        
        // Persistent Bottom Playback Bar
        Rectangle {
            id: playbackBar
            width: parent.width
            height: 80
            anchors.bottom: parent.bottom
            color: "#18181c"
            border.color: "#33333b"
            border.width: 1

            // Format helper function
            function formatTime(seconds) {
                if (!seconds || isNaN(seconds)) return "00:00";
                let m = Math.floor(seconds / 60);
                let s = Math.floor(seconds % 60);
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 20
                
                ToolButton {
                    icon.source: nowPlayingPopup.opened ? "qrc:/qml/icons/expand_down.svg" : "qrc:/qml/icons/expand_up.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 40
                    height: 40
                    onClicked: {
                        if (nowPlayingPopup.opened) nowPlayingPopup.close()
                        else nowPlayingPopup.open()
                    }
                }
                
                RoundButton {
                    icon.source: "qrc:/qml/icons/prev.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: {
                        if (window.currentPlayingIndex > 0) {
                            window.playTrackAtIndex(window.currentPlayingIndex - 1)
                        }
                    }
                }
                
                RoundButton {
                    icon.source: audioEngine.isPlaying ? "qrc:/qml/icons/pause.svg" : "qrc:/qml/icons/play.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 50
                    height: 50
                    onClicked: {
                        if (window.currentPlayingIndex === -1 && trackModel.rowCount() > 0) {
                            window.playTrackAtIndex(0)
                        } else {
                            if (audioEngine.isPlaying) audioEngine.pause()
                            else audioEngine.play()
                        }
                    }
                }
                
                RoundButton {
                    icon.source: "qrc:/qml/icons/next.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: {
                        if (window.currentPlayingIndex >= 0 && window.currentPlayingIndex < trackModel.rowCount() - 1) {
                            window.playTrackAtIndex(window.currentPlayingIndex + 1)
                        }
                    }
                }

                Text {
                    text: playbackBar.formatTime(audioEngine.position)
                    color: "white"
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
