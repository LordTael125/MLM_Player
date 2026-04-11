import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import Qt.labs.settings 1.0

Item {
    id: libraryView
    property string activeCategoryName: "All Tracks"
    property string categoryContext: "All Tracks"
    property bool isSidebarVisible: false
    property bool isListview: false
    signal menuClicked

    Settings {
        id: librarySettings
        category: "LibraryView"
        property alias savedviewMode: libraryView.isListview
        property alias savedSidebarVisible: libraryView.isSidebarVisible
    }

    function goBack() {
        if (mainStack.depth > 1) {
            mainStack.pop();
            libraryView.activeCategoryName = libraryView.categoryContext;
        }
    }

    function switchview() {
        if (isListview) {
            isListview = false;
        } else {
            isListview = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 10

        // Left sidebar for filters
        Rectangle {
            id: sidebarRect
            Layout.preferredWidth: isSidebarVisible ? 200 : 0
            Layout.fillHeight: true
            color: "#18181c"
            radius: 12
            clip: true
            visible: Layout.preferredWidth > 0

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                anchors.fill: parent

                Label {
                    text: "Filters"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }

                Repeater {
                    model: [
                        {
                            name: "Tracks",
                            ctx: "All Tracks"
                        },
                        {
                            name: "Artists",
                            ctx: "Artists"
                        },
                        {
                            name: "Albums",
                            ctx: "Albums"
                        },
                        {
                            name: "Folders",
                            ctx: "Folders"
                        },
                        {
                            name: "Collections",
                            ctx: "Collections"
                        }
                    ]

                    delegate: ItemDelegate {
                        Layout.fillWidth: true
                        height: 50
                        hoverEnabled: true

                        property bool isActive: libraryView.categoryContext === modelData.ctx

                        background: Rectangle {
                            color: parent.isActive ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")

                            // Left accent bar for active tab
                            Rectangle {
                                width: 4
                                height: parent.height
                                anchors.left: parent.left
                                color: "#0078d7" // Accent color
                                visible: parent.parent.isActive
                            }
                        }

                        contentItem: Text {
                            text: modelData.name
                            color: parent.isActive ? "white" : "#aaa"
                            font.pixelSize: 16
                            font.bold: parent.isActive
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 20
                        }

                        onClicked: {
                            libraryView.activeCategoryName = modelData.name === "Tracks" ? "All Tracks" : modelData.name;
                            libraryView.categoryContext = modelData.ctx;
                            if (modelData.name === "Tracks")
                                trackModel.filterAll();
                            mainStack.clear();
                            mainStack.push(unifiedCategoryView, {
                                categoryType: modelData.name
                            });
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                } // spacer
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.topMargin: 5
                    spacing: 10

                    ToolButton {
                        icon.source: libraryView.isSidebarVisible ? "qrc:/qml/icons/panel_close.svg" : "qrc:/qml/icons/panel_open.svg"
                        icon.color: "white"
                        onClicked: libraryView.isSidebarVisible = !libraryView.isSidebarVisible
                    }

                    ToolButton {
                        visible: mainStack.depth > 1
                        icon.source: "qrc:/qml/icons/back.svg"
                        icon.color: "white"
                        onClicked: libraryView.goBack()
                    }

                    Label {
                        text: libraryView.activeCategoryName
                        font.pixelSize: 28
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                    }

                    ToolButton {
                        icon.source: libraryView.isListview ? "qrc:/qml/icons/view_list.svg" : "qrc:/qml/icons/view_grid.svg"
                        icon.color: "white"
                        onClicked: libraryView.switchview()
                    }

                    ToolButton {
                        icon.source: "qrc:/qml/icons/menu.svg"
                        icon.color: "white"
                        icon.width: 24
                        icon.height: 24
                        display: AbstractButton.IconOnly
                        onClicked: libraryView.menuClicked()
                    }
                }

                StackView {
                    id: mainStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Component.onCompleted: push(unifiedCategoryView, {
                        categoryType: "Tracks"
                    })
                }
            }
        }
    }

    Component {
        id: unifiedCategoryView

        Item {
            id: categoryContainer
            property string categoryType // "Tracks", "Artists", "Albums", "Folders", "Collections"
            property var activeModel: {
                if (categoryType === "Tracks")
                    return trackModel;
                if (categoryType === "Albums")
                    return trackModel.getAlbumTiles();
                if (categoryType === "Artists")
                    return trackModel.getArtistTiles();
                if (categoryType === "Folders")
                    return trackModel.getFolderTiles();
                if (categoryType === "Collections")
                    return trackModel.getCollectionTiles();
                return trackModel;
            }

            Loader {
                anchors.fill: parent
                sourceComponent: libraryView.isListview ? listComp : gridComp
            }

            Component {
                id: gridComp
                GridView {
                    model: categoryContainer.activeModel
                    cellWidth: categoryContainer.categoryType === "Tracks" ? 160 : 180
                    cellHeight: categoryContainer.categoryType === "Tracks" ? 200 : 220
                    clip: true
                    cacheBuffer: 1000

                    delegate: Item {
                        width: categoryContainer.categoryType === "Tracks" ? 160 : 180
                        height: categoryContainer.categoryType === "Tracks" ? 200 : 220

                        property bool isTrack: categoryContainer.categoryType === "Tracks"
                        property string dTitle: isTrack ? model.title : modelData.name
                        property string dSubtitle: {
                            if (isTrack)
                                return model.artist;
                            if (categoryContainer.categoryType === "Folders")
                                return "Directory";
                            if (categoryContainer.categoryType === "Collections")
                                return "Collection";
                            return modelData.artist || "";
                        }
                        property string dPath: isTrack ? model.filePath : (modelData.filePath || "")
                        property bool dHasCoverArt: isTrack ? model.hasCoverArt : (modelData.hasCoverArt !== undefined ? modelData.hasCoverArt : false)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 10
                            color: (isTrack && window.currentPlayingPath === dPath) ? "#2a2a35" : "#202025"
                            radius: 8
                            border.color: (isTrack && window.currentPlayingPath === dPath) ? "#0078d7" : "transparent"
                            border.width: (isTrack && window.currentPlayingPath === dPath) ? 2 : 0

                            Rectangle {
                                id: artRect
                                width: parent.width - 20
                                height: width
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "#33333b"
                                radius: categoryContainer.categoryType === "Artists" ? 100 : 8
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: dHasCoverArt ? "image://musiccover/" + dPath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: dHasCoverArt
                                    asynchronous: true
                                    sourceSize: Qt.size(200, 200)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "?"
                                    color: "#555"
                                    font.pixelSize: 40
                                    visible: !dHasCoverArt
                                }
                            }

                            Text {
                                id: titleText
                                anchors.top: artRect.bottom
                                anchors.topMargin: categoryContainer.categoryType === "Artists" ? 20 : 10
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                text: dTitle
                                color: "white"
                                elide: Text.ElideRight
                                font.bold: true
                                font.pixelSize: categoryContainer.categoryType === "Artists" ? 18 : 14
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                visible: categoryContainer.categoryType !== "Artists"
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                text: dSubtitle
                                color: "#aaa"
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (isTrack) {
                                        window.playTrackAtIndex(index, libraryView.activeCategoryName);
                                    } else {
                                        libraryView.activeCategoryName = modelData.name;
                                        if (categoryContainer.categoryType === "Albums")
                                            trackModel.filterByAlbum(modelData.name);
                                        else if (categoryContainer.categoryType === "Artists")
                                            trackModel.filterByArtist(modelData.name);
                                        else if (categoryContainer.categoryType === "Folders")
                                            trackModel.filterByFolder(modelData.path);
                                        else if (categoryContainer.categoryType === "Collections")
                                            trackModel.filterByCollection(modelData.name);

                                        mainStack.push(unifiedCategoryView, {
                                            categoryType: "Tracks"
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: listComp
                ListView {
                    model: categoryContainer.activeModel
                    clip: true
                    cacheBuffer: 1000

                    delegate: Item {
                        width: ListView.view.width
                        height: 60

                        property bool isTrack: categoryContainer.categoryType === "Tracks"
                        property string dTitle: isTrack ? model.title : modelData.name
                        property string dSubtitle: {
                            if (isTrack)
                                return model.artist;
                            if (categoryContainer.categoryType === "Folders")
                                return "Directory";
                            if (categoryContainer.categoryType === "Collections")
                                return "Collection";
                            return modelData.artist || "";
                        }
                        property string dPath: isTrack ? model.filePath : (modelData.filePath || "")
                        property bool dHasCoverArt: isTrack ? model.hasCoverArt : (modelData.hasCoverArt !== undefined ? modelData.hasCoverArt : false)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: (isTrack && window.currentPlayingPath === dPath) ? "#2a2a35" : (hoverArea.containsMouse ? "#22222b" : "transparent")
                            border.color: (isTrack && window.currentPlayingPath === dPath) ? "#0078d7" : "transparent"
                            border.width: (isTrack && window.currentPlayingPath === dPath) ? 2 : 0
                            radius: 6

                            Rectangle {
                                id: listThumb
                                width: 44
                                height: 44
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#33333b"
                                radius: categoryContainer.categoryType === "Artists" ? 22 : 4
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
                                id: listTitleText
                                anchors.left: listThumb.right
                                anchors.leftMargin: 15
                                anchors.right: parent.right
                                anchors.rightMargin: 15
                                anchors.top: parent.top
                                anchors.topMargin: categoryContainer.categoryType === "Artists" ? 20 : 10
                                text: dTitle
                                color: "white"
                                elide: Text.ElideRight
                                font.bold: true
                                font.pixelSize: 15
                            }

                            Text {
                                visible: categoryContainer.categoryType !== "Artists"
                                anchors.left: listThumb.right
                                anchors.leftMargin: 15
                                anchors.right: parent.right
                                anchors.rightMargin: 15
                                anchors.top: listTitleText.bottom
                                anchors.topMargin: 2
                                text: dSubtitle
                                color: "#aaa"
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (isTrack) {
                                        window.playTrackAtIndex(index, libraryView.activeCategoryName);
                                    } else {
                                        libraryView.activeCategoryName = modelData.name;
                                        if (categoryContainer.categoryType === "Albums")
                                            trackModel.filterByAlbum(modelData.name);
                                        else if (categoryContainer.categoryType === "Artists")
                                            trackModel.filterByArtist(modelData.name);
                                        else if (categoryContainer.categoryType === "Folders")
                                            trackModel.filterByFolder(modelData.path);
                                        else if (categoryContainer.categoryType === "Collections")
                                            trackModel.filterByCollection(modelData.name);

                                        mainStack.push(unifiedCategoryView, {
                                            categoryType: "Tracks"
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
