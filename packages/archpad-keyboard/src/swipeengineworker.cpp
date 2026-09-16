#include "swipeengineworker.h"

#include <swipe_decoder/engine.hpp>
#include <swipe_decoder/layout.hpp>
#include <swipe_decoder/trie.hpp>

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QElapsedTimer>
#include <QDebug>
#include <cmath>

struct SwipeEngineWorker::Impl {
    SwipeEngineWorker::State state = SwipeEngineWorker::State::Unloaded;
    QString lastError;
    std::unique_ptr<swipe_decoder::SwipeEngine> engine;
    std::optional<swipe_decoder::Trie> trie;
    swipe_decoder::KeyboardLayout layout;
    quint64 latestRequestId = 0;
};

SwipeEngineWorker::SwipeEngineWorker(QObject *parent)
    : QObject(parent)
    , m_impl(std::make_unique<Impl>())
{
}

SwipeEngineWorker::~SwipeEngineWorker()
{
    unloadEngine();
}

SwipeEngineWorker::State SwipeEngineWorker::state() const
{
    return m_impl->state;
}

QString SwipeEngineWorker::stateString() const
{
    switch (m_impl->state) {
    case State::Unloaded:
        return QStringLiteral("Unloaded");
    case State::Loading:
        return QStringLiteral("Loading");
    case State::Ready:
        return QStringLiteral("Ready");
    case State::Error:
        return QStringLiteral("Error: ") + m_impl->lastError;
    }
    return QStringLiteral("Unknown");
}

bool SwipeEngineWorker::isReady() const
{
    return m_impl->state == State::Ready && m_impl->engine != nullptr;
}

quint64 SwipeEngineWorker::getMemoryPssKiB()
{
    FILE *fp = fopen("/proc/self/smaps_rollup", "r");
    if (!fp) {
        return 0;
    }
    char buf[256];
    quint64 pss = 0;
    while (fgets(buf, sizeof(buf), fp)) {
        if (strncmp(buf, "Pss:", 4) == 0) {
            unsigned long long val = 0;
            if (sscanf(buf + 4, "%llu", &val) == 1) {
                pss = static_cast<quint64>(val);
                break;
            }
        }
    }
    fclose(fp);
    return pss;
}

void SwipeEngineWorker::initEngine(const QString &assetsPath)
{
    if (m_impl->state == State::Ready) {
        return;
    }

    m_impl->state = State::Loading;
    Q_EMIT stateChanged(m_impl->state, QStringLiteral("Loading"));

    const QString base = assetsPath.isEmpty() ? QStringLiteral("/usr/share/archpad-futo-swipe") : assetsPath;

    // Resolve paths with fallback support for both structured and flat asset layouts
    auto resolvePath = [&base](const QString &rel1, const QString &rel2) -> QString {
        const QString p1 = base + QLatin1Char('/') + rel1;
        if (QFile::exists(p1)) return p1;
        const QString p2 = base + QLatin1Char('/') + rel2;
        if (QFile::exists(p2)) return p2;
        return p1;
    };

    const QString encoderPath = resolvePath(QStringLiteral("models/en/honorable_sturgeon/model_fp32.pte"),
                                            QStringLiteral("honorable_sturgeon/model_fp32.pte"));
    const QString decoderPath = resolvePath(QStringLiteral("models/en/magic_macaw/model_fp32.pte"),
                                            QStringLiteral("magic_macaw/model_fp32.pte"));
    const QString lmModelPath = resolvePath(QStringLiteral("models/en/hungry_jellyfish/context_lm.pte"),
                                            QStringLiteral("hungry_jellyfish/context_lm.pte"));
    const QString lmVocabPath = resolvePath(QStringLiteral("models/en/hungry_jellyfish/vocab.txt"),
                                            QStringLiteral("hungry_jellyfish/vocab.txt"));
    const QString dictPath    = resolvePath(QStringLiteral("dictionaries/en.combined"),
                                            QStringLiteral("vocabs/en.combined"));
    const QString scoringPath = base + QStringLiteral("/scoring.json");
    const QString layoutPath  = resolvePath(QStringLiteral("layouts/en_qwerty.json"),
                                            QStringLiteral("en_qwerty.json"));

    if (!QFile::exists(dictPath)) {
        m_impl->state = State::Error;
        m_impl->lastError = QStringLiteral("Missing dictionary: ") + dictPath;
        Q_EMIT stateChanged(m_impl->state, m_impl->lastError);
        return;
    }

    if (!QFile::exists(encoderPath) || !QFile::exists(decoderPath)) {
        m_impl->state = State::Error;
        m_impl->lastError = QStringLiteral("Missing model weights in ") + base;
        Q_EMIT stateChanged(m_impl->state, m_impl->lastError);
        return;
    }

    // Load vocabulary trie
    auto trieOpt = swipe_decoder::load_trie_simple(dictPath.toStdString());
    if (!trieOpt) {
        m_impl->state = State::Error;
        m_impl->lastError = QStringLiteral("Failed to parse dictionary trie: ") + dictPath;
        Q_EMIT stateChanged(m_impl->state, m_impl->lastError);
        return;
    }
    m_impl->trie = std::move(trieOpt);

    // Setup layout: prefer file layout if available, otherwise default en_qwerty
    if (m_impl->layout.num_keys == 0) {
        if (QFile::exists(layoutPath)) {
            swipe_decoder::load_layout_json(layoutPath.toStdString(), m_impl->layout);
        }
        if (m_impl->layout.num_keys == 0) {
            m_impl->layout = swipe_decoder::default_en_qwerty();
        }
    }

    swipe_decoder::SwipeEngine::Config config;
    config.encoder_path = encoderPath.toStdString();
    config.decoder_path = decoderPath.toStdString();
    config.lm_model_path = lmModelPath.toStdString();
    config.lm_vocab_path = lmVocabPath.toStdString();
    config.scoring_path = scoringPath.toStdString();
    config.layout = m_impl->layout;
    config.dictionaries = {m_impl->trie->itrie()};
    config.beam_width = 100;
    config.top_k = 4;
    config.num_threads = 1;

    QElapsedTimer timer;
    timer.start();

    m_impl->engine = std::make_unique<swipe_decoder::SwipeEngine>();
    if (!m_impl->engine->init(config)) {
        m_impl->state = State::Error;
        m_impl->lastError = QStringLiteral("Failed to initialize FUTO SwipeEngine");
        m_impl->engine.reset();
        m_impl->trie.reset();
        Q_EMIT stateChanged(m_impl->state, m_impl->lastError);
        return;
    }

    const quint64 initTimeMs = static_cast<quint64>(timer.elapsed());
    const quint64 memPssKiB = getMemoryPssKiB();

    m_impl->state = State::Ready;
    m_impl->lastError.clear();

    Q_EMIT stateChanged(m_impl->state, QStringLiteral("Ready"));
    Q_EMIT modelsLoaded(initTimeMs, memPssKiB);
}

