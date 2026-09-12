#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <dirent.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <glib.h>
#include <glib-unix.h>
#include <gio/gio.h>

#define LONG_PRESS_MS 750
#define RESUME_DEBOUNCE_MS 1200
#define PWRKEY_DEV_NAME "pm8941_pwrkey"

typedef struct {
    GMainLoop *loop;
    GDBusConnection *session_bus;
    GDBusConnection *system_bus;
    int pwr_fd;
    int uinput_fd;
    guint long_press_timer_id;
    bool button_down;
    bool long_press_handled;
    uint64_t press_start_ms;
} DaemonContext;

static uint64_t g_last_resume_time_ms = 0;

static uint64_t get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

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

    usleep(20000);

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
    return true;
}

static void lock_and_suspend(GDBusConnection *session_bus, GDBusConnection *system_bus)
{
    g_message("Action: Instant screen off, session lock, and system suspend (s2idle)");

    system("kscreen-doctor --dpms off 2>/dev/null &");
    system("loginctl lock-session 2>/dev/null &");

    if (session_bus) {
        g_dbus_connection_call(
            session_bus,
            "org.freedesktop.ScreenSaver",
            "/ScreenSaver",
            "org.freedesktop.ScreenSaver",
            "Lock",
            NULL,
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            500,
            NULL,
            NULL,
            NULL
        );
    }

    if (system_bus) {
        g_dbus_connection_call(
            system_bus,
            "org.freedesktop.login1",
            "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager",
            "Suspend",
            g_variant_new("(b)", FALSE),
            NULL,
            G_DBUS_CALL_FLAGS_NONE,
            2000,
            NULL,
            NULL,
            NULL
        );
    } else {
        system("systemctl suspend &");
    }
}

static void wake_screen(GDBusConnection *bus, int uinput_fd)
{
    g_message("Action: Waking screen");

    system("kscreen-doctor --dpms on 2>/dev/null &");
    emit_uinput_key(uinput_fd, KEY_POWER);

    const char *desktop = g_getenv("XDG_CURRENT_DESKTOP");
    if (desktop && g_strrstr(desktop, "GNOME")) {
        system("busctl --user set-property org.gnome.Mutter.DisplayConfig /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i 0 2>/dev/null || true");
    }

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

static gboolean on_long_press_timeout(gpointer user_data)
{
    DaemonContext *ctx = (DaemonContext *)user_data;
    ctx->long_press_timer_id = 0;

    if (ctx->button_down && !ctx->long_press_handled) {
        trigger_power_menu(ctx->session_bus);
        ctx->long_press_handled = true;
    }
    return G_SOURCE_REMOVE;
}

static void on_prepare_for_sleep(GDBusConnection *connection,
                                 const gchar *sender_name,
                                 const gchar *object_path,
                                 const gchar *interface_name,
                                 const gchar *signal_name,
                                 GVariant *parameters,
                                 gpointer user_data)
{
    (void)connection; (void)sender_name; (void)object_path;
    (void)interface_name; (void)signal_name; (void)user_data;

    gboolean going_to_sleep = FALSE;
    g_variant_get(parameters, "(b)", &going_to_sleep);

    if (!going_to_sleep) {
        g_last_resume_time_ms = get_time_ms();
        g_message("System resumed from sleep (wake recorded at %llu ms)",
                  (unsigned long long)g_last_resume_time_ms);
        system("kscreen-doctor --dpms on 2>/dev/null &");
    }
}

static gboolean on_pwrkey_event(GIOChannel *source, GIOCondition condition, gpointer user_data)
{
    (void)source;
    DaemonContext *ctx = (DaemonContext *)user_data;

    if (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL)) {
        g_warning("Power key device disconnected or error");
        g_main_loop_quit(ctx->loop);
        return G_SOURCE_REMOVE;
    }

    struct input_event ev[16];
    ssize_t bytes = read(ctx->pwr_fd, ev, sizeof(ev));
    if (bytes < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return G_SOURCE_CONTINUE;
        g_warning("read error on power key: %s", strerror(errno));
        g_main_loop_quit(ctx->loop);
        return G_SOURCE_REMOVE;
    }

    int count = bytes / sizeof(struct input_event);
    for (int i = 0; i < count; i++) {
        if (ev[i].type != EV_KEY || ev[i].code != KEY_POWER)
            continue;

        if (ev[i].value == 1) {
            ctx->button_down = true;
            ctx->press_start_ms = get_time_ms();
            ctx->long_press_handled = false;

            if (ctx->long_press_timer_id > 0) {
                g_source_remove(ctx->long_press_timer_id);
            }
            ctx->long_press_timer_id = g_timeout_add(LONG_PRESS_MS, on_long_press_timeout, ctx);

        } else if (ev[i].value == 0) {
            if (ctx->long_press_timer_id > 0) {
                g_source_remove(ctx->long_press_timer_id);
                ctx->long_press_timer_id = 0;
            }

            if (ctx->button_down) {
                ctx->button_down = false;
                if (!ctx->long_press_handled) {
                    uint64_t now = get_time_ms();
                    if (g_last_resume_time_ms > 0 && (now - g_last_resume_time_ms < RESUME_DEBOUNCE_MS)) {
                        g_message("Ignored power button release: system just resumed (%llu ms ago)",
                                  (unsigned long long)(now - g_last_resume_time_ms));
                        system("kscreen-doctor --dpms on 2>/dev/null &");
                    } else {
                        if (is_screen_on()) {
                            lock_and_suspend(ctx->session_bus, ctx->system_bus);
                        } else {
                            wake_screen(ctx->session_bus, ctx->uinput_fd);
                        }
                    }
                }
            }
        }
    }

    return G_SOURCE_CONTINUE;
}

