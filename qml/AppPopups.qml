import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

Item {
    id: root
    anchors.fill: parent

    // References to main application context and dependencies
    property var window
    property var globalGamepadManager
    property var folderDialog
    property var sessionSettings

    // Convenience properties mapping window state if needed
    property string launchMode: window && window.launchMode ? window.launchMode : "Library"
    property string applicationVersion: window && window.applicationVersion ? window.applicationVersion : "1.3-beta"

    // Exposed Top-Level Aliases for backward compatibility
    property alias volumeOSDPopup: volumeOSDPopup
    property alias mainMenuPopup: mainMenuPopup
    property alias settingsPopup: settingsPopup
    property alias eqPopup: eqPopup
    property alias volumePopup: volumePopup
    property alias nowPlayingPopup: nowPlayingPopup
    property alias shortcutsPopup: shortcutsPopup
    property alias supportPopup: supportPopup
    property alias scanningPopup: scanningPopup
    property alias queueDrawer: queueDrawer
    property alias queueListView: queueListView

    // Helper functions mapped from window if referenced inside popups
    function toggleFullScreen() {
        if (window && typeof window.toggleFullScreen === "function") {
            window.toggleFullScreen();
        }
    }

    // ==========================================
    // 1. Volume OSD Popup
    // ==========================================
    Popup {
        id: volumeOSDPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.85) // Bottom center
        width: 250
        height: 60
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose

        background: Rectangle {
            color: "#cc18181c"
            radius: 30
            border.color: "#33333b"
            border.width: 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 15

            Image {
                source: audioEngine && audioEngine.volume === 0.0 ? "qrc:/qml/icons/volume_off.svg" : "qrc:/qml/icons/volume.svg"
                sourceSize: Qt.size(24, 24)
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }

            ProgressBar {
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                value: audioEngine ? audioEngine.volume : 0.0

                background: Rectangle {
                    implicitHeight: 6
                    color: "#33333b"
                    radius: 3
                }
                contentItem: Item {
                    implicitHeight: 6
                    Rectangle {
                        width: parent.width * (audioEngine ? audioEngine.volume : 0.0)
                        height: parent.height
                        radius: 3
                        color: "#0078d7"
                    }
                }
            }

            Label {
                text: Math.round((audioEngine ? audioEngine.volume : 0.0) * 100) + "%"
                color: "white"
                font.bold: true
                font.pixelSize: 14
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
            }
        }

        Timer {
            id: volumeOSDTimer
            interval: 2000
            onTriggered: volumeOSDPopup.close()
        }

        function show() {
            volumeOSDPopup.open();
            volumeOSDTimer.restart();
        }
    }

    // ==========================================
    // 2. Main Menu Popup
    // ==========================================
    Popup {
        id: mainMenuPopup
        x: window ? window.width - width - 15 : 0
        y: 45
        width: 220
        height: menuLayout.implicitHeight + topPadding + bottomPadding
        padding: 5
        background: Rectangle {
            color: "#18181c"
            border.color: "#33333b"
            radius: 8
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property alias menuList: menuWrapper

        onOpened: {
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
            menuWrapper.forceActiveFocus();
        }
        onClosed: {
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
        }

        Item {
            id: menuWrapper
            anchors.fill: parent

            property int currentIndex: 0

            // We dynamically filter out invisible children (like Exit in fullscreen)
            property var visibleChildren: {
                var arr = [];
                for (var i = 0; i < menuLayout.children.length; i++) {
                    if (menuLayout.children[i].visible && typeof menuLayout.children[i].triggerAction === "function")
                        arr.push(menuLayout.children[i]);
                }
                return arr;
            }

            function decrementCurrentIndex() {
                if (currentIndex > 0)
                    currentIndex--;
            }
            function incrementCurrentIndex() {
                if (currentIndex < visibleChildren.length - 1)
                    currentIndex++;
            }

            property var currentItem: visibleChildren.length > 0 ? visibleChildren[currentIndex] : null

            Rectangle {
                color: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "MainMenu") ? "#1AFFFFFF" : "transparent"
                opacity: 1.0
                radius: 4
                border.color: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "MainMenu") ? "#ffffff" : "transparent"
                border.width: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "MainMenu") ? 2 : 0
                z: 2

                property var targetItem: menuWrapper.currentItem

                x: targetItem ? targetItem.x + menuLayout.x : 0
                y: targetItem ? targetItem.y + menuLayout.y : 0
                width: targetItem ? targetItem.width : 0
                height: targetItem ? targetItem.height : 0

                Behavior on y {
                    SpringAnimation {
                        spring: 3
                        damping: 0.2
                    }
                }
                Behavior on height {
                    SpringAnimation {
                        spring: 3
                        damping: 0.2
                    }
                }
            }

            ColumnLayout {
                id: menuLayout
                anchors.fill: parent
                spacing: 2

                Button {
                    Layout.fillWidth: true
                    text: "Toggle Fullscreen"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        root.toggleFullScreen();
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Scan Directory"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        if (folderDialog)
                            folderDialog.open();
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Clear Database"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        if (libraryScanner)
                            libraryScanner.clearDatabase();
                        if (window) {
                            window.playbackQueue = [];
                            window.currentQueueIndex = -1;
                            window.currentPlayingTitle = "No Song Playing";
                            window.currentPlayingArtist = "";
                            window.currentPlayingPath = "";
                        }
                        if (audioEngine)
                            audioEngine.stop();
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#33333b"
                }
                Button {
                    Layout.fillWidth: true
                    text: "Keyboard Shortcuts"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#0078d7"
                        font.bold: true
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        shortcutsPopup.open();
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "About Music Player"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        supportPopup.open();
                    }
                }

                Rectangle {
                    visible: window && (window.isFullScreen || (globalGamepadManager && globalGamepadManager.controllerConnected))
                    Layout.fillWidth: true
                    height: 1
                    color: "#33333b"
                }

                Button {
                    visible: window && (window.isFullScreen || (globalGamepadManager && globalGamepadManager.controllerConnected))
                    Layout.fillWidth: true
                    text: "Exit"
                    function triggerAction() {
                        clicked();
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        if (window)
                            window.close();
                    }
                }
            }
        }
    }

    // ==========================================
    // 3. Settings Popup
    // ==========================================
    Popup {
        id: settingsPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(parent.width * 0.9, 850)
        height: Math.min(parent.height * 0.8, 650)
        modal: true
        focus: true
        padding: 0
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()
        onClosed: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: 40
                color: '#494954'

                Label {
                    text: "Settings"
                    font.pixelSize: 14
                    color: "white"
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
            }
        }
    }

    // ==========================================
    // 4. Equalizer Popup
    // ==========================================
    Popup {
        id: eqPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(parent.width * 0.9, 850)
        height: Math.min(parent.height * 0.8, 650)
        modal: true
        focus: true
        padding: 0
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()
        onClosed: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()

        EqualizerView {
            anchors.fill: parent
        }
    }

    // ==========================================
    // 5. Volume Popup
    // ==========================================
    Popup {
        id: volumePopup
        width: 60
        height: 240
        padding: 10
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: volumeCloseTimer.start()
        onClosed: volumeCloseTimer.stop()

        Timer {
            id: volumeCloseTimer
            interval: 4000
            onTriggered: volumePopup.close()
        }

        ColumnLayout {
            Layout.margins: 5
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: " " + Math.round((audioEngine ? audioEngine.volume : 0.0) * 100) + "%"
                color: "white"
                font.bold: true
                font.pixelSize: 14
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter
            }

            Slider {
                Layout.fillHeight: true
                Layout.preferredWidth: 40
                orientation: Qt.Vertical
                from: 0.0
                to: 1.0
                value: audioEngine ? audioEngine.volume : 0.0
                focusPolicy: Qt.NoFocus
                onMoved: {
                    if (audioEngine)
                        audioEngine.volume = value;
                    volumeCloseTimer.restart();
                }
                  
                WheelHandler {
                    id: volumeWheelHandler
                    onWheel: (event) => {
                        event.accepted = true;
                        if (event.angleDelta.y > 0) {
                            audioEngine.volume += 0.05;
                            if (audioEngine.volume > 1.0) {
                                audioEngine.volume = 1.0;
                                volumeCloseTimer.restart();
                            }
                        } else {
                            audioEngine.volume -= 0.05;
                            if (audioEngine.volume < 0.0) {
                                audioEngine.volume = 0.0;
                                volumeCloseTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 6. Now Playing Overlay Popup
    // ==========================================
    Popup {
        id: nowPlayingPopup
        x: 0
        y: 0
        width: parent.width
        height: parent.height
        modal: false
        focus: true
        padding: 0
        background: Rectangle {
            color: "#0a0a0c"
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property alias controlsList: npView.controlsList

        onOpened: {
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
            controlsList.forceActiveFocus();
        }
        onClosed: {
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
        }

        NowPlayingView {
            id: npView
            anchors.fill: parent
        }
    }

    // ==========================================
    // 7. Keyboard Shortcuts Popup
    // ==========================================
    Popup {
        id: shortcutsPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 750
        height: 480
        modal: true
        focus: true
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()
        onClosed: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 12

            Label {
                text: "Keyboard Shortcuts"
                font.bold: true
                font.pixelSize: 20
                color: "white"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#33333b"
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 30
                rowSpacing: 15

                Repeater {
                    model: [
                        {
                            k: "Space",
                            d: "Play / Pause"
                        },
                        {
                            k: "Ctrl + Left",
                            d: "Play Previous Track"
                        },
                        {
                            k: "Ctrl + Right",
                            d: "Play Next Track"
                        },
                        {
                            k: "Left / Right",
                            d: "Seek +/- 10 Seconds"
                        },
                        {
                            k: "Up / Down",
                            d: "Volume +/- 10%"
                        },
                        {
                            k: "Ctrl + M",
                            d: "Mute / Unmute"
                        },
                        {
                            k: "Ctrl + P",
                            d: "Toggle Queue Panel"
                        },
                        {
                            k: "F",
                            d: "Toggle Library Filters"
                        },
                        {
                            k: "Ctrl+Shift+F",
                            d: "Toggle Fullscreen"
                        },
                        {
                            k: "Backspace",
                            d: "Go Back (Library)"
                        },
                        {
                            k: "Esc",
                            d: "Close Menus / Popups"
                        },
                        {
                            k: "Ctrl + Q",
                            d: "Quit Player"
                        }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: "transparent"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 24
                                color: "#22222b"
                                radius: 4
                                border.color: "#33333b"

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.k
                                    color: "#0078d7"
                                    font.bold: true
                                    font.pixelSize: 13
                                }
                            }

                            Item {
                                Layout.preferredWidth: 10
                            } // Spacer

                            Label {
                                text: modelData.d
                                color: "#e0e0e0"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                text: "Got It"
                Layout.alignment: Qt.AlignHCenter
                background: Rectangle {
                    color: "#0078d7"
                    radius: 6
                    implicitWidth: 100
                    implicitHeight: 35
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                }
                onClicked: shortcutsPopup.close()
            }
        }
    }

    // ==========================================
    // 8. Support / About Popup
    // ==========================================
    Popup {
        id: supportPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 380
        height: 320
        modal: true
        focus: true
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()
        onClosed: if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
            globalGamepadManager.evaluateZone()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 15

            Label {
                text: "Modern Music Player"
                font.bold: true
                font.pixelSize: 22
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "Version " + root.applicationVersion
                font.pixelSize: 14
                color: "#aaa"
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "Built with Qt C++"
                font.pixelSize: 14
                color: "#aaa"
                Layout.alignment: Qt.AlignHCenter
            }

            Label {
                text: "Covered under <a href='https://www.gnu.org/licenses/gpl-3.0.html'>GPLv3 License</a>"
                font.pixelSize: 14
                color: "white"
                linkColor: "#0078d7"
                Layout.alignment: Qt.AlignHCenter
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#33333b"
            }

            Label {
                text: "Developed by <a href='https://github.com/LordTael125'>LordTael125</a>"
                font.pixelSize: 16
                color: "white"
                linkColor: "#0078d7"
                Layout.alignment: Qt.AlignHCenter
                onLinkActivated: Qt.openUrlExternally(link)
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                text: "Close"
                Layout.alignment: Qt.AlignHCenter
                background: Rectangle {
                    color: "#33333b"
                    radius: 6
                    implicitWidth: 100
                    implicitHeight: 35
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                }
                onClicked: supportPopup.close()
            }
        }
    }

    // ==========================================
    // 9. Scanning Progress Popup
    // ==========================================
    Popup {
        id: scanningPopup
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 350
        height: 180
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        background: Rectangle {
            color: "#18181c"
            radius: 12
            border.color: "#33333b"
            border.width: 1
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: scanningPopup.visible
            }

            Label {
                id: scanningLabel
                text: "Scanning Library..."
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    Connections {
        target: libraryScanner
        function onScanStarted() {
            scanningPopup.open();
            scanningLabel.text = "Scanning Library... Please Wait";
        }
        function onScanProgress(count) {
            scanningLabel.text = "Found " + count + " Tracks...";
        }
        function onScanFinished(total) {
            scanningPopup.close();
        }
    }

    // ==========================================
    // 10. Queue Drawer
    // ==========================================
    Drawer {
        id: queueDrawer
        edge: Qt.RightEdge
        width: Math.min(parent.width * 0.4, 400)
        height: parent.height

        onOpened: {
            queueListView.forceActiveFocus();
            if (window && window.currentQueueIndex >= 0) {
                queueListView.currentIndex = window.currentQueueIndex;
                queueListView.positionViewAtIndex(window.currentQueueIndex, ListView.Center);
            }
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
        }
        onClosed: {
            if (globalGamepadManager && typeof globalGamepadManager.evaluateZone === "function")
                globalGamepadManager.evaluateZone();
        }

        background: Rectangle {
            color: "#18181c"
            border.color: "#33333b"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Label {
                text: "Up Next"
                font.pixelSize: 24
                font.bold: true
                color: "white"
            }

            ListView {
                id: queueListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: window ? window.playbackQueue : null
                cacheBuffer: 1000
                focus: true

                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    color: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "QueueDrawer") ? "#1AFFFFFF" : "transparent"
                    radius: 6
                    border.color: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "QueueDrawer") ? "#ffffff" : "transparent"
                    border.width: (globalGamepadManager && globalGamepadManager.controllerConnected && globalGamepadManager.currentZone === "QueueDrawer") ? 2 : 0
                    z: 2
                    Behavior on y {
                        SpringAnimation {
                            spring: 3
                            damping: 0.2
                        }
                    }
                }

                Keys.onReturnPressed: if (currentItem)
                    currentItem.triggerAction()
                Keys.onSpacePressed: if (currentItem)
                    currentItem.triggerAction()

                add: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 250
                        easing.type: Easing.OutQuad
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 250
                        easing.type: Easing.OutQuad
                    }
                }
                remove: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 250
                        easing.type: Easing.OutQuad
                    }
                }

                delegate: ItemDelegate {
                    id: queueDelegate
                    width: ListView.view.width

                    property bool isCurrentItem: ListView.isCurrentItem

                    height: 60
                    opacity: 1.0
                    visible: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }
                    }

                    // Background for hover and current playing states
                    background: Rectangle {
                        color: window && index === window.currentQueueIndex ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")
                        radius: 6
                        Behavior on color {
                            ColorAnimation {
                                duration: 250
                            }
                        }

                        Rectangle {
                            width: 4
                            height: parent.height
                            anchors.left: parent.left
                            color: "#0078d7"
                            visible: window && index === window.currentQueueIndex
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        Image {
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : "qrc:/qml/icons/play.svg"
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(100, 100)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.title
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.artist
                                color: "#aaa"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    function triggerAction() {
                        if (window)
                            window.playTrackAtIndex(index);
                    }

                    onClicked: {
                        queueListView.currentIndex = index;
                        triggerAction();
                    }
                }
            }
        }
    }
}
