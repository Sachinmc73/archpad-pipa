#include "keyboardmanager.h"
#include "swipeengineworker.h"

#include <QThread>
#include <linux/uinput.h>
#include <linux/input-event-codes.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <canberra.h>

#include <QDebug>
#include <QGuiApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QUrl>
#include <QSettings>
#include <QDir>
#include <QFile>
#include <QPalette>
#include <QProcess>
#include <QStyleHints>

KeyboardManager::KeyboardManager(QObject *parent)
    : QObject(parent)
{
    initUInput();
    loadSettings();

    // Register DBus interface
    QDBusConnection connection = QDBusConnection::sessionBus();
    if (connection.isConnected()) {
        if (!connection.registerObject(QStringLiteral("/org/archpad/Keyboard"), this, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals)) {
            qWarning() << "Could not register DBus object /org/archpad/Keyboard:" << connection.lastError().message();
        }

        // Sync with KWin VirtualKeyboard status
        connection.connect(
            QStringLiteral("org.kde.KWin"),
            QStringLiteral("/VirtualKeyboard"),
            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
            QStringLiteral("activeChanged"),
            this,
            SLOT(onKWinActiveChanged())
        );
        connection.connect(
            QStringLiteral("org.kde.KWin"),
            QStringLiteral("/VirtualKeyboard"),
            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
            QStringLiteral("visibleChanged"),
            this,
            SLOT(onKWinVisibleChanged())
        );

        m_kwinServiceWatcher = new QDBusServiceWatcher(
            QStringLiteral("org.kde.KWin"),
            connection,
            QDBusServiceWatcher::WatchForOwnerChange,
            this);
        connect(m_kwinServiceWatcher, &QDBusServiceWatcher::serviceOwnerChanged,
                this, [this](const QString &, const QString &, const QString &newOwner) {
                    if (!newOwner.isEmpty()) {
                        syncKWinVirtualKeyboardState();
                    } else if (!m_manuallyShown) {
                        clearTransientState();
                        setIsVisible(false);
                    }
                });

        if (QDBusConnectionInterface *busInterface = connection.interface()) {
            const QDBusReply<bool> kwinRegistered = busInterface->isServiceRegistered(QStringLiteral("org.kde.KWin"));
            if (kwinRegistered.isValid() && kwinRegistered.value()) {
                syncKWinVirtualKeyboardState();
            }
        }
    }

    // Initialize lightweight XDG event sound via libcanberra.
    int soundResult = ca_context_create(&m_caContext);
    if (soundResult < 0) {
        qWarning() << "Could not create libcanberra context:" << ca_strerror(soundResult);
        m_caContext = nullptr;
    }
    if (m_caContext) {
        soundResult = ca_context_change_props(m_caContext,
            CA_PROP_APPLICATION_ID, "org.archpad.Keyboard",
            CA_PROP_APPLICATION_NAME, "ArchPad Keyboard",
            nullptr);
        if (soundResult < 0) {
            qWarning() << "Could not configure libcanberra context:" << ca_strerror(soundResult);
        }

        soundResult = ca_context_open(m_caContext);
        if (soundResult < 0) {
            qWarning() << "Could not open libcanberra context:" << ca_strerror(soundResult);
            ca_context_destroy(m_caContext);
            m_caContext = nullptr;
        }

        m_clickSoundPath = soundPathForProfile(m_soundProfile);
        if (m_caContext && !QFile::exists(m_clickSoundPath)) {
            qWarning() << "Keyboard click sound is missing:" << m_clickSoundPath;
        }
    }

    // Initialize standard Qt system appearance tracking.
    m_cachedSystemDark = detectSystemDark();
    updateResolvedDark();
    saveSettings();

    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
            this, [this](Qt::ColorScheme) {
        m_cachedSystemDark = detectSystemDark();
        updateResolvedDark();
    });

    // Initialize background single-owner SwipeEngineWorker thread
    m_swipeThread = new QThread(this);
    m_swipeWorker = new SwipeEngineWorker();
    m_swipeWorker->moveToThread(m_swipeThread);

    connect(m_swipeThread, &QThread::finished, m_swipeWorker, &QObject::deleteLater);

    connect(m_swipeWorker, &SwipeEngineWorker::stateChanged, this, [this](SwipeEngineWorker::State state, const QString &) {
        const bool ready = (state == SwipeEngineWorker::State::Ready);
        if (m_swipeReady != ready) {
            m_swipeReady = ready;
            Q_EMIT swipeReadyChanged(m_swipeReady);
        }
        Q_EMIT swipeStateChanged(m_swipeWorker->stateString());
    });

    connect(m_swipeWorker, &SwipeEngineWorker::decodeFinished, this, [this](quint64 reqId, const QStringList &candidates, const QVariantMap &timings) {
        qInfo() << "Swipe decode finished for req" << reqId
                << "candidates:" << candidates
                << "inference:" << timings.value(QStringLiteral("inference_us")).toDouble() / 1000.0 << "ms";
        Q_EMIT swipeCandidatesReady(reqId, candidates, timings);
    });

    connect(m_swipeWorker, &SwipeEngineWorker::decodeError, this, [this](quint64 reqId, const QString &err) {
        qWarning() << "Swipe decode error for req" << reqId << ":" << err;
        Q_EMIT swipeDecodeError(reqId, err);
    });

    m_swipeThread->start();
    loadSwipeEngine();
}

