#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QVariantMap>
#include <memory>

class SwipeEngineWorker : public QObject
{
    Q_OBJECT

public:
    enum class State {
        Unloaded,
        Loading,
        Ready,
        Error
    };
    Q_ENUM(State)

    explicit SwipeEngineWorker(QObject *parent = nullptr);
    ~SwipeEngineWorker() override;

    State state() const;
    QString stateString() const;
    bool isReady() const;

    static quint64 getMemoryPssKiB();

public Q_SLOTS:
    void initEngine(const QString &assetsPath = QString());
    void unloadEngine();
    void setLayout(const QString &letters, const QVector<float> &cx, const QVector<float> &cy);
    void requestDecode(quint64 requestId,
                       const QVector<float> &x,
                       const QVector<float> &y,
                       const QVector<float> &t,
                       const QStringList &contextWords,
                       int topK = 4,
                       int beamWidth = 100);

Q_SIGNALS:
    void stateChanged(SwipeEngineWorker::State state, const QString &statusMessage);
    void modelsLoaded(quint64 initTimeMs, quint64 memoryPssKiB);
    void decodeFinished(quint64 requestId, const QStringList &candidates, const QVariantMap &timings);
    void decodeError(quint64 requestId, const QString &errorMessage);

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
