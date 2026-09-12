#include "DesktopController.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QIcon>
#include <QJsonDocument>
#include <QLocalSocket>
#include <QLockFile>
#include <QMenu>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <cstdio>
#include <memory>
#include <unistd.h>

static QByteArray request(const QString &socketPath, const QJsonObject &message) {
    QLocalSocket socket;
    socket.connectToServer(socketPath);
    if (!socket.waitForConnected(500)) return {};
    socket.write(QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n');
    if (!socket.waitForBytesWritten(1000)) return {};
    QElapsedTimer deadline; deadline.start();
    QByteArray reply;
    while (deadline.elapsed() < 3000 && reply.size() < 4 * 1024 * 1024) {
        reply += socket.readAll();
        if (reply.contains('\n')) return reply;
        if (!socket.waitForReadyRead(qMax(1, 3000 - int(deadline.elapsed())))) {
            reply += socket.readAll();
            return reply.contains('\n') ? reply : QByteArray();
        }
    }
    return {};
}

int main(int argc, char **argv) {
    // IPC clients do not load a GUI platform plugin or instantiate a second backend.
    auto application = std::make_unique<QCoreApplication>(argc, argv);
    QCoreApplication::setApplicationName("codexbar-linux");
    QCoreApplication::setApplicationVersion("0.1.0");
    QCommandLineParser parser;
    parser.setApplicationDescription("CodexBar desktop for Linux · Qt windows and optional tray");
    parser.addHelpOption(); parser.addVersionOption();
    for (const auto &name : {"snapshot", "refresh", "settings", "spending", "usage", "quit", "background", "no-tray"})
        parser.addOption(QCommandLineOption(name, QString("%1 the running desktop app").arg(name)));
    parser.addOption(QCommandLineOption("configure", "Update desktop settings through local IPC", "json"));
    parser.addOption(QCommandLineOption("cli", "CodexBar CLI executable for a new instance", "path"));
    parser.process(*application);
    QString command = "usage";
    for (const auto &name : {"background", "usage", "settings", "spending", "refresh", "snapshot", "quit", "configure"})
        if (parser.isSet(name)) command = name;
    const bool clientOnly = QStringList{"snapshot", "refresh", "quit", "configure"}.contains(command);
    const bool noTray = parser.isSet("no-tray");
    const auto cli = parser.value("cli");
    QJsonObject message{{"command", command}};
    if (command == "configure") {
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(parser.value("configure").toUtf8(), &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            std::fputs("--configure requires a JSON object\n", stderr); return 2;
        }
        message["settings"] = document.object();
    }
    QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (runtime.isEmpty()) runtime = QDir::tempPath() + "/codexbar-" + QString::number(getuid());
    runtime += "/codexbar-linux";
    if (!QDir().mkpath(runtime) || QFileInfo(runtime).ownerId() != getuid() || QFileInfo(runtime).isSymLink()) {
        std::fputs("Cannot create a private runtime directory\n", stderr); return 1;
    }
    QFile::setPermissions(runtime, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    const auto socketPath = runtime + "/desktop.sock";
    auto reply = request(socketPath, message);
    if (!reply.isEmpty()) {
        std::fwrite(reply.constData(), 1, reply.size(), stdout);
        return QJsonDocument::fromJson(reply).object().value("ok").toBool(true) ? 0 : 1;
    }
    if (clientOnly) { std::fputs("CodexBar desktop is not running\n", stderr); return 1; }
    QLockFile lock(runtime + "/desktop.lock");
    if (!lock.tryLock(0)) {
        // Another launch may still be loading QML. Never remove its live socket.
        for (int attempt = 0; attempt < 10 && reply.isEmpty(); ++attempt) {
            usleep(100000); reply = request(socketPath, message);
        }
        if (reply.isEmpty()) { std::fputs("CodexBar is already starting; retry shortly\n", stderr); return 1; }
        return 0;
    }
    application.reset();
    QApplication app(argc, argv);
    app.setApplicationName("codexbar-linux");
    app.setApplicationDisplayName("CodexBar");
    app.setDesktopFileName("com.steipete.CodexBar");
    app.setQuitOnLastWindowClosed(false);
    app.setWindowIcon(QIcon(":/icon.svg"));
    QQuickStyle::setStyle("Fusion");
    DesktopController controller(cli);
    if (!controller.listen(socketPath)) { std::fputs("Cannot start local IPC\n", stderr); return 1; }
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::quit, &app, &QCoreApplication::quit);
    engine.rootContext()->setContextProperty("desktop", &controller);
    engine.load(QUrl("qrc:/qml/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    QSystemTrayIcon tray(QIcon(":/icon.svg"));
    QMenu menu;
    menu.addAction("Usage & Spend…", &controller, [&controller] { controller.showWindow("usage"); });
    menu.addAction("Settings…", &controller, [&controller] { controller.showWindow("settings"); });
    menu.addSeparator();
    menu.addAction("Refresh", &controller, [&controller] { controller.refresh(); controller.refreshCosts(); });
    menu.addAction("Quit CodexBar", &app, &QCoreApplication::quit);
    tray.setContextMenu(&menu);
    QObject::connect(&tray, &QSystemTrayIcon::activated, &controller, [&controller](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) controller.showWindow("usage");
    });
    QObject::connect(&controller, &DesktopController::changed, &tray, [&] {
        tray.setToolTip("CodexBar · " + (controller.summary().isEmpty() ? "Usage unavailable" : controller.summary()));
    });
    auto updateTray = [&] { tray.setVisible(!noTray && controller.settings().value("showTray").toBool()); };
    QObject::connect(&controller, &DesktopController::settingsChanged, &tray, updateTray);
    updateTray();
    if (command != "background") QTimer::singleShot(0, &controller, [&] { controller.showWindow(command); });
    return app.exec();
}
