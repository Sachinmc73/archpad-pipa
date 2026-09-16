#include "settingscontroller.h"

#include <QDir>
#include <QSettings>
#include <QDebug>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusServiceWatcher>

SettingsController::SettingsController(QObject *parent)
    : QObject(parent)
{
    loadSettings();

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        if (bus.interface() && bus.interface()->isServiceRegistered(QStringLiteral("org.archpad.Keyboard"))) {
            m_daemonConnected = true;
        }

        auto *watcher = new QDBusServiceWatcher(QStringLiteral("org.archpad.Keyboard"),
                                               bus,
                                               QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration,
                                               this);
        connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, [this]() {
            m_daemonConnected = true;
            Q_EMIT daemonConnectedChanged(true);
        });
        connect(watcher, &QDBusServiceWatcher::serviceUnregistered, this, [this]() {
            m_daemonConnected = false;
            Q_EMIT daemonConnectedChanged(false);
        });

        connectDBusSignals();
    }
}

SettingsController::~SettingsController()
{
    if (m_saveTimer && m_saveTimer->isActive()) {
        m_saveTimer->stop();
        saveSettings();
    }
}

void SettingsController::connectDBusSignals()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    const QString service = QStringLiteral("org.archpad.Keyboard");
    const QString path = QStringLiteral("/org/archpad/Keyboard");
    const QString iface = QStringLiteral("org.archpad.Keyboard");

    bus.connect(service, path, iface, QStringLiteral("themeModeChanged"), this, SLOT(onThemeModeChanged(int)));
    bus.connect(service, path, iface, QStringLiteral("resolvedDarkChanged"), this, SLOT(onResolvedDarkChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("heightScaleChanged"), this, SLOT(onHeightScaleChanged(double)));
    bus.connect(service, path, iface, QStringLiteral("longPressDelayChanged"), this, SLOT(onLongPressDelayChanged(int)));
    bus.connect(service, path, iface, QStringLiteral("soundEnabledChanged"), this, SLOT(onSoundEnabledChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("soundProfileChanged"), this, SLOT(onSoundProfileChanged(int)));
    bus.connect(service, path, iface, QStringLiteral("soundVolumeChanged"), this, SLOT(onSoundVolumeChanged(int)));
    bus.connect(service, path, iface, QStringLiteral("splitModeChanged"), this, SLOT(onSplitModeChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("floatingWidthChanged"), this, SLOT(onFloatingWidthChanged(double)));
    bus.connect(service, path, iface, QStringLiteral("themePinnedChanged"), this, SLOT(onThemePinnedChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("soundPinnedChanged"), this, SLOT(onSoundPinnedChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("splitPinnedChanged"), this, SLOT(onSplitPinnedChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("quickPadPinnedChanged"), this, SLOT(onQuickPadPinnedChanged(bool)));
    bus.connect(service, path, iface, QStringLiteral("quickPadKeyCountChanged"), this, SLOT(onQuickPadKeyCountChanged(int)));
    bus.connect(service, path, iface, QStringLiteral("quickPadSizeChanged"), this, SLOT(onQuickPadSizeChanged(double)));
    bus.connect(service, path, iface, QStringLiteral("quickPadConfigChanged"), this, SLOT(onQuickPadConfigChanged()));
}

void SettingsController::onThemeModeChanged(int mode)
{
    if (m_themeMode != mode) {
        m_themeMode = mode;
        Q_EMIT themeModeChanged(mode);
        Q_EMIT resolvedDarkChanged(resolvedDark());
    }
}

void SettingsController::onResolvedDarkChanged(bool isDark)
{
    if (m_resolvedDark != isDark) {
        m_resolvedDark = isDark;
        Q_EMIT resolvedDarkChanged(resolvedDark());
    }
}

void SettingsController::onHeightScaleChanged(double scale)
{
    if (qAbs(m_heightScale - scale) > 0.001) {
        m_heightScale = scale;
        Q_EMIT heightScaleChanged(scale);
    }
}

void SettingsController::onLongPressDelayChanged(int ms)
{
    if (m_longPressDelay != ms) {
        m_longPressDelay = ms;
        Q_EMIT longPressDelayChanged(m_longPressDelay);
    }
}

void SettingsController::onSoundEnabledChanged(bool enabled)
{
    if (m_soundEnabled != enabled) {
        m_soundEnabled = enabled;
        Q_EMIT soundEnabledChanged(enabled);
    }
}

void SettingsController::onSoundProfileChanged(int profile)
{
    if (m_soundProfile != profile) {
        m_soundProfile = profile;
        Q_EMIT soundProfileChanged(m_soundProfile);
    }
}

void SettingsController::onSoundVolumeChanged(int volume)
{
    if (m_soundVolume != volume) {
        m_soundVolume = volume;
        Q_EMIT soundVolumeChanged(m_soundVolume);
    }
}

void SettingsController::onSplitModeChanged(bool split)
{
    if (m_splitMode != split) {
        m_splitMode = split;
        Q_EMIT splitModeChanged(split);
    }
}

void SettingsController::onFloatingWidthChanged(double width)
{
    if (qAbs(m_floatingWidth - width) > 0.1) {
        m_floatingWidth = width;
        Q_EMIT floatingWidthChanged(m_floatingWidth);
    }
}

void SettingsController::onThemePinnedChanged(bool pinned)
{
    if (m_themePinned != pinned) {
        m_themePinned = pinned;
        Q_EMIT themePinnedChanged(pinned);
    }
}

void SettingsController::onSoundPinnedChanged(bool pinned)
{
    if (m_soundPinned != pinned) {
        m_soundPinned = pinned;
        Q_EMIT soundPinnedChanged(pinned);
    }
}

void SettingsController::onSplitPinnedChanged(bool pinned)
{
    if (m_splitPinned != pinned) {
        m_splitPinned = pinned;
        Q_EMIT splitPinnedChanged(pinned);
    }
}

void SettingsController::onQuickPadPinnedChanged(bool pinned)
{
    if (m_quickPadPinned != pinned) {
        m_quickPadPinned = pinned;
        Q_EMIT quickPadPinnedChanged(pinned);
    }
}

void SettingsController::onQuickPadKeyCountChanged(int count)
{
    if (m_quickPadKeyCount != count) {
        m_quickPadKeyCount = count;
        if (m_selectedSlot >= m_quickPadKeyCount) {
            m_selectedSlot = qMax(0, m_quickPadKeyCount - 1);
            Q_EMIT selectedSlotChanged(m_selectedSlot);
        }
        Q_EMIT quickPadKeyCountChanged(count);
    }
}

void SettingsController::onQuickPadSizeChanged(double size)
{
    if (qAbs(m_quickPadSize - size) > 0.1) {
        m_quickPadSize = size;
        Q_EMIT quickPadSizeChanged(size);
    }
}

void SettingsController::onQuickPadConfigChanged()
{
    loadSettings();
    m_configRevision++;
    Q_EMIT quickPadConfigChanged();
}

void SettingsController::loadSettings()
{
    QString confPath = QDir::homePath() + QStringLiteral("/.config/archpad/keyboard.conf");
    QSettings s(confPath, QSettings::IniFormat);

    s.beginGroup(QStringLiteral("General"));
    m_themeMode = s.value(QStringLiteral("themeMode"), 0).toInt();
    m_resolvedDark = s.value(QStringLiteral("resolvedDark"), true).toBool();
    m_heightScale = s.value(QStringLiteral("heightScale"), 1.0).toReal();
    m_soundEnabled = s.value(QStringLiteral("soundEnabled"), true).toBool();
    m_soundProfile = qBound(0, s.value(QStringLiteral("soundProfile"), 0).toInt(), 3);
    m_soundVolume = qBound(0, s.value(QStringLiteral("soundVolume"), 70).toInt(), 100);
    m_splitMode = s.value(QStringLiteral("splitMode"), false).toBool();
    m_themePinned = s.value(QStringLiteral("themePinned"), false).toBool();
    m_soundPinned = s.value(QStringLiteral("soundPinned"), false).toBool();
    m_splitPinned = s.value(QStringLiteral("splitPinned"), false).toBool();
    m_floatingWidth = s.value(QStringLiteral("floatingWidth"), 420.0).toReal();
    m_longPressDelay = s.value(QStringLiteral("longPressDelay"), 350).toInt();
    s.endGroup();

    if (m_floatingWidth < 340.0) m_floatingWidth = 340.0;
    if (m_floatingWidth > 580.0) m_floatingWidth = 580.0;
    if (m_longPressDelay < 150) m_longPressDelay = 150;
    if (m_longPressDelay > 1000) m_longPressDelay = 1000;

    s.beginGroup(QStringLiteral("QuickPad"));
    m_quickPadPinned = s.value(QStringLiteral("pinned"), false).toBool();
    m_quickPadKeyCount = s.value(QStringLiteral("keyCount"), 4).toInt();
    if (m_quickPadKeyCount < 1) m_quickPadKeyCount = 1;
    if (m_quickPadKeyCount > 4) m_quickPadKeyCount = 4;
    m_quickPadSize = s.value(QStringLiteral("size"), 220.0).toReal();
    if (m_quickPadSize < 160.0) m_quickPadSize = 160.0;
    if (m_quickPadSize > 380.0) m_quickPadSize = 380.0;

    m_quickPadSlots[0] = {
        s.value(QStringLiteral("slot0_label"), QStringLiteral("Esc")).toString(),
        s.value(QStringLiteral("slot0_code"), KEY_ESC).toInt(),
        s.value(QStringLiteral("slot0_ctrl"), false).toBool(),
        s.value(QStringLiteral("slot0_alt"), false).toBool(),
        s.value(QStringLiteral("slot0_shift"), false).toBool(),
        s.value(QStringLiteral("slot0_meta"), false).toBool()
    };
    m_quickPadSlots[1] = {
        s.value(QStringLiteral("slot1_label"), QStringLiteral("Tab")).toString(),
        s.value(QStringLiteral("slot1_code"), KEY_TAB).toInt(),
        s.value(QStringLiteral("slot1_ctrl"), false).toBool(),
        s.value(QStringLiteral("slot1_alt"), false).toBool(),
        s.value(QStringLiteral("slot1_shift"), false).toBool(),
        s.value(QStringLiteral("slot1_meta"), false).toBool()
    };
    m_quickPadSlots[2] = {
        s.value(QStringLiteral("slot2_label"), QStringLiteral("Ctrl+C")).toString(),
        s.value(QStringLiteral("slot2_code"), KEY_C).toInt(),
        s.value(QStringLiteral("slot2_ctrl"), true).toBool(),
        s.value(QStringLiteral("slot2_alt"), false).toBool(),
        s.value(QStringLiteral("slot2_shift"), false).toBool(),
        s.value(QStringLiteral("slot2_meta"), false).toBool()
    };
    m_quickPadSlots[3] = {
        s.value(QStringLiteral("slot3_label"), QStringLiteral("Ctrl+V")).toString(),
        s.value(QStringLiteral("slot3_code"), KEY_V).toInt(),
        s.value(QStringLiteral("slot3_ctrl"), true).toBool(),
        s.value(QStringLiteral("slot3_alt"), false).toBool(),
        s.value(QStringLiteral("slot3_shift"), false).toBool(),
        s.value(QStringLiteral("slot3_meta"), false).toBool()
    };
    s.endGroup();
}

void SettingsController::saveSettings()
{
    QString confDir = QDir::homePath() + QStringLiteral("/.config/archpad");
    QDir().mkpath(confDir);
    QString confPath = confDir + QStringLiteral("/keyboard.conf");
    QSettings s(confPath, QSettings::IniFormat);

    s.beginGroup(QStringLiteral("General"));
    s.setValue(QStringLiteral("themeMode"), m_themeMode);
    s.setValue(QStringLiteral("heightScale"), m_heightScale);
    s.setValue(QStringLiteral("soundEnabled"), m_soundEnabled);
    s.setValue(QStringLiteral("soundProfile"), m_soundProfile);
    s.setValue(QStringLiteral("soundVolume"), m_soundVolume);
    s.setValue(QStringLiteral("splitMode"), m_splitMode);
    s.setValue(QStringLiteral("themePinned"), m_themePinned);
    s.setValue(QStringLiteral("soundPinned"), m_soundPinned);
    s.setValue(QStringLiteral("splitPinned"), m_splitPinned);
    s.setValue(QStringLiteral("floatingWidth"), m_floatingWidth);
    s.setValue(QStringLiteral("longPressDelay"), m_longPressDelay);
    s.endGroup();

    s.beginGroup(QStringLiteral("QuickPad"));
    s.setValue(QStringLiteral("pinned"), m_quickPadPinned);
    s.setValue(QStringLiteral("keyCount"), m_quickPadKeyCount);
    s.setValue(QStringLiteral("size"), m_quickPadSize);
    for (int i = 0; i < 4; ++i) {
        s.setValue(QStringLiteral("slot%1_label").arg(i), m_quickPadSlots[i].label);
        s.setValue(QStringLiteral("slot%1_code").arg(i), m_quickPadSlots[i].keycode);
        s.setValue(QStringLiteral("slot%1_ctrl").arg(i), m_quickPadSlots[i].ctrl);
        s.setValue(QStringLiteral("slot%1_alt").arg(i), m_quickPadSlots[i].alt);
        s.setValue(QStringLiteral("slot%1_shift").arg(i), m_quickPadSlots[i].shift);
        s.setValue(QStringLiteral("slot%1_meta").arg(i), m_quickPadSlots[i].meta);
    }
    s.endGroup();
    s.sync();
}

void SettingsController::scheduleSaveSettings()
{
    if (!m_saveTimer) {
        m_saveTimer = new QTimer(this);
        m_saveTimer->setSingleShot(true);
        m_saveTimer->setInterval(250);
        connect(m_saveTimer, &QTimer::timeout, this, &SettingsController::saveSettings);
    }
    m_saveTimer->start();
}

void SettingsController::sendDBusAsync(const QString &method, const QVariantList &args)
{
    QDBusInterface iface(QStringLiteral("org.archpad.Keyboard"),
                         QStringLiteral("/org/archpad/Keyboard"),
                         QStringLiteral("org.archpad.Keyboard"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        iface.asyncCallWithArgumentList(method, args);
    }
}

void SettingsController::setThemeMode(int mode)
{
    if (m_themeMode != mode) {
        m_themeMode = mode;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetThemeMode"), { mode });
        Q_EMIT themeModeChanged(m_themeMode);
        Q_EMIT resolvedDarkChanged(resolvedDark());
    }
}

void SettingsController::setHeightScale(qreal scale)
{
    if (qAbs(m_heightScale - scale) > 0.001) {
        m_heightScale = scale;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetHeightScale"), { (double)scale });
        Q_EMIT heightScaleChanged(m_heightScale);
    }
}

void SettingsController::setSoundEnabled(bool enabled)
{
    if (m_soundEnabled != enabled) {
        m_soundEnabled = enabled;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSoundEnabled"), { enabled });
        Q_EMIT soundEnabledChanged(m_soundEnabled);
    }
}

void SettingsController::setSoundProfile(int profile)
{
    profile = qBound(0, profile, 3);
    if (m_soundProfile != profile) {
        m_soundProfile = profile;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSoundProfile"), { profile });
        Q_EMIT soundProfileChanged(m_soundProfile);
    }
}

void SettingsController::setSoundVolume(int volume)
{
    volume = qBound(0, volume, 100);
    if (m_soundVolume != volume) {
        m_soundVolume = volume;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSoundVolume"), { volume });
        Q_EMIT soundVolumeChanged(m_soundVolume);
    }
}

void SettingsController::selectSoundProfile(int profile)
{
    setSoundProfile(profile);
    sendDBusAsync(QStringLiteral("PreviewSoundProfile"), { qBound(0, profile, 3) });
}

void SettingsController::setSplitMode(bool split)
{
    if (m_splitMode != split) {
        m_splitMode = split;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSplitMode"), { split });
        Q_EMIT splitModeChanged(m_splitMode);
    }
}

void SettingsController::setFloatingWidth(qreal width)
{
    if (qAbs(m_floatingWidth - width) > 1.0) {
        m_floatingWidth = width;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetFloatingWidth"), { (double)width });
        Q_EMIT floatingWidthChanged(m_floatingWidth);
    }
}

void SettingsController::setThemePinned(bool pinned)
{
    if (m_themePinned != pinned) {
        m_themePinned = pinned;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetThemePinned"), { pinned });
        Q_EMIT themePinnedChanged(m_themePinned);
    }
}

void SettingsController::setSoundPinned(bool pinned)
{
    if (m_soundPinned != pinned) {
        m_soundPinned = pinned;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSoundPinned"), { pinned });
        Q_EMIT soundPinnedChanged(m_soundPinned);
    }
}

void SettingsController::setSplitPinned(bool pinned)
{
    if (m_splitPinned != pinned) {
        m_splitPinned = pinned;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetSplitPinned"), { pinned });
        Q_EMIT splitPinnedChanged(m_splitPinned);
    }
}

void SettingsController::setQuickPadPinned(bool pinned)
{
    if (m_quickPadPinned != pinned) {
        m_quickPadPinned = pinned;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetQuickPadPinned"), { pinned });
        Q_EMIT quickPadPinnedChanged(m_quickPadPinned);
    }
}

void SettingsController::setQuickPadKeyCount(int count)
{
    if (count < 1) count = 1;
    if (count > 4) count = 4;
    if (m_quickPadKeyCount != count) {
        m_quickPadKeyCount = count;
        if (m_selectedSlot >= m_quickPadKeyCount) {
            m_selectedSlot = qMax(0, m_quickPadKeyCount - 1);
            Q_EMIT selectedSlotChanged(m_selectedSlot);
        }
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetQuickPadKeyCount"), { count });
        Q_EMIT quickPadKeyCountChanged(m_quickPadKeyCount);
    }
}

void SettingsController::setQuickPadSize(qreal size)
{
    if (size < 160.0) size = 160.0;
    if (size > 380.0) size = 380.0;
    if (qAbs(m_quickPadSize - size) > 0.5) {
        m_quickPadSize = size;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetQuickPadSize"), { (double)size });
        Q_EMIT quickPadSizeChanged(m_quickPadSize);
    }
}

void SettingsController::setSelectedSlot(int slot)
{
    if (slot >= 0 && slot < m_quickPadKeyCount && m_selectedSlot != slot) {
        m_selectedSlot = slot;
        Q_EMIT selectedSlotChanged(m_selectedSlot);
    }
}

QString SettingsController::quickPadLabel(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].label;
    return QString();
}

int SettingsController::quickPadKeycode(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].keycode;
    return 1;
}

bool SettingsController::quickPadCtrl(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].ctrl;
    return false;
}

bool SettingsController::quickPadAlt(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].alt;
    return false;
}

bool SettingsController::quickPadShift(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].shift;
    return false;
}

bool SettingsController::quickPadMeta(int slot) const
{
    if (slot >= 0 && slot < 4) return m_quickPadSlots[slot].meta;
    return false;
}

void SettingsController::setQuickPadSlot(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot] = { label, keycode, ctrl, alt, shift, meta };
    saveSettings();
    sendDBusAsync(QStringLiteral("SetQuickPadSlot"), { slot, label, keycode, ctrl, alt, shift, meta });
    m_configRevision++;
    Q_EMIT quickPadConfigChanged();
}

