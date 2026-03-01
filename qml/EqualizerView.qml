import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: eqRoot

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
                        value: audioEngine.equalizer ? audioEngine.equalizer.bandGain(index) : 0
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
    }
}
