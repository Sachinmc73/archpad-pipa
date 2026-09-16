#pragma once

#include <QObject>
#include <QString>
#include <QQuickWindow>
#include <QTimer>
#include <linux/input-event-codes.h>

struct QuickPadSlotConfig {
    QString label;
    int keycode = 1;
    bool ctrl = false;
    bool alt = false;
    bool shift = false;
    bool meta = false;
};

class SettingsController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool daemonConnected READ daemonConnected NOTIFY daemonConnectedChanged)
    Q_PROPERTY(bool resolvedDark READ resolvedDark NOTIFY resolvedDarkChanged)
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(qreal heightScale READ heightScale WRITE setHeightScale NOTIFY heightScaleChanged)
    Q_PROPERTY(bool soundEnabled READ soundEnabled WRITE setSoundEnabled NOTIFY soundEnabledChanged)
    Q_PROPERTY(int soundProfile READ soundProfile WRITE setSoundProfile NOTIFY soundProfileChanged)
    Q_PROPERTY(int soundVolume READ soundVolume WRITE setSoundVolume NOTIFY soundVolumeChanged)
    Q_PROPERTY(bool splitMode READ splitMode WRITE setSplitMode NOTIFY splitModeChanged)
    Q_PROPERTY(qreal floatingWidth READ floatingWidth WRITE setFloatingWidth NOTIFY floatingWidthChanged)
    Q_PROPERTY(bool themePinned READ themePinned WRITE setThemePinned NOTIFY themePinnedChanged)
    Q_PROPERTY(bool soundPinned READ soundPinned WRITE setSoundPinned NOTIFY soundPinnedChanged)
    Q_PROPERTY(bool splitPinned READ splitPinned WRITE setSplitPinned NOTIFY splitPinnedChanged)
    Q_PROPERTY(bool quickPadPinned READ quickPadPinned WRITE setQuickPadPinned NOTIFY quickPadPinnedChanged)
    Q_PROPERTY(int quickPadKeyCount READ quickPadKeyCount WRITE setQuickPadKeyCount NOTIFY quickPadKeyCountChanged)
    Q_PROPERTY(qreal quickPadSize READ quickPadSize WRITE setQuickPadSize NOTIFY quickPadSizeChanged)
    Q_PROPERTY(int selectedSlot READ selectedSlot WRITE setSelectedSlot NOTIFY selectedSlotChanged)
    Q_PROPERTY(int configRevision READ configRevision NOTIFY quickPadConfigChanged)
    Q_PROPERTY(int longPressDelay READ longPressDelay WRITE setLongPressDelay NOTIFY longPressDelayChanged)
    Q_PROPERTY(int selectedCategory READ selectedCategory WRITE setSelectedCategory NOTIFY selectedCategoryChanged)

public:
    explicit SettingsController(QObject *parent = nullptr);
    ~SettingsController() override;

    int selectedCategory() const { return m_selectedCategory; }
    void setSelectedCategory(int cat);

    int configRevision() const { return m_configRevision; }
    int longPressDelay() const { return m_longPressDelay; }
    void setLongPressDelay(int ms);

    void setMainWindow(QQuickWindow *window) { m_mainWindow = window; }

    bool daemonConnected() const { return m_daemonConnected; }
    bool resolvedDark() const {
        if (m_themeMode == 1) return false;
        if (m_themeMode == 2) return true;
        return m_resolvedDark;
    }

    int themeMode() const { return m_themeMode; }
    void setThemeMode(int mode);

    qreal heightScale() const { return m_heightScale; }
    void setHeightScale(qreal scale);

    bool soundEnabled() const { return m_soundEnabled; }
    void setSoundEnabled(bool enabled);

    int soundProfile() const { return m_soundProfile; }
    void setSoundProfile(int profile);

    int soundVolume() const { return m_soundVolume; }
    void setSoundVolume(int volume);

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

    bool quickPadPinned() const { return m_quickPadPinned; }
    void setQuickPadPinned(bool pinned);

    int quickPadKeyCount() const { return m_quickPadKeyCount; }
    void setQuickPadKeyCount(int count);

    qreal quickPadSize() const { return m_quickPadSize; }
    void setQuickPadSize(qreal size);

    int selectedSlot() const { return m_selectedSlot; }
    void setSelectedSlot(int slot);

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

    Q_INVOKABLE void applyPreset(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta);
    Q_INVOKABLE void applyFunctionKey(int slot, const QString &fnName, int keycode);
    Q_INVOKABLE void applyNavKey(int slot, const QString &keyName, int keycode);

    Q_INVOKABLE void testKey(int slot);
    Q_INVOKABLE void launchQuickPad();
    Q_INVOKABLE void showKeyboard();
    Q_INVOKABLE void hideKeyboard();
    Q_INVOKABLE void toggleKeyboard();
    Q_INVOKABLE void selectSoundProfile(int profile);
    Q_INVOKABLE void resetToDefaults();

