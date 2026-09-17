#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QIcon>
#include <QCommandLineParser>
#include <QQuickWindow>
#include <QDebug>
#include <QDBusInterface>
#include <LayerShellQt/Window>

#include "keyboardmanager.h"
#include "gesturetrailitem.h"

int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", QByteArray("wayland"));

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("archpad-keyboard"));
    app.setApplicationDisplayName(QStringLiteral("ArchPad Keyboard"));
    app.setOrganizationName(QStringLiteral("ArchPad"));
    app.setOrganizationDomain(QStringLiteral("archpad.org"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("input-keyboard-virtual")));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Touch-first virtual keyboard for ArchPad"));
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption toggleOpt(QStringList() << "t" << "toggle", QStringLiteral("Toggle keyboard visibility"));
    parser.addOption(toggleOpt);

    QCommandLineOption showOpt(QStringList() << "s" << "show", QStringLiteral("Show the keyboard"));
    parser.addOption(showOpt);

    QCommandLineOption hideOpt(QStringList() << "hide", QStringLiteral("Hide the keyboard"));
    parser.addOption(hideOpt);

    QCommandLineOption daemonOpt(QStringList() << "d" << "daemon", QStringLiteral("Start hidden in background daemon mode"));
    parser.addOption(daemonOpt);
    parser.process(app);

    // Atomically acquire the well-known name before initializing QML or uinput.
    // KWin and the user service can start at the same time, so a separate
    // isServiceRegistered() check would have a check-then-register race.
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected() && !bus.registerService(QStringLiteral("org.archpad.Keyboard"))) {
        QDBusInterface iface(QStringLiteral("org.archpad.Keyboard"),
                             QStringLiteral("/org/archpad/Keyboard"),
                             QStringLiteral("org.archpad.Keyboard"),
                             bus);
        if (iface.isValid()) {
            if (parser.isSet(toggleOpt)) {
                iface.call(QStringLiteral("Toggle"));
            } else if (parser.isSet(showOpt)) {
                iface.call(QStringLiteral("Show"));
            } else if (parser.isSet(hideOpt)) {
                iface.call(QStringLiteral("Hide"));
            } else if (!parser.isSet(daemonOpt)) {
                iface.call(QStringLiteral("Toggle"));
            }
        } else {
            qWarning() << "Another process owns org.archpad.Keyboard but does not expose the expected interface";
        }
        return 0;
    }

    auto *keyboardMgr = new KeyboardManager(&app);
    if (parser.isSet(showOpt)) {
        keyboardMgr->Show();
    } else if (parser.isSet(toggleOpt)) {
        keyboardMgr->Toggle();
    }
    // By default (and with --daemon), keyboard starts cleanly hidden in background

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &w : warnings) {
            qWarning() << "QML Error:" << w.toString();
        }
    });

    qmlRegisterType<GestureTrailItem>("org.archpad.keyboard", 1, 0, "GestureTrail");

    // Expose Theme as lowercase 'theme' context property
    QQmlComponent themeComp(&engine, QUrl(QStringLiteral("qrc:/qml/Theme.qml")));
    QObject *themeObj = themeComp.create();
    if (themeObj) {
        engine.rootContext()->setContextProperty(QStringLiteral("theme"), themeObj);
    } else {
        qWarning() << "Failed to create Theme object:" << themeComp.errorString();
    }

    engine.rootContext()->setContextProperty(QStringLiteral("km"), keyboardMgr);

    const QUrl url(QStringLiteral("qrc:/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qCritical() << "Failed to create root QML object from" << url;
            QCoreApplication::exit(-1);
        } else {
            qInfo() << "Successfully created root keyboard window!";
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
