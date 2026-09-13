#include "keyboardmanager.h"

#include <linux/uinput.h>
#include <linux/input-event-codes.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <canberra.h>

#include <QDebug>
#include <QDBusConnection>
#include <QDBusError>
#include <QDBusInterface>
#include <QUrl>
#include <QSettings>
#include <QDir>
#include <QFile>

KeyboardManager::KeyboardManager(QObject *parent)
    : QObject(parent)
{
    initUInput();
    loadSettings();

    // Register DBus interface
    QDBusConnection connection = QDBusConnection::sessionBus();
    if (connection.isConnected()) {
        if (!connection.registerService(QStringLiteral("org.archpad.Keyboard"))) {
            qWarning() << "Could not register DBus service org.archpad.Keyboard:" << connection.lastError().message();
        }
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
    }

    // Initialize lightweight XDG event sound via libcanberra
    ca_context_create(&m_caContext);
    if (m_caContext) {
        ca_context_open(m_caContext);
        ca_context_change_props(m_caContext,
            CA_PROP_APPLICATION_ID, "org.archpad.Keyboard",
            CA_PROP_APPLICATION_NAME, "ArchPad Keyboard",
            nullptr);
        QString soundPath = QStringLiteral("/usr/share/archpad-keyboard/sounds/tick.wav");
        if (!QFile::exists(soundPath)) {
            soundPath = QStringLiteral("/home/archpad/archpad-keyboard/src/sounds/tick.wav");
        }
        if (QFile::exists(soundPath)) {
            ca_context_cache(m_caContext,
                CA_PROP_EVENT_ID, "key-click",
                CA_PROP_MEDIA_FILENAME, soundPath.toUtf8().constData(),
                nullptr);
        }
    }

    // Initialize Theme System & Watcher
    m_cachedSystemDark = detectSystemDark();
    updateResolvedDark();
    saveSettings();

    m_themeWatcher = new QFileSystemWatcher(this);
    QString kdeGlobals = QDir::homePath() + QStringLiteral("/.config/kdeglobals");
    if (QFile::exists(kdeGlobals)) {
        m_themeWatcher->addPath(kdeGlobals);
    }
    connect(m_themeWatcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
        if (!m_themeWatcher->files().contains(path) && QFile::exists(path)) {
            m_themeWatcher->addPath(path);
        }
        m_cachedSystemDark = detectSystemDark();
        updateResolvedDark();
    });
}

KeyboardManager::~KeyboardManager()
{
    if (m_saveSettingsTimer && m_saveSettingsTimer->isActive()) {
        m_saveSettingsTimer->stop();
        saveSettings();
    }
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
        ioctl(m_uinputFd, UI_SET_KEYBIT, key);
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
    write(m_uinputFd, &ie, sizeof(ie));
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
    if (!m_soundEnabled || !m_caContext) return;
    ca_context_play(m_caContext, 1,
        CA_PROP_EVENT_ID, "key-click",
        nullptr);
}

bool KeyboardManager::detectSystemDark()
{
    QString kdeGlobals = QDir::homePath() + QStringLiteral("/.config/kdeglobals");
    if (QFile::exists(kdeGlobals)) {
        QFile file(kdeGlobals);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool inColorsWindow = false;
            while (!file.atEnd()) {
                QString line = QString::fromUtf8(file.readLine()).trimmed();
                if (line.startsWith(QLatin1Char('['))) {
                    inColorsWindow = (line == QStringLiteral("[Colors:Window]"));
                } else if (inColorsWindow && line.startsWith(QStringLiteral("BackgroundNormal="))) {
                    QString val = line.section(QLatin1Char('='), 1).trimmed();
                    QStringList rgb = val.split(QLatin1Char(','));
                    if (rgb.size() >= 3) {
                        int r = rgb[0].trimmed().toInt();
                        int g = rgb[1].trimmed().toInt();
                        int b = rgb[2].trimmed().toInt();
                        int brightness = (r * 299 + g * 587 + b * 114) / 1000;
                        return brightness < 128;
                    }
                }
            }
        }
    }
    return true; // Default to dark
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
    m_themePinned = s.value(QStringLiteral("themePinned"), false).toBool();
    m_soundPinned = s.value(QStringLiteral("soundPinned"), false).toBool();
    m_splitPinned = s.value(QStringLiteral("splitPinned"), false).toBool();
    m_floatingWidth = s.value(QStringLiteral("floatingWidth"), 420.0).toReal();
    s.endGroup();
    if (m_floatingWidth < 340.0) m_floatingWidth = 340.0;
    if (m_floatingWidth > 580.0) m_floatingWidth = 580.0;
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
    s.setValue(QStringLiteral("themePinned"), m_themePinned);
    s.setValue(QStringLiteral("soundPinned"), m_soundPinned);
    s.setValue(QStringLiteral("splitPinned"), m_splitPinned);
    s.setValue(QStringLiteral("floatingWidth"), m_floatingWidth);
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
        emitKey(KEY_LEFTCTRL, m_ctrlActive ? 1 : 0);
        Q_EMIT ctrlActiveChanged(m_ctrlActive);
    }
}

void KeyboardManager::setAltActive(bool active)
{
    if (m_altActive != active) {
        m_altActive = active;
        emitKey(KEY_LEFTALT, m_altActive ? 1 : 0);
        Q_EMIT altActiveChanged(m_altActive);
    }
}

void KeyboardManager::setMetaActive(bool active)
{
    if (m_metaActive != active) {
        m_metaActive = active;
        emitKey(KEY_LEFTMETA, m_metaActive ? 1 : 0);
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

void KeyboardManager::setOptionsVisible(bool visible)
{
    if (m_optionsVisible != visible) {
        m_optionsVisible = visible;
        Q_EMIT optionsVisibleChanged(m_optionsVisible);
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

void KeyboardManager::setSplitMode(bool split)
{
    if (m_splitMode != split) {
        m_splitMode = split;
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

void KeyboardManager::emitKeyWithActiveModifiers(int keycode, bool forceShift, bool forceAltGr)
{
    playClick();

    bool needsShift = forceShift || m_shiftActive || m_capsLockActive;

    if (m_ctrlActive) emitKey(KEY_LEFTCTRL, 1);
    if (m_altActive) emitKey(KEY_LEFTALT, 1);
    if (m_metaActive) emitKey(KEY_LEFTMETA, 1);
    if (forceAltGr) emitKey(KEY_RIGHTALT, 1);
    if (needsShift) emitKey(KEY_LEFTSHIFT, 1);

    emitKeyPressAndRelease(keycode);

    if (needsShift) {
        emitKey(KEY_LEFTSHIFT, 0);
        if (m_shiftActive && !m_capsLockActive) {
            setShiftActive(false);
        }
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

void KeyboardManager::ToggleOptions()
{
    setOptionsVisible(!m_optionsVisible);
}

void KeyboardManager::SetOptionsVisible(bool visible)
{
    setOptionsVisible(visible);
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
