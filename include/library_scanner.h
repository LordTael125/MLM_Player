#ifndef LIBRARY_SCANNER_H
#define LIBRARY_SCANNER_H

#include "track.h"
#include <QObject>
#include <QString>
#include <QThread>
#include <QVector>

class LibraryScanner : public QObject {
  Q_OBJECT
public:
  explicit LibraryScanner(QObject *parent = nullptr);
  ~LibraryScanner() override;

  const QVector<Track> &getTracks() const;

public slots:
  void scanDirectory(const QString &directoryPath);
  void clearDatabase();

signals:
  void scanStarted();
  void scanProgress(int filesProcessed);
  void scanFinished(int totalFiles);
  void tracksAdded(const QVector<Track> &newTracks);

private:
  void initializeDatabase();
  void loadDatabase();
  void processFile(const QString &filePath);

  QVector<Track> m_tracks;
};

#endif // LIBRARY_SCANNER_H
