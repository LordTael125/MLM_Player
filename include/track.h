#ifndef TRACK_H
#define TRACK_H

#include <QString>

struct Track {
  QString filePath;
  QString title;
  QString artist;
  QString album;
  QString genre;
  int duration{0}; // in seconds
  bool hasCoverArt{false};
  int trackNumber{0};
  int discNumber{0};
};

#endif // TRACK_H
