import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: nowPlayingRoot

    // Format helper function
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds)) return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    ToolButton {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 15
        icon.source: "qrc:/qml/icons/eq.svg"
        icon.color: "white"
        icon.width: 24
        icon.height: 24
        onClicked: eqPopup.open()
        display: AbstractButton.IconOnly
        z: 10
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 50

        // Large Album Art (Left Side)
        Rectangle {
            id: largeArt
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: Math.min(parent.width * 0.55, 650)
            Layout.preferredHeight: width
            radius: 16
            color: "#202025"
            border.color: "#33333b"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: window.currentPlayingPath !== "" ? "image://musiccover/" + window.currentPlayingPath : ""
                fillMode: Image.PreserveAspectCrop
                visible: window.currentPlayingPath !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "Album\nArt"
                color: "#555"
                font.pixelSize: 48
                horizontalAlignment: Text.AlignHCenter
                visible: window.currentPlayingPath === ""
            }
        }

        // Title and Artist and Controls (Right Side)
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15
            
            Item { Layout.fillHeight: true } // top spacer
            
            Text {
                text: window.currentPlayingTitle
                color: "white"
                font.pixelSize: 42
                font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingArtist
                color: "#aaa"
                font.pixelSize: 24
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingPath !== "" ? "Now Playing" : ""
                color: "#777"
                font.pixelSize: 20
            }
            
            Item { Layout.preferredHeight: 30 } // Visual separation
            
            // Re-adding Progress Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                
                Text {
                    text: nowPlayingRoot.formatTime(audioEngine.position)
                    color: "#888"
                }
                
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: audioEngine.duration
                    value: audioEngine.position
                    onMoved: audioEngine.position = value
                }
                
                Text {
                    text: nowPlayingRoot.formatTime(audioEngine.duration)
                    color: "#888"
                }
            }
            
            // Playback Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                RoundButton {
                    icon.source: window.repeatMode ? "qrc:/qml/icons/repeat_one.svg" : "qrc:/qml/icons/repeat.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    checked: window.repeatMode
                    onClicked: window.repeatMode = !window.repeatMode
                    Material.background: window.repeatMode ? Material.accent : "transparent"
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
                    width: 64
                    height: 64
                    onClicked: {
                        if (audioEngine.isPlaying) audioEngine.pause()
                        else audioEngine.play()
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

                RoundButton {
                    icon.source: "qrc:/qml/icons/stop.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: audioEngine.stop()
                }
            }

            Item { Layout.fillHeight: true } // spacer
        }
    }
}
