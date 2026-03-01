#ifndef COVER_ART_PROVIDER_H
#define COVER_ART_PROVIDER_H

#include <QImage>
#include <QQuickImageProvider>

class CoverArtProvider : public QQuickImageProvider {
public:
  CoverArtProvider();

  QImage requestImage(const QString &id, QSize *size,
                      const QSize &requestedSize) override;
};

#endif // COVER_ART_PROVIDER_H
