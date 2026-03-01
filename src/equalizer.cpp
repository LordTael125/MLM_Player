#include "equalizer.h"
#include <math.h>

Equalizer::Equalizer(QObject *parent) : QObject(parent), m_enabled(false) {
  // A standard 10-band graphic equalizer frequencies
  m_frequencies = {31.25f,  62.5f,   125.0f,  250.0f,  500.0f,
                   1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
  m_gains.fill(0.0f, m_frequencies.size());
}

bool Equalizer::isEnabled() const { return m_enabled; }

void Equalizer::setEnabled(bool enabled) {
  if (m_enabled != enabled) {
    m_enabled = enabled;
    emit enabledChanged(m_enabled);
  }
}

int Equalizer::bandCount() const { return m_frequencies.size(); }

float Equalizer::bandGain(int index) const {
  if (index >= 0 && index < m_gains.size())
    return m_gains[index];
  return 0.0f;
}

float Equalizer::bandFrequency(int index) const {
  if (index >= 0 && index < m_frequencies.size())
    return m_frequencies[index];
  return 0.0f;
}

void Equalizer::setBandGain(int index, float gainDb) {
  // Clamp to logical ranges, e.g. -12dB to +12dB
  float clampedGain = fmaxf(-12.0f, fminf(12.0f, gainDb));

  if (index >= 0 && index < m_gains.size()) {
    if (m_gains[index] != clampedGain) {
      m_gains[index] = clampedGain;
      emit bandGainChanged(index, clampedGain);
    }
  }
}
