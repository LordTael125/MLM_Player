import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: playlistsViewRoot
    
    function forceContentFocus() {
        if (gridView.visible) gridView.forceActiveFocus();
    }
    
    property var modelList: playlistManager.getPlaylists()
    property var playlistName: ""


    Connections {
        target: playlistManager
        function onPlaylistsChanged() {
            playlistsViewRoot.modelList = playlistManager.getPlaylists();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            
            Item {
                Layout.fillWidth: true
            }
            
            Button {
                text: "Create"
                background: Rectangle { color: "#0078d7"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {

                    createPlaylistPopup.open()
                }
            }
        }
        
        GridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: playlistsViewRoot.modelList
            cellWidth: 200
            cellHeight: 200
            clip: true
            focus: true
            
            delegate: Item {
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    
                    Rectangle {
                        id: artRect
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        
                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/qml/icons/view_list.svg"
                            width: 64
                            height: 64
                            sourceSize: Qt.size(64, 64)
                        }
                    }
                    
                    Text {
                        anchors.top: artRect.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: modelData
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 16
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: {
                            if (mouse.button == Qt.LeftButton){
                                libraryView.activeCategoryName = modelData;
                                trackModel.filterByPlaylist(modelData, playlistManager.getPlaylistTracks(modelData));
                                mainStack.push("qrc:/qml/PlaylistDetailsView.qml", { playlistName: modelData });
                            }else if (mouse.button == Qt.RightButton){
                                playlistMenuPopup.playlistName = modelData;
                                playlistMenuPopup.open();
                            }
                        }
                        
                    }
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
    height: 200
    anchors.centerIn: parent
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
            height: 50
            color:"#202025"
            radius: 6

            TextField {
                id: newPlaylistField
                Layout.fillWidth: true
                Layout.margins: 10
                Layout.alignment: Qt.CenterIn
                placeholderText: " Playlist name"
            
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
                        playlistManager.createPlaylist(newPlaylistField.text);
                        newPlaylistField.text = "";
                        createPlaylistPopup.close()
                    }
                }
            }
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
            text: playlistName
            color: "white"
            font.bold: true
            font.pixelSize: 24
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            text: "Open"
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
            text: "Rename"
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
                playlistManager.deletePlaylist(playlistName);
                playlistMenuPopup.close()
            }
        }
    }
}

}