void SettingsController::setQuickPadLabel(int slot, const QString &label)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].label = label;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::setQuickPadKeycode(int slot, int keycode)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].keycode = keycode;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::setQuickPadCtrl(int slot, bool ctrl)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].ctrl = ctrl;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::setQuickPadAlt(int slot, bool alt)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].alt = alt;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::setQuickPadShift(int slot, bool shift)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].shift = shift;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::setQuickPadMeta(int slot, bool meta)
{
    if (slot < 0 || slot >= 4) return;
    m_quickPadSlots[slot].meta = meta;
    setQuickPadSlot(slot, m_quickPadSlots[slot].label, m_quickPadSlots[slot].keycode,
                    m_quickPadSlots[slot].ctrl, m_quickPadSlots[slot].alt,
                    m_quickPadSlots[slot].shift, m_quickPadSlots[slot].meta);
}

void SettingsController::applyPreset(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta)
{
    setQuickPadSlot(slot, label, keycode, ctrl, alt, shift, meta);
}

void SettingsController::applyFunctionKey(int slot, const QString &fnName, int keycode)
{
    if (slot < 0 || slot >= 4) return;
    bool ctrl = m_quickPadSlots[slot].ctrl;
    bool alt = m_quickPadSlots[slot].alt;
    bool shift = m_quickPadSlots[slot].shift;
    bool meta = m_quickPadSlots[slot].meta;
    QString pfx = (ctrl ? QStringLiteral("Ctrl+") : QString()) +
                  (alt ? QStringLiteral("Alt+") : QString()) +
                  (shift ? QStringLiteral("Shift+") : QString()) +
                  (meta ? QStringLiteral("Super+") : QString());
    setQuickPadSlot(slot, pfx + fnName, keycode, ctrl, alt, shift, meta);
}

