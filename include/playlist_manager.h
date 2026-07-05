#ifndef PLAYLIST_MANAGER_H
#define PLAYLIST_MANAGER_H

#include <QObject>
#include <QStringList>
#include <QVariantList>

class PlaylistManager : public QObject {
  Q_OBJECT
public:
  explicit PlaylistManager(QObject *parent = nullptr);

  Q_INVOKABLE QStringList getPlaylists() const;
  Q_INVOKABLE QStringList getPlaylistTracks(const QString &playlistName) const;

  Q_INVOKABLE void createPlaylist(const QString &name);
  Q_INVOKABLE void deletePlaylist(const QString &name);
  Q_INVOKABLE void addTrack(const QString &playlistName, const QString &trackPath);
  Q_INVOKABLE void removeTrack(const QString &playlistName, const QString &trackPath);
  Q_INVOKABLE void moveTrack(const QString &playlistName, int fromIndex, int toIndex);
  Q_INVOKABLE void sortPlaylist(const QString &playlistName, const QString &sortType);

signals:
  void playlistsChanged();
  void playlistTracksChanged(const QString &playlistName);

private:
  int getPlaylistId(const QString &name) const;
};

#endif // PLAYLIST_MANAGER_H
