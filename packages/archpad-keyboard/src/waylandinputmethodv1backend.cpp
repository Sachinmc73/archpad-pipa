#include "waylandinputmethodv1backend.h"

#include <QDebug>
#include <cstring>
#include <unistd.h>

namespace ArchPad {

const struct wl_registry_listener WaylandInputMethodV1Backend::s_registryListener = {
    .global = WaylandInputMethodV1Backend::registryHandleGlobal,
    .global_remove = WaylandInputMethodV1Backend::registryHandleGlobalRemove,
};

const struct zwp_input_method_v1_listener WaylandInputMethodV1Backend::s_inputMethodListener = {
    .activate = WaylandInputMethodV1Backend::inputMethodHandleActivate,
    .deactivate = WaylandInputMethodV1Backend::inputMethodHandleDeactivate,
};

const struct zwp_input_method_context_v1_listener WaylandInputMethodV1Backend::s_contextListener = {
    .surrounding_text = WaylandInputMethodV1Backend::contextHandleSurroundingText,
    .reset = WaylandInputMethodV1Backend::contextHandleReset,
    .content_type = WaylandInputMethodV1Backend::contextHandleContentType,
    .invoke_action = WaylandInputMethodV1Backend::contextHandleInvokeAction,
    .commit_state = WaylandInputMethodV1Backend::contextHandleCommitState,
    .preferred_language = WaylandInputMethodV1Backend::contextHandlePreferredLanguage,
};

WaylandInputMethodV1Backend::WaylandInputMethodV1Backend(QObject *parent)
    : TextCommitBackend(parent)
{
    initWayland();
}

WaylandInputMethodV1Backend::~WaylandInputMethodV1Backend()
{
    cleanupWayland();
}

void WaylandInputMethodV1Backend::initWayland()
{
    m_display = wl_display_connect(nullptr);
    if (!m_display) {
        qWarning() << "[TextCommitBackend] Failed to connect to Wayland display";
        return;
    }

    m_registry = wl_display_get_registry(m_display);
    wl_registry_add_listener(m_registry, &s_registryListener, this);

    wl_display_roundtrip(m_display);

    if (m_inputMethod) {
        wl_display_roundtrip(m_display);
        qInfo() << "[TextCommitBackend] Successfully bound zwp_input_method_v1";
    } else {
        qWarning() << "[TextCommitBackend] zwp_input_method_v1 not advertised by compositor";
    }

    int fd = wl_display_get_fd(m_display);
    m_notifier = new QSocketNotifier(fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &WaylandInputMethodV1Backend::onSocketActivated);
}

void WaylandInputMethodV1Backend::cleanupWayland()
{
    if (m_notifier) {
        m_notifier->setEnabled(false);
        delete m_notifier;
        m_notifier = nullptr;
    }

    if (m_context) {
        zwp_input_method_context_v1_destroy(m_context);
        m_context = nullptr;
    }

    if (m_inputMethod) {
        zwp_input_method_v1_destroy(m_inputMethod);
        m_inputMethod = nullptr;
    }

    if (m_registry) {
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
    }

    if (m_display) {
        wl_display_flush(m_display);
        wl_display_disconnect(m_display);
        m_display = nullptr;
    }
}

void WaylandInputMethodV1Backend::onSocketActivated()
{
    if (!m_display) return;

    // Dispatch any already pending events
    wl_display_dispatch_pending(m_display);

    // Read events from socket
    if (wl_display_prepare_read(m_display) == 0) {
        wl_display_read_events(m_display);
    }

    wl_display_dispatch_pending(m_display);
    wl_display_flush(m_display);
}

void WaylandInputMethodV1Backend::registryHandleGlobal(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    if (strcmp(interface, zwp_input_method_v1_interface.name) == 0) {
        self->m_inputMethod = static_cast<struct zwp_input_method_v1 *>(
            wl_registry_bind(registry, name, &zwp_input_method_v1_interface, 1));
        zwp_input_method_v1_add_listener(self->m_inputMethod, &s_inputMethodListener, self);
    }
}

void WaylandInputMethodV1Backend::registryHandleGlobalRemove(void *data, struct wl_registry *registry, uint32_t name)
{
    Q_UNUSED(data);
    Q_UNUSED(registry);
    Q_UNUSED(name);
}

void WaylandInputMethodV1Backend::inputMethodHandleActivate(void *data, struct zwp_input_method_v1 *im, struct zwp_input_method_context_v1 *ctx)
{
    Q_UNUSED(im);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    qInfo() << "[TextCommitBackend] Wayland input-method context activated:" << ctx;

    if (self->m_context && self->m_context != ctx) {
        zwp_input_method_context_v1_destroy(self->m_context);
    }

    self->m_context = ctx;
    self->m_isActive = true;
    self->m_hasSerial = false;
    self->m_hasSurrounding = false;
    self->m_surroundingCursor = 0;
    self->m_surroundingAnchor = 0;

    zwp_input_method_context_v1_add_listener(ctx, &s_contextListener, self);
    Q_EMIT self->activeChanged(true);
}

void WaylandInputMethodV1Backend::inputMethodHandleDeactivate(void *data, struct zwp_input_method_v1 *im, struct zwp_input_method_context_v1 *ctx)
{
    Q_UNUSED(im);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    qInfo() << "[TextCommitBackend] Wayland input-method context deactivated:" << ctx;

    if (ctx) {
        zwp_input_method_context_v1_destroy(ctx);
    }

    if (self->m_context == ctx) {
        self->m_context = nullptr;
        self->m_isActive = false;
        self->m_hasSerial = false;
        self->m_hasSurrounding = false;
        self->m_surroundingCursor = 0;
        self->m_surroundingAnchor = 0;
        Q_EMIT self->activeChanged(false);
    }
}

void WaylandInputMethodV1Backend::contextHandleSurroundingText(void *data, struct zwp_input_method_context_v1 *ctx, const char *text, uint32_t cursor, uint32_t anchor)
{
    Q_UNUSED(ctx);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    // Hard privacy rule: Never store or log the text string itself
    self->m_hasSurrounding = (text != nullptr && strlen(text) > 0);
    self->m_surroundingCursor = cursor;
    self->m_surroundingAnchor = anchor;
    Q_EMIT self->surroundingTextChanged(self->m_hasSurrounding, cursor, anchor);
}

void WaylandInputMethodV1Backend::contextHandleReset(void *data, struct zwp_input_method_context_v1 *ctx)
{
    Q_UNUSED(ctx);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    self->m_hasSurrounding = false;
    self->m_surroundingCursor = 0;
    self->m_surroundingAnchor = 0;
    Q_EMIT self->stateReset();
}

void WaylandInputMethodV1Backend::contextHandleContentType(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t hint, uint32_t purpose)
{
    Q_UNUSED(ctx);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    self->m_hints = static_cast<ContentHintFlag>(hint);
    self->m_purpose = static_cast<ContentPurpose>(purpose);
    Q_EMIT self->contentHintsChanged(self->m_hints);
    Q_EMIT self->contentPurposeChanged(self->m_purpose);
}

void WaylandInputMethodV1Backend::contextHandleInvokeAction(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t button, uint32_t index)
{
    Q_UNUSED(data);
    Q_UNUSED(ctx);
    Q_UNUSED(button);
    Q_UNUSED(index);
}

void WaylandInputMethodV1Backend::contextHandleCommitState(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t serial)
{
    Q_UNUSED(ctx);
    auto *self = static_cast<WaylandInputMethodV1Backend *>(data);
    self->m_serial = serial;
    self->m_hasSerial = true;
    qInfo() << "[TextCommitBackend] commit_state received with serial:" << serial;
}

void WaylandInputMethodV1Backend::contextHandlePreferredLanguage(void *data, struct zwp_input_method_context_v1 *ctx, const char *language)
{
    Q_UNUSED(ctx);
    Q_UNUSED(language);
}

bool WaylandInputMethodV1Backend::commitText(const QString &text)
{
    if (!m_isActive || !m_context) {
        return false;
    }
    QByteArray utf8 = text.toUtf8();
    zwp_input_method_context_v1_commit_string(m_context, m_serial, utf8.constData());
    wl_display_flush(m_display);
    qInfo() << "[TextCommitBackend] commitText sent:" << text << "serial:" << m_serial;
    return true;
}

bool WaylandInputMethodV1Backend::replacePrevious(size_t beforeUtf8Bytes, const QString &newText)
{
    if (!m_isActive || !m_context) {
        return false;
    }
    int32_t deleteIndex = -static_cast<int32_t>(beforeUtf8Bytes);
    zwp_input_method_context_v1_delete_surrounding_text(m_context, deleteIndex, static_cast<uint32_t>(beforeUtf8Bytes));
    QByteArray utf8 = newText.toUtf8();
    zwp_input_method_context_v1_commit_string(m_context, m_serial, utf8.constData());
    wl_display_flush(m_display);
    qInfo() << "[TextCommitBackend] replacePrevious sent: deleteIndex=" << deleteIndex
            << "bytes=" << beforeUtf8Bytes << "newText=" << newText << "serial:" << m_serial;
    return true;
}

bool WaylandInputMethodV1Backend::deleteSurrounding(size_t beforeUtf8Bytes, size_t afterUtf8Bytes)
{
    if (!m_isActive || !m_context) {
        return false;
    }
    int32_t deleteIndex = -static_cast<int32_t>(beforeUtf8Bytes);
    uint32_t length = static_cast<uint32_t>(beforeUtf8Bytes + afterUtf8Bytes);
    zwp_input_method_context_v1_delete_surrounding_text(m_context, deleteIndex, length);
    wl_display_flush(m_display);
    qInfo() << "[TextCommitBackend] deleteSurrounding sent: deleteIndex=" << deleteIndex << "length=" << length;
    return true;
}

} // namespace ArchPad
