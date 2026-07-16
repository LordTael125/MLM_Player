import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property var playlistManager: null

    property alias addPopup: addPopup
    property alias playlistMenuPopup: playlistMenuPopup
    property alias createPlaylistPopup: createPlaylistPopup

    function openAddPopup(manager, name) {
        root.playlistManager = manager;
        addPopup.playlistName = name;
        addPopup.open();
        if (manager) manager.updatePlaylists();
    }

    function openCreatePlaylistPopup(manager) {
        root.playlistManager = manager;
        createPlaylistPopup.x = (Overlay.overlay.width - createPlaylistPopup.width) / 2;
        createPlaylistPopup.y = (Overlay.overlay.height - createPlaylistPopup.height) / 2;
        createPlaylistPopup.open();
    }

    function openPlaylistMenuPopup(manager) {
        root.playlistManager = manager;
        var pos = mapToItem(null, mouseEvent.x, mouseEvent.y)

        playlistMenuPopup.x = pos.x
        playlistMenuPopup.y = pos.y
        
        playlistMenuPopup.open();
    }

    // ==================================
    // |===  Add to Playlist popup   ===|
    // ==================================
    Popup {
        id: addPopup
        property string playlistName: ""
        

        width: 800
        height: 650
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        modal: true
        focus: true
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            RowLayout {
                Label {
                    text: "Add Content to " + addPopup.playlistName
                    color: "white"
                    font.pixelSize: 22
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 30
                    color: "#333333"
                    radius: 6

                    Label {
                        anchors.centerIn: parent
                        text: "Filter"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#121216"
                border.color: "#33333b"
                radius: 6

                ListView {
                    id: trackList
                    anchors.fill: parent
                    anchors.margins: 2
                    clip: true
                    model: trackModel.getAllTracks()

                    delegate: Item {
                        width: ListView.view.width
                        height: 50

                        Rectangle {
                            anchors.fill: parent
                            color: parent.hovered ? "#22222b" : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 5

                                Text {
                                    text: modelData.title
                                    color: "white"
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.artist
                                    color: "#aaa"
                                    Layout.preferredWidth: 200
                                }

                                Button {
                                    text: "Add"
                                    background: Rectangle {
                                        color: "#0078d7"
                                        radius: 6
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: "white"
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 12
                                    }
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 30
                                    onClicked: {
                                        if (root.playlistManager)
                                            root.playlistManager.addTrack(addPopup.playlistName, modelData.filePath);
                                        text = "Added";
                                        enabled = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Button {
                text: "Done"
                Layout.alignment: Qt.AlignRight
                background: Rectangle {
                    color: "#33333b"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 20
                    rightPadding: 20
                    font.pixelSize: 14
                    font.bold: true
                }
                onClicked: addPopup.close()
            }
        }
    }

    //  ========================================
    // |====   Playlist RightClick popup   =====|
    //  ========================================

    Popup {
        id: playlistMenuPopup
        property string playlistName: ""
        anchors.centerIn: parent
        width: 300
        height: 250
        modal: true
        focus: true
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 1
            
            Text {
                text: playlistMenuPopup.playlistName
                color: "white"
                font.bold: true
                font.pixelSize: 24
                Layout.alignment: Qt.AlignHCenter
            }

            Button {
                text: "Open"
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#202025"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                }
                onClicked: {
                    
                }
            }

            Button{
                text: "Add Songs"
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#202025"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                }
                onClicked: {
                    
                    root.openAddPopup(root.playlistManager, playlistMenuPopup.playlistName);
                    playlistMenuPopup.close()
                }
            }

            Button{
                text: "Rename"
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#202025"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                }
                onClicked: {
                    
                }
            }

            Button {
                text: "Delete"
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#202025"
                    radius: 6
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                }
                onClicked: {
                    if (root.playlistManager)
                        root.playlistManager.deletePlaylist(playlistMenuPopup.playlistName);
                    playlistMenuPopup.close()
                }
            }
        }
    }

    //  ===================================
    // |===    Create Playlist popup    ===|
    //  ===================================

    Popup {
        id: createPlaylistPopup
        width: 600
        height: 250
        anchors.centerIn: parent.Center
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10
            
            Text {
                text: "Create Playlist"
                color: "white"
                font.bold: true
                font.pixelSize: 24
                Layout.alignment: Qt.AlignHCenter
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color:"#202025"
                radius: 6

                TextField {
                    id: newPlaylistField
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "white"
                    placeholderText: "Playlist name"
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Item {
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "Cancel"
                    background: Rectangle {
                        color: "#202025"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                    }
                    onClicked: {
                        createPlaylistPopup.close()
                    }
                }
                
                Button {
                    text: "Create"
                    background: Rectangle {
                        color: "#0078d7"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                    }
                    onClicked: {
                        if (newPlaylistField.text !== "") {
                            if (root.playlistManager)
                                root.playlistManager.createPlaylist(newPlaylistField.text);
                            newPlaylistField.text = "";
                            createPlaylistPopup.close()
                        }
                    }
                }
            }
        }
    }
}
