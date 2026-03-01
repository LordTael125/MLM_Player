#define MINIAUDIO_IMPLEMENTATION
#include "audio_engine.h"
#include <QDebug>

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent), m_equalizer(new Equalizer(this)) {
  ma_result result = ma_engine_init(nullptr, &m_engine);
  if (result != MA_SUCCESS) {
    qWarning() << "Failed to initialize miniaudio engine.";
    return;
  }
  m_isInitialized = true;

  connect(m_equalizer, &Equalizer::enabledChanged, this,
          &AudioEngine::onEqualizerEnabledChanged);
  connect(m_equalizer, &Equalizer::bandGainChanged, this,
          &AudioEngine::onEqualizerBandGainChanged);

  connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
    if (m_soundLoaded) {
      if (ma_sound_at_end(&m_sound)) {
        stop();
        emit playbackFinished();
      } else if (isPlaying()) {
        emit positionChanged(position());
      }
    }
  });
  m_progressTimer.start(250); // 250ms update interval

  ma_node_graph *pGraph = ma_engine_get_node_graph(&m_engine);
  ma_uint32 channels = ma_engine_get_channels(&m_engine);
  ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);

  for (int i = 0; i < 10; ++i) {
    float freq = m_equalizer->bandFrequency(i);
    ma_peak_node_config config =
        ma_peak_node_config_init(channels, sampleRate, 0.0, 1.414, freq);
    ma_peak_node_init(pGraph, &config, nullptr, &m_eqNodes[i]);

    if (i > 0) {
      ma_node_attach_output_bus(&m_eqNodes[i - 1], 0, &m_eqNodes[i], 0);
    }
  }
  // Attach the last EQ node to the endpoint
  ma_node_attach_output_bus(&m_eqNodes[9], 0, ma_engine_get_endpoint(&m_engine),
                            0);
}

AudioEngine::~AudioEngine() {
  if (m_soundLoaded) {
    ma_sound_uninit(&m_sound);
  }
  if (m_isInitialized) {
    ma_engine_uninit(&m_engine);
  }
}

void AudioEngine::onEqualizerEnabledChanged(bool enabled) {
  // Re-apply gains for all bands
  for (int i = 0; i < 10; ++i) {
    onEqualizerBandGainChanged(i, m_equalizer->bandGain(i));
  }
}

void AudioEngine::onEqualizerBandGainChanged(int index, float gainDb) {
  if (index < 0 || index >= 10)
    return;

  ma_uint32 channels = ma_engine_get_channels(&m_engine);
  ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
  float freq = m_equalizer->bandFrequency(index);
  float actualGain = m_equalizer->isEnabled() ? gainDb : 0.0f;

  ma_peak2_config config = ma_peak2_config_init(
      ma_format_f32, channels, sampleRate, actualGain, 1.414, freq);

  // Miniaudio node graphs are thread-safe or we reinit
  ma_peak_node_reinit((const ma_peak_config *)&config, &m_eqNodes[index]);
}

void AudioEngine::loadFile(const QString &filePath) {
  if (!m_isInitialized)
    return;

  if (m_soundLoaded) {
    ma_sound_uninit(&m_sound);
    m_soundLoaded = false;
  }

  ma_result result = ma_sound_init_from_file(
      &m_engine, filePath.toUtf8().constData(),
      MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_ASYNC, nullptr, nullptr, &m_sound);

  if (result != MA_SUCCESS) {
    emit errorOccurred("Failed to load audio file: " + filePath);
    return;
  }

  // Attach to EQ instead of engine endpoint directly
  ma_node_attach_output_bus(&m_sound, 0, &m_eqNodes[0], 0);

  m_soundLoaded = true;

  // Get duration
  float len = 0.0f;
  ma_sound_get_length_in_seconds(&m_sound, &len);
  emit durationChanged(len);

  emit positionChanged(0.0f);
}

void AudioEngine::play() {
  if (!m_soundLoaded)
    return;
  ma_sound_start(&m_sound);
  emit playingChanged(true);
}

void AudioEngine::pause() {
  if (!m_soundLoaded)
    return;
  ma_sound_stop(&m_sound);
  emit playingChanged(false);
}

void AudioEngine::stop() {
  if (m_soundLoaded) {
    ma_sound_stop(&m_sound);
    ma_sound_seek_to_pcm_frame(&m_sound, 0);
    emit playingChanged(false);
  }
  emit positionChanged(0.0f);
}

void AudioEngine::setPosition(float pos) {
  if (!m_soundLoaded)
    return;

  ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);

  ma_uint64 targetFrame = static_cast<ma_uint64>(pos * sampleRate);
  ma_sound_seek_to_pcm_frame(&m_sound, targetFrame);
  emit positionChanged(pos);
}

void AudioEngine::setVolume(float vol) {
  if (!m_soundLoaded)
    return;
  ma_sound_set_volume(&m_sound, vol);
  emit volumeChanged(vol);
}

bool AudioEngine::isPlaying() const {
  if (!m_soundLoaded)
    return false;
  return ma_sound_is_playing(&m_sound);
}

float AudioEngine::position() const {
  if (!m_soundLoaded)
    return 0.0f;
  float cursor = 0.0f;
  ma_sound_get_cursor_in_seconds(&m_sound, &cursor);
  return cursor;
}

float AudioEngine::duration() const {
  if (!m_soundLoaded)
    return 0.0f;
  float len = 0.0f;
  ma_sound_get_length_in_seconds(&m_sound, &len);
  return len;
}

float AudioEngine::volume() const {
  if (!m_soundLoaded)
    return 1.0f;
  return ma_sound_get_volume(&m_sound);
}