KeyboardManager::~KeyboardManager()
{
    if (m_swipeThread) {
        m_swipeThread->quit();
        m_swipeThread->wait(1000);
    }
    if (m_saveSettingsTimer && m_saveSettingsTimer->isActive()) {
        m_saveSettingsTimer->stop();
        saveSettings();
    }
    clearTransientState();
    closeUInput();
    if (m_caContext) {
        ca_context_destroy(m_caContext);
        m_caContext = nullptr;
    }
}

bool KeyboardManager::initUInput()
{
    m_uinputFd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (m_uinputFd < 0) {
        qWarning() << "Failed to open /dev/uinput:" << strerror(errno);
        return false;
    }

    // Enable EV_KEY and EV_SYN
    if (ioctl(m_uinputFd, UI_SET_EVBIT, EV_KEY) < 0 ||
        ioctl(m_uinputFd, UI_SET_EVBIT, EV_SYN) < 0) {
        qWarning() << "Failed to set EV bits on uinput:" << strerror(errno);
        closeUInput();
        return false;
    }

    // Enable all standard keyboard keys
    for (int key = 1; key <= KEY_MICMUTE; ++key) {
        if (ioctl(m_uinputFd, UI_SET_KEYBIT, key) < 0) {
            qWarning() << "Failed to enable uinput key" << key << ":" << strerror(errno);
            closeUInput();
            return false;
        }
    }

    struct uinput_setup usetup;
    std::memset(&usetup, 0, sizeof(usetup));
    usetup.id.bustype = BUS_VIRTUAL;
    usetup.id.vendor  = 0x18d1; // Google
    usetup.id.product = 0x0001;
    usetup.id.version = 1;
    std::strncpy(usetup.name, "ArchPad Virtual Keyboard", UINPUT_MAX_NAME_SIZE - 1);

    if (ioctl(m_uinputFd, UI_DEV_SETUP, &usetup) < 0 ||
        ioctl(m_uinputFd, UI_DEV_CREATE) < 0) {
        qWarning() << "Failed to create uinput device:" << strerror(errno);
        closeUInput();
        return false;
    }

    qInfo() << "Successfully initialized ArchPad Virtual Keyboard on /dev/uinput";
    ensureXkbOptions();
    return true;
}

void KeyboardManager::ensureXkbOptions()
{
    QString kxkbPath = QDir::homePath() + QStringLiteral("/.config/kxkbrc");
    QSettings kxkb(kxkbPath, QSettings::IniFormat);
    QString currentOptions = kxkb.value(QStringLiteral("Layout/Options")).toString();
    if (!currentOptions.contains(QStringLiteral("rupeesign:4")) ||
        !currentOptions.contains(QStringLiteral("lv3:ralt_switch"))) {
        kxkb.setValue(QStringLiteral("Layout/LayoutList"), QStringLiteral("us"));
        QStringList opts;
        if (!currentOptions.isEmpty()) {
            opts = currentOptions.split(QLatin1Char(','), Qt::SkipEmptyParts);
        }
        if (!opts.contains(QStringLiteral("rupeesign:4"))) opts.append(QStringLiteral("rupeesign:4"));
        if (!opts.contains(QStringLiteral("eurosign:e"))) opts.append(QStringLiteral("eurosign:e"));
        if (!opts.contains(QStringLiteral("lv3:ralt_switch"))) opts.append(QStringLiteral("lv3:ralt_switch"));
        kxkb.setValue(QStringLiteral("Layout/Options"), opts.join(QLatin1Char(',')));
        kxkb.setValue(QStringLiteral("Layout/ResetOldOptions"), true);
        kxkb.setValue(QStringLiteral("Layout/Use"), true);
        kxkb.sync();

        QDBusInterface kwinLayouts(QStringLiteral("org.kde.KWin"),
                                  QStringLiteral("/Layouts"),
                                  QStringLiteral("org.kde.KeyboardLayouts"),
                                  QDBusConnection::sessionBus());
        if (kwinLayouts.isValid()) {
            kwinLayouts.call(QStringLiteral("setLayout"), 0u);
        }
    }
}

