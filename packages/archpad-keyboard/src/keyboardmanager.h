#pragma once

#include <QObject>
#include <QString>
#include <QSet>
#include <QFileSystemWatcher>

struct ca_context;

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
    Q_PROPERTY(bool optionsVisible READ optionsVisible WRITE setOptionsVisible NOTIFY optionsVisibleChanged)
    Q_PROPERTY(bool pushWindows READ pushWindows WRITE setPushWindows NOTIFY pushWindowsChanged)
    
    // 3-Way Theme: 0 = Follow System, 1 = Light, 2 = Dark
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(bool resolvedDark READ resolvedDark NOTIFY resolvedDarkChanged)
    
    // Keyboard Height Customization
    Q_PROPERTY(qreal heightScale READ heightScale WRITE setHeightScale NOTIFY heightScaleChanged)
    
    // Landscape Split Mode
    Q_PROPERTY(bool splitMode READ splitMode WRITE setSplitMode NOTIFY splitModeChanged)
    
    // Floating Resize (Locked Aspect Ratio)
    Q_PROPERTY(qreal floatingWidth READ floatingWidth WRITE setFloatingWidth NOTIFY floatingWidthChanged)

    // Dynamic Toolbar Pinning
    Q_PROPERTY(bool themePinned READ themePinned WRITE setThemePinned NOTIFY themePinnedChanged)
    Q_PROPERTY(bool soundPinned READ soundPinned WRITE setSoundPinned NOTIFY soundPinnedChanged)
    Q_PROPERTY(bool splitPinned READ splitPinned WRITE setSplitPinned NOTIFY splitPinnedChanged)

public:
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

    bool optionsVisible() const { return m_optionsVisible; }
    void setOptionsVisible(bool visible);

    bool pushWindows() const { return m_pushWindows; }
    void setPushWindows(bool push);

    int themeMode() const { return m_themeMode; }
    void setThemeMode(int mode);

    bool resolvedDark() const;

    qreal heightScale() const { return m_heightScale; }
    void setHeightScale(qreal scale);

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

    // QML Invocable methods
    Q_INVOKABLE void tapKey(int keycode);
    Q_INVOKABLE void tapKeyWithModifiers(int keycode, bool shift, bool ctrl, bool alt);
    Q_INVOKABLE void tapText(const QString &text);
    Q_INVOKABLE void tapSymbol(const QString &symbol);
    Q_INVOKABLE void tapNavKey(const QString &navKey);
    Q_INVOKABLE void playClick();
    Q_INVOKABLE void cycleThemeMode();
    Q_INVOKABLE void togglePinTheme() { setThemePinned(!m_themePinned); }
    Q_INVOKABLE void togglePinSound() { setSoundPinned(!m_soundPinned); }
    Q_INVOKABLE void togglePinSplit() { setSplitPinned(!m_splitPinned); }
    Q_INVOKABLE void toggleSplitMode() { setSplitMode(!m_splitMode); }

public Q_SLOTS:
    // D-Bus accessible methods
    void Show();
    void Hide();
    void Toggle();
    void ToggleFloating();
    void SetFloating(bool floating);
    void ToggleOptions();
    void SetOptionsVisible(bool visible);
    void TogglePushWindows();
    void SetPushWindows(bool push);
    void CycleThemeMode();
    void SetThemeMode(int mode);
    void SetHeightScale(double scale);
    void ToggleSplitMode();
    void SetSplitMode(bool split);
    void TogglePinTheme() { togglePinTheme(); }
    void TogglePinSound() { togglePinSound(); }
    void TogglePinSplit() { togglePinSplit(); }
    void SetThemePinned(bool pinned) { setThemePinned(pinned); }
    void SetSoundPinned(bool pinned) { setSoundPinned(pinned); }
    void SetSplitPinned(bool pinned) { setSplitPinned(pinned); }
    void TapText(const QString &text) { tapText(text); }
    void TapKey(int keycode) { tapKey(keycode); }
    void TapNavKey(const QString &navKey) { tapNavKey(navKey); }

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
    void optionsVisibleChanged(bool visible);
    void pushWindowsChanged(bool push);
    void themeModeChanged(int mode);
    void resolvedDarkChanged(bool isDark);
    void heightScaleChanged(qreal scale);
    void splitModeChanged(bool split);
    void floatingWidthChanged(qreal width);
    void themePinnedChanged(bool pinned);
    void soundPinnedChanged(bool pinned);
    void splitPinnedChanged(bool pinned);

private:
    bool initUInput();
    void closeUInput();
    void emitRawEvent(int type, int code, int value);
    void emitKey(int code, int value);
    void emitKeyPressAndRelease(int code);

    bool detectSystemDark();
    void updateResolvedDark();
    void loadSettings();
    void saveSettings();

    int m_uinputFd = -1;
    bool m_shiftActive = false;
    bool m_capsLockActive = false;
    bool m_ctrlActive = false;
    bool m_altActive = false;
    bool m_metaActive = false;
    bool m_isFloating = false;
    bool m_isVisible = true;
    bool m_soundEnabled = true;
    bool m_optionsVisible = false;
    bool m_pushWindows = true; // Default: Push Windows (Displace Apps)
    
    int m_themeMode = 0; // 0 = Follow System, 1 = Light, 2 = Dark
    bool m_cachedSystemDark = true;
    bool m_resolvedDark = true;

    qreal m_heightScale = 1.0; // 0.85 (Compact) to 1.25 (Expanded)
    bool m_splitMode = false;
    qreal m_floatingWidth = 400.0;

    // Pinning: by default only essentials are outside; theme/sound/split are unpinned
    bool m_themePinned = false;
    bool m_soundPinned = false;
    bool m_splitPinned = false;
    ca_context *m_caContext = nullptr;
    QFileSystemWatcher *m_themeWatcher = nullptr;
};
