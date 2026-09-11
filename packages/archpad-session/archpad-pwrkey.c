/*
 * ArchPad Power Button Daemon (archpad-pwrkey)
 *
 * Provides native tablet power key behavior:
 * - Short press (< 750ms):
 *     If screen is ON  -> Lock session and turn screen OFF.
 *     If screen is OFF -> Wake screen immediately.
 * - Long press (>= 750ms):
 *     Opens the full-screen Power / Shutdown Menu.
 *
 * Multi-DE compatible: Uses Linux evdev + FreeDesktop / DE standards.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <time.h>
#include <dirent.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <gio/gio.h>

#define LONG_PRESS_MS 750
#define PWRKEY_DEV_NAME "pm8941_pwrkey"

static volatile sig_atomic_t g_running = 1;

static void sig_handler(int sig)
{
    (void)sig;
    g_running = 0;
}

static uint64_t get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

/* Discover input event node for pm8941_pwrkey */
static int open_pwrkey_device(void)
{
    DIR *dir = opendir("/dev/input");
    if (!dir) {
        perror("opendir /dev/input");
        return -1;
    }

    struct dirent *ent;
    char path[512];
    char name[256];
    int fd = -1;

    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "event", 5) != 0)
            continue;

        snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
        int cur_fd = open(path, O_RDONLY | O_NONBLOCK);
        if (cur_fd < 0)
            continue;

        memset(name, 0, sizeof(name));
        if (ioctl(cur_fd, EVIOCGNAME(sizeof(name) - 1), name) >= 0) {
            if (strstr(name, PWRKEY_DEV_NAME) != NULL) {
                fd = cur_fd;
                g_message("Found power key on %s: %s", path, name);
                break;
            }
        }
        close(cur_fd);
    }
    closedir(dir);
    return fd;
}

/* Set up persistent uinput device for injecting wake events */
static int setup_uinput_device(void)
{
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        g_warning("Failed to open /dev/uinput: %s", strerror(errno));
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_KEYBIT, KEY_POWER);
    ioctl(fd, UI_SET_KEYBIT, KEY_WAKEUP);

    struct uinput_setup usetup;
    memset(&usetup, 0, sizeof(usetup));
    usetup.id.bustype = BUS_USB;
    usetup.id.vendor = 0x1d6b;
    usetup.id.product = 0x0001;
    strncpy(usetup.name, "ArchPad Virtual Wakeup Key", sizeof(usetup.name) - 1);

    if (ioctl(fd, UI_DEV_SETUP, &usetup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
        g_warning("Failed to create uinput device: %s", strerror(errno));
        close(fd);
        return -1;
    }

    g_message("ArchPad virtual input device created successfully");
    return fd;
}

static void emit_uinput_key(int uinput_fd, int key)
{
    if (uinput_fd < 0)
        return;

    struct input_event ev;

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY;
    ev.code = key;
    ev.value = 1;
    if (write(uinput_fd, &ev, sizeof(ev)) < 0)
        g_warning("uinput write down failed: %s", strerror(errno));

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    write(uinput_fd, &ev, sizeof(ev));

    usleep(20000); // 20ms hold

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_KEY;
    ev.code = key;
    ev.value = 0;
    if (write(uinput_fd, &ev, sizeof(ev)) < 0)
        g_warning("uinput write up failed: %s", strerror(errno));

    memset(&ev, 0, sizeof(ev));
    ev.type = EV_SYN;
    ev.code = SYN_REPORT;
    write(uinput_fd, &ev, sizeof(ev));
}

static bool is_screen_on(void)
{
    const char *paths[] = {
        "/sys/class/drm/card1-DSI-1/dpms",
        "/sys/class/drm/card0-DSI-1/dpms",
        NULL
    };

    for (int i = 0; paths[i]; i++) {
        FILE *f = fopen(paths[i], "r");
        if (!f)
            continue;

        char buf[32] = {0};
        if (fgets(buf, sizeof(buf), f)) {
            fclose(f);
            if (strncmp(buf, "On", 2) == 0)
                return true;
            if (strncmp(buf, "Off", 3) == 0)
                return false;
        } else {
            fclose(f);
        }
    }
    return true; // Default fallback assume ON
}

static void lock_and_turn_off_screen(GDBusConnection *bus)
{
    g_message("Action: Locking session and turning off screen");

    // 1. Lock screen via standard FreeDesktop API
    if (bus) {
        g_dbus_connection_call(
            bus,
            "org.freedesktop.ScreenSaver",
            "/ScreenSaver",
            "org.freedesktop.ScreenSaver",
            "Lock",
            NULL,
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            1000,
            NULL,
            NULL,
            NULL
        );
    }

    // 2. Turn off display according to desktop environment
    const char *desktop = g_getenv("XDG_CURRENT_DESKTOP");
    if (!desktop)
        desktop = "";

    if (g_strrstr(desktop, "KDE") || g_strrstr(desktop, "Plasma")) {
        if (bus) {
            g_dbus_connection_call(
                bus,
                "org.kde.kglobalaccel",
                "/component/org_kde_powerdevil",
                "org.kde.kglobalaccel.Component",
                "invokeShortcut",
                g_variant_new("(s)", "Turn Off Screen"),
                NULL,
                G_DBUS_CALL_FLAGS_NONE,
                1000,
                NULL,
                NULL,
                NULL
            );
        }
    } else if (g_strrstr(desktop, "GNOME")) {
        system("dbus-send --session --dest=org.gnome.Mutter.DisplayConfig /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig.SetPowerState int32:0 2>/dev/null || true");
    } else {
        system("hyprctl dispatch dpms off 2>/dev/null || wlopm --off 2>/dev/null || true");
    }
}