void KeyboardManager::closeUInput()
{
    if (m_uinputFd >= 0) {
        ioctl(m_uinputFd, UI_DEV_DESTROY);
        close(m_uinputFd);
        m_uinputFd = -1;
    }
}

void KeyboardManager::emitRawEvent(int type, int code, int value)
{
    if (m_uinputFd < 0) return;

    struct input_event ie;
    std::memset(&ie, 0, sizeof(ie));
    ie.type = static_cast<__u16>(type);
    ie.code = static_cast<__u16>(code);
    ie.value = value;
    const ssize_t written = write(m_uinputFd, &ie, sizeof(ie));
    if (written < 0) {
        qWarning() << "Failed to emit uinput event:" << strerror(errno);
    } else if (written != static_cast<ssize_t>(sizeof(ie))) {
        qWarning() << "Short uinput write:" << written << "of" << sizeof(ie) << "bytes";
    }
}

void KeyboardManager::emitKey(int code, int value)
{
    emitRawEvent(EV_KEY, code, value);
    emitRawEvent(EV_SYN, SYN_REPORT, 0);
}

void KeyboardManager::emitKeyPressAndRelease(int code)
{
    emitKey(code, 1);
    emitKey(code, 0);
}

void KeyboardManager::playClick()
{
    if (!m_soundEnabled) return;
    playSoundFile(m_clickSoundPath);
}

void KeyboardManager::previewSoundProfile(int profile)
{
    if (!m_soundEnabled) return;
    playSoundFile(soundPathForProfile(qBound(0, profile, 3)));
}

QString KeyboardManager::soundPathForProfile(int profile) const
{
    static const char *const fileNames[] = {
        "keypress-standard.ogg",
        "keypress-soft.ogg",
        "keypress-crisp.ogg",
        "keypress-deep.ogg"
    };
    const int boundedProfile = qBound(0, profile, 3);
    return QStringLiteral("/usr/share/archpad-keyboard/sounds/")
        + QString::fromLatin1(fileNames[boundedProfile]);
}

void KeyboardManager::playSoundFile(const QString &path)
{
    if (!m_caContext || path.isEmpty() || m_soundVolume <= 0) return;

    const double linearGain = static_cast<double>(m_soundVolume) / 100.0;
    const QByteArray volumeDb = QByteArray::number(20.0 * std::log10(linearGain), 'f', 2);

    const int result = ca_context_play(m_caContext, 0,
        CA_PROP_MEDIA_FILENAME, path.toUtf8().constData(),
        CA_PROP_CANBERRA_VOLUME, volumeDb.constData(),
        nullptr);
    if (result < 0 && !m_clickPlaybackErrorLogged) {
        m_clickPlaybackErrorLogged = true;
        qWarning() << "Could not play keyboard click sound:" << ca_strerror(result);
    }
}

bool KeyboardManager::detectSystemDark()
{
    const Qt::ColorScheme scheme = QGuiApplication::styleHints()->colorScheme();
    if (scheme == Qt::ColorScheme::Dark) {
        return true;
    }
    if (scheme == Qt::ColorScheme::Light) {
        return false;
    }

    return QGuiApplication::palette().color(QPalette::Window).lightness() < 128;
}

void KeyboardManager::updateResolvedDark()
{
    bool isDark = true;
    if (m_themeMode == 1) {
        isDark = false; // Forced Light
    } else if (m_themeMode == 2) {
        isDark = true; // Forced Dark
    } else {
        isDark = m_cachedSystemDark; // Follow System
    }

    if (m_resolvedDark != isDark) {
        m_resolvedDark = isDark;
        saveSettings();
        Q_EMIT resolvedDarkChanged(m_resolvedDark);
    }
}

bool KeyboardManager::resolvedDark() const
{
    return m_resolvedDark;
}