void SettingsController::applyNavKey(int slot, const QString &keyName, int keycode)
{
    if (slot < 0 || slot >= 4) return;
    bool ctrl = m_quickPadSlots[slot].ctrl;
    bool alt = m_quickPadSlots[slot].alt;
    bool shift = m_quickPadSlots[slot].shift;
    bool meta = m_quickPadSlots[slot].meta;
    QString pfx = (ctrl ? QStringLiteral("Ctrl+") : QString()) +
                  (alt ? QStringLiteral("Alt+") : QString()) +
                  (shift ? QStringLiteral("Shift+") : QString()) +
                  (meta ? QStringLiteral("Super+") : QString());
    setQuickPadSlot(slot, pfx + keyName, keycode, ctrl, alt, shift, meta);
}

void SettingsController::testKey(int slot)
{
    sendDBusAsync(QStringLiteral("TapQuickPadKey"), { slot });
}

void SettingsController::launchQuickPad()
{
    sendDBusAsync(QStringLiteral("SetQuickPad"), { true });
    sendDBusAsync(QStringLiteral("Show"));
}

void SettingsController::showKeyboard()
{
    sendDBusAsync(QStringLiteral("Show"));
}

void SettingsController::hideKeyboard()
{
    sendDBusAsync(QStringLiteral("Hide"));
}

