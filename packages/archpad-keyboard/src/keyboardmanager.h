#pragma once

#include <QObject>
#include <QString>
#include <QSet>
#include <QTimer>
#include "swipeengineworker.h"
#include "textcommitbackend.h"
#include "waylandinputmethodv1backend.h"

struct ca_context;
class QDBusServiceWatcher;
class QThread;
class SwipeEngineWorker;

class KeyboardManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.archpad.Keyboard")

    Q_PROPERTY(bool shiftActive READ shiftActive WRITE setShiftActive NOTIFY shiftActiveChanged)
    Q_PROPERTY(bool capsLockActive READ capsLockActive WRITE setCapsLockActive NOTIFY capsLockActiveChanged)
    Q_PROPERTY(bool ctrlActive READ ctrlActive WRITE setCtrlActive NOTIFY ctrlActiveChanged)
    Q_PROPERTY(bool altActive READ altActive WRITE setAltActive NOTIFY altActiveChanged)
    Q_PROPERTY(bool metaActive READ metaActive WRITE setMetaActive NOTIFY metaActiveChanged)
    Q_PROPERTY(bool isFloating READ isFloating WRITE setIsFloating NOTIFY isFloatingChanged)
    Q_PROPERTY(bool isVisible READ isVisible WRITE setIsVisible NOTIFY isVisibleChanged)
    Q_PROPERTY(bool soundEnabled READ soundEnabled WRITE setSoundEnabled NOTIFY soundEnabledChanged)
    Q_PROPERTY(int soundProfile READ soundProfile WRITE setSoundProfile NOTIFY soundProfileChanged)
    Q_PROPERTY(int soundVolume READ soundVolume WRITE setSoundVolume NOTIFY soundVolumeChanged)
    
    // 3-Way Theme: 0 = Follow System, 1 = Light, 2 = Dark
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(bool resolvedDark READ resolvedDark NOTIFY resolvedDarkChanged)
    
    // Keyboard Height Customization
    Q_PROPERTY(qreal heightScale READ heightScale WRITE setHeightScale NOTIFY heightScaleChanged)

    // Long-press timing for secondary key actions
    Q_PROPERTY(int longPressDelay READ longPressDelay WRITE setLongPressDelay NOTIFY longPressDelayChanged)
    
    // Landscape Split Mode
    Q_PROPERTY(bool splitMode READ splitMode WRITE setSplitMode NOTIFY splitModeChanged)
    
    // Floating Resize (Locked Aspect Ratio)
    Q_PROPERTY(qreal floatingWidth READ floatingWidth WRITE setFloatingWidth NOTIFY floatingWidthChanged)

    // Dynamic Toolbar Pinning
    Q_PROPERTY(bool themePinned READ themePinned WRITE setThemePinned NOTIFY themePinnedChanged)
    Q_PROPERTY(bool soundPinned READ soundPinned WRITE setSoundPinned NOTIFY soundPinnedChanged)
    Q_PROPERTY(bool splitPinned READ splitPinned WRITE setSplitPinned NOTIFY splitPinnedChanged)

    // Custom Quick-Pad Mode
    Q_PROPERTY(bool isQuickPad READ isQuickPad WRITE setIsQuickPad NOTIFY isQuickPadChanged)
    Q_PROPERTY(bool quickPadPinned READ quickPadPinned WRITE setQuickPadPinned NOTIFY quickPadPinnedChanged)
    Q_PROPERTY(int quickPadKeyCount READ quickPadKeyCount WRITE setQuickPadKeyCount NOTIFY quickPadKeyCountChanged)
    Q_PROPERTY(qreal quickPadSize READ quickPadSize WRITE setQuickPadSize NOTIFY quickPadSizeChanged)

    // Swipe Typing Engine
    Q_PROPERTY(bool swipeReady READ swipeReady NOTIFY swipeReadyChanged)
    Q_PROPERTY(bool swipeActive READ swipeActive WRITE setSwipeActive NOTIFY swipeActiveChanged)
    Q_PROPERTY(QString swipeState READ swipeState NOTIFY swipeStateChanged)
    Q_PROPERTY(QStringList swipeAlternatives READ swipeAlternatives NOTIFY swipeAlternativesChanged)
    Q_PROPERTY(bool hasSwipeAlternatives READ hasSwipeAlternatives NOTIFY swipeAlternativesChanged)
    Q_PROPERTY(bool swipeEnabled READ swipeEnabled WRITE setSwipeEnabled NOTIFY swipeEnabledChanged)
    Q_PROPERTY(bool swipeTrailEnabled READ swipeTrailEnabled WRITE setSwipeTrailEnabled NOTIFY swipeTrailEnabledChanged)
    Q_PROPERTY(bool swipeAutoInsert READ swipeAutoInsert WRITE setSwipeAutoInsert NOTIFY swipeAutoInsertChanged)
    Q_PROPERTY(qreal swipeStrokeWidth READ swipeStrokeWidth WRITE setSwipeStrokeWidth NOTIFY swipeStrokeWidthChanged)
    Q_PROPERTY(int swipeDecayMs READ swipeDecayMs WRITE setSwipeDecayMs NOTIFY swipeDecayMsChanged)
    Q_PROPERTY(QString swipeTrailColor READ swipeTrailColor WRITE setSwipeTrailColor NOTIFY swipeTrailColorChanged)