void KeyboardManager::loadSettings()
{
    QString confPath = QDir::homePath() + QStringLiteral("/.config/archpad/keyboard.conf");
    QSettings s(confPath, QSettings::IniFormat);
    s.beginGroup(QStringLiteral("General"));
    m_themeMode = s.value(QStringLiteral("themeMode"), 0).toInt();
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
    m_longPressDelay = qBound(150, m_longPressDelay, 1000);

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

void KeyboardManager::saveSettings()
{
    QString confDir = QDir::homePath() + QStringLiteral("/.config/archpad");
    QDir().mkpath(confDir);
    QString confPath = confDir + QStringLiteral("/keyboard.conf");
    QSettings s(confPath, QSettings::IniFormat);
    s.beginGroup(QStringLiteral("General"));
    s.setValue(QStringLiteral("themeMode"), m_themeMode);
    s.setValue(QStringLiteral("resolvedDark"), m_resolvedDark);
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

void KeyboardManager::scheduleSaveSettings()
{
    if (!m_saveSettingsTimer) {
        m_saveSettingsTimer = new QTimer(this);
        m_saveSettingsTimer->setSingleShot(true);
        m_saveSettingsTimer->setInterval(300); // 300ms debounce
        connect(m_saveSettingsTimer, &QTimer::timeout, this, &KeyboardManager::saveSettings);
    }
    m_saveSettingsTimer->start();
}

void KeyboardManager::setShiftActive(bool active)
{
    if (m_shiftActive != active) {
        m_shiftActive = active;
        Q_EMIT shiftActiveChanged(m_shiftActive);
    }
}

void KeyboardManager::setCapsLockActive(bool active)
{
    if (m_capsLockActive != active) {
        m_capsLockActive = active;
        Q_EMIT capsLockActiveChanged(m_capsLockActive);
    }
}

void KeyboardManager::setCtrlActive(bool active)
{
    if (m_ctrlActive != active) {
        m_ctrlActive = active;
        Q_EMIT ctrlActiveChanged(m_ctrlActive);
    }
}

void KeyboardManager::setAltActive(bool active)
{
    if (m_altActive != active) {
        m_altActive = active;
        Q_EMIT altActiveChanged(m_altActive);
    }
}

void KeyboardManager::setMetaActive(bool active)
{
    if (m_metaActive != active) {
        m_metaActive = active;
        Q_EMIT metaActiveChanged(m_metaActive);
    }
}

void KeyboardManager::setIsFloating(bool floating)
{
    if (m_isFloating != floating) {
        m_isFloating = floating;
        Q_EMIT isFloatingChanged(m_isFloating);
    }
}

void KeyboardManager::setIsVisible(bool visible)
{
    if (m_isVisible != visible) {
        m_isVisible = visible;
        Q_EMIT isVisibleChanged(m_isVisible);
    }
}

void KeyboardManager::setSoundEnabled(bool enabled)
{
    if (m_soundEnabled != enabled) {
        m_soundEnabled = enabled;
        saveSettings();
        Q_EMIT soundEnabledChanged(m_soundEnabled);
    }
}

void KeyboardManager::setSoundProfile(int profile)
{
    profile = qBound(0, profile, 3);
    if (m_soundProfile != profile) {
        m_soundProfile = profile;
        m_clickSoundPath = soundPathForProfile(m_soundProfile);
        m_clickPlaybackErrorLogged = false;
        saveSettings();
        Q_EMIT soundProfileChanged(m_soundProfile);
    }
}

void KeyboardManager::setSoundVolume(int volume)
{
    volume = qBound(0, volume, 100);
    if (m_soundVolume != volume) {
        m_soundVolume = volume;
        saveSettings();
        Q_EMIT soundVolumeChanged(m_soundVolume);
    }
}

void KeyboardManager::setThemeMode(int mode)
{
    if (mode < 0 || mode > 2) mode = 0;
    if (m_themeMode != mode) {
        m_themeMode = mode;
        updateResolvedDark();
        saveSettings();
        Q_EMIT themeModeChanged(m_themeMode);
    }
}

void KeyboardManager::cycleThemeMode()
{
    setThemeMode((m_themeMode + 1) % 3);
}

void KeyboardManager::setHeightScale(qreal scale)
{
    if (scale < 0.75) scale = 0.75;
    if (scale > 1.40) scale = 1.40;
    if (!qFuzzyCompare(m_heightScale, scale)) {
        m_heightScale = scale;
        saveSettings();
        Q_EMIT heightScaleChanged(m_heightScale);
    }
}

void KeyboardManager::setLongPressDelay(int delay)
{
    delay = qBound(150, delay, 1000);
    if (m_longPressDelay != delay) {
        m_longPressDelay = delay;
        saveSettings();
        Q_EMIT longPressDelayChanged(m_longPressDelay);
    }
}

void KeyboardManager::setSplitMode(bool split)
{
    if (m_splitMode != split) {
        m_splitMode = split;
        saveSettings();
        Q_EMIT splitModeChanged(m_splitMode);
    }
}

void KeyboardManager::setFloatingWidth(qreal width)
{
    if (width < 340.0) width = 340.0;
    if (width > 580.0) width = 580.0;
    if (!qFuzzyCompare(m_floatingWidth, width)) {
        m_floatingWidth = width;
        scheduleSaveSettings();
        Q_EMIT floatingWidthChanged(m_floatingWidth);
    }
}

void KeyboardManager::setThemePinned(bool pinned)
{
    if (m_themePinned != pinned) {
        m_themePinned = pinned;
        saveSettings();
        Q_EMIT themePinnedChanged(m_themePinned);
    }
}

void KeyboardManager::setSoundPinned(bool pinned)
{
    if (m_soundPinned != pinned) {
        m_soundPinned = pinned;
        saveSettings();
        Q_EMIT soundPinnedChanged(m_soundPinned);
    }
}

void KeyboardManager::setSplitPinned(bool pinned)
{
    if (m_splitPinned != pinned) {
        m_splitPinned = pinned;
        saveSettings();
        Q_EMIT splitPinnedChanged(m_splitPinned);
    }
}

void KeyboardManager::setIsQuickPad(bool active)
{
    if (m_isQuickPad != active) {
        m_isQuickPad = active;
        Q_EMIT isQuickPadChanged(m_isQuickPad);
    }
}

void KeyboardManager::setQuickPadPinned(bool pinned)
{
    if (m_quickPadPinned != pinned) {
        m_quickPadPinned = pinned;
        saveSettings();
        Q_EMIT quickPadPinnedChanged(m_quickPadPinned);
    }
}

void KeyboardManager::setQuickPadKeyCount(int count)
{
    count = qBound(1, count, 4);
    if (m_quickPadKeyCount != count) {
        m_quickPadKeyCount = count;
        saveSettings();
        Q_EMIT quickPadKeyCountChanged(m_quickPadKeyCount);
    }
}

void KeyboardManager::setQuickPadSize(qreal size)
{
    size = qBound(160.0, size, 380.0);
    if (!qFuzzyCompare(m_quickPadSize, size)) {
        m_quickPadSize = size;
        scheduleSaveSettings();
        Q_EMIT quickPadSizeChanged(m_quickPadSize);
    }
}

QString KeyboardManager::quickPadLabel(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].label;
    }
    return QString();
}

