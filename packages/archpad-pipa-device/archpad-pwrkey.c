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
#include <dirent.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <glib.h>
#include <glib-unix.h>
#include <gio/gio.h>

/*
 * archpad-pwrkey — ArchPad Tablet Power Key Daemon
 *
 * Grabs pm8941_pwrkey exclusively (EVIOCGRAB) so that systemd-logind and
 * PowerDevil never see KEY_POWER.  All decisions are made here:
 *
 *   Short press (while awake)  → Suspend() via logind (KWin delay inhibitor locks session cleanly)
 *   Short press (while waking) → ignored; is_waking cleared immediately on release
 *   Long press  (≥ 750 ms)     → org.kde.LogoutPrompt.promptAll
 *
 * State machine driven entirely by the PrepareForSleep logind signal:
 *   PrepareForSleep(true)  → is_sleeping = true,  is_waking = false
 *   PrepareForSleep(false) → is_sleeping = false,  is_waking = true
 *   KEY_POWER release while is_waking → is_waking = false  (debounce cleared immediately)
 */

#define LONG_PRESS_MS    750
#define WAKE_DEBOUNCE_MS 500
#define PWRKEY_DEV_NAME  "pm8941_pwrkey"

typedef struct {
    GMainLoop        *loop;
    GDBusConnection  *session_bus;
    GDBusConnection  *system_bus;
    int               pwr_fd;
    guint             long_press_timer_id;
    guint             wake_timer_id;
    bool              button_down;
    bool              long_press_handled;
    bool              is_sleeping;
    bool              is_waking;
} DaemonContext;

/* ── Device discovery ─────────────────────────────────────────────────────── */

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

/* ── Actions ──────────────────────────────────────────────────────────────── */


static void call_suspend(GDBusConnection *system_bus)
{
    if (!system_bus) {
        g_warning("No system bus — cannot call Suspend");
        return;
    }

    g_message("Action: Requesting system suspend via logind Suspend()");
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
}

