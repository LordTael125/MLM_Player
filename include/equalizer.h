#ifndef EQUALIZER_H
#define EQUALIZER_H

#include <QObject>
#include <QVector>

class Equalizer : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
  explicit Equalizer(QObject *parent = nullptr);
  ~Equalizer() override = default;

  bool isEnabled() const;
  Q_INVOKABLE int bandCount() const;
  Q_INVOKABLE float bandGain(int index) const; // In dB
  Q_INVOKABLE float bandFrequency(int index) const;

public slots:
  void setEnabled(bool enabled);
  void setBandGain(int index, float gainDb);

signals:
  void enabledChanged(bool enabled);
  void bandGainChanged(int index, float gainDb);

private:
  bool m_enabled{false};
  QVector<float> m_frequencies;
  QVector<float> m_gains; // stored in dB
};

#endif // EQUALIZER_H
