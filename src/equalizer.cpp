#include "equalizer.h"
#include <QMap>
#include <QSettings>
#include <QStringList>
#include <math.h>

// Pre-defined standard EQ templates
static QMap<QString, QVector<float>> getFactoryPresets() {
  QMap<QString, QVector<float>> presets;
  presets["Flat"] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  presets["Acoustic"] = {5, 5, 4, 1, 1, 1, 3, 4, 3, 2};
  presets["Bass Booster"] = {6, 5, 4, 2, 1, 0, 0, 0, 0, 0};
  presets["Classical"] = {5, 4, 3, 2, -1, -1, 0, 2, 3, 4};
  presets["Dance"] = {4, 6, 5, 0, 2, 3, 5, 4, 3, 0};
  presets["Electronic"] = {4, 3, 1, -2, -3, 1, 3, 5, 4, 5};
  presets["Pop"] = {-1, -1, 0, 2, 4, 4, 2, 0, -1, -2};
  presets["Rock"] = {5, 4, 3, 1, -1, -1, 1, 2, 3, 4};
  return presets;
}

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

QStringList Equalizer::getPresetNames() const {
  QStringList names = getFactoryPresets().keys();

  QSettings settings("ModernMusicPlayer", "EqualizerPresets");
  names.append(settings.childGroups());

  names.removeDuplicates();
  names.sort();
  return names;
}

void Equalizer::saveCustomPreset(const QString &name) {
  if (name.isEmpty() || getFactoryPresets().contains(name))
    return;

  QSettings settings("ModernMusicPlayer", "EqualizerPresets");
  settings.beginGroup(name);
  settings.beginWriteArray("bands");
  for (int i = 0; i < m_gains.size(); ++i) {
    settings.setArrayIndex(i);
    settings.setValue("gain", m_gains[i]);
  }
  settings.endArray();
  settings.endGroup();
}

void Equalizer::loadPreset(const QString &name) {
  auto factory = getFactoryPresets();
  if (factory.contains(name)) {
    const auto &gains = factory[name];
    for (int i = 0; i < gains.size() && i < m_gains.size(); ++i) {
      setBandGain(i, gains[i]);
    }
    return;
  }

  QSettings settings("ModernMusicPlayer", "EqualizerPresets");
  if (settings.childGroups().contains(name)) {
    settings.beginGroup(name);
    int size = settings.beginReadArray("bands");
    for (int i = 0; i < size && i < m_gains.size(); ++i) {
      settings.setArrayIndex(i);
      float gain = settings.value("gain").toFloat();
      setBandGain(i, gain);
    }
    settings.endArray();
    settings.endGroup();
  }
}

bool Equalizer::isCustomPreset(const QString &name) const {
  if (name.isEmpty())
    return false;

  // If it's in the factory list, it's NOT custom
  if (getFactoryPresets().contains(name))
    return false;

  // If it's dynamically registered in QSettings, it IS custom
  QSettings settings("ModernMusicPlayer", "EqualizerPresets");
  return settings.childGroups().contains(name);
}

void Equalizer::deleteCustomPreset(const QString &name) {
  if (!isCustomPreset(name))
    return;

  QSettings settings("ModernMusicPlayer", "EqualizerPresets");
  settings.beginGroup(name);
  settings.remove(""); // Erase everything under this group
  settings.endGroup();
}
