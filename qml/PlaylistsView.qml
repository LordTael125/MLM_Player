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
}

