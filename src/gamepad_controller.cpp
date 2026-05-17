#include "gamepad_controller.h"
#include "SDL_gamecontroller.h"
#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QWindow>

GamepadController::GamepadController(QObject *parent) : QObject(parent) {
  // Explicitly initialize only input subsystems to prevent Wayland hotplug/detection issues
  if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER | SDL_INIT_EVENTS) < 0) {
    qWarning() << "SDL could not initialize! SDL_Error:" << SDL_GetError();
    return;
  }

  // Try to open existing controllers
  for (int i = 0; i < SDL_NumJoysticks(); ++i) {
    if (SDL_IsGameController(i)) {
      handleDeviceAdded(i);
    }
  }

  // Run polling loop every ~16ms (60fps)
  connect(&m_pollTimer, &QTimer::timeout, this, &GamepadController::pollEvents);
  m_pollTimer.start(16);
}

GamepadController::~GamepadController() {
  if (m_controller) {
    SDL_GameControllerClose(m_controller);
    m_controller = nullptr;
  }
  SDL_Quit();
}

void GamepadController::handleDeviceAdded(int deviceIndex) {
  if (!m_controller) {
    m_controller = SDL_GameControllerOpen(deviceIndex);
    if (m_controller) {
      qDebug() << "Gamepad connected:" << SDL_GameControllerName(m_controller);
      emit connectionChanged(true);
    } else {
      qWarning() << "Could not open gamepad:" << SDL_GetError();
    }
  }
}

void GamepadController::handleDeviceRemoved(int instanceId) {
  if (m_controller) {
    SDL_Joystick *joystick = SDL_GameControllerGetJoystick(m_controller);
    if (joystick && SDL_JoystickInstanceID(joystick) == instanceId) {
      SDL_GameControllerClose(m_controller);
      m_controller = nullptr;
      qDebug() << "Gamepad disconnected.";
      emit connectionChanged(false);

      // Try to open another one if available
      for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i)) {
          handleDeviceAdded(i);
          break;
        }
      }
    }
  }
}

void GamepadController::simulateKeyPress(int qtKey) {
  // Get the currently active window
  QWindow *activeWindow = QGuiApplication::focusWindow();
  if (!activeWindow)
    return;

  // We post both Press and Release events to simulate a full keystroke
  QKeyEvent *pressEvent =
      new QKeyEvent(QEvent::KeyPress, qtKey, Qt::NoModifier);
  QKeyEvent *releaseEvent =
      new QKeyEvent(QEvent::KeyRelease, qtKey, Qt::NoModifier);

  QCoreApplication::postEvent(activeWindow, pressEvent);
  QCoreApplication::postEvent(activeWindow, releaseEvent);
}

