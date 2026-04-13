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
  void loadSpecificFiles(const QStringList &filePaths);
  void appendSpecificFiles(const QStringList &filePaths);
  void loadDatabase();
  void clearDatabase();

signals:
  void scanStarted();
  void scanProgress(int filesProcessed);
  void scanFinished(int totalFiles);
  void tracksAdded(const QVector<Track> &tracks);
  void tracksAppended(const QVector<Track> &tracks);

private:
  void initializeDatabase();
  void processFile(const QString &filePath);

  QVector<Track> m_tracks;
};

#endif // LIBRARY_SCANNER_H