public:
    struct QuickPadSlot {
        QString label;
        int keycode = 0;
        bool ctrl = false;
        bool alt = false;
        bool shift = false;
        bool meta = false;
    };

    explicit KeyboardManager(QObject *parent = nullptr);
    ~KeyboardManager() override;

    bool shiftActive() const { return m_shiftActive; }
    void setShiftActive(bool active);

    bool capsLockActive() const { return m_capsLockActive; }
    void setCapsLockActive(bool active);

    bool ctrlActive() const { return m_ctrlActive; }
    void setCtrlActive(bool active);

    bool altActive() const { return m_altActive; }
    void setAltActive(bool active);

    bool metaActive() const { return m_metaActive; }
    void setMetaActive(bool active);

    bool isFloating() const { return m_isFloating; }
    void setIsFloating(bool floating);

    bool isVisible() const { return m_isVisible; }
    void setIsVisible(bool visible);

    bool soundEnabled() const { return m_soundEnabled; }
    void setSoundEnabled(bool enabled);

    int soundProfile() const { return m_soundProfile; }
    void setSoundProfile(int profile);

    int soundVolume() const { return m_soundVolume; }
    void setSoundVolume(int volume);

    int themeMode() const { return m_themeMode; }
    void setThemeMode(int mode);

    bool resolvedDark() const;

    qreal heightScale() const { return m_heightScale; }
    void setHeightScale(qreal scale);

    int longPressDelay() const { return m_longPressDelay; }
    void setLongPressDelay(int delay);

    bool splitMode() const { return m_splitMode; }
    void setSplitMode(bool split);

    qreal floatingWidth() const { return m_floatingWidth; }
    void setFloatingWidth(qreal width);

    bool themePinned() const { return m_themePinned; }
    void setThemePinned(bool pinned);

    bool soundPinned() const { return m_soundPinned; }
    void setSoundPinned(bool pinned);

    bool splitPinned() const { return m_splitPinned; }
    void setSplitPinned(bool pinned);

    bool isQuickPad() const { return m_isQuickPad; }
    void setIsQuickPad(bool active);

    bool quickPadPinned() const { return m_quickPadPinned; }
    void setQuickPadPinned(bool pinned);

    int quickPadKeyCount() const { return m_quickPadKeyCount; }
    void setQuickPadKeyCount(int count);

    qreal quickPadSize() const { return m_quickPadSize; }
    void setQuickPadSize(qreal size);

    Q_INVOKABLE QString quickPadLabel(int slot) const;
    Q_INVOKABLE int quickPadKeycode(int slot) const;
    Q_INVOKABLE bool quickPadCtrl(int slot) const;
    Q_INVOKABLE bool quickPadAlt(int slot) const;
    Q_INVOKABLE bool quickPadShift(int slot) const;
    Q_INVOKABLE bool quickPadMeta(int slot) const;

    Q_INVOKABLE void setQuickPadSlot(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta);
    Q_INVOKABLE void setQuickPadLabel(int slot, const QString &label);
    Q_INVOKABLE void setQuickPadKeycode(int slot, int keycode);
    Q_INVOKABLE void setQuickPadCtrl(int slot, bool ctrl);
    Q_INVOKABLE void setQuickPadAlt(int slot, bool alt);
    Q_INVOKABLE void setQuickPadShift(int slot, bool shift);
    Q_INVOKABLE void setQuickPadMeta(int slot, bool meta);
    Q_INVOKABLE void tapQuickPadKey(int slot);
    Q_INVOKABLE void togglePinQuickPad() { setQuickPadPinned(!m_quickPadPinned); }
    Q_INVOKABLE void toggleQuickPad();

    // QML Invocable methods
    Q_INVOKABLE void tapKey(int keycode);
    Q_INVOKABLE void tapKeyWithModifiers(int keycode, bool shift, bool ctrl, bool alt);
    Q_INVOKABLE void tapText(const QString &text);
    Q_INVOKABLE void tapSymbol(const QString &symbol);
    Q_INVOKABLE void tapNavKey(const QString &navKey);
    Q_INVOKABLE void playClick();
    Q_INVOKABLE void previewSoundProfile(int profile);
    Q_INVOKABLE void cycleThemeMode();
    Q_INVOKABLE void togglePinTheme() { setThemePinned(!m_themePinned); }
    Q_INVOKABLE void togglePinSound() { setSoundPinned(!m_soundPinned); }
    Q_INVOKABLE void togglePinSplit() { setSplitPinned(!m_splitPinned); }
    Q_INVOKABLE void toggleSplitMode() { setSplitMode(!m_splitMode); }
    Q_INVOKABLE void openSettingsApp();

    // Swipe Typing Invocables
    bool swipeReady() const { return m_swipeReady; }
    bool swipeActive() const { return m_swipeActive; }
    void setSwipeActive(bool active);
    QString swipeState() const;
    QStringList swipeAlternatives() const { return m_swipeAlternatives; }
    bool hasSwipeAlternatives() const { return !m_swipeAlternatives.isEmpty(); }
    bool swipeEnabled() const { return m_swipeEnabled; }
    void setSwipeEnabled(bool enabled);
    bool swipeTrailEnabled() const { return m_swipeTrailEnabled; }
    void setSwipeTrailEnabled(bool enabled);
    bool swipeAutoInsert() const { return m_swipeAutoInsert; }
    void setSwipeAutoInsert(bool autoInsert);
    qreal swipeStrokeWidth() const { return m_swipeStrokeWidth; }
    void setSwipeStrokeWidth(qreal width);
    int swipeDecayMs() const { return m_swipeDecayMs; }
    void setSwipeDecayMs(int ms);
    QString swipeTrailColor() const { return m_swipeTrailColor; }
    void setSwipeTrailColor(const QString &color);

    Q_INVOKABLE void requestSwipeDecode(quint64 requestId, const QVariantList &points, const QStringList &contextWords);
    Q_INVOKABLE void selectSwipeAlternative(int index);
    Q_INVOKABLE void dismissSwipeAlternatives();
    Q_INVOKABLE void loadSwipeEngine();
    Q_INVOKABLE void unloadSwipeEngine();
    Q_INVOKABLE quint64 getSwipeMemoryPssKiB() const;

