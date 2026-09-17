#include "gesturetrailitem.h"

#include <QSGGeometryNode>
#include <QSGGeometry>
#include <QSGVertexColorMaterial>
#include <QtMath>
#include <algorithm>

GestureTrailItem::GestureTrailItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);
    m_timer.start();
}

void GestureTrailItem::setTrailColor(const QColor &color)
{
    if (m_trailColor != color) {
        m_trailColor = color;
        Q_EMIT trailColorChanged();
        update();
    }
}

void GestureTrailItem::setStrokeWidth(qreal width)
{
    if (qFuzzyCompare(m_strokeWidth, width)) {
        return;
    }
    m_strokeWidth = width;
    Q_EMIT strokeWidthChanged();
    update();
}

void GestureTrailItem::setDecayDurationMs(int durationMs)
{
    if (m_decayDurationMs != durationMs) {
        m_decayDurationMs = durationMs;
        Q_EMIT decayDurationMsChanged();
        update();
    }
}

void GestureTrailItem::addPoint(qreal x, qreal y)
{
    const qint64 now = m_timer.elapsed();
    const QPointF newPt(x, y);

    if (!m_points.isEmpty()) {
        const QPointF &lastPt = m_points.last().pos;
        const qreal dx = newPt.x() - lastPt.x();
        const qreal dy = newPt.y() - lastPt.y();
        if ((dx * dx + dy * dy) < 2.0) {
            // Drop jitter points less than ~1.4px apart to keep strip geometry clean
            return;
        }
    }

    m_points.append({newPt, now});
    m_strokeActive = true;
    update();
}

void GestureTrailItem::endStroke()
{
    m_strokeActive = false;
    update();
}

void GestureTrailItem::clear()
{
    m_points.clear();
    m_strokeActive = false;
    update();
}

QSGNode *GestureTrailItem::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    auto *node = static_cast<QSGGeometryNode *>(oldNode);
    const qint64 now = m_timer.elapsed();

    // 1. Prune points that have exceeded decay duration
    while (!m_points.isEmpty() && (now - m_points.first().timestamp) > m_decayDurationMs) {
        m_points.removeFirst();
    }

    // 2. If points remain, schedule another frame to animate decay fade-out
    if (!m_points.isEmpty()) {
        update();
    }

    // 3. Early exit if insufficient points to build triangle strip
    if (m_points.size() < 2) {
        if (node) {
            node->geometry()->allocate(0);
            node->markDirty(QSGNode::DirtyGeometry);
        }
        return node;
    }

    // 4. Create node and materials if not present
    if (!node) {
        node = new QSGGeometryNode();
        auto *geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), 0);
        geometry->setDrawingMode(QSGGeometry::DrawTriangleStrip);
        node->setGeometry(geometry);
        node->setFlag(QSGNode::OwnsGeometry);

        auto *material = new QSGVertexColorMaterial();
        node->setMaterial(material);
        node->setFlag(QSGNode::OwnsMaterial);
    }

    const int pointCount = m_points.size();
    const int vertexCount = pointCount * 2;
    QSGGeometry *geometry = node->geometry();
    geometry->allocate(vertexCount);
    auto *vertices = geometry->vertexDataAsColoredPoint2D();

    const qreal baseAlpha = m_trailColor.alphaF();
    const qreal baseRed = m_trailColor.redF();
    const qreal baseGreen = m_trailColor.greenF();
    const qreal baseBlue = m_trailColor.blueF();
    const qreal halfMaxStroke = m_strokeWidth / 2.0;

    for (int i = 0; i < pointCount; ++i) {
        const TrailPoint &tp = m_points[i];
        const qint64 age = now - tp.timestamp;
        const float lifetime = std::clamp(1.0f - static_cast<float>(age) / static_cast<float>(m_decayDurationMs), 0.0f, 1.0f);

        // Compute tangent direction
        QPointF tangent;
        if (i == 0) {
            tangent = m_points[1].pos - tp.pos;
        } else if (i == pointCount - 1) {
            tangent = tp.pos - m_points[i - 1].pos;
        } else {
            tangent = m_points[i + 1].pos - m_points[i - 1].pos;
        }

        qreal len = std::hypot(tangent.x(), tangent.y());
        QPointF normal(0.0, 1.0);
        if (len > 1e-4) {
            normal = QPointF(-tangent.y() / len, tangent.x() / len);
        }

        // Taper width towards tail: width proportional to remaining lifetime
        const qreal halfWidth = halfMaxStroke * lifetime;
        const QPointF leftPos = tp.pos + normal * halfWidth;
        const QPointF rightPos = tp.pos - normal * halfWidth;

        // Premultiplied alpha for QSGVertexColorMaterial
        const float alpha = baseAlpha * lifetime;
        const auto a = static_cast<unsigned char>(std::round(alpha * 255.0f));
        const auto r = static_cast<unsigned char>(std::round(baseRed * alpha * 255.0f));
        const auto g = static_cast<unsigned char>(std::round(baseGreen * alpha * 255.0f));
        const auto b = static_cast<unsigned char>(std::round(baseBlue * alpha * 255.0f));

        const int vIdx = i * 2;
        vertices[vIdx].set(static_cast<float>(leftPos.x()), static_cast<float>(leftPos.y()), r, g, b, a);
        vertices[vIdx + 1].set(static_cast<float>(rightPos.x()), static_cast<float>(rightPos.y()), r, g, b, a);
    }

    geometry->markVertexDataDirty();
    node->markDirty(QSGNode::DirtyGeometry);

    return node;
}
