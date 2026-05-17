import QtQuick 2.15

Item {
    id: root

    property string currentZone: "LibraryGrid"
    property bool controllerConnected: typeof gamepad !== "undefined" && gamepad ? gamepad.isConnected : false

    // References to main window components
    property var window

    // UI components
    property var libraryViewMain
    property var queueListView
    property var queueDrawer
    property var nowPlayingPopup
    property var eqPopup
    property var shortcutsPopup
    property var supportPopup
    property var mainMenuPopup
    property var volumePopup
    property var playbackBar
    property var volumeOSDPopup

    function evaluateZone() {
        if (supportPopup && supportPopup.opened) {
            currentZone = "SupportPopup";
        } else if (shortcutsPopup && shortcutsPopup.opened) {
            currentZone = "ShortcutsPopup";
        } else if (eqPopup && eqPopup.opened) {
            currentZone = "EqPopup";
        } else if (mainMenuPopup && mainMenuPopup.opened) {
            currentZone = "MainMenu";
        } else if (queueDrawer && queueDrawer.opened) {
            currentZone = "QueueDrawer";
        } else if (nowPlayingPopup && nowPlayingPopup.opened) {
            currentZone = "NowPlaying";
        } else if (launchMode === "Library") {
            if (libraryViewMain && libraryViewMain.isSidebarVisible) {
                currentZone = "LibrarySidebar";
            } else {
                currentZone = "LibraryGrid";
            }
        } else {
            currentZone = "NowPlaying";
        }
        console.log("GamepadControl Zone dynamically evaluated to:", currentZone);
    }

    Connections {
        target: gamepad

        function onButtonA() {
            root.triggerAction();
        }

        function onButtonB() {
            if (nowPlayingPopup && nowPlayingPopup.opened)
                nowPlayingPopup.close();
            else if (queueDrawer && queueDrawer.opened)
                queueDrawer.close();
            else if (eqPopup && eqPopup.opened)
                eqPopup.close();
            else if (shortcutsPopup && shortcutsPopup.opened)
                shortcutsPopup.close();
            else if (supportPopup && supportPopup.opened)
                supportPopup.close();
            else if (mainMenuPopup && mainMenuPopup.opened)
                mainMenuPopup.close();
            else if (launchMode === "Library" && libraryViewMain)
                libraryViewMain.goBack();
            else if (volumePopup && volumePopup.opened)
                volumePopup.close();
        }

        function onButtonX() {
            if (launchMode === "Minimal")
                return;
            if (nowPlayingPopup) {
                if (nowPlayingPopup.opened)
                    nowPlayingPopup.close();
                else
                    nowPlayingPopup.open();
            }
        }

        function onButtonY() {
            if (launchMode === "Minimal")
                return;
            if (launchMode === "Library" && libraryViewMain) {
                libraryViewMain.toggleSidebar();
                root.evaluateZone();
            }
        }

        function onButtonStart() {
            if (launchMode === "Minimal")
                return;
            if (mainMenuPopup) {
                if (mainMenuPopup.opened)
                    mainMenuPopup.close();
                else
                    mainMenuPopup.open();
            }
        }

        function onDpadUp() {
            if (queueDrawer) {
                if (queueDrawer.opened)
                    queueDrawer.close();
                else
                    queueDrawer.open();
            }
        }

        function onDpadDown() {
            if (volumePopup && volumePopup.opened) {
                volumePopup.close();
            } else if (window && playbackBar) {
                window.showVolumePopup(playbackBar);
            }
        }

        function onTriggerLeft() {
            if (audioEngine)
                audioEngine.setPosition(Math.max(0.0, audioEngine.position - 5.0));
        }

        function onTriggerRight() {
            if (audioEngine)
                audioEngine.setPosition(Math.min(audioEngine.duration, audioEngine.position + 5.0));
        }

        function onVolumeChange(delta) {
            if (audioEngine) {
                audioEngine.volume = Math.max(0.0, Math.min(1.0, audioEngine.volume + delta));
                if (volumeOSDPopup)
                    volumeOSDPopup.show();
            }
        }

        function onLeftStickUp() {
            root.handleNavigation("Up");
        }
        function onLeftStickDown() {
            root.handleNavigation("Down");
        }
        function onLeftStickLeft() {
            root.handleNavigation("Left");
        }
        function onLeftStickRight() {
            root.handleNavigation("Right");
        }

        function onLeftShoulder() {
            if (audioEngine && window) {
                if (audioEngine.position > 2.0) {
                    audioEngine.setPosition(0.0);
                } else {
                    if (window.currentQueueIndex > 0) {
                        window.playTrackAtIndex(window.currentQueueIndex - 1);
                    } else {
                        audioEngine.setPosition(0.0);
                    }
                }
            }
        }

        function onRightShoulder() {
            if (window && window.playbackQueue) {
                if (window.currentQueueIndex >= 0 && window.currentQueueIndex < window.playbackQueue.length - 1) {
                    window.playTrackAtIndex(window.currentQueueIndex + 1);
                }
            }
        }

        function onButtonSelect() {
            if (launchMode === "Minimal") {
                root.triggerAction();
            } else if (window && window.libraryViewMain) {
                window.libraryViewMain.switchView();
                root.evaluateZone();
            }
        }
    }

    function handleNavigation(dir) {
        if (currentZone === "LibraryGrid") {
            if (!libraryViewMain)
                return;
            var gridItem = libraryViewMain.getActiveGridView();
            if (!gridItem)
                return;

            if (dir === "Up") {
                if (typeof gridItem.moveCurrentIndexUp === "function")
                    gridItem.moveCurrentIndexUp();
                else if (typeof gridItem.decrementCurrentIndex === "function")
                    gridItem.decrementCurrentIndex();
            } else if (dir === "Down") {
                if (typeof gridItem.moveCurrentIndexDown === "function")
                    gridItem.moveCurrentIndexDown();
                else if (typeof gridItem.incrementCurrentIndex === "function")
                    gridItem.incrementCurrentIndex();
            } else if (dir === "Left") {
                if (typeof gridItem.moveCurrentIndexLeft === "function")
                    gridItem.moveCurrentIndexLeft();
                else if (typeof gridItem.decrementCurrentIndex === "function" && gridItem.orientation === ListView.Horizontal)
                    gridItem.decrementCurrentIndex();
            } else if (dir === "Right") {
                if (typeof gridItem.moveCurrentIndexRight === "function")
                    gridItem.moveCurrentIndexRight();
                else if (typeof gridItem.incrementCurrentIndex === "function" && gridItem.orientation === ListView.Horizontal)
                    gridItem.incrementCurrentIndex();
            }
        } else if (currentZone === "LibrarySidebar") {
            if (!libraryViewMain || !libraryViewMain.filterListView)
                return;
            var filterList = libraryViewMain.filterListView;
            if (dir === "Up")
                filterList.decrementCurrentIndex();
            else if (dir === "Down")
                filterList.incrementCurrentIndex();
        } else if (currentZone === "QueueDrawer") {
            if (!queueListView)
                return;
            if (dir === "Up")
                queueListView.decrementCurrentIndex();
            else if (dir === "Down")
                queueListView.incrementCurrentIndex();
        } else if (currentZone === "MainMenu") {
            if (!mainMenuPopup || !mainMenuPopup.menuList)
                return;
            var mList = mainMenuPopup.menuList;
            if (dir === "Up")
                mList.decrementCurrentIndex();
            else if (dir === "Down")
                mList.incrementCurrentIndex();
        } else if (currentZone === "NowPlaying") {
            if (!nowPlayingPopup || !nowPlayingPopup.controlsList)
                return;
            var npList = nowPlayingPopup.controlsList;
            if (dir === "Left")
                npList.decrementCurrentIndex();
            else if (dir === "Right")
                npList.incrementCurrentIndex();
        }
    }

    function triggerAction() {
        if (currentZone === "LibraryGrid") {
            if (!libraryViewMain)
                return;
            var gridItem = libraryViewMain.getActiveGridView();
            if (gridItem && gridItem.currentItem)
                gridItem.currentItem.triggerAction();
        } else if (currentZone === "LibrarySidebar") {
            if (!libraryViewMain || !libraryViewMain.filterListView)
                return;
            var filterList = libraryViewMain.filterListView;
            if (filterList && filterList.currentItem)
                filterList.currentItem.triggerAction();
        } else if (currentZone === "QueueDrawer") {
            if (queueListView && queueListView.currentItem)
                queueListView.currentItem.triggerAction();
        } else if (currentZone === "MainMenu") {
            if (mainMenuPopup && mainMenuPopup.menuList && mainMenuPopup.menuList.currentItem) {
                mainMenuPopup.menuList.currentItem.triggerAction();
            }
        } else if (currentZone === "NowPlaying") {
            if (nowPlayingPopup && nowPlayingPopup.controlsList && nowPlayingPopup.controlsList.currentItem) {
                nowPlayingPopup.controlsList.currentItem.triggerAction();
            }
        }
    }
}
