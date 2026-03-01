#include "library_scanner.h"

#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTimer>
#include <QVariant>

// TagLib includes
#include <QUrl>
#include <taglib/attachedpictureframe.h>
#include <taglib/audioproperties.h>
#include <taglib/fileref.h>
#include <taglib/flacfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mpegfile.h>
#include <taglib/tag.h>
#include <taglib/tpropertymap.h>

LibraryScanner::LibraryScanner(QObject *parent) : QObject(parent) {
  initializeDatabase();
  loadDatabase();
}

void LibraryScanner::initializeDatabase() {
  QString dataDir =
      QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
  QDir().mkpath(dataDir);

  QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");
  db.setDatabaseName(dataDir + "/tracks.db");

  if (db.open()) {
    QSqlQuery query;
    query.exec("CREATE TABLE IF NOT EXISTS tracks ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "title TEXT, "
               "artist TEXT, "
               "album TEXT, "
               "genre TEXT, "
               "duration INTEGER, "
               "filePath TEXT UNIQUE, "
               "hasCoverArt INTEGER, "
               "trackNumber INTEGER, "
               "discNumber INTEGER)");

    // Migration patch
    query.exec("ALTER TABLE tracks ADD COLUMN trackNumber INTEGER DEFAULT 0");
    query.exec("ALTER TABLE tracks ADD COLUMN discNumber INTEGER DEFAULT 0");
  } else {
    qWarning() << "Failed to open database:" << db.lastError().text();
  }
}

void LibraryScanner::loadDatabase() {
  QVector<Track> loadedTracks;
  QSqlQuery query("SELECT title, artist, album, genre, duration, filePath, "
                  "hasCoverArt, trackNumber, discNumber FROM tracks");
  while (query.next()) {
    Track t;
    t.title = query.value(0).toString();
    t.artist = query.value(1).toString();
    t.album = query.value(2).toString();
    t.genre = query.value(3).toString();
    t.duration = query.value(4).toInt();
    t.filePath = query.value(5).toString();
    t.hasCoverArt = query.value(6).toBool();
    t.trackNumber = query.value(7).toInt();
    t.discNumber = query.value(8).toInt();
    loadedTracks.append(t);
  }
  if (!loadedTracks.isEmpty()) {
    m_tracks.clear();
    m_tracks.append(loadedTracks);
    QTimer::singleShot(
        0, this, [this, loadedTracks]() { emit tracksAdded(loadedTracks); });
  }
}

void LibraryScanner::clearDatabase() {
  QSqlDatabase db = QSqlDatabase::database();
  if (db.isOpen()) {
    QSqlQuery query;
    query.exec("DELETE FROM tracks");
  }
  m_tracks.clear();
  emit tracksAdded(m_tracks);
}

LibraryScanner::~LibraryScanner() = default;

const QVector<Track> &LibraryScanner::getTracks() const { return m_tracks; }

void LibraryScanner::scanDirectory(const QString &directoryPath) {
  emit scanStarted();

  QString path = directoryPath;
  if (path.startsWith("file://")) {
    path = QUrl(path).toLocalFile();
  }

  QDirIterator it(path,
                  QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a"
                                << "*.aac" << "*.ogg",
                  QDir::Files, QDirIterator::Subdirectories);

  int filesProcessed = 0;
  QVector<Track> newTracks;

  while (it.hasNext()) {
    QString filePath = it.next();

    Track track;
    track.filePath = filePath;

    TagLib::FileRef f(filePath.toUtf8().constData());
    if (!f.isNull() && f.tag()) {
      TagLib::Tag *tag = f.tag();

      track.title = QString::fromStdWString(tag->title().toWString());
      track.artist = QString::fromStdWString(tag->artist().toWString());
      track.album = QString::fromStdWString(tag->album().toWString());
      track.genre = QString::fromStdWString(tag->genre().toWString());

      if (track.title.isEmpty()) {
        track.title = QFileInfo(filePath).completeBaseName();
      }
      if (track.artist.isEmpty()) {
        track.artist = "Unknown Artist";
      }

      TagLib::PropertyMap properties = f.file()->properties();
      if (properties.contains("TRACKNUMBER") &&
          !properties["TRACKNUMBER"].isEmpty()) {
        track.trackNumber = properties["TRACKNUMBER"].front().toInt();
      } else {
        track.trackNumber = tag->track();
      }

      if (properties.contains("DISCNUMBER") &&
          !properties["DISCNUMBER"].isEmpty()) {
        track.discNumber = properties["DISCNUMBER"].front().toInt();
      }

      if (f.audioProperties()) {
        track.duration = f.audioProperties()->lengthInSeconds();
      }

      // Check for cover art
      bool hasArt = false;
      if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
        TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
        if (mpegFile.hasID3v2Tag()) {
          TagLib::ID3v2::Tag *id3v2tag = mpegFile.ID3v2Tag();
          if (id3v2tag) {
            auto frameList = id3v2tag->frameListMap()["APIC"];
            if (!frameList.isEmpty()) {
              hasArt = true;
            }
          }
        }
      } else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
        TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
        if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) {
          hasArt = true;
        }
      } else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
        TagLib::MP4::File mp4File(filePath.toUtf8().constData());
        if (mp4File.isValid() && mp4File.tag()) {
          auto itemList = mp4File.tag()->itemMap();
          if (itemList.contains("covr")) {
            hasArt = true;
          }
        }
      }

      track.hasCoverArt = hasArt;
    } else {
      // Fallback for tags extraction failure
      track.title = QFileInfo(filePath).completeBaseName();
      track.artist = "Unknown Artist";
    }

    newTracks.append(track);
    filesProcessed++;

    if (filesProcessed % 10 == 0) {
      emit scanProgress(filesProcessed);
    }
  }

  QSqlDatabase::database().transaction();
  QSqlQuery insertQuery;
  insertQuery.prepare(
      "INSERT OR REPLACE INTO tracks (title, artist, album, "
      "genre, duration, filePath, hasCoverArt, trackNumber, discNumber) "
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

  for (const Track &t : newTracks) {
    insertQuery.bindValue(0, t.title);
    insertQuery.bindValue(1, t.artist);
    insertQuery.bindValue(2, t.album);
    insertQuery.bindValue(3, t.genre);
    insertQuery.bindValue(4, t.duration);
    insertQuery.bindValue(5, t.filePath);
    insertQuery.bindValue(6, t.hasCoverArt ? 1 : 0);
    insertQuery.bindValue(7, t.trackNumber);
    insertQuery.bindValue(8, t.discNumber);
    insertQuery.exec();
  }
  QSqlDatabase::database().commit();

  loadDatabase();
  emit scanFinished(filesProcessed);
}