int KeyboardManager::quickPadKeycode(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].keycode;
    }
    return 0;
}

bool KeyboardManager::quickPadCtrl(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].ctrl;
    }
    return false;
}

bool KeyboardManager::quickPadAlt(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].alt;
    }
    return false;
}

bool KeyboardManager::quickPadShift(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].shift;
    }
    return false;
}

bool KeyboardManager::quickPadMeta(int slot) const
{
    if (slot >= 0 && slot < 4) {
        return m_quickPadSlots[slot].meta;
    }
    return false;
}

void KeyboardManager::setQuickPadSlot(int slot, const QString &label, int keycode, bool ctrl, bool alt, bool shift, bool meta)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot] = { label, keycode, ctrl, alt, shift, meta };
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadLabel(int slot, const QString &label)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].label = label;
        scheduleSaveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadKeycode(int slot, int keycode)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].keycode = keycode;
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadCtrl(int slot, bool ctrl)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].ctrl = ctrl;
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadAlt(int slot, bool alt)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].alt = alt;
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadShift(int slot, bool shift)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].shift = shift;
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::setQuickPadMeta(int slot, bool meta)
{
    if (slot >= 0 && slot < 4) {
        m_quickPadSlots[slot].meta = meta;
        saveSettings();
        Q_EMIT quickPadConfigChanged();
    }
}

void KeyboardManager::tapQuickPadKey(int slot)
{
    if (slot < 0 || slot >= 4) return;
    const QuickPadSlot &s = m_quickPadSlots[slot];
    if (s.keycode <= 0) return;

    playClick();

    if (s.ctrl) emitKey(KEY_LEFTCTRL, 1);
    if (s.alt) emitKey(KEY_LEFTALT, 1);
    if (s.meta) emitKey(KEY_LEFTMETA, 1);
    if (s.shift) emitKey(KEY_LEFTSHIFT, 1);

    emitKeyPressAndRelease(s.keycode);

    if (s.shift) emitKey(KEY_LEFTSHIFT, 0);
    if (s.meta) emitKey(KEY_LEFTMETA, 0);
    if (s.alt) emitKey(KEY_LEFTALT, 0);
    if (s.ctrl) emitKey(KEY_LEFTCTRL, 0);
}

void KeyboardManager::toggleQuickPad()
{
    if (m_isQuickPad && m_isVisible) {
        Hide();
    } else {
        setIsQuickPad(true);
        Show();
    }
}


