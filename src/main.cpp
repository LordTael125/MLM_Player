#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"
#include "gamepad_controller.h"
#include "playlist_manager.h"

// TagLib includes
#include <QtNetwork/QLocalServer>
#include <QtNetwork/QLocalSocket>
#include <qchar.h>
#include <qcoreapplication.h>
#include <qlist.h>
#include <taglib/tdebuglistener.h>

class SilentTagLibListener : public TagLib::DebugListener {
public:
  void printMessage(const TagLib::String &msg) override {
    // Suppress TagLib debug and warning messages from polluting the console
  }
};

int main(int argc, char *argv[]) {
  // Silence TagLib
  static SilentTagLibListener silentListener;
  TagLib::setDebugListener(&silentListener);
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
  QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

  // Hardcode the QML Material Dark theme explicitly to prevent OS Light-theme
  // overrides
  qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
  qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT", "Purple");

  // Application metadata for QSettings
  QCoreApplication::setOrganizationName("LordTael");
  QCoreApplication::setOrganizationDomain("lordtael.com");
  QCoreApplication::setApplicationName("MLP Player");

  QApplication app(argc, argv);

  QStringList args = QCoreApplication::arguments();
  QStringList filepath = args.mid(1);

  QString launchMode;
  if (filepath.isEmpty()) {
    launchMode = "Library";
  } else if (filepath.size() == 1) {
    launchMode = "Minimal";
  } else {
    launchMode = "Queue";
  }

  // Single Instance Interceptor
  bool isIpcServerRunning = false;
  QLocalSocket socket;
  socket.connectToServer("MLP_MusicPlayerIPC");
  if (socket.waitForConnected(500)) {
    isIpcServerRunning = true;
    if (launchMode != "Library") {
      if (!filepath.isEmpty()) {
        socket.write(filepath.join('\n').toUtf8());
        socket.waitForBytesWritten(1000);
      }
      return 0; // Exit successfully, yielding to the original process
    }
    socket.disconnectFromServer();
  }

  // Register Equalizer structure for QML so it can interact with the pointer
  // correctly
  qmlRegisterUncreatableType<Equalizer>("com.musicplayer", 1, 0, "Equalizer",
                                        "Equalizer cannot be created in QML");

  // Core Backend instances
  AudioEngine audioEngine;
  LibraryScanner libraryScanner;
  TrackModel trackModel;
  GamepadController gamepad;
  PlaylistManager playlistManager;

  // Connect scanner to model
  QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded, &trackModel,
                   &TrackModel::setTracks);
  QObject::connect(&libraryScanner, &LibraryScanner::tracksAppended, &trackModel,
                   &TrackModel::addTracks);
                   
  QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                   &libraryScanner, &LibraryScanner::updatePlayTime);
  QObject::connect(&audioEngine, &AudioEngine::playTimeAccumulated,
                   &trackModel, &TrackModel::updateTrackPlayTime);

  if (launchMode == "Library") {
    libraryScanner.loadDatabase();
  } else {
    libraryScanner.loadSpecificFiles(filepath);
  }

  // Bind the IPC Server to catch new OS explorer hooks
  if (!isIpcServerRunning) {
    QLocalServer::removeServer("MLP_MusicPlayerIPC");
    QLocalServer *server = new QLocalServer(&app);
    server->listen("MLP_MusicPlayerIPC");
    QObject::connect(
        server, &QLocalServer::newConnection, [&libraryScanner, server]() {
          QLocalSocket *clientSocket = server->nextPendingConnection();
          QObject::connect(clientSocket, &QLocalSocket::readyRead,
                           [&libraryScanner, clientSocket]() {
                             QByteArray data = clientSocket->readAll();
                             QStringList newFiles = QString::fromUtf8(data).split(
                                 '\n', Qt::SkipEmptyParts);
                             if (!newFiles.isEmpty()) {
                               libraryScanner.appendSpecificFiles(newFiles);
                             }
                           });
          QObject::connect(clientSocket, &QLocalSocket::disconnected,
                           clientSocket, &QLocalSocket::deleteLater);
        });
  }

  QQmlApplicationEngine engine;
  engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

  // Provide these to QML
  engine.rootContext()->setContextProperty("launchMode", launchMode);
  engine.rootContext()->setContextProperty("audioEngine", &audioEngine);
  engine.rootContext()->setContextProperty("libraryScanner", &libraryScanner);
  engine.rootContext()->setContextProperty("trackModel", &trackModel);
  engine.rootContext()->setContextProperty("gamepad", &gamepad);
  engine.rootContext()->setContextProperty("playlistManager", &playlistManager);

  const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreated, &app,
      [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
          QCoreApplication::exit(-1);
      },
      Qt::QueuedConnection);
  engine.load(url);

  return app.exec();
}