void SwipeEngineWorker::unloadEngine()
{
    m_impl->engine.reset();
    m_impl->trie.reset();
    m_impl->state = State::Unloaded;
    m_impl->lastError.clear();
    Q_EMIT stateChanged(m_impl->state, QStringLiteral("Unloaded"));
}

void SwipeEngineWorker::setLayout(const QString &letters, const QVector<float> &cx, const QVector<float> &cy)
{
    if (letters.isEmpty() || cx.size() != letters.size() || cy.size() != letters.size()) {
        qWarning() << "SwipeEngineWorker: Invalid layout parameters";
        return;
    }

    m_impl->layout = swipe_decoder::make_layout(
        letters.toStdString(), cx.constData(), cy.constData(), letters.size()
    );

    if (m_impl->engine && m_impl->state == State::Ready) {
        swipe_decoder::SwipeEngine::Mode mode;
        mode.layout = m_impl->layout;
        m_impl->engine->setMode(mode);
    }
}

void SwipeEngineWorker::requestDecode(quint64 requestId,
                                       const QVector<float> &x,
                                       const QVector<float> &y,
                                       const QVector<float> &t,
                                       const QStringList &contextWords,
                                       int topK,
                                       int beamWidth)
{
    // Queue bounding (depth 1): reject stale requests
    if (requestId < m_impl->latestRequestId) {
        return;
    }
    m_impl->latestRequestId = requestId;

    if (m_impl->state != State::Ready || !m_impl->engine) {
        Q_EMIT decodeError(requestId, QStringLiteral("Swipe engine is not ready"));
        return;
    }

    if (x.size() < 2 || x.size() != y.size() || x.size() != t.size()) {
        Q_EMIT decodeError(requestId, QStringLiteral("Trace must contain at least two valid points with matching dimensions"));
        return;
    }

    // Validate points: finite, normalized coordinates [0, 1], monotonic non-decreasing timestamps
    float prev_t = -1.0f;
    for (int i = 0; i < x.size(); ++i) {
        const float px = x[i];
        const float py = y[i];
        const float pt = t[i];
        if (!std::isfinite(px) || !std::isfinite(py) || !std::isfinite(pt)) {
            Q_EMIT decodeError(requestId, QStringLiteral("Non-finite values in trace"));
            return;
        }
        if (px < 0.0f || px > 1.0f || py < 0.0f || py > 1.0f) {
            Q_EMIT decodeError(requestId, QStringLiteral("Coordinates must be normalized to [0.0, 1.0]"));
            return;
        }
        if (pt < 0.0f || pt < prev_t) {
            Q_EMIT decodeError(requestId, QStringLiteral("Timestamps must be non-negative and monotonic"));
            return;
        }
        prev_t = pt;
    }

    // Convert context words to std::vector<std::string>
    std::vector<std::string> stdContext;
    stdContext.reserve(contextWords.size());
    for (const QString &w : contextWords) {
        stdContext.push_back(w.toStdString());
    }

    const auto decodedWords = m_impl->engine->recognize(
        x.constData(), y.constData(), t.constData(), static_cast<size_t>(x.size()),
        stdContext, topK, beamWidth
    );

    // If another request arrived while recognizing, drop these stale results
    if (requestId < m_impl->latestRequestId) {
        return;
    }

    QStringList candidates;
    candidates.reserve(static_cast<int>(decodedWords.size()));
    for (const auto &dw : decodedWords) {
        candidates.append(QString::fromStdString(dw.word));
    }

    const auto &timing = m_impl->engine->last_timing();
    QVariantMap timingMap;
    timingMap.insert(QStringLiteral("resample_us"), timing.resample_us);
    timingMap.insert(QStringLiteral("encoder_us"), timing.encoder_us);
    timingMap.insert(QStringLiteral("decoder_us"), timing.decoder_us);
    timingMap.insert(QStringLiteral("beam_us"), timing.beam_us);
    timingMap.insert(QStringLiteral("lm_us"), timing.lm_us);
    timingMap.insert(QStringLiteral("total_us"), timing.total_us);

    Q_EMIT decodeFinished(requestId, candidates, timingMap);
}
