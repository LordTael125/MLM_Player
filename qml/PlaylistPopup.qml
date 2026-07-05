import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

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
                text: "Add Content to " + playlistName
                color: "white"
                font.pixelSize: 22
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

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
                                    playlistManager.addTrack(playlistName, modelData.filePath);
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