void SettingsController::toggleKeyboard()
{
    sendDBusAsync(QStringLiteral("Toggle"));
}

void SettingsController::setLongPressDelay(int ms)
{
    if (ms < 150) ms = 150;
    if (ms > 1000) ms = 1000;
    if (m_longPressDelay != ms) {
        m_longPressDelay = ms;
        scheduleSaveSettings();
        sendDBusAsync(QStringLiteral("SetLongPressDelay"), { ms });
        Q_EMIT longPressDelayChanged(m_longPressDelay);
    }
}

void SettingsController::resetToDefaults()
{
    m_themeMode = 0;
    m_heightScale = 1.0;
    m_soundEnabled = true;
    m_soundProfile = 0;
    m_soundVolume = 70;
    m_splitMode = false;
    m_floatingWidth = 420.0;
    m_themePinned = false;
    m_soundPinned = false;
    m_splitPinned = false;
    m_quickPadPinned = false;
    m_quickPadKeyCount = 4;
    m_quickPadSize = 220.0;
    m_selectedSlot = 0;
    m_longPressDelay = 350;

    m_quickPadSlots[0] = { QStringLiteral("Esc"), KEY_ESC, false, false, false, false };
    m_quickPadSlots[1] = { QStringLiteral("Tab"), KEY_TAB, false, false, false, false };
    m_quickPadSlots[2] = { QStringLiteral("Ctrl+C"), KEY_C, true, false, false, false };
    m_quickPadSlots[3] = { QStringLiteral("Ctrl+V"), KEY_V, true, false, false, false };

    saveSettings();

    // Push to daemon over D-Bus
    sendDBusAsync(QStringLiteral("SetThemeMode"), { 0 });
    sendDBusAsync(QStringLiteral("SetHeightScale"), { 1.0 });
    sendDBusAsync(QStringLiteral("SetSoundEnabled"), { true });
    sendDBusAsync(QStringLiteral("SetSoundProfile"), { 0 });
    sendDBusAsync(QStringLiteral("SetSoundVolume"), { 70 });
    sendDBusAsync(QStringLiteral("SetSplitMode"), { false });
    sendDBusAsync(QStringLiteral("SetThemePinned"), { false });
    sendDBusAsync(QStringLiteral("SetSoundPinned"), { false });
    sendDBusAsync(QStringLiteral("SetSplitPinned"), { false });
    sendDBusAsync(QStringLiteral("SetQuickPadPinned"), { false });
    sendDBusAsync(QStringLiteral("SetQuickPad"), { false });
    sendDBusAsync(QStringLiteral("SetFloating"), { false });
    sendDBusAsync(QStringLiteral("SetQuickPadKeyCount"), { 4 });
    sendDBusAsync(QStringLiteral("SetQuickPadSize"), { 220.0 });
    for (int i = 0; i < 4; ++i) {
        sendDBusAsync(QStringLiteral("SetQuickPadSlot"), {
            i, m_quickPadSlots[i].label, m_quickPadSlots[i].keycode,
            m_quickPadSlots[i].ctrl, m_quickPadSlots[i].alt,
            m_quickPadSlots[i].shift, m_quickPadSlots[i].meta
        });
    }

    m_configRevision++;
    Q_EMIT themeModeChanged(m_themeMode);
    Q_EMIT resolvedDarkChanged(resolvedDark());
    Q_EMIT heightScaleChanged(m_heightScale);
    Q_EMIT soundEnabledChanged(m_soundEnabled);
    Q_EMIT soundProfileChanged(m_soundProfile);
    Q_EMIT soundVolumeChanged(m_soundVolume);
    Q_EMIT splitModeChanged(m_splitMode);
    Q_EMIT floatingWidthChanged(m_floatingWidth);
    Q_EMIT themePinnedChanged(m_themePinned);
    Q_EMIT soundPinnedChanged(m_soundPinned);
    Q_EMIT splitPinnedChanged(m_splitPinned);
    Q_EMIT quickPadPinnedChanged(m_quickPadPinned);
    Q_EMIT quickPadKeyCountChanged(m_quickPadKeyCount);
    Q_EMIT quickPadSizeChanged(m_quickPadSize);
    Q_EMIT selectedSlotChanged(m_selectedSlot);
    Q_EMIT longPressDelayChanged(m_longPressDelay);
    Q_EMIT quickPadConfigChanged();
}

void SettingsController::Activate()
{
    if (m_mainWindow) {
        m_mainWindow->showNormal();
        m_mainWindow->raise();
        m_mainWindow->requestActivate();
    }
}

void SettingsController::setSelectedCategory(int cat)
{
    if (cat < 0) cat = 0;
    if (cat > 5) cat = 5;
    if (m_selectedCategory != cat) {
        m_selectedCategory = cat;
        Q_EMIT selectedCategoryChanged(m_selectedCategory);
    }
}
