import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: libraryView
    property string activeCategoryName: "All Tracks"
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Left sidebar for filters
        Rectangle {
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            color: "#18181c"
            radius: 12
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Label {
                    text: "Filters"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                }
                
                Button {
                    text: "Tracks"
                    Layout.fillWidth: true
                    onClicked: {
                        libraryView.activeCategoryName = "All Tracks"
                        trackModel.filterAll()
                        mainStack.clear()
                        mainStack.push(trackGridComponent)
                    }
                }

                
                Button {
                    text: "Artists"
                    Layout.fillWidth: true
                    onClicked: {
                        libraryView.activeCategoryName = "Artists"
                        mainStack.clear()
                        mainStack.push(artistGridComponent)
                    }
                }
                
                Button {
                    text: "Albums"
                    Layout.fillWidth: true
                    onClicked: {
                        libraryView.activeCategoryName = "Albums"
                        mainStack.clear()
                        mainStack.push(albumGridComponent)
                    }
                }

                Button {
                    text: "Folders"
                    Layout.fillWidth: true
                    onClicked: {
                        libraryView.activeCategoryName = "Folders"
                        mainStack.clear()
                        mainStack.push(folderGridComponent)
                    }
                }

                Button {
                    text: "Collections"
                    Layout.fillWidth: true
                    onClicked: {
                        libraryView.activeCategoryName = "Collections"
                        mainStack.clear()
                        mainStack.push(collectionGridComponent)
                    }
                }

                Item { Layout.fillHeight: true } // spacer
            }
        }
        
        // Right side: Tile Grid view
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 15

                Label {
                    text: libraryView.activeCategoryName
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                    Layout.leftMargin: 10
                    Layout.topMargin: 5
                }
                
                StackView {
                    id: mainStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    initialItem: trackGridComponent
                }
            }
        }
    }

    Component {
        id: trackGridComponent
        GridView {
            model: trackModel
            cellWidth: 160
            cellHeight: 200
            clip: true
            
            delegate: Item {
                width: 160
                height: 200
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    
                    // Album Art
                    Rectangle {
                        id: artRect
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: model.hasCoverArt ? "image://musiccover/" + model.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: model.hasCoverArt
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            color: "#555"
                            font.pixelSize: 40
                            visible: !model.hasCoverArt
                        }
                    }
                    
                    Text {
                        anchors.top: artRect.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: model.title
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: model.artist
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            window.playTrackAtIndex(index)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: albumGridComponent
        GridView {
            model: trackModel.getAlbumTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: albArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                        }
                    }
                    Text {
                        anchors.top: albArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.artist
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByAlbum(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: artistGridComponent
        GridView {
            model: trackModel.getArtistTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: artArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 100 // circle
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                        }
                    }
                    Text {
                        anchors.top: artArt.bottom
                        anchors.topMargin: 20
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByArtist(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: folderGridComponent
        GridView {
            model: trackModel.getFolderTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: folderArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                        }
                    }
                    Text {
                        anchors.top: folderArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: "Directory"
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByFolder(modelData.path)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: collectionGridComponent
        GridView {
            model: trackModel.getCollectionTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: collectionArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                        }
                    }
                    Text {
                        anchors.top: collectionArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: "Collection"
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByCollection(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }
}