void KeyboardManager::emitKeyWithActiveModifiers(int keycode, bool forceShift, bool forceAltGr)
{
    playClick();

    const bool isAlpha = (keycode >= KEY_Q && keycode <= KEY_P) ||
                         (keycode >= KEY_A && keycode <= KEY_L) ||
                         (keycode >= KEY_Z && keycode <= KEY_M);

    bool needsShift = forceShift;
    if (isAlpha) {
        // On alphabetic keys, Shift inverts CapsLock state (standard XKB / hardware behavior)
        if (m_shiftActive != m_capsLockActive) {
            needsShift = true;
        }
    } else {
        // On non-alphabetic keys (numbers, symbols), CapsLock has zero effect; only Shift applies
        if (m_shiftActive) {
            needsShift = true;
        }
    }

    if (m_ctrlActive) emitKey(KEY_LEFTCTRL, 1);
    if (m_altActive) emitKey(KEY_LEFTALT, 1);
    if (m_metaActive) emitKey(KEY_LEFTMETA, 1);
    if (forceAltGr) emitKey(KEY_RIGHTALT, 1);
    if (needsShift) emitKey(KEY_LEFTSHIFT, 1);

    emitKeyPressAndRelease(keycode);

    if (needsShift) {
        emitKey(KEY_LEFTSHIFT, 0);
    }
    if (m_shiftActive) {
        setShiftActive(false);
    }
    if (forceAltGr) {
        emitKey(KEY_RIGHTALT, 0);
    }
    if (m_metaActive) {
        emitKey(KEY_LEFTMETA, 0);
        setMetaActive(false);
    }
    if (m_altActive) {
        emitKey(KEY_LEFTALT, 0);
        setAltActive(false);
    }
    if (m_ctrlActive) {
        emitKey(KEY_LEFTCTRL, 0);
        setCtrlActive(false);
    }
}

void KeyboardManager::clearTransientState()
{
    setShiftActive(false);
    setCapsLockActive(false);
    setCtrlActive(false);
    setAltActive(false);
    setMetaActive(false);
}

void KeyboardManager::tapKey(int keycode)
{
    emitKeyWithActiveModifiers(keycode, false);
}

void KeyboardManager::tapKeyWithModifiers(int keycode, bool shift, bool ctrl, bool alt)
{
    playClick();

    if (shift) emitKey(KEY_LEFTSHIFT, 1);
    if (ctrl) emitKey(KEY_LEFTCTRL, 1);
    if (alt) emitKey(KEY_LEFTALT, 1);

    emitKeyPressAndRelease(keycode);

    if (alt) emitKey(KEY_LEFTALT, 0);
    if (ctrl) emitKey(KEY_LEFTCTRL, 0);
    if (shift) emitKey(KEY_LEFTSHIFT, 0);
}

void KeyboardManager::tapNavKey(const QString &navKey)
{
    int keycode = 0;
    if (navKey == QLatin1String("Esc")) {
        keycode = KEY_ESC;
    } else if (navKey == QLatin1String("Tab")) {
        keycode = KEY_TAB;
    } else if (navKey == QLatin1String("Space")) {
        keycode = KEY_SPACE;
    } else if (navKey == QLatin1String("Backspace")) {
        keycode = KEY_BACKSPACE;
    } else if (navKey == QLatin1String("Delete") || navKey == QLatin1String("Del")) {
        keycode = KEY_DELETE;
    } else if (navKey == QLatin1String("Enter") || navKey == QLatin1String("Return")) {
        keycode = KEY_ENTER;
    } else if (navKey == QLatin1String("Left")) {
        keycode = KEY_LEFT;
    } else if (navKey == QLatin1String("Right")) {
        keycode = KEY_RIGHT;
    } else if (navKey == QLatin1String("Up")) {
        keycode = KEY_UP;
    } else if (navKey == QLatin1String("Down")) {
        keycode = KEY_DOWN;
    } else if (navKey == QLatin1String("Home")) {
        keycode = KEY_HOME;
    } else if (navKey == QLatin1String("End")) {
        keycode = KEY_END;
    } else if (navKey == QLatin1String("PageUp")) {
        keycode = KEY_PAGEUP;
    } else if (navKey == QLatin1String("PageDown")) {
        keycode = KEY_PAGEDOWN;
    }

    if (keycode != 0) {
        emitKeyWithActiveModifiers(keycode, false);
    }
}