public Q_SLOTS:
    // D-Bus accessible methods
    void Show();
    void Hide();
    void Toggle();
    void ToggleFloating();
    bool IsFloating() const { return m_isFloating; }
    bool IsVisible() const { return m_isVisible; }
    void SelectSwipeAlternative(int index) { selectSwipeAlternative(index); }
    void DismissSwipeAlternatives() { dismissSwipeAlternatives(); }
    void SimulateSwipeCandidates(const QStringList &candidates);
    void LoadSwipeEngine() { loadSwipeEngine(); }
    void UnloadSwipeEngine() { unloadSwipeEngine(); }
    QString GetSwipeState() { return swipeState(); }
    qulonglong GetSwipeMemoryPssKiB() { return static_cast<qulonglong>(getSwipeMemoryPssKiB()); }
    void SetSwipeEnabled(bool enabled) { setSwipeEnabled(enabled); }
    void SetSwipeTrailEnabled(bool enabled) { setSwipeTrailEnabled(enabled); }
    void SetSwipeAutoInsert(bool autoInsert) { setSwipeAutoInsert(autoInsert); }
    void SetSwipeStrokeWidth(double width) { setSwipeStrokeWidth(width); }
    void SetSwipeDecayMs(int ms) { setSwipeDecayMs(ms); }
    void SetSwipeTrailColor(const QString &color) { setSwipeTrailColor(color); }
    void SetFloating(bool floating);
    void OpenSettingsApp();
    void CycleThemeMode();
    void SetThemeMode(int mode);
    void SetHeightScale(double scale);
    void SetLongPressDelay(int delay) { setLongPressDelay(delay); }
    void SetSoundEnabled(bool enabled) { setSoundEnabled(enabled); }
    void SetSoundProfile(int profile) { setSoundProfile(profile); }
    void SetSoundVolume(int volume) { setSoundVolume(volume); }
    void PreviewSoundProfile(int profile) { previewSoundProfile(profile); }
    void SetFloatingWidth(double width) { setFloatingWidth(width); }
    void ToggleSplitMode();
    void SetSplitMode(bool split);
    void TogglePinTheme() { togglePinTheme(); }
    void TogglePinSound() { togglePinSound(); }
    void TogglePinSplit() { togglePinSplit(); }
    void SetThemePinned(bool pinned) { setThemePinned(pinned); }
    void SetSoundPinned(bool pinned) { setSoundPinned(pinned); }
    void SetSplitPinned(bool pinned) { setSplitPinned(pinned); }
    void ToggleQuickPad() { toggleQuickPad(); }
    void SetQuickPad(bool active) { setIsQuickPad(active); }
    void TogglePinQuickPad() { togglePinQuickPad(); }
    void SetQuickPadPinned(bool pinned) { setQuickPadPinned(pinned); }
    void SetQuickPadKeyCount(int count) { setQuickPadKeyCount(count); }
    void SetQuickPadSize(double size) { setQuickPadSize(size); }
    void SetQuickPadSlot(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta) {
        setQuickPadSlot(slot, label, keycode, ctrl, alt, shift, meta);
    }
    void OpenQuickPadConfig();
    void TapQuickPadKey(int slot) { tapQuickPadKey(slot); }
    void TapText(const QString &text) { tapText(text); }
    void TapKey(int keycode) { tapKey(keycode); }
    void TapNavKey(const QString &navKey) { tapNavKey(navKey); }
    void TapSymbol(const QString &symbol) { tapSymbol(symbol); }
    void SetCapsLockActive(bool active) { setCapsLockActive(active); }
    void SetShiftActive(bool active) { setShiftActive(active); }

    // KWin VirtualKeyboard sync slots
    void onKWinActiveChanged();
    void onKWinVisibleChanged();