static void wake_screen(GDBusConnection *bus, int uinput_fd)
{
    g_message("Action: Waking screen");

    // 1. Send hardware KEY_POWER through uinput virtual device
    emit_uinput_key(uinput_fd, KEY_POWER);

    // 2. Also simulate activity via ScreenSaver D-Bus
    if (bus) {
        g_dbus_connection_call(
            bus,
            "org.freedesktop.ScreenSaver",
            "/ScreenSaver",
            "org.freedesktop.ScreenSaver",
            "SimulateUserActivity",
            NULL,
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            1000,
            NULL,
            NULL,
            NULL
        );
    }
}

static void trigger_power_menu(GDBusConnection *bus)
{
    g_message("Action: Triggering Power Menu (Long Press)");

    const char *desktop = g_getenv("XDG_CURRENT_DESKTOP");
    if (!desktop)
        desktop = "";

    if (g_strrstr(desktop, "KDE") || g_strrstr(desktop, "Plasma")) {
        if (bus) {
            g_dbus_connection_call(
                bus,
                "org.kde.LogoutPrompt",
                "/LogoutPrompt",
                "org.kde.LogoutPrompt",
                "promptAll",
                NULL,
                NULL,
                G_DBUS_CALL_FLAGS_NONE,
                2000,
                NULL,
                NULL,
                NULL
            );
        }
    } else if (g_strrstr(desktop, "GNOME")) {
        system("gnome-session-quit --power-off &");
    } else {
        system("wlogout &");
    }
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    g_message("Starting ArchPad Power Key Daemon (archpad-pwrkey)...");

    // Connect to user session D-Bus
    GError *error = NULL;
    GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!bus) {
        g_warning("Failed to connect to session bus: %s (will retry on demand)",
                  error ? error->message : "unknown");
        g_clear_error(&error);
    }

    // Set up uinput device
    int uinput_fd = setup_uinput_device();

    // Open physical power key device
    int pwr_fd = -1;
    while (g_running && pwr_fd < 0) {
        pwr_fd = open_pwrkey_device();
        if (pwr_fd < 0) {
            g_warning("Power key not found, retrying in 2 seconds...");
            sleep(2);
        }
    }

    if (!g_running || pwr_fd < 0) {
        if (uinput_fd >= 0) {
            ioctl(uinput_fd, UI_DEV_DESTROY);
            close(uinput_fd);
        }
        return 1;
    }

    // Grab the device exclusively
    if (ioctl(pwr_fd, EVIOCGRAB, 1) < 0) {
        g_warning("Failed to grab power key device: %s", strerror(errno));
    } else {
        g_message("Acquired exclusive grab on power key");
    }

    bool button_down = false;
    uint64_t press_start_ms = 0;
    bool long_press_handled = false;

    struct pollfd pfd;
    pfd.fd = pwr_fd;
    pfd.events = POLLIN;

    while (g_running) {
        // Reconnect session bus if disconnected
        if (!bus || g_dbus_connection_is_closed(bus)) {
            if (bus)
                g_object_unref(bus);
            bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, NULL);
        }

        int timeout_ms = -1;
        if (button_down && !long_press_handled) {
            uint64_t elapsed = get_time_ms() - press_start_ms;
            if (elapsed >= LONG_PRESS_MS) {
                // Long press timeout reached while button is held
                trigger_power_menu(bus);
                long_press_handled = true;
                timeout_ms = -1;
            } else {
                timeout_ms = LONG_PRESS_MS - elapsed;
            }
        }

        int ret = poll(&pfd, 1, timeout_ms);
        if (ret < 0) {
            if (errno == EINTR)
                continue;
            g_warning("poll error: %s", strerror(errno));
            break;
        }

        if (ret == 0) {
            // Timeout fired while button is down
            if (button_down && !long_press_handled) {
                trigger_power_menu(bus);
                long_press_handled = true;
            }
            continue;
        }

        if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) {
            g_warning("Input device disconnect/error");
            break;
        }

        if (pfd.revents & POLLIN) {
            struct input_event ev[16];
            ssize_t bytes = read(pwr_fd, ev, sizeof(ev));
            if (bytes < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK)
                    continue;
                g_warning("read error: %s", strerror(errno));
                break;
            }

            int count = bytes / sizeof(struct input_event);
            for (int i = 0; i < count; i++) {
                if (ev[i].type != EV_KEY || ev[i].code != KEY_POWER)
                    continue;

                if (ev[i].value == 1) {
                    // Key Down
                    button_down = true;
                    press_start_ms = get_time_ms();
                    long_press_handled = false;
                } else if (ev[i].value == 0) {
                    // Key Up
                    if (button_down) {
                        button_down = false;
                        if (!long_press_handled) {
                            // Short Press!
                            if (is_screen_on()) {
                                lock_and_turn_off_screen(bus);
                            } else {
                                wake_screen(bus, uinput_fd);
                            }
                        }
                    }
                }
            }
        }
    }

    g_message("Shutting down archpad-pwrkey...");

    if (pwr_fd >= 0) {
        ioctl(pwr_fd, EVIOCGRAB, 0);
        close(pwr_fd);
    }
    if (uinput_fd >= 0) {
        ioctl(uinput_fd, UI_DEV_DESTROY);
        close(uinput_fd);
    }
    if (bus)
        g_object_unref(bus);

    return 0;
}
