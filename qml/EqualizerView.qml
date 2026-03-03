import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: eqRoot
    property int triggerUpdate: 0

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 800)
        height: Math.min(parent.height * 0.8, 600)
        spacing: 30

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Equalizer"
                font.pixelSize: 32
                font.bold: true
                color: "white"
            }
            Item { Layout.fillWidth: true }
            Switch {
                text: "Enable EQ"
                checked: audioEngine.equalizer ? audioEngine.equalizer.enabled : false
                onCheckedChanged: {
                    if (audioEngine.equalizer) audioEngine.equalizer.enabled = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Repeater {
                model: 10 // 10 bands
                delegate: ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: (eqSlider.value > 0 ? "+" : "") + eqSlider.value.toFixed(1) + " dB"
                        color: "#aaa"
                        font.pixelSize: 12
                    }

                    Slider {
                        id: eqSlider
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter
                        orientation: Qt.Vertical
                        from: -12.0
                        to: 12.0
                        value: {
                            var dummy = eqRoot.triggerUpdate;
                            return audioEngine.equalizer ? audioEngine.equalizer.bandGain(index) : 0
                        }
                        enabled: audioEngine.equalizer ? audioEngine.equalizer.enabled : false
                        onMoved: {
                            if (audioEngine.equalizer) {
                                audioEngine.equalizer.setBandGain(index, value)
                            }
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!audioEngine.equalizer) return ""
                            let freq = audioEngine.equalizer.bandFrequency(index)
                            if (freq >= 1000) return (freq / 1000).toFixed(0) + "k"
                            return freq.toFixed(0)
                        }
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 15
            Layout.rightMargin: 10

            Button {
                text: "Load"
                background: Rectangle { color: "#33333b"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
                onClicked: {
                    if (audioEngine.equalizer) {
                        loadPresetPopup.presetList = audioEngine.equalizer.getPresetNames();
                        loadPresetPopup.open();
                    }
                }
            }
            Button {
                text: "Save"
                background: Rectangle { color: "#0078d7"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
                onClicked: {
                    savePresetPopup.open()
                }
            }
        }
    }

    // Save Preset Popup
    Popup {
        id: savePresetPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 300
        height: 200
        modal: true
        focus: true
        background: Rectangle { color: "#18181c"; radius: 8; border.color: "#33333b" }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Label {
                text: "Save Preset"
                font.bold: true
                color: "white"
                font.pixelSize: 18
            }

            TextField {
                id: presetNameField
                Layout.fillWidth: true
                placeholderText: "Preset Name"
                color: "white"
                horizontalAlignment: TextInput.AlignHCenter
                background: Rectangle { color: "#22222b"; radius: 4 }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Cancel"
                    background: Rectangle { color: "#33333b"; radius: 4 }
                    contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 15; rightPadding: 15 }
                    onClicked: savePresetPopup.close()
                }
                Button {
                    text: "Save"
                    background: Rectangle { color: "#0078d7"; radius: 4 }
                    contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; leftPadding: 15; rightPadding: 15 }
                    onClicked: {
                        if (presetNameField.text !== "" && audioEngine.equalizer) {
                            audioEngine.equalizer.saveCustomPreset(presetNameField.text);
                            presetNameField.text = "";
                            savePresetPopup.close();
                        }
                    }
                }
            }
        }
    }

    // Load Preset Popup
    Popup {
        id: loadPresetPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 300
        height: 400
        modal: true
        focus: true
        background: Rectangle { color: "#18181c"; radius: 8; border.color: "#33333b" }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var presetList: []

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Label {
                text: "Load Preset"
                font.bold: true
                color: "white"
                font.pixelSize: 18
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: loadPresetPopup.presetList
                delegate: ItemDelegate {
                    width: ListView.view.width
                    height: 40
                    
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        
                        Text {
                            text: modelData
                            color: "white"
                            font.pixelSize: 16
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        ToolButton {
                            icon.source: "qrc:/qml/icons/close.svg"
                            icon.color: "#ff4444"
                            visible: audioEngine.equalizer ? audioEngine.equalizer.isCustomPreset(modelData) : false
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            padding: 5
                            onClicked: {
                                if (audioEngine.equalizer) {
                                    audioEngine.equalizer.deleteCustomPreset(modelData);
                                    loadPresetPopup.presetList = audioEngine.equalizer.getPresetNames(); // Refresh
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        if (audioEngine.equalizer) {
                            audioEngine.equalizer.loadPreset(modelData);
                            eqRoot.triggerUpdate++;
                            loadPresetPopup.close();
                        }
                    }
                }
            }
            
            Button {
                text: "Close"
                Layout.alignment: Qt.AlignRight
                onClicked: loadPresetPopup.close()
            }
        }
    }
}