Q_SIGNALS:
    void shiftActiveChanged(bool active);
    void capsLockActiveChanged(bool active);
    void ctrlActiveChanged(bool active);
    void altActiveChanged(bool active);
    void metaActiveChanged(bool active);
    void isFloatingChanged(bool floating);
    void isVisibleChanged(bool visible);
    void soundEnabledChanged(bool enabled);
    void soundProfileChanged(int profile);
    void soundVolumeChanged(int volume);
    void themeModeChanged(int mode);
    void resolvedDarkChanged(bool isDark);
    void heightScaleChanged(qreal scale);
    void longPressDelayChanged(int delay);
    void splitModeChanged(bool split);
    void floatingWidthChanged(qreal width);
    void themePinnedChanged(bool pinned);
    void soundPinnedChanged(bool pinned);
    void splitPinnedChanged(bool pinned);
    void isQuickPadChanged(bool isQuickPad);
    void quickPadPinnedChanged(bool pinned);
    void quickPadKeyCountChanged(int count);
    void quickPadSizeChanged(qreal size);
    void quickPadConfigChanged();
    void openQuickPadConfigRequested();
    void swipeReadyChanged(bool ready);
    void swipeActiveChanged(bool active);
    void swipeStateChanged(const QString &state);
    void swipeCandidatesReady(quint64 requestId, const QStringList &candidates, const QVariantMap &timings);
    void swipeDecodeError(quint64 requestId, const QString &errorMessage);
    void swipeAlternativesChanged(const QStringList &alternatives);
    void swipeEnabledChanged(bool enabled);
    void swipeTrailEnabledChanged(bool enabled);
    void swipeAutoInsertChanged(bool autoInsert);
    void swipeStrokeWidthChanged(double width);
    void swipeDecayMsChanged(int ms);
    void swipeTrailColorChanged(const QString &color);

