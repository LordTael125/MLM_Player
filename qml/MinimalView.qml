import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: minimalRoot

    // Format helper function
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds))
            return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Top Right Controls (Close / Minimize)
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 5
        z: 20

        ToolButton {
            icon.source: "qrc:/qml/icons/minimize.svg"
            icon.color: "white"
            display: AbstractButton.IconOnly
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            onClicked: window.showMinimized()
        }

        ToolButton {
            icon.source: "qrc:/qml/icons/close.svg"
            icon.color: "white"
            display: AbstractButton.IconOnly
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            onClicked: window.close()
        }
    }

    // Drag capability across the entire minimal view empty zones!
    DragHandler {
        onActiveChanged: if (active)
            window.startSystemMove()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 30

        // Compact Album Art (Left Side)
        Rectangle {
            id: compactArt
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.preferredWidth: parent.height - 40 // Scaled dynamically with height
            Layout.preferredHeight: Layout.preferredWidth
            radius: 12
            color: "#202025"
            border.color: "#33333b"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: "image://musiccover/" + window.currentPlayingPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(300, 300)
            }
        }

        // Title and Artist and Controls (Right Side)
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Item {
                Layout.fillHeight: true
            } // top spacer

            Text {
                text: window.currentPlayingTitle
                color: "white"
                font.pixelSize: 32
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingArtist
                color: "#aaa"
                font.pixelSize: 18
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingPath !== "" ? "Now Playing" : ""
                color: "#777"
                font.pixelSize: 15
            }

            Item {
                Layout.preferredHeight: 15
            } // Visual separation

            // Progress Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Text {
                    text: minimalRoot.formatTime(audioEngine.position)
                    color: "#888"
                    font.pixelSize: 12
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: audioEngine.duration
                    value: audioEngine.position
                    focusPolicy: Qt.NoFocus
                    onMoved: audioEngine.position = value
                }

                Text {
                    text: minimalRoot.formatTime(audioEngine.duration)
                    color: "#888"
                    font.pixelSize: 12
                }
            }

            // Playback Controls Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                RoundButton {
                    icon.source: window.repeatMode === 1 ? "qrc:/qml/icons/repeat_one.svg" : "qrc:/qml/icons/repeat.svg"
                    icon.color: window.repeatMode !== 0 ? Material.color(Material.Purple) : "white"
                    display: AbstractButton.IconOnly
                    width: 40
                    height: 40
                    onClicked: window.repeatMode = (window.repeatMode + 1) % 3
                    background: Rectangle {
                        color: "transparent"
                    }
                }

                RoundButton {
                    icon.source: "qrc:/qml/icons/prev.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 48
                    height: 48
                    onClicked: {
                        if (audioEngine.position > 2.0) {
                            audioEngine.setPosition(0.0);
                        } else {
                            if (window.currentQueueIndex > 0) {
                                window.playTrackAtIndex(window.currentQueueIndex - 1);
                            } else {
                                audioEngine.setPosition(0.0);
                            }
                        }
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                }

                RoundButton {
                    icon.source: audioEngine.isPlaying ? "qrc:/qml/icons/pause.svg" : "qrc:/qml/icons/play.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 56
                    height: 56
                    onClicked: {
                        if (audioEngine.isPlaying)
                            audioEngine.pause();
                        else
                            audioEngine.play();
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                }

                RoundButton {
                    icon.source: "qrc:/qml/icons/next.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 48
                    height: 48
                    onClicked: {
                        if (window.currentQueueIndex >= 0 && window.currentQueueIndex < window.playbackQueue.length - 1) {
                            window.playTrackAtIndex(window.currentQueueIndex + 1);
                        }
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                }

                Item {
                    Layout.fillWidth: true
                } // Spacer pushes tools rightwards

                ToolButton {
                    icon.source: audioEngine.volume === 0.0 ? "qrc:/qml/icons/volume_off.svg" : "qrc:/qml/icons/volume.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 40
                    height: 40
                    onClicked: window.showVolumePopup(this)
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

            Item {
                Layout.fillHeight: true
            } // bottom spacer
        }
    }
}
