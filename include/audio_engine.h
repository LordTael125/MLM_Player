#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include "equalizer.h"
#include <QObject>
#include <QString>
#include <QTimer>
#include <miniaudio.h>

class AudioEngine : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingChanged)
  Q_PROPERTY(
      float position READ position WRITE setPosition NOTIFY positionChanged)
  Q_PROPERTY(float duration READ duration NOTIFY durationChanged)
  Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
  Q_PROPERTY(Equalizer *equalizer READ equalizer CONSTANT)

public:
  explicit AudioEngine(QObject *parent = nullptr);
  ~AudioEngine() override;

  bool isPlaying() const;
  float position() const; // in seconds
  float duration() const; // in seconds
  float volume() const;   // 0.0 to 1.0
  Equalizer *equalizer() const { return m_equalizer; }

public slots:
  void loadFile(const QString &filePath);
  void play();
  void pause();
  void stop();
  void setPosition(float pos);
  void setVolume(float vol);

signals:
  void playingChanged(bool isPlaying);
  void positionChanged(float position);
  void durationChanged(float duration);
  void volumeChanged(float volume);
  void playbackFinished();
  void errorOccurred(const QString &message);

private slots:
  void onEqualizerEnabledChanged(bool enabled);
  void onEqualizerBandGainChanged(int index, float gainDb);

private:
  static void dataCallback(ma_device *pDevice, void *pOutput,
                           const void *pInput, ma_uint32 frameCount);

  ma_engine m_engine;
  ma_sound m_sound;
  bool m_isInitialized{false};
  bool m_soundLoaded{false};
  float m_volume{1.0f};

  Equalizer *m_equalizer{nullptr};
  ma_peak_node m_eqNodes[10];
  QTimer m_progressTimer;
};

#endif // AUDIO_ENGINE_H