private:
    bool initUInput();
    void closeUInput();
    void emitRawEvent(int type, int code, int value);
    void emitKey(int code, int value);
    void emitKeyPressAndRelease(int code);
    void emitKeyWithActiveModifiers(int keycode, bool forceShift = false, bool forceAltGr = false);
    void clearTransientState();
    void syncKWinVirtualKeyboardState();
    void ensureXkbOptions();
    void handleDecodeFinished(quint64 reqId, const QStringList &candidates, const QVariantMap &timings);

    bool detectSystemDark();
    void updateResolvedDark();
    void loadSettings();
    void saveSettings();
    void scheduleSaveSettings();
    QString soundPathForProfile(int profile) const;
    void playSoundFile(const QString &path);

    int m_uinputFd = -1;
    bool m_shiftActive = false;
    bool m_capsLockActive = false;
    bool m_ctrlActive = false;
    bool m_altActive = false;
    bool m_metaActive = false;
    bool m_isFloating = false;
    bool m_isVisible = false;
    bool m_manuallyShown = false;
    bool m_soundEnabled = true;
    int m_soundProfile = 0;
    int m_soundVolume = 70;
    
    int m_themeMode = 0; // 0 = Follow System, 1 = Light, 2 = Dark
    bool m_cachedSystemDark = true;
    bool m_resolvedDark = true;

    qreal m_heightScale = 1.0; // 0.85 (Compact) to 1.25 (Expanded)
    int m_longPressDelay = 350;
    bool m_splitMode = false;
    qreal m_floatingWidth = 420.0;

    // Pinning: by default only essentials are outside; theme/sound/split are unpinned
    bool m_themePinned = false;
    bool m_soundPinned = false;
    bool m_splitPinned = false;
    bool m_isQuickPad = false;
    bool m_quickPadPinned = false;
    int m_quickPadKeyCount = 4;
    qreal m_quickPadSize = 220.0;
    QuickPadSlot m_quickPadSlots[4];
    ca_context *m_caContext = nullptr;
    QString m_clickSoundPath;
    bool m_clickPlaybackErrorLogged = false;
    QDBusServiceWatcher *m_kwinServiceWatcher = nullptr;
    QTimer *m_saveSettingsTimer = nullptr;
    bool m_swipeReady = false;
    bool m_swipeActive = false;
    QThread *m_swipeThread = nullptr;
    SwipeEngineWorker *m_swipeWorker = nullptr;
    ArchPad::TextCommitBackend *m_textCommitBackend = nullptr;
    QStringList m_swipeAlternatives;
    QString m_lastCommittedWord;
    size_t m_lastCommittedBytes = 0;
    uint32_t m_lastCommittedSerial = 0;

    bool m_swipeEnabled = true;
    bool m_swipeTrailEnabled = true;
    bool m_swipeAutoInsert = true;
    qreal m_swipeStrokeWidth = 8.0;
    int m_swipeDecayMs = 280;
    QString m_swipeTrailColor = QStringLiteral("#3399ff");
};
