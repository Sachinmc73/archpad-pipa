#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QDBusInterface>
#include <QDBusConnection>
#include <QDBusError>
#include <QQuickWindow>
#include <QDebug>

#include "settingscontroller.h"

int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", QByteArray("wayland"));

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("archpad-keyboard-settings"));
    app.setApplicationDisplayName(QStringLiteral("Keyboard Settings"));
    app.setOrganizationName(QStringLiteral("ArchPad"));
    app.setOrganizationDomain(QStringLiteral("archpad.org"));
    app.setDesktopFileName(QStringLiteral("archpad-keyboard-settings"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("input-keyboard-virtual")));

    // Atomically acquire the well-known name before creating the controller or
    // QML window. Multiple rapid launches must never create duplicate windows.
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QString serviceName = QStringLiteral("org.archpad.KeyboardSettings");
    if (bus.isConnected() && !bus.registerService(serviceName)) {
        QDBusInterface iface(serviceName,
                             QStringLiteral("/org/archpad/KeyboardSettings"),
                             serviceName,
                             bus);
        if (iface.isValid()) {
            iface.call(QStringLiteral("Activate"));
        }
        return 0;
    }

    auto *controller = new SettingsController(&app);

    if (bus.isConnected()) {
        if (!bus.registerObject(QStringLiteral("/org/archpad/KeyboardSettings"),
                                serviceName,
                                controller,
                                QDBusConnection::ExportAllSlots)) {
            qWarning() << "Could not register settings D-Bus object:" << bus.lastError().message();
        }
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &w : warnings) {
            qWarning() << "Settings QML Warning:" << w.toString();
        }
    });

    engine.rootContext()->setContextProperty(QStringLiteral("controller"), controller);

    const QUrl url(QStringLiteral("qrc:/settings/SettingsMain.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url, controller](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qCritical() << "Failed to load SettingsMain.qml from" << url;
            QCoreApplication::exit(-1);
        } else if (obj) {
            auto *window = qobject_cast<QQuickWindow*>(obj);
            if (window) {
                controller->setMainWindow(window);
            }
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