void GamepadController::pollEvents() {
  bool isActive = (QGuiApplication::applicationState() == Qt::ApplicationActive);

  if (!isActive) {
    // Force reset all continuous navigation and triggers when app loses focus
    m_navDirection = NavNone;
    m_triggerL_down = false;
    m_triggerR_down = false;
  }

  SDL_Event e;
  while (SDL_PollEvent(&e) != 0) {
    if (e.type == SDL_CONTROLLERDEVICEADDED) {
      handleDeviceAdded(e.cdevice.which);
    }

    else if (e.type == SDL_CONTROLLERDEVICEREMOVED) {
      handleDeviceRemoved(e.cdevice.which);
    }

    // Ignore all input events if the application is not actively focused
    if (!isActive) {
      continue;
    }

    else if (e.type == SDL_CONTROLLERBUTTONDOWN) {
      switch (e.cbutton.button) {
      case SDL_CONTROLLER_BUTTON_A:
        emit buttonA();
        break;
      case SDL_CONTROLLER_BUTTON_B:
        emit buttonB();
        break;
      case SDL_CONTROLLER_BUTTON_X:
        emit buttonX();
        break;
      case SDL_CONTROLLER_BUTTON_Y:
        emit buttonY();
        break;
      case SDL_CONTROLLER_BUTTON_START:
        emit buttonStart();
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_UP:
        m_navDirection = NavDpadUp;
        m_navTicks = 0;
        m_navInterval = 25;
        emit dpadUp();
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        m_navDirection = NavDpadDown;
        m_navTicks = 0;
        m_navInterval = 25;
        emit dpadDown();
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        m_navDirection = NavDpadLeft;
        m_navTicks = 0;
        m_navInterval = 25;
        emit dpadLeft();
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        m_navDirection = NavDpadRight;
        m_navTicks = 0;
        m_navInterval = 25;
        emit dpadRight();
        break;
      case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
        emit leftShoulder();
        break;
      case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
        emit rightShoulder();
        break;
      case SDL_CONTROLLER_BUTTON_BACK:
        emit buttonSelect();
        break;
      default:
        break;
      }
    }

    else if (e.type == SDL_CONTROLLERBUTTONUP) {
      switch (e.cbutton.button) {
      case SDL_CONTROLLER_BUTTON_DPAD_UP:
        if (m_navDirection == NavDpadUp)
          m_navDirection = NavNone;
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        if (m_navDirection == NavDpadDown)
          m_navDirection = NavNone;
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        if (m_navDirection == NavDpadLeft)
          m_navDirection = NavNone;
        break;
      case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        if (m_navDirection == NavDpadRight)
          m_navDirection = NavNone;
        break;
      default:
        break;
      }
    }

    else if (e.type == SDL_CONTROLLERAXISMOTION) {
      if (e.caxis.axis == SDL_CONTROLLER_AXIS_LEFTX) {
        if (e.caxis.value < -m_deadzone) {
          if (!m_axisX_negative) {
            m_axisX_negative = true;
            m_navDirection = NavLStickLeft;
            m_navTicks = 0;
            m_navInterval = 25;
            emit leftStickLeft();
          }
        } else if (e.caxis.value > m_deadzone) {
          if (!m_axisX_positive) {
            m_axisX_positive = true;
            m_navDirection = NavLStickRight;
            m_navTicks = 0;
            m_navInterval = 25;
            emit leftStickRight();
          }
        } else {
          m_axisX_negative = false;
          m_axisX_positive = false;
          if (m_navDirection == NavLStickLeft ||
              m_navDirection == NavLStickRight) {
            m_navDirection = NavNone;
          }
        }
      }

      else if (e.caxis.axis == SDL_CONTROLLER_AXIS_LEFTY) {
        // Note: SDL Y axis is negative UP, positive DOWN
        if (e.caxis.value < -m_deadzone) {
          if (!m_axisY_negative) {
            m_axisY_negative = true;
            m_navDirection = NavLStickUp;
            m_navTicks = 0;
            m_navInterval = 25;
            emit leftStickUp();
          }
        } else if (e.caxis.value > m_deadzone) {
          if (!m_axisY_positive) {
            m_axisY_positive = true;
            m_navDirection = NavLStickDown;
            m_navTicks = 0;
            m_navInterval = 25;
            emit leftStickDown();
          }
        } else {
          m_axisY_negative = false;
          m_axisY_positive = false;
          if (m_navDirection == NavLStickUp ||
              m_navDirection == NavLStickDown) {
            m_navDirection = NavNone;
          }
        }
      }
      // Triggers for skipping
      else if (e.caxis.axis == SDL_CONTROLLER_AXIS_TRIGGERLEFT) {
        if (e.caxis.value > 16000) {
          if (!m_triggerL_down) {
            m_triggerL_down = true;
            m_triggerTicksL = 0;
            emit triggerLeft();
          }
        } else {
          m_triggerL_down = false;
        }
      } else if (e.caxis.axis == SDL_CONTROLLER_AXIS_TRIGGERRIGHT) {
        if (e.caxis.value > 16000) {
          if (!m_triggerR_down) {
            m_triggerR_down = true;
            m_triggerTicksR = 0;
            emit triggerRight();
          }
        } else {
          m_triggerR_down = false;
        }
      }
      // Right Stick X-Axis
      else if (e.caxis.axis == SDL_CONTROLLER_AXIS_RIGHTX) {
        if (e.caxis.value < -m_deadzone) {
          if (!m_axisRX_negative) {
            m_axisRX_negative = true;
            emit rightStickLeft();
          }
        } else if (e.caxis.value > m_deadzone) {
          if (!m_axisRX_positive) {
            m_axisRX_positive = true;
            emit rightStickRight();
          }
        } else {
          m_axisRX_negative = false;
          m_axisRX_positive = false;
        }
      }
      // Right Stick Y-Axis for volume
      else if (e.caxis.axis == SDL_CONTROLLER_AXIS_RIGHTY) {
        // Polling at 16ms, so adjust by small amount per frame to smooth it out
        if (e.caxis.value < -m_deadzone) {
          emit volumeChange(0.01f);
        } else if (e.caxis.value > m_deadzone) {
          emit volumeChange(-0.01f);
        }
      }
    }
  }

  // Continuous Navigation Logic
  if (m_navDirection != NavNone) {
    m_navTicks++;
    if (m_navTicks >= m_navInterval) {
      m_navTicks = 0;
      m_navInterval =
          m_navInterval > 4 ? m_navInterval - 4 : 4; // accelerate down to ~64ms
      switch (m_navDirection) {
      case NavDpadUp:
        emit dpadUp();
        break;
      case NavDpadDown:
        emit dpadDown();
        break;
      case NavDpadLeft:
        emit dpadLeft();
        break;
      case NavDpadRight:
        emit dpadRight();
        break;
      case NavLStickUp:
        emit leftStickUp();
        break;
      case NavLStickDown:
        emit leftStickDown();
        break;
      case NavLStickLeft:
        emit leftStickLeft();
        break;
      case NavLStickRight:
        emit leftStickRight();
        break;
      default:
        break;
      }
    }
  }

  // Continuous Triggers (Seek Audio) Logic
  if (m_triggerL_down) {
    m_triggerTicksL++;
    if (m_triggerTicksL >= 6) { // ~96ms per tick
      m_triggerTicksL = 0;
      emit triggerLeft();
    }
  }
  if (m_triggerR_down) {
    m_triggerTicksR++;
    if (m_triggerTicksR >= 6) { // ~96ms per tick
      m_triggerTicksR = 0;
      emit triggerRight();
    }
  }
}