void KeyboardManager::tapSymbol(const QString &symbol)
{
    if (symbol.isEmpty()) return;
    if (symbol == QLatin1String("...")) {
        tapSymbol(QStringLiteral("."));
        tapSymbol(QStringLiteral("."));
        tapSymbol(QStringLiteral("."));
        return;
    }

    QChar c = symbol.at(0);

    bool shift = false;
    bool altGr = false;
    int keycode = 0;

    static const int s_alphaKeycodes[26] = {
        KEY_A, // a / A
        KEY_B, // b / B
        KEY_C, // c / C
        KEY_D, // d / D
        KEY_E, // e / E
        KEY_F, // f / F
        KEY_G, // g / G
        KEY_H, // h / H
        KEY_I, // i / I
        KEY_J, // j / J
        KEY_K, // k / K
        KEY_L, // l / L
        KEY_M, // m / M
        KEY_N, // n / N
        KEY_O, // o / O
        KEY_P, // p / P
        KEY_Q, // q / Q
        KEY_R, // r / R
        KEY_S, // s / S
        KEY_T, // t / T
        KEY_U, // u / U
        KEY_V, // v / V
        KEY_W, // w / W
        KEY_X, // x / X
        KEY_Y, // y / Y
        KEY_Z  // z / Z
    };

    if (c >= QLatin1Char('a') && c <= QLatin1Char('z')) {
        keycode = s_alphaKeycodes[c.unicode() - 'a'];
        shift = false;
    } else if (c >= QLatin1Char('A') && c <= QLatin1Char('Z')) {
        keycode = s_alphaKeycodes[c.unicode() - 'A'];
        shift = true;
    } else if (c >= QLatin1Char('1') && c <= QLatin1Char('9')) {
        keycode = KEY_1 + (c.unicode() - '1');
        shift = false;
    } else if (c == QLatin1Char('0')) {
        keycode = KEY_0;
        shift = false;
    } else {
        switch (c.unicode()) {
        case '!': keycode = KEY_1; shift = true; break;
        case '@': keycode = KEY_2; shift = true; break;
        case '#': keycode = KEY_3; shift = true; break;
        case '$': keycode = KEY_4; shift = true; break;
        case '%': keycode = KEY_5; shift = true; break;
        case '^': keycode = KEY_6; shift = true; break;
        case '&': keycode = KEY_7; shift = true; break;
        case '*': keycode = KEY_8; shift = true; break;
        case '(': keycode = KEY_9; shift = true; break;
        case ')': keycode = KEY_0; shift = true; break;
        case '-': keycode = KEY_MINUS; shift = false; break;
        case '_': keycode = KEY_MINUS; shift = true; break;
        case '=': keycode = KEY_EQUAL; shift = false; break;
        case '+': keycode = KEY_EQUAL; shift = true; break;
        case '[': keycode = KEY_LEFTBRACE; shift = false; break;
        case '{': keycode = KEY_LEFTBRACE; shift = true; break;
        case ']': keycode = KEY_RIGHTBRACE; shift = false; break;
        case '}': keycode = KEY_RIGHTBRACE; shift = true; break;
        case ';': keycode = KEY_SEMICOLON; shift = false; break;
        case ':': keycode = KEY_SEMICOLON; shift = true; break;
        case '\'': keycode = KEY_APOSTROPHE; shift = false; break;
        case '"': keycode = KEY_APOSTROPHE; shift = true; break;
        case '`': keycode = KEY_GRAVE; shift = false; break;
        case '~': keycode = KEY_GRAVE; shift = true; break;
        case '\\': keycode = KEY_BACKSLASH; shift = false; break;
        case '|': keycode = KEY_BACKSLASH; shift = true; break;
        case ',': keycode = KEY_COMMA; shift = false; break;
        case '<': keycode = KEY_COMMA; shift = true; break;
        case '.': keycode = KEY_DOT; shift = false; break;
        case '>': keycode = KEY_DOT; shift = true; break;
        case '/': keycode = KEY_SLASH; shift = false; break;
        case '?': keycode = KEY_SLASH; shift = true; break;
        case ' ': keycode = KEY_SPACE; shift = false; break;

        // Indian Rupee & Currency
        case 0x20B9: // '₹' Indian Rupee
            keycode = KEY_4; altGr = true; shift = false; break;
        case 0x20AC: // '€' Euro
            keycode = KEY_E; altGr = true; shift = false; break;
        case 0x00A3: // '£' Pound Sterling
            keycode = KEY_4; altGr = true; shift = true; break;
        case 0x00A5: // '¥' Yen
            keycode = KEY_MINUS; altGr = true; shift = false; break;
        case 0x00A2: // '¢' Cent
            keycode = KEY_C; altGr = true; shift = true; break;

        // Math & Specials
        case 0x00D7: // '×' Multiplication
            keycode = KEY_8; shift = true; break;
        case 0x00F7: // '÷' Division
            keycode = KEY_SLASH; shift = false; break;
        case 0x00B0: // '°' Degree
            keycode = KEY_SEMICOLON; altGr = true; shift = true; break;
        case 0x00B1: // '±' Plus-minus
            keycode = KEY_M; altGr = true; shift = true; break;
        case 0x2022: // '•' Bullet
        case 0x00B7: // '·' Middle dot
            keycode = KEY_B; altGr = true; shift = false; break;
        case 0x00A9: // '©' Copyright
            keycode = KEY_C; altGr = true; shift = false; break;
        case 0x00AE: // '®' Registered
            keycode = KEY_V; altGr = true; shift = false; break;
        case 0x2122: // '™' Trademark
            keycode = KEY_V; altGr = true; shift = true; break;
        case 0x00A7: // '§' Section
            keycode = KEY_S; altGr = true; shift = true; break;
        case 0x00B6: // '¶' Pilcrow
            keycode = KEY_SEMICOLON; altGr = true; shift = false; break;
        case 0x2713: // '✓' Checkmark
            keycode = KEY_V; shift = false; break;

        default:
            return;
        }
    }

    emitKeyWithActiveModifiers(keycode, shift, altGr);
}