static void call_logout_prompt(GDBusConnection *session_bus)
{
    if (!session_bus)
        return;

    g_message("Action: Triggering KDE LogoutPrompt (long press)");
    g_dbus_connection_call(
        session_bus,
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

/* ── Timers ───────────────────────────────────────────────────────────────── */

static gboolean on_long_press_timeout(gpointer user_data)
{
    DaemonContext *ctx = (DaemonContext *)user_data;
    ctx->long_press_timer_id = 0;

    if (ctx->button_down && !ctx->long_press_handled) {
        call_logout_prompt(ctx->session_bus);
        ctx->long_press_handled = true;
    }
    return G_SOURCE_REMOVE;
}

static gboolean on_wake_timeout(gpointer user_data)
{
    DaemonContext *ctx = (DaemonContext *)user_data;
    ctx->wake_timer_id = 0;
    ctx->is_waking = false;
    g_message("Wake settle complete (%d ms) — power button fully active", WAKE_DEBOUNCE_MS);
    return G_SOURCE_REMOVE;
}

static void cancel_all_timers(DaemonContext *ctx)
{
    if (ctx->long_press_timer_id > 0) {
        g_source_remove(ctx->long_press_timer_id);
        ctx->long_press_timer_id = 0;
    }
    if (ctx->wake_timer_id > 0) {
        g_source_remove(ctx->wake_timer_id);
        ctx->wake_timer_id = 0;
    }
}

/* ── PrepareForSleep signal handler ──────────────────────────────────────── */

static void on_prepare_for_sleep(GDBusConnection *connection,
                                 const gchar *sender_name,
                                 const gchar *object_path,
                                 const gchar *interface_name,
                                 const gchar *signal_name,
                                 GVariant *parameters,
                                 gpointer user_data)
{
    (void)connection; (void)sender_name; (void)object_path;
    (void)interface_name; (void)signal_name;

    DaemonContext *ctx = (DaemonContext *)user_data;

    gboolean going_to_sleep = FALSE;
    g_variant_get(parameters, "(b)", &going_to_sleep);

    if (going_to_sleep) {
        g_message("PrepareForSleep(true): entering sleep — cancelling pending timers");
        cancel_all_timers(ctx);
        ctx->is_sleeping       = true;
        ctx->is_waking         = false;
        ctx->button_down       = false;
        ctx->long_press_handled = false;
    } else {
        g_message("PrepareForSleep(false): system resumed — starting %d ms wake settle timer",
                  WAKE_DEBOUNCE_MS);
        cancel_all_timers(ctx);
        ctx->is_sleeping       = false;
        ctx->is_waking         = true;
        ctx->button_down       = false;
        ctx->long_press_handled = false;
        ctx->wake_timer_id     = g_timeout_add(WAKE_DEBOUNCE_MS, on_wake_timeout, ctx);
    }
}

/* ── Main evdev handler ───────────────────────────────────────────────────── */

static gboolean on_pwrkey_event(GIOChannel *source, GIOCondition condition,
                                gpointer user_data)
{
    (void)source;
    DaemonContext *ctx = (DaemonContext *)user_data;

    if (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL)) {
        g_warning("Power key device disconnected or error — exiting event loop");
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

    int count = (int)(bytes / sizeof(struct input_event));
    for (int i = 0; i < count; i++) {
        if (ev[i].type != EV_KEY || ev[i].code != KEY_POWER)
            continue;

        if (ev[i].value == 1) {
            /* ── Button pressed ─────────────────────────────────────────── */

            if (ctx->is_sleeping || ctx->is_waking) {
                g_message("KEY_POWER press ignored: %s",
                          ctx->is_sleeping ? "system is sleeping"
                                           : "wake in progress");
                continue;
            }

            g_message("KEY_POWER press: starting long-press timer (%d ms)",
                      LONG_PRESS_MS);
            ctx->button_down       = true;
            ctx->long_press_handled = false;

            if (ctx->long_press_timer_id > 0)
                g_source_remove(ctx->long_press_timer_id);
            ctx->long_press_timer_id =
                g_timeout_add(LONG_PRESS_MS, on_long_press_timeout, ctx);

        } else if (ev[i].value == 0) {
            /* ── Button released ────────────────────────────────────────── */

            /* Cancel long-press timer regardless */
            if (ctx->long_press_timer_id > 0) {
                g_source_remove(ctx->long_press_timer_id);
                ctx->long_press_timer_id = 0;
            }

            if (ctx->is_sleeping) {
                g_message("KEY_POWER release ignored: system is sleeping");
                continue;
            }

            if (ctx->is_waking) {
                g_message("KEY_POWER release during wake — clearing wake debounce");
                ctx->button_down = false;
                ctx->is_waking = false;
                if (ctx->wake_timer_id > 0) {
                    g_source_remove(ctx->wake_timer_id);
                    ctx->wake_timer_id = 0;
                }
                continue;
            }

            if (ctx->button_down && !ctx->long_press_handled) {
                /* Short press: suspend system via logind Suspend() */
                g_message("Short press: requesting system suspend via logind Suspend()");
                ctx->button_down = false;
                call_suspend(ctx->system_bus);
            } else {
                ctx->button_down = false;
            }
        }
        /* Ignore auto-repeat (value == 2) */
    }

    return G_SOURCE_CONTINUE;
}

/* ── Signal handling ──────────────────────────────────────────────────────── */

static gboolean on_unix_signal(gpointer user_data)
{
    GMainLoop *loop = (GMainLoop *)user_data;
    g_message("Termination signal received — shutting down");
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

/* ── main ─────────────────────────────────────────────────────────────────── */

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    g_message("Starting ArchPad Power Key Daemon (archpad-pwrkey)");

    DaemonContext ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.loop = g_main_loop_new(NULL, FALSE);

    g_unix_signal_add(SIGTERM, on_unix_signal, ctx.loop);
    g_unix_signal_add(SIGINT,  on_unix_signal, ctx.loop);

    GError *error = NULL;

    /* Session bus — for KDE LogoutPrompt */
    ctx.session_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
    if (!ctx.session_bus) {
        g_warning("Failed to connect to session bus: %s",
                  error ? error->message : "unknown");
        g_clear_error(&error);
    }

    /* System bus — for logind LockSessions / Suspend / PrepareForSleep */
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
        g_message("Subscribed to logind PrepareForSleep signal");
    } else {
        g_warning("Failed to connect to system bus: %s",
                  error ? error->message : "unknown");
        g_clear_error(&error);
    }

    /* Open power key device (retry up to 10 s for late udev enumeration) */
    ctx.pwr_fd = -1;
    for (int attempt = 0; attempt < 10 && ctx.pwr_fd < 0; attempt++) {
        ctx.pwr_fd = open_pwrkey_device();
        if (ctx.pwr_fd < 0) {
            g_warning("Power key not found, retrying in 1 second... (%d/10)",
                      attempt + 1);
            sleep(1);
        }
    }

    if (ctx.pwr_fd < 0) {
        g_error("Could not open power key device — giving up");
        return 1;
    }

    if (ioctl(ctx.pwr_fd, EVIOCGRAB, 1) < 0) {
        g_warning("EVIOCGRAB failed: %s — logind may also handle KEY_POWER",
                  strerror(errno));
    } else {
        g_message("Acquired exclusive grab on power key (EVIOCGRAB)");
    }

    GIOChannel *channel = g_io_channel_unix_new(ctx.pwr_fd);
    g_io_channel_set_encoding(channel, NULL, NULL);
    g_io_channel_set_buffered(channel, FALSE);
    g_io_add_watch(channel, G_IO_IN | G_IO_HUP | G_IO_ERR, on_pwrkey_event, &ctx);
    g_io_channel_unref(channel);

    g_message("Ready — listening for power key events");
    g_main_loop_run(ctx.loop);

    g_message("Shutting down archpad-pwrkey");

    cancel_all_timers(&ctx);

    if (ctx.pwr_fd >= 0) {
        ioctl(ctx.pwr_fd, EVIOCGRAB, 0);
        close(ctx.pwr_fd);
    }

    if (ctx.session_bus)
        g_object_unref(ctx.session_bus);
    if (ctx.system_bus)
        g_object_unref(ctx.system_bus);

    g_main_loop_unref(ctx.loop);
    return 0;
}
