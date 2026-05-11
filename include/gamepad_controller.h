#ifndef GAMEPAD_CONTROLLER_H
#define GAMEPAD_CONTROLLER_H

#include <QObject>
#include <QTimer>
#include <SDL2/SDL.h>

class GamepadController : public QObject {
  Q_OBJECT
public:
  explicit GamepadController(QObject *parent = nullptr);
  ~GamepadController();

  Q_INVOKABLE void simulateKeyPress(int qtKey);

  Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionChanged)
  bool isConnected() const { return m_controller != nullptr; }

signals:
  void connectionChanged(bool connected);
  void buttonA();
  void buttonB();
  void buttonX();
  void buttonY();

  void dpadUp();
  void dpadDown();
  void dpadLeft();
  void dpadRight();

  void triggerLeft();
  void triggerRight();
  void leftShoulder();
  void rightShoulder();

  void leftStickUp();
  void leftStickDown();
  void leftStickLeft();
  void leftStickRight();

  void rightStickUp();
  void rightStickDown();
  void rightStickLeft();
  void rightStickRight();

  void buttonStart();
  void buttonSelect();

  void volumeChange(float delta);

private slots:
  void pollEvents();

private:
  void handleDeviceAdded(int deviceIndex);
  void handleDeviceRemoved(int instanceId);

  QTimer m_pollTimer;
  SDL_GameController *m_controller = nullptr;
  int m_deadzone = 8000;

  // Track previous axis states to avoid spamming key events
  bool m_axisX_positive = false;
  bool m_axisX_negative = false;
  bool m_axisY_positive = false;
  bool m_axisY_negative = false;
  bool m_axisRX_positive = false;
  bool m_axisRX_negative = false;
  bool m_axisRY_positive = false;
  bool m_axisRY_negative = false;

  // Trigger tracking
  bool m_triggerL_down = false;
  bool m_triggerR_down = false;

  // Continuous navigation tracking
  enum NavDirection { 
      NavNone, 
      NavDpadUp, NavDpadDown, NavDpadLeft, NavDpadRight,
      NavLStickUp, NavLStickDown, NavLStickLeft, NavLStickRight 
  };
  NavDirection m_navDirection = NavNone;
  int m_navTicks = 0;
  int m_navInterval = 0;

  // Continuous trigger tracking
  int m_triggerTicksL = 0;
  int m_triggerTicksR = 0;
};

#endif // GAMEPAD_CONTROLLER_H
