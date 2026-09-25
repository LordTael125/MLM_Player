# Chapter 11 — Gamepad Control

## 11.1 What the Gamepad System Does

The gamepad system allows users to navigate the entire application using a game controller (Xbox, PlayStation, or any SDL2-compatible gamepad). This enables a "lean-back" or "couch mode" experience where the keyboard and mouse are not required.

Features:
- Full D-pad and left-stick navigation through library grids, queues, and menus
- A/B/X/Y button mapping for confirm, back, and context actions
- Trigger-based volume control (hold L/R trigger to decrease/increase volume)
- Automatic hot-plug detection (connect/disconnect a controller at any time)
- Zone-based input routing so buttons do different things depending on which UI element is active

---

## 11.2 Architecture: C++ Polling + QML Routing

The system is split into two layers:

```
┌─────────────────────────────────────────────────────────┐
│  GamepadController (C++ / SDL2)                          │
│  - Initializes SDL2 gamepad subsystem                    │
│  - Polls for button/axis events every 16ms (~60 Hz)      │
│  - Emits Qt signals: buttonA(), dpadUp(), volumeChange() │
│  - Handles hot-plug (device added/removed)               │
└──────────────────────────┬──────────────────────────────┘
                           │ Qt signals
┌──────────────────────────▼──────────────────────────────┐
│  GamepadControl.qml (QML)                                │
│  - Receives signals via Connections { target: gamepad }  │
│  - Maintains a "currentZone" string                      │
│  - Routes each signal to the correct UI action           │
│    based on which zone is currently active                │
└─────────────────────────────────────────────────────────┘
```

---

## 11.3 The C++ Layer: `GamepadController`

### Initialization

```cpp
GamepadController::GamepadController(QObject *parent) : QObject(parent) {
    SDL_Init(SDL_INIT_GAMECONTROLLER);

    // Start a 16ms poll timer (~60 Hz)
    connect(&m_pollTimer, &QTimer::timeout, this, &GamepadController::pollEvents);
    m_pollTimer.start(16);
}
```

SDL2 does not use callbacks like Qt — it uses a polling model. We bridge this with a `QTimer` that calls `pollEvents()` every frame.

### Button and Axis Signals

The controller emits one signal per logical input:

| Signal | Triggered By |
|---|---|
| `buttonA()` | A / Cross button |
| `buttonB()` | B / Circle button |
| `buttonX()` | X / Square button |
| `buttonY()` | Y / Triangle button |
| `dpadUp/Down/Left/Right()` | D-pad directions |
| `leftStickUp/Down/Left/Right()` | Left analog stick (with deadzone) |
| `triggerLeft/Right()` | L2/R2 triggers |
| `leftShoulder/rightShoulder()` | L1/R1 bumpers |
| `buttonStart/Select()` | Start/Select (Menu/View) |
| `volumeChange(delta)` | Continuous trigger hold |

### Deadzone Handling

Analog sticks produce continuous values even when "at rest" due to hardware imprecision. A deadzone of 8000 (out of 32768 max) prevents phantom inputs:

```cpp
int m_deadzone = 8000;

// In pollEvents():
Sint16 axisX = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTX);
if (axisX > m_deadzone && !m_axisX_positive) {
    m_axisX_positive = true;
    emit leftStickRight();
} else if (axisX < m_deadzone) {
    m_axisX_positive = false;
}
```

The boolean tracking (`m_axisX_positive`) ensures the signal fires once when the stick crosses the threshold, not continuously every 16ms.

### Hot-Plug Detection

```cpp
case SDL_CONTROLLERDEVICEADDED:
    handleDeviceAdded(event.cdevice.which);
    break;
case SDL_CONTROLLERDEVICEREMOVED:
    handleDeviceRemoved(event.cdevice.which);
    break;
```

When a controller is plugged in, `handleDeviceAdded` opens it and emits `connectionChanged(true)`. When unplugged, `handleDeviceRemoved` closes it and emits `connectionChanged(false)`. QML can bind to `gamepad.isConnected` to show/hide gamepad UI hints.

---

## 11.4 The QML Layer: `GamepadControl.qml`

### Zone-Based Navigation

The central concept is the **zone** — a string that identifies which part of the UI is currently active:

```qml
property string currentZone: "LibraryGrid"

function evaluateZone() {
    if (eqPopup && eqPopup.opened)           currentZone = "EqPopup";
    else if (mainMenuPopup && mainMenuPopup.opened)  currentZone = "MainMenu";
    else if (queueDrawer && queueDrawer.opened)      currentZone = "QueueDrawer";
    else if (nowPlayingPopup && nowPlayingPopup.opened) currentZone = "NowPlaying";
    else if (launchMode === "Library")       currentZone = "LibraryGrid";
    else                                     currentZone = "NowPlaying";
}
```

The zone is re-evaluated whenever a popup opens or closes, or when the user navigates between views. Each signal handler then switches on the zone:

```qml
function onDpadUp() {
    evaluateZone();
    if (currentZone === "LibraryGrid")
        navigateGrid(-columnsCount);      // Move up one row
    else if (currentZone === "QueueDrawer")
        navigateQueue(-1);                // Move up one item
    else if (currentZone === "EqPopup")
        adjustSlider(+1);                 // Increase EQ band
}
```

### Button Mapping

| Button | Zone: LibraryGrid | Zone: QueueDrawer | Zone: NowPlaying |
|---|---|---|---|
| **A** | Select tile / Play track | Play selected track | Toggle play/pause |
| **B** | Close filter / Back | Close drawer | Close overlay |
| **X** | Open queue | — | — |
| **Y** | Open now playing | — | Open EQ |
| **Start** | Open main menu | — | — |
| **D-pad** | Navigate grid | Navigate list | Seek / Volume |

### Volume Control via Triggers

Holding a trigger continuously adjusts volume:

```qml
Connections {
    target: gamepad
    function onVolumeChange(delta) {
        audioEngine.setVolume(Math.max(0, Math.min(1, audioEngine.volume + delta)));
    }
}
```

The C++ side emits `volumeChange(delta)` with small increments (~0.02) while the trigger is held, providing smooth volume ramping.

---

## 11.5 Dependencies

The gamepad system requires:
- **SDL2 development library**: `pkg_check_modules(SDL2 REQUIRED sdl2)` in CMakeLists.txt
- **Linking**: `${SDL2_LIBRARIES}` and `dl pthread m` in `target_link_libraries`

SDL2 is used only for gamepad input — audio playback uses miniaudio (Chapter 6).