static gboolean on_unix_signal(gpointer user_data)
{
    GMainLoop *loop = (GMainLoop *)user_data;
    g_message("Termination signal received, exiting main loop...");
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    g_message("Starting ArchPad Power Key Daemon (archpad-pwrkey)...");

    DaemonContext ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.loop = g_main_loop_new(NULL, FALSE);

    g_unix_signal_add(SIGTERM, on_unix_signal, ctx.loop);
    g_unix_signal_add(SIGINT, on_unix_signal, ctx.loop);

    GError *error = NULL;
    ctx.session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!ctx.session_bus) {
        g_warning("Failed to connect to session bus: %s", error ? error->message : "unknown");
        g_clear_error(&error);
    }

    ctx.system_bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (ctx.system_bus) {
        g_dbus_connection_signal_subscribe(
            ctx.system_bus,
            "org.freedesktop.login1",
            "org.freedesktop.login1.Manager",
            "PrepareForSleep",
            "/org/freedesktop/login1",
            NULL,
            G_DBUS_SIGNAL_FLAGS_NONE,
            on_prepare_for_sleep,
            &ctx,
            NULL
        );
        g_message("Subscribed to systemd-logind PrepareForSleep signals");
    } else {
        g_warning("Failed to connect to system bus: %s", error ? error->message : "unknown");
        g_clear_error(&error);
    }

    ctx.uinput_fd = setup_uinput_device();

    ctx.pwr_fd = -1;
    for (int attempt = 0; attempt < 10 && ctx.pwr_fd < 0; attempt++) {
        ctx.pwr_fd = open_pwrkey_device();
        if (ctx.pwr_fd < 0) {
            g_warning("Power key not found, retrying in 1 second...");
            sleep(1);
        }
    }

    if (ctx.pwr_fd < 0) {
        g_error("Could not open power key device!");
        if (ctx.uinput_fd >= 0) {
            ioctl(ctx.uinput_fd, UI_DEV_DESTROY);
            close(ctx.uinput_fd);
        }
        return 1;
    }

    if (ioctl(ctx.pwr_fd, EVIOCGRAB, 1) < 0) {
        g_warning("Failed to grab power key device: %s", strerror(errno));
    } else {
        g_message("Acquired exclusive grab on power key");
    }

    GIOChannel *channel = g_io_channel_unix_new(ctx.pwr_fd);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    g_io_add_watch(channel, G_IO_IN | G_IO_HUP | G_IO_ERR, on_pwrkey_event, &ctx);
    g_io_channel_unref(channel);

    g_main_loop_run(ctx.loop);

    g_message("Shutting down archpad-pwrkey...");

    if (ctx.long_press_timer_id > 0)
        g_source_remove(ctx.long_press_timer_id);

    if (ctx.pwr_fd >= 0) {
        ioctl(ctx.pwr_fd, EVIOCGRAB, 0);
        close(ctx.pwr_fd);
    }

    if (ctx.uinput_fd >= 0) {
        ioctl(ctx.uinput_fd, UI_DEV_DESTROY);
        close(ctx.uinput_fd);
    }

    if (ctx.session_bus)
        g_object_unref(ctx.session_bus);
    if (ctx.system_bus)
        g_object_unref(ctx.system_bus);

    g_main_loop_unref(ctx.loop);
    return 0;
}
