import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: playlistDetailsRoot
    property string playlistName: ""
    property bool isEditMode: false

    function forceContentFocus() {
        listView.forceActiveFocus();
    }

    Connections {
        target: playlistManager
        function onPlaylistTracksChanged(pName) {
            if (pName === playlistName) {
                trackModel.filterByPlaylist(playlistName, playlistManager.getPlaylistTracks(playlistName));
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 15

            Button {
                text: "Add Content"
                background: Rectangle {
                    color: "#33333b"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var popup = Qt.createComponent("qrc:/qml/PlaylistPopup.qml").createObject(libraryView, {
                        playlistName: playlistDetailsRoot.playlistName
                    });
                    popup.open();
                }
            }

            Button {
                text: isEditMode ? "Done Editing" : "Edit Playlist"
                background: Rectangle {
                    color: isEditMode ? "#0078d7" : "#33333b"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: isEditMode = !isEditMode
            }

            Item {
                Layout.fillWidth: true
            } // Spacer

            ComboBox {
                id: sortCombo
                model: ["Manual", "Sort by Title", "Sort by Artist", "Sort by Track Number"]
                background: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 10
                    color: '#33333b'
                    radius: 6
                }

                onActivated: {
                    if (currentIndex === 1)
                        playlistManager.sortPlaylist(playlistName, "title");
                    else if (currentIndex === 2)
                        playlistManager.sortPlaylist(playlistName, "artist");
                    else if (currentIndex === 3)
                        playlistManager.sortPlaylist(playlistName, "trackNumber");
                    // Reset to manual so it doesn't look like it's stuck forcing a sort
                    currentIndex = 0;
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: trackModel
            clip: true

            delegate: Item {
                width: ListView.view.width
                height: 60

                property string dPath: model.filePath
                property bool dHasCoverArt: model.hasCoverArt

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: isEditMode ? "#202025" : "transparent"
                    border.color: isEditMode ? "#33333b" : "transparent"
                    radius: 6

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5

                        ToolButton {
                            icon.source: "qrc:/qml/icons/sort.svg"
                            icon.color: "white"
                            visible: isEditMode
                            onClicked: {
                                playlistManager.moveTrack(playlistName, index, index + 1);
                            }
                        }

                        Rectangle {
                            id: listThumb
                            width: 44
                            height: 44
                            Layout.alignment: Qt.AlignCenter
                            color: "#33333b"
                            radius: 4
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: dHasCoverArt ? "image://musiccover/" + dPath : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: dHasCoverArt
                                asynchronous: true
                                sourceSize: Qt.size(100, 100)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "?"
                                color: "#555"
                                font.pixelSize: 20
                                visible: !dHasCoverArt
                            }
                        }

                        Text {
                            text: model.title
                            color: "white"
                            font.bold: true
                            Layout.fillWidth: true
                            leftPadding: 10
                        }

                        Text {
                            text: model.artist
                            color: "#aaa"
                            Layout.preferredWidth: 300
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/close.svg"
                            icon.color: "#ff4444"
                            visible: isEditMode
                            onClicked: playlistManager.removeTrack(playlistName, dPath)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !isEditMode
                        onClicked: {
                            if (window.currentPlayingPath === dPath) {
                                if (audioEngine.isPlaying)
                                    audioEngine.pause();
                                else
                                    audioEngine.play();
                            } else {
                                window.playTrackAtIndex(index, playlistName);
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: sortPopup
        width: 200
        height: 120
        // We might need to bind x and y to something else since it's now at root, but let's keep it simple for now
        y: 50
        x: 50

        contentItem: Text {
            text: sortCombo.displayText
            color: "white"
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: '#33333b'
            radius: 6
        }
    }
}
