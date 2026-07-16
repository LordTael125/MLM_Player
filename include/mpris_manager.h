#ifndef MPRIS_MANAGER_H
#define MPRIS_MANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QtDBus/QDBusAbstractAdaptor>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusObjectPath>

class MprisManager : public QObject {
  Q_OBJECT
public:
  explicit MprisManager(QObject *parent = nullptr);

public slots:
  void setPlaybackStatus(bool isPlaying);
  void setMetadata(const QString &id, const QString &title,
                   const QString &artist, const QString &album,
                   const QString &artUrl, int lengthSeconds);
  void setPosition(int positionSeconds);

signals:
  void playRequested();
  void pauseRequested();
  void playPauseRequested();
  void stopRequested();
  void nextRequested();
  void previousRequested();
  void seekRequested(int positionSeconds);

private:
  void updateProperties(const QString &interface, const QVariantMap &changed);

  QString m_playbackStatus = "Stopped";
  QVariantMap m_metadata;
  int m_positionSeconds = 0;

  friend class MprisRootAdaptor;
  friend class MprisPlayerAdaptor;
};

// =========================================================
// org.mpris.MediaPlayer2
// =========================================================
class MprisRootAdaptor : public QDBusAbstractAdaptor {
  Q_OBJECT
  Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
  Q_PROPERTY(bool CanQuit READ CanQuit)
  Q_PROPERTY(bool CanRaise READ CanRaise)
  Q_PROPERTY(bool HasTrackList READ HasTrackList)
  Q_PROPERTY(QString Identity READ Identity)
  Q_PROPERTY(QString DesktopEntry READ DesktopEntry)

public:
  explicit MprisRootAdaptor(MprisManager *parent);

  bool CanQuit() const { return false; }
  bool CanRaise() const { return false; }
  bool HasTrackList() const { return false; }
  QString Identity() const { return "MLM Player"; }
  QString DesktopEntry() const { return "MusicPlayer"; }

public slots:
  void Quit() {}
  void Raise() {}
};

// =========================================================
// org.mpris.MediaPlayer2.Player
// =========================================================
class MprisPlayerAdaptor : public QDBusAbstractAdaptor {
  Q_OBJECT
  Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
  Q_PROPERTY(QString PlaybackStatus READ PlaybackStatus)
  Q_PROPERTY(double Rate READ Rate)
  Q_PROPERTY(QVariantMap Metadata READ Metadata)
  Q_PROPERTY(double Volume READ Volume WRITE setVolume)
  Q_PROPERTY(qlonglong Position READ Position)
  Q_PROPERTY(double MinimumRate READ MinimumRate)
  Q_PROPERTY(double MaximumRate READ MaximumRate)
  Q_PROPERTY(bool CanGoNext READ CanGoNext)
  Q_PROPERTY(bool CanGoPrevious READ CanGoPrevious)
  Q_PROPERTY(bool CanPlay READ CanPlay)
  Q_PROPERTY(bool CanPause READ CanPause)
  Q_PROPERTY(bool CanSeek READ CanSeek)
  Q_PROPERTY(bool CanControl READ CanControl)

public:
  explicit MprisPlayerAdaptor(MprisManager *parent);

  QString PlaybackStatus() const { return m_manager->m_playbackStatus; }
  double Rate() const { return 1.0; }
  QVariantMap Metadata() const { return m_manager->m_metadata; }
  double Volume() const { return 1.0; }
  void setVolume(double) {}
  qlonglong Position() const {
    return static_cast<qlonglong>(m_manager->m_positionSeconds) * 1000000LL;
  }
  double MinimumRate() const { return 1.0; }
  double MaximumRate() const { return 1.0; }

  bool CanGoNext() const { return true; }
  bool CanGoPrevious() const { return true; }
  bool CanPlay() const { return true; }
  bool CanPause() const { return true; }
  bool CanSeek() const { return true; }
  bool CanControl() const { return true; }

public slots:
  void Next() { emit m_manager->nextRequested(); }
  void Previous() { emit m_manager->previousRequested(); }
  void Pause() { emit m_manager->pauseRequested(); }
  void PlayPause() { emit m_manager->playPauseRequested(); }
  void Stop() { emit m_manager->stopRequested(); }
  void Play() { emit m_manager->playRequested(); }
  void Seek(qlonglong Offset) {
    emit m_manager->seekRequested(m_manager->m_positionSeconds +
                                  Offset / 1000000LL);
  }
  void SetPosition(const QDBusObjectPath &, qlonglong Position) {
    emit m_manager->seekRequested(Position / 1000000LL);
  }
  void OpenUri(const QString &) {}

private:
  MprisManager *m_manager;
};

#endif // MPRIS_MANAGER_H
