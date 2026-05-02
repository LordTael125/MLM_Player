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

signals:
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

  // Trigger tracking
  bool m_triggerL_down = false;
  bool m_triggerR_down = false;
};

#endif // GAMEPAD_CONTROLLER_H