public Q_SLOTS:
    void Activate();
    void SetCategory(int cat) { setSelectedCategory(cat); }

Q_SIGNALS:
    void daemonConnectedChanged(bool connected);
    void resolvedDarkChanged(bool isDark);
    void themeModeChanged(int mode);
    void heightScaleChanged(qreal scale);
    void soundEnabledChanged(bool enabled);
    void soundProfileChanged(int profile);
    void soundVolumeChanged(int volume);
    void splitModeChanged(bool split);
    void floatingWidthChanged(qreal width);
    void themePinnedChanged(bool pinned);
    void soundPinnedChanged(bool pinned);
    void splitPinnedChanged(bool pinned);
    void quickPadPinnedChanged(bool pinned);
    void quickPadKeyCountChanged(int count);
    void quickPadSizeChanged(qreal size);
    void selectedSlotChanged(int slot);
    void quickPadConfigChanged();
    void longPressDelayChanged(int ms);
    void selectedCategoryChanged(int cat);

private Q_SLOTS:
    void onThemeModeChanged(int mode);
    void onResolvedDarkChanged(bool isDark);
    void onHeightScaleChanged(double scale);
    void onLongPressDelayChanged(int ms);
    void onSoundEnabledChanged(bool enabled);
    void onSoundProfileChanged(int profile);
    void onSoundVolumeChanged(int volume);
    void onSplitModeChanged(bool split);
    void onFloatingWidthChanged(double width);
    void onThemePinnedChanged(bool pinned);
    void onSoundPinnedChanged(bool pinned);
    void onSplitPinnedChanged(bool pinned);
    void onQuickPadPinnedChanged(bool pinned);
    void onQuickPadKeyCountChanged(int count);
    void onQuickPadSizeChanged(double size);
    void onQuickPadConfigChanged();

private:
    void loadSettings();
    void saveSettings();
    void scheduleSaveSettings();
    void sendDBusAsync(const QString &method, const QVariantList &args = {});
    void connectDBusSignals();

    QQuickWindow *m_mainWindow = nullptr;
    QTimer *m_saveTimer = nullptr;

    bool m_daemonConnected = false;
    bool m_resolvedDark = true;
    int m_themeMode = 0;
    qreal m_heightScale = 1.0;
    bool m_soundEnabled = true;
    int m_soundProfile = 0;
    int m_soundVolume = 70;
    bool m_splitMode = false;
    qreal m_floatingWidth = 420.0;
    bool m_themePinned = false;
    bool m_soundPinned = false;
    bool m_splitPinned = false;
    bool m_quickPadPinned = false;
    int m_quickPadKeyCount = 4;
    qreal m_quickPadSize = 220.0;
    int m_selectedSlot = 0;
    int m_configRevision = 0;
    int m_longPressDelay = 350;
    int m_selectedCategory = 0;

    QuickPadSlotConfig m_quickPadSlots[4];
};
