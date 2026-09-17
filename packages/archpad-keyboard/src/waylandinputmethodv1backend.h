#pragma once

#include "textcommitbackend.h"
#include <wayland-client.h>
#include "input-method-unstable-v1-client-protocol.h"
#include <QSocketNotifier>

namespace ArchPad {

class WaylandInputMethodV1Backend : public TextCommitBackend {
    Q_OBJECT

public:
    explicit WaylandInputMethodV1Backend(QObject *parent = nullptr);
    ~WaylandInputMethodV1Backend() override;

    bool isAvailable() const override { return m_inputMethod != nullptr; }
    bool isActive() const override { return m_isActive && m_context != nullptr; }
    uint32_t currentSerial() const override { return m_serial; }

    ContentPurpose contentPurpose() const override { return m_purpose; }
    ContentHints contentHints() const override { return m_hints; }
    bool hasSurroundingText() const override { return m_hasSurrounding; }
    size_t surroundingCursorBytes() const override { return m_surroundingCursor; }
    size_t surroundingAnchorBytes() const override { return m_surroundingAnchor; }
    bool hasActiveSelection() const override { return m_surroundingCursor != m_surroundingAnchor; }

    bool commitText(const QString &text) override;
    bool replacePrevious(size_t beforeUtf8Bytes, const QString &newText) override;
    bool deleteSurrounding(size_t beforeUtf8Bytes, size_t afterUtf8Bytes) override;

private Q_SLOTS:
    void onSocketActivated();

private:
    void initWayland();
    void cleanupWayland();

    static void registryHandleGlobal(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version);
    static void registryHandleGlobalRemove(void *data, struct wl_registry *registry, uint32_t name);

    static void inputMethodHandleActivate(void *data, struct zwp_input_method_v1 *im, struct zwp_input_method_context_v1 *ctx);
    static void inputMethodHandleDeactivate(void *data, struct zwp_input_method_v1 *im, struct zwp_input_method_context_v1 *ctx);

    static void contextHandleSurroundingText(void *data, struct zwp_input_method_context_v1 *ctx, const char *text, uint32_t cursor, uint32_t anchor);
    static void contextHandleReset(void *data, struct zwp_input_method_context_v1 *ctx);
    static void contextHandleContentType(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t hint, uint32_t purpose);
    static void contextHandleInvokeAction(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t button, uint32_t index);
    static void contextHandleCommitState(void *data, struct zwp_input_method_context_v1 *ctx, uint32_t serial);
    static void contextHandlePreferredLanguage(void *data, struct zwp_input_method_context_v1 *ctx, const char *language);

    static const struct wl_registry_listener s_registryListener;
    static const struct zwp_input_method_v1_listener s_inputMethodListener;
    static const struct zwp_input_method_context_v1_listener s_contextListener;

    struct wl_display *m_display = nullptr;
    struct wl_registry *m_registry = nullptr;
    struct zwp_input_method_v1 *m_inputMethod = nullptr;
    struct zwp_input_method_context_v1 *m_context = nullptr;
    QSocketNotifier *m_notifier = nullptr;

    bool m_isActive = false;
    bool m_hasSerial = false;
    uint32_t m_serial = 0;
    ContentPurpose m_purpose = ContentPurpose::Normal;
    ContentHints m_hints = ContentHintFlag::None;
    bool m_hasSurrounding = false;
    size_t m_surroundingCursor = 0;
    size_t m_surroundingAnchor = 0;
};

} // namespace ArchPad
