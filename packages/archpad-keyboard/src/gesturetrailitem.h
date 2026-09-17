#pragma once

#include <QQuickItem>
#include <QColor>
#include <QElapsedTimer>
#include <QPointF>
#include <QVector>

class GestureTrailItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QColor trailColor READ trailColor WRITE setTrailColor NOTIFY trailColorChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY strokeWidthChanged)
    Q_PROPERTY(int decayDurationMs READ decayDurationMs WRITE setDecayDurationMs NOTIFY decayDurationMsChanged)

public:
    explicit GestureTrailItem(QQuickItem *parent = nullptr);
    ~GestureTrailItem() override = default;

    QColor trailColor() const { return m_trailColor; }
    void setTrailColor(const QColor &color);

    qreal strokeWidth() const { return m_strokeWidth; }
    void setStrokeWidth(qreal width);

    int decayDurationMs() const { return m_decayDurationMs; }
    void setDecayDurationMs(int durationMs);

    Q_INVOKABLE void addPoint(qreal x, qreal y);
    Q_INVOKABLE void endStroke();
    Q_INVOKABLE void clear();

Q_SIGNALS:
    void trailColorChanged();
    void strokeWidthChanged();
    void decayDurationMsChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *data) override;

private:
    struct TrailPoint {
        QPointF pos;
        qint64 timestamp;
    };

    QColor m_trailColor{51, 153, 255, 230};
    qreal m_strokeWidth = 8.0;
    int m_decayDurationMs = 280;

    QElapsedTimer m_timer;
    QVector<TrailPoint> m_points;
    bool m_strokeActive = false;
};
