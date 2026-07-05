#include "playlist_manager.h"
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>
#include <QVariant>

PlaylistManager::PlaylistManager(QObject *parent) : QObject(parent) {
}

int PlaylistManager::getPlaylistId(const QString &name) const {
  QSqlQuery query;
  query.prepare("SELECT id FROM playlists WHERE name = ?");
  query.bindValue(0, name);
  if (query.exec() && query.next()) {
    return query.value(0).toInt();
  }
  return -1;
}

QStringList PlaylistManager::getPlaylists() const {
  QStringList list;
  QSqlQuery query("SELECT name FROM playlists ORDER BY name ASC");
  while (query.next()) {
    list.append(query.value(0).toString());
  }
  return list;
}

QStringList PlaylistManager::getPlaylistTracks(const QString &playlistName) const {
  QStringList list;
  int pid = getPlaylistId(playlistName);
  if (pid == -1) return list;
  
  QSqlQuery query;
  query.prepare("SELECT track_path FROM playlist_tracks WHERE playlist_id = ? ORDER BY position ASC");
  query.bindValue(0, pid);
  if (query.exec()) {
    while (query.next()) {
      list.append(query.value(0).toString());
    }
  }
  return list;
}

void PlaylistManager::createPlaylist(const QString &name) {
  if (name.isEmpty()) return;
  QSqlQuery query;
  query.prepare("INSERT INTO playlists (name) VALUES (?)");
  query.bindValue(0, name);
  if (query.exec()) {
    emit playlistsChanged();
  }
}

void PlaylistManager::deletePlaylist(const QString &name) {
  int pid = getPlaylistId(name);
  if (pid == -1) return;
  
  QSqlQuery query;
  query.prepare("DELETE FROM playlist_tracks WHERE playlist_id = ?");
  query.bindValue(0, pid);
  query.exec();
  
  query.prepare("DELETE FROM playlists WHERE id = ?");
  query.bindValue(0, pid);
  if (query.exec()) {
    emit playlistsChanged();
  }
}

void PlaylistManager::addTrack(const QString &playlistName, const QString &trackPath) {
  int pid = getPlaylistId(playlistName);
  if (pid == -1) return;
  
  // Check if it already exists to avoid duplicates
  QSqlQuery checkQuery;
  checkQuery.prepare("SELECT position FROM playlist_tracks WHERE playlist_id = ? AND track_path = ?");
  checkQuery.bindValue(0, pid);
  checkQuery.bindValue(1, trackPath);
  if (checkQuery.exec() && checkQuery.next()) {
    return; // Already exists
  }
  
  // Get max position
  int maxPos = 0;
  QSqlQuery posQuery;
  posQuery.prepare("SELECT MAX(position) FROM playlist_tracks WHERE playlist_id = ?");
  posQuery.bindValue(0, pid);
  if (posQuery.exec() && posQuery.next()) {
    maxPos = posQuery.value(0).toInt() + 1;
  }
  
  QSqlQuery query;
  query.prepare("INSERT INTO playlist_tracks (playlist_id, track_path, position) VALUES (?, ?, ?)");
  query.bindValue(0, pid);
  query.bindValue(1, trackPath);
  query.bindValue(2, maxPos);
  
  if (query.exec()) {
    emit playlistTracksChanged(playlistName);
  }
}

void PlaylistManager::removeTrack(const QString &playlistName, const QString &trackPath) {
  int pid = getPlaylistId(playlistName);
  if (pid == -1) return;
  
  QSqlQuery query;
  query.prepare("DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_path = ?");
  query.bindValue(0, pid);
  query.bindValue(1, trackPath);
  
  if (query.exec()) {
    emit playlistTracksChanged(playlistName);
  }
}

void PlaylistManager::moveTrack(const QString &playlistName, int fromIndex, int toIndex) {
  if (fromIndex == toIndex) return;
  
  int pid = getPlaylistId(playlistName);
  if (pid == -1) return;
  
  // To move safely, we should fetch all paths ordered by position, update the list, and write them back
  QStringList tracks = getPlaylistTracks(playlistName);
  if (fromIndex < 0 || fromIndex >= tracks.size() || toIndex < 0 || toIndex >= tracks.size()) return;
  
  QString track = tracks.takeAt(fromIndex);
  tracks.insert(toIndex, track);
  
  QSqlDatabase db = QSqlDatabase::database();
  db.transaction();
  
  QSqlQuery delQuery;
  delQuery.prepare("DELETE FROM playlist_tracks WHERE playlist_id = ?");
  delQuery.bindValue(0, pid);
  delQuery.exec();
  
  QSqlQuery insQuery;
  insQuery.prepare("INSERT INTO playlist_tracks (playlist_id, track_path, position) VALUES (?, ?, ?)");
  for (int i = 0; i < tracks.size(); ++i) {
    insQuery.bindValue(0, pid);
    insQuery.bindValue(1, tracks[i]);
    insQuery.bindValue(2, i);
    insQuery.exec();
  }
  
  db.commit();
  emit playlistTracksChanged(playlistName);
}

void PlaylistManager::sortPlaylist(const QString &playlistName, const QString &sortType) {
  int pid = getPlaylistId(playlistName);
  if (pid == -1) return;
  
  QStringList sortedTracks;
  QSqlQuery query;
  if (sortType == "title") {
    query.prepare("SELECT pt.track_path FROM playlist_tracks pt JOIN tracks t ON pt.track_path = t.filePath WHERE pt.playlist_id = ? ORDER BY t.title ASC");
  } else if (sortType == "artist") {
    query.prepare("SELECT pt.track_path FROM playlist_tracks pt JOIN tracks t ON pt.track_path = t.filePath WHERE pt.playlist_id = ? ORDER BY t.artist ASC, t.title ASC");
  } else if (sortType == "trackNumber") {
    query.prepare("SELECT pt.track_path FROM playlist_tracks pt JOIN tracks t ON pt.track_path = t.filePath WHERE pt.playlist_id = ? ORDER BY t.trackNumber ASC, t.title ASC");
  } else {
    return;
  }
  
  query.bindValue(0, pid);
  if (query.exec()) {
    while (query.next()) {
      sortedTracks.append(query.value(0).toString());
    }
  }
  
  if (sortedTracks.isEmpty()) return;
  
  QSqlDatabase db = QSqlDatabase::database();
  db.transaction();
  
  QSqlQuery delQuery;
  delQuery.prepare("DELETE FROM playlist_tracks WHERE playlist_id = ?");
  delQuery.bindValue(0, pid);
  delQuery.exec();
  
  QSqlQuery insQuery;
  insQuery.prepare("INSERT INTO playlist_tracks (playlist_id, track_path, position) VALUES (?, ?, ?)");
  for (int i = 0; i < sortedTracks.size(); ++i) {
    insQuery.bindValue(0, pid);
    insQuery.bindValue(1, sortedTracks[i]);
    insQuery.bindValue(2, i);
    insQuery.exec();
  }
  
  db.commit();
  emit playlistTracksChanged(playlistName);
}