void KeyboardManager::tapText(const QString &text)
{
    for (const QChar &ch : text) {
        tapSymbol(QString(ch));
    }
}

void KeyboardManager::Show()
{
    m_manuallyShown = true;
    setIsVisible(true);
}

void KeyboardManager::Hide()
{
    m_manuallyShown = false;
    clearTransientState();
    setIsVisible(false);
    QDBusInterface kwinVk(QStringLiteral("org.kde.KWin"),
                          QStringLiteral("/VirtualKeyboard"),
                          QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                          QDBusConnection::sessionBus());
    if (kwinVk.isValid()) {
        kwinVk.setProperty("active", false);
    }
}

void KeyboardManager::Toggle()
{
    if (m_isVisible) {
        Hide();
    } else {
        Show();
    }
}

void KeyboardManager::onKWinActiveChanged()
{
    syncKWinVirtualKeyboardState();
}

void KeyboardManager::syncKWinVirtualKeyboardState()
{
    QDBusInterface kwinVk(QStringLiteral("org.kde.KWin"),
                          QStringLiteral("/VirtualKeyboard"),
                          QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                          QDBusConnection::sessionBus());
    if (kwinVk.isValid()) {
        bool visible = kwinVk.property("visible").toBool();
        bool active = kwinVk.property("active").toBool();
        if (visible || active) {
            m_manuallyShown = false;
            setIsVisible(true);
        } else if (!m_manuallyShown) {
            clearTransientState();
            setIsVisible(false);
        }
    }
}

void KeyboardManager::onKWinVisibleChanged()
{
    onKWinActiveChanged();
}

void KeyboardManager::ToggleFloating()
{
    setIsFloating(!m_isFloating);
}

void KeyboardManager::SetFloating(bool floating)
{
    setIsFloating(floating);
}

void KeyboardManager::CycleThemeMode()
{
    cycleThemeMode();
}

void KeyboardManager::SetThemeMode(int mode)
{
    setThemeMode(mode);
}

void KeyboardManager::SetHeightScale(double scale)
{
    setHeightScale(scale);
}

void KeyboardManager::ToggleSplitMode()
{
    toggleSplitMode();
}

void KeyboardManager::SetSplitMode(bool split)
{
    setSplitMode(split);
}

void KeyboardManager::openSettingsApp()
{
    if (!QProcess::startDetached(QStringLiteral("/usr/bin/archpad-keyboard-settings"), {})) {
        qWarning() << "Could not launch archpad-keyboard-settings";
    }
}

void KeyboardManager::OpenSettingsApp()
{
    openSettingsApp();
}

void KeyboardManager::OpenQuickPadConfig()
{
    openSettingsApp();
}

void KeyboardManager::setSwipeActive(bool active)
{
    if (m_swipeActive != active) {
        m_swipeActive = active;
        Q_EMIT swipeActiveChanged(m_swipeActive);
    }
}

QString KeyboardManager::swipeState() const
{
    if (!m_swipeWorker) return QStringLiteral("Unloaded");
    return m_swipeWorker->stateString();
}

void KeyboardManager::requestSwipeDecode(quint64 requestId, const QVariantList &points, const QStringList &contextWords)
{
    if (!m_swipeReady || !m_swipeWorker) {
        return;
    }
    QVector<float> x, y, t;
    x.reserve(points.size());
    y.reserve(points.size());
    t.reserve(points.size());
    for (const auto &p : points) {
        const QVariantMap map = p.toMap();
        x.append(map.value(QStringLiteral("x")).toFloat());
        y.append(map.value(QStringLiteral("y")).toFloat());
        t.append(map.value(QStringLiteral("t")).toFloat());
    }
    QMetaObject::invokeMethod(m_swipeWorker, "requestDecode",
                             Qt::QueuedConnection,
                             Q_ARG(quint64, requestId),
                             Q_ARG(QVector<float>, x),
                             Q_ARG(QVector<float>, y),
                             Q_ARG(QVector<float>, t),
                             Q_ARG(QStringList, contextWords),
                             Q_ARG(int, 4),
                             Q_ARG(int, 100));
}

void KeyboardManager::loadSwipeEngine()
{
    if (m_swipeWorker) {
        QMetaObject::invokeMethod(m_swipeWorker, "initEngine", Qt::QueuedConnection, Q_ARG(QString, QString()));
    }
}

void KeyboardManager::unloadSwipeEngine()
{
    if (m_swipeWorker) {
        QMetaObject::invokeMethod(m_swipeWorker, "unloadEngine", Qt::QueuedConnection);
    }
}

quint64 KeyboardManager::getSwipeMemoryPssKiB() const
{
    return SwipeEngineWorker::getMemoryPssKiB();
}

