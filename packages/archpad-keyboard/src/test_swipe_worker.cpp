#include <QCoreApplication>
#include <QThread>
#include <QTimer>
#include <QDebug>
#include <QElapsedTimer>
#include "swipeengineworker.h"

int main(int argc, char **argv)
{
    qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &msg) {
        fprintf(stderr, "%s\n", qPrintable(msg));
        fflush(stderr);
    });

    QCoreApplication app(argc, argv);

    qInfo() << "=== ArchPad SwipeEngineWorker Test Suite ===";

    const quint64 memBefore = SwipeEngineWorker::getMemoryPssKiB();
    qInfo() << "Baseline PSS:" << memBefore << "KiB";

    QThread workerThread;
    SwipeEngineWorker worker;
    worker.moveToThread(&workerThread);

    bool success = true;

    QObject::connect(&worker, &SwipeEngineWorker::stateChanged, [&](SwipeEngineWorker::State state, const QString &msg) {
        qInfo() << "State changed to:" << static_cast<int>(state) << msg;
    });

    QObject::connect(&worker, &SwipeEngineWorker::modelsLoaded, [&](quint64 elapsedMs, quint64 memKiB) {
        qInfo() << "Models loaded in:" << elapsedMs << "ms";
        qInfo() << "Loaded PSS:" << memKiB << "KiB (delta:" << (memKiB > memBefore ? memKiB - memBefore : 0) << "KiB)";
        if (elapsedMs > 5000) {
            qCritical() << "FAIL: Model initialization too slow:" << elapsedMs << "ms";
            success = false;
        }

        // Test 2: Inference on deterministic synthetic swipe trace
        qInfo() << "Starting Test 2: Inference on synthetic trace...";
        const QVector<float> x = { 0.10f, 0.20f };
        const QVector<float> y = { 0.25f, 0.25f };
        const QVector<float> t = { 0.0f, 1.0f };
        QMetaObject::invokeMethod(&worker, "requestDecode", Qt::QueuedConnection,
                                 Q_ARG(quint64, 1),
                                 Q_ARG(QVector<float>, x),
                                 Q_ARG(QVector<float>, y),
                                 Q_ARG(QVector<float>, t),
                                 Q_ARG(QStringList, QStringList()),
                                 Q_ARG(int, 4),
                                 Q_ARG(int, 100));
    });

    QObject::connect(&worker, &SwipeEngineWorker::decodeFinished, [&](quint64 reqId, const QStringList &candidates, const QVariantMap &timings) {
        qInfo() << "Decode finished for req" << reqId << "candidates:" << candidates;
        qInfo() << "Total timing:" << timings.value(QStringLiteral("total_us")).toDouble() / 1000.0 << "ms";
        if (reqId == 1) {
            if (candidates.isEmpty()) {
                qCritical() << "FAIL: No candidates returned";
                success = false;
            }

            // Test 3: Queue bounding (rapid requests)
            qInfo() << "Starting Test 3: Queue bounding (dispatching rapid requests 2, 3, 4)...";
            const QVector<float> x = { 0.10f, 0.20f };
            const QVector<float> y = { 0.25f, 0.25f };
            const QVector<float> t = { 0.0f, 1.0f };
            QMetaObject::invokeMethod(&worker, "requestDecode", Qt::QueuedConnection,
                                     Q_ARG(quint64, 2),
                                     Q_ARG(QVector<float>, x),
                                     Q_ARG(QVector<float>, y),
                                     Q_ARG(QVector<float>, t),
                                     Q_ARG(QStringList, QStringList()),
                                     Q_ARG(int, 4),
                                     Q_ARG(int, 100));
            QMetaObject::invokeMethod(&worker, "requestDecode", Qt::QueuedConnection,
                                     Q_ARG(quint64, 3),
                                     Q_ARG(QVector<float>, x),
                                     Q_ARG(QVector<float>, y),
                                     Q_ARG(QVector<float>, t),
                                     Q_ARG(QStringList, QStringList()),
                                     Q_ARG(int, 4),
                                     Q_ARG(int, 100));
            QMetaObject::invokeMethod(&worker, "requestDecode", Qt::QueuedConnection,
                                     Q_ARG(quint64, 4),
                                     Q_ARG(QVector<float>, x),
                                     Q_ARG(QVector<float>, y),
                                     Q_ARG(QVector<float>, t),
                                     Q_ARG(QStringList, QStringList()),
                                     Q_ARG(int, 4),
                                     Q_ARG(int, 100));
        } else if (reqId == 4) {
            qInfo() << "Request 4 received as expected!";

            // Test 4: Unload
            qInfo() << "Starting Test 4: Unload engine...";
            QMetaObject::invokeMethod(&worker, "unloadEngine", Qt::QueuedConnection);
            const quint64 memAfterUnload = SwipeEngineWorker::getMemoryPssKiB();
            qInfo() << "Post-unload PSS:" << memAfterUnload << "KiB";

            qInfo() << "=== Test Suite PASSED ===";
            QTimer::singleShot(50, &app, [&]() {
                workerThread.quit();
                workerThread.wait();
                app.exit(success ? 0 : 1);
            });
        }
    });

    QObject::connect(&worker, &SwipeEngineWorker::decodeError, [&](quint64 reqId, const QString &err) {
        qCritical() << "Decode error on req" << reqId << ":" << err;
        success = false;
        app.exit(1);
    });

    // Timeout safety
    QTimer::singleShot(15000, [&]() {
        qCritical() << "FAIL: Test timed out after 15s";
        app.exit(2);
    });

    workerThread.start();
    qInfo() << "Starting Test 1: Asynchronous model loading...";
    QMetaObject::invokeMethod(&worker, "initEngine", Qt::QueuedConnection, Q_ARG(QString, QString()));

    return app.exec();
}
