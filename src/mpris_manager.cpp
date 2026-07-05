#include "mpris_manager.h"
#include <QtDBus/QDBusMessage>
#include <QtDBus/QDBusObjectPath>

MprisRootAdaptor::MprisRootAdaptor(MprisManager *parent) 
    : QDBusAbstractAdaptor(parent) {}

MprisPlayerAdaptor::MprisPlayerAdaptor(MprisManager *parent) 
    : QDBusAbstractAdaptor(parent), m_manager(parent) {}

MprisManager::MprisManager(QObject *parent) : QObject(parent) {
    new MprisRootAdaptor(this);
    new MprisPlayerAdaptor(this);

    QDBusConnection dbus = QDBusConnection::sessionBus();
    dbus.registerObject("/org/mpris/MediaPlayer2", this, QDBusConnection::ExportAdaptors);
    dbus.registerService("org.mpris.MediaPlayer2.MLMPlayer");
}

void MprisManager::updateProperties(const QString &interface, const QVariantMap &changed) {
    QDBusMessage msg = QDBusMessage::createSignal("/org/mpris/MediaPlayer2", 
                                                  "org.freedesktop.DBus.Properties", 
                                                  "PropertiesChanged");
    msg << interface << changed << QStringList();
    QDBusConnection::sessionBus().send(msg);
}

void MprisManager::setPlaybackStatus(bool isPlaying) {
    QString newStatus = isPlaying ? "Playing" : "Paused";
    if (m_playbackStatus != newStatus) {
        m_playbackStatus = newStatus;
        updateProperties("org.mpris.MediaPlayer2.Player", {{"PlaybackStatus", m_playbackStatus}});
    }
}

void MprisManager::setMetadata(const QString &id, const QString &title, const QString &artist, 
                               const QString &album, const QString &artUrl, int lengthSeconds) {
    QVariantMap metadata;
    metadata["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack"));
    metadata["xesam:title"] = title;
    metadata["xesam:artist"] = QStringList() << artist;
    metadata["xesam:album"] = album;
    if (!artUrl.isEmpty()) {
        metadata["mpris:artUrl"] = artUrl;
    }
    metadata["mpris:length"] = static_cast<qlonglong>(lengthSeconds) * 1000000LL;

    m_metadata = metadata;
    updateProperties("org.mpris.MediaPlayer2.Player", {{"Metadata", m_metadata}});
}

void MprisManager::setPosition(int positionSeconds) {
    if (m_positionSeconds != positionSeconds) {
        m_positionSeconds = positionSeconds;
    }
}
