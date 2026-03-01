#include "cover_art_provider.h"

// TagLib includes
#include <taglib/attachedpictureframe.h>
#include <taglib/fileref.h>
#include <taglib/flacfile.h>
#include <taglib/id3v2tag.h>
#include <taglib/mp4file.h>
#include <taglib/mp4tag.h>
#include <taglib/mpegfile.h>
#include <taglib/tag.h>

CoverArtProvider::CoverArtProvider()
    : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage CoverArtProvider::requestImage(const QString &id, QSize *size,
                                      const QSize &requestedSize) {
  // The incoming ID is the absolute file path, possibly URL-encoded if passed
  // carelessly, but we expect a standard file path.
  QString filePath = id;
  QImage image;

  // Setup a fallback return
  auto returnImage = [&]() {
    if (size)
      *size = image.size();
    if (requestedSize.width() > 0 && requestedSize.height() > 0) {
      image = image.scaled(requestedSize, Qt::KeepAspectRatio,
                           Qt::SmoothTransformation);
    }
    return image;
  };

  if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
    TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
    if (mpegFile.hasID3v2Tag()) {
      TagLib::ID3v2::Tag *id3v2tag = mpegFile.ID3v2Tag();
      if (id3v2tag) {
        auto frameList = id3v2tag->frameListMap()["APIC"];
        if (!frameList.isEmpty()) {
          auto frame = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(
              frameList.front());
          image.loadFromData((const uchar *)frame->picture().data(),
                             frame->picture().size());
        }
      }
    }
  } else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
    TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
    if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) {
      auto picture = flacFile.pictureList().front();
      image.loadFromData((const uchar *)picture->data().data(),
                         picture->data().size());
    }
  } else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
    TagLib::MP4::File mp4File(filePath.toUtf8().constData());
    if (mp4File.isValid() && mp4File.tag()) {
      auto itemList = mp4File.tag()->itemMap();
      if (itemList.contains("covr")) {
        auto covrList = itemList["covr"].toCoverArtList();
        if (!covrList.isEmpty()) {
          auto picture = covrList.front();
          image.loadFromData((const uchar *)picture.data().data(),
                             picture.data().size());
        }
      }
    }
  }

  if (image.isNull()) {
    // Create a basic fallback placeholder
    image = QImage(200, 200, QImage::Format_RGB32);
    image.fill(QColor("#33333b"));
  }

  return returnImage();
}
