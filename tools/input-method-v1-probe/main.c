#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <poll.h>
#include <time.h>
#include <limits.h>
#include <unistd.h>

#include <wayland-client.h>
#include <systemd/sd-bus.h>

#include "input-method-unstable-v1-client-protocol.h"

static volatile sig_atomic_t g_running = 1;

static void sig_handler(int sig)
{
    (void)sig;
    g_running = 0;
}

struct ContextState {
    struct zwp_input_method_context_v1 *context;
    bool is_active;
    bool has_serial;
    uint32_t serial;
    uint32_t content_hint;
    uint32_t content_purpose;
    bool has_surrounding;
    uint32_t surrounding_cursor;
    uint32_t surrounding_anchor;
};

struct ProbeApp {
    struct wl_display *display;
    struct wl_registry *registry;
    struct zwp_input_method_v1 *input_method;
    sd_bus *bus;
    struct ContextState ctx_state;
};

static struct ProbeApp g_app;

/* zwp_input_method_context_v1 listener */

static void context_handle_surrounding_text(void *data,
                                            struct zwp_input_method_context_v1 *context,
                                            const char *text,
                                            uint32_t cursor,
                                            uint32_t anchor)
{
    (void)data;
    (void)context;
    // Hard requirement: report presence, but NEVER log or persist surrounding text itself
    g_app.ctx_state.has_surrounding = (text != NULL && strlen(text) > 0);
    g_app.ctx_state.surrounding_cursor = cursor;
    g_app.ctx_state.surrounding_anchor = anchor;
    bool has_sel = (cursor != anchor);
    printf("[probe] surrounding_text event: available=%s cursor=%u anchor=%u selection=%s (text content suppressed)\n",
           g_app.ctx_state.has_surrounding ? "true" : "false",
           cursor, anchor, has_sel ? "true" : "false");
    fflush(stdout);
}

static void context_handle_reset(void *data,
                                 struct zwp_input_method_context_v1 *context)
{
    (void)data;
    (void)context;
    printf("[probe] reset event received\n");
    g_app.ctx_state.has_surrounding = false;
    fflush(stdout);
}

static void context_handle_content_type(void *data,
                                        struct zwp_input_method_context_v1 *context,
                                        uint32_t hint,
                                        uint32_t purpose)
{
    (void)data;
    (void)context;
    g_app.ctx_state.content_hint = hint;
    g_app.ctx_state.content_purpose = purpose;
    printf("[probe] content_type event: hint=0x%04x purpose=%u\n", hint, purpose);
    fflush(stdout);
}

static void context_handle_invoke_action(void *data,
                                         struct zwp_input_method_context_v1 *context,
                                         uint32_t button,
                                         uint32_t index)
{
    (void)data;
    (void)context;
    printf("[probe] invoke_action event: button=%u index=%u\n", button, index);
    fflush(stdout);
}

static void context_handle_commit_state(void *data,
                                        struct zwp_input_method_context_v1 *context,
                                        uint32_t serial)
{
    (void)data;
    (void)context;
    g_app.ctx_state.serial = serial;
    g_app.ctx_state.has_serial = true;
    printf("[probe] commit_state event: serial=%u\n", serial);
    fflush(stdout);
}

static void context_handle_preferred_language(void *data,
                                              struct zwp_input_method_context_v1 *context,
                                              const char *language)
{
    (void)data;
    (void)context;
    printf("[probe] preferred_language event: language=%s\n", language ? language : "(null)");
    fflush(stdout);
}

static const struct zwp_input_method_context_v1_listener context_listener = {
    .surrounding_text = context_handle_surrounding_text,
    .reset = context_handle_reset,
    .content_type = context_handle_content_type,
    .invoke_action = context_handle_invoke_action,
    .commit_state = context_handle_commit_state,
    .preferred_language = context_handle_preferred_language,
};

/* zwp_input_method_v1 listener */

static void input_method_handle_activate(void *data,
                                         struct zwp_input_method_v1 *zwp_input_method_v1,
                                         struct zwp_input_method_context_v1 *id)
{
    (void)data;
    (void)zwp_input_method_v1;
    printf("[probe] activate event received -> new context %p\n", (void *)id);
    fflush(stdout);

    if (g_app.ctx_state.context && g_app.ctx_state.context != id) {
        printf("[probe] destroying previous unhandled context %p\n", (void *)g_app.ctx_state.context);
        zwp_input_method_context_v1_destroy(g_app.ctx_state.context);
    }

    g_app.ctx_state.context = id;
    g_app.ctx_state.is_active = true;
    g_app.ctx_state.has_serial = false;
    g_app.ctx_state.has_surrounding = false;
    g_app.ctx_state.surrounding_cursor = 0;
    g_app.ctx_state.surrounding_anchor = 0;

    zwp_input_method_context_v1_add_listener(id, &context_listener, NULL);
}

static void input_method_handle_deactivate(void *data,
                                           struct zwp_input_method_v1 *zwp_input_method_v1,
                                           struct zwp_input_method_context_v1 *context)
{
    (void)data;
    (void)zwp_input_method_v1;
    printf("[probe] deactivate event received for context %p\n", (void *)context);
    fflush(stdout);

    if (context) {
        zwp_input_method_context_v1_destroy(context);
    }

    if (g_app.ctx_state.context == context) {
        g_app.ctx_state.context = NULL;
        g_app.ctx_state.is_active = false;
        g_app.ctx_state.has_serial = false;
        g_app.ctx_state.has_surrounding = false;
        g_app.ctx_state.surrounding_cursor = 0;
        g_app.ctx_state.surrounding_anchor = 0;
    }
}

static const struct zwp_input_method_v1_listener input_method_listener = {
    .activate = input_method_handle_activate,
    .deactivate = input_method_handle_deactivate,
};

/* Registry listener */

static void registry_handle_global(void *data,
                                   struct wl_registry *registry,
                                   uint32_t name,
                                   const char *interface,
                                   uint32_t version)
{
    (void)data;
    if (strcmp(interface, zwp_input_method_v1_interface.name) == 0) {
        printf("[probe] Discovered %s v%u (id %u)\n", interface, version, name);
        fflush(stdout);
        g_app.input_method = wl_registry_bind(registry, name, &zwp_input_method_v1_interface, 1);
        zwp_input_method_v1_add_listener(g_app.input_method, &input_method_listener, NULL);
    }
}

static void registry_handle_global_remove(void *data,
                                          struct wl_registry *registry,
                                          uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

/* D-Bus methods */

static int method_commit(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
    (void)userdata;
    (void)ret_error;
    const char *text = NULL;
    int r = sd_bus_message_read(m, "s", &text);
    if (r < 0) {
        return sd_bus_reply_method_return(m, "bs", 0, "Invalid argument: string expected");
    }

    if (!g_app.ctx_state.is_active || !g_app.ctx_state.context) {
        printf("[probe] Rejecting Commit: no active input-method context\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No active input-method context");
    }

    if (!g_app.ctx_state.has_serial) {
        printf("[probe] Rejecting Commit: no serial received from compositor yet\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No serial received from compositor");
    }

    printf("[probe] Committing text (serial=%u, bytes=%zu)\n",
           g_app.ctx_state.serial, strlen(text));
    fflush(stdout);
    zwp_input_method_context_v1_commit_string(g_app.ctx_state.context,
                                              g_app.ctx_state.serial,
                                              text);
    wl_display_flush(g_app.display);

    char resp[128];
    snprintf(resp, sizeof(resp), "Committed %zu bytes at serial %u",
             strlen(text), g_app.ctx_state.serial);
    return sd_bus_reply_method_return(m, "bs", 1, resp);
}

static int method_replace_previous(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
    (void)userdata;
    (void)ret_error;
    uint32_t before_bytes = 0;
    const char *text = NULL;
    int r = sd_bus_message_read(m, "us", &before_bytes, &text);
    if (r < 0) {
        return sd_bus_reply_method_return(m, "bs", 0, "Invalid arguments: uint32 and string expected");
    }

    if (!g_app.ctx_state.is_active || !g_app.ctx_state.context) {
        printf("[probe] Rejecting ReplacePrevious: no active input-method context\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No active input-method context");
    }

    if (!g_app.ctx_state.has_serial) {
        printf("[probe] Rejecting ReplacePrevious: no serial received from compositor yet\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No serial received from compositor");
    }

    printf("[probe] Replacing previous %u bytes with text (serial=%u, new_bytes=%zu)\n",
           before_bytes, g_app.ctx_state.serial, strlen(text));
    fflush(stdout);

    int32_t delete_index = -(int32_t)before_bytes;
    zwp_input_method_context_v1_delete_surrounding_text(g_app.ctx_state.context,
                                                        delete_index,
                                                        before_bytes);
    zwp_input_method_context_v1_commit_string(g_app.ctx_state.context,
                                              g_app.ctx_state.serial,
                                              text);
    wl_display_flush(g_app.display);

    char resp[128];
    snprintf(resp, sizeof(resp), "Deleted %u bytes and committed %zu bytes at serial %u",
             before_bytes, strlen(text), g_app.ctx_state.serial);
    return sd_bus_reply_method_return(m, "bs", 1, resp);
}

static int method_commit_selection(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
    (void)userdata;
    (void)ret_error;
    const char *text = NULL;
    int r = sd_bus_message_read(m, "s", &text);
    if (r < 0) {
        return sd_bus_reply_method_return(m, "bs", 0, "Invalid argument: string expected");
    }

    if (!g_app.ctx_state.is_active || !g_app.ctx_state.context) {
        printf("[probe] Rejecting CommitSelection: no active input-method context\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No active input-method context");
    }

    if (!g_app.ctx_state.has_serial) {
        printf("[probe] Rejecting CommitSelection: no serial received from compositor yet\n");
        fflush(stdout);
        return sd_bus_reply_method_return(m, "bs", 0, "No serial received from compositor");
    }

    printf("[probe] Committing selection replacement text (serial=%u, bytes=%zu)\n",
           g_app.ctx_state.serial, strlen(text));
    fflush(stdout);
    zwp_input_method_context_v1_commit_string(g_app.ctx_state.context,
                                              g_app.ctx_state.serial,
                                              text);
    wl_display_flush(g_app.display);

    char resp[128];
    snprintf(resp, sizeof(resp), "Committed %zu bytes replacing selection at serial %u",
             strlen(text), g_app.ctx_state.serial);
    return sd_bus_reply_method_return(m, "bs", 1, resp);
}

static int method_get_status(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
    (void)userdata;
    (void)ret_error;
    bool has_sel = (g_app.ctx_state.surrounding_cursor != g_app.ctx_state.surrounding_anchor);
    return sd_bus_reply_method_return(m, "buuubuub",
                                      (int)g_app.ctx_state.is_active,
                                      g_app.ctx_state.serial,
                                      g_app.ctx_state.content_hint,
                                      g_app.ctx_state.content_purpose,
                                      (int)g_app.ctx_state.has_surrounding,
                                      g_app.ctx_state.surrounding_cursor,
                                      g_app.ctx_state.surrounding_anchor,
                                      (int)has_sel);
}

static int method_quit(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
    (void)userdata;
    (void)ret_error;
    printf("[probe] Quit request received via D-Bus\n");
    fflush(stdout);
    g_running = 0;
    return sd_bus_reply_method_return(m, "");
}

static const sd_bus_vtable probe_vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("Commit", "s", "bs", method_commit, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("ReplacePrevious", "us", "bs", method_replace_previous, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("CommitSelection", "s", "bs", method_commit_selection, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("GetStatus", "", "buuubuub", method_get_status, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("Quit", "", "", method_quit, SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_VTABLE_END
};

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    printf("[probe] Starting input-method-v1-probe...\n");
    fflush(stdout);

    g_app.display = wl_display_connect(NULL);
    if (!g_app.display) {
        fprintf(stderr, "[probe] Fatal: Cannot connect to Wayland display\n");
        return 1;
    }

    g_app.registry = wl_display_get_registry(g_app.display);
    wl_registry_add_listener(g_app.registry, &registry_listener, NULL);
    wl_display_roundtrip(g_app.display);

    if (!g_app.input_method) {
        fprintf(stderr, "[probe] Fatal: zwp_input_method_v1 not advertised by compositor\n");
        wl_registry_destroy(g_app.registry);
        wl_display_disconnect(g_app.display);
        return 2;
    }

    // Connect to user session bus
    int r = sd_bus_default_user(&g_app.bus);
    if (r < 0) {
        fprintf(stderr, "[probe] Fatal: Failed to connect to user session bus: %s\n", strerror(-r));
        zwp_input_method_v1_destroy(g_app.input_method);
        wl_registry_destroy(g_app.registry);
        wl_display_disconnect(g_app.display);
        return 3;
    }

    r = sd_bus_add_object_vtable(g_app.bus,
                                 NULL,
                                 "/org/archpad/InputMethodProbe",
                                 "org.archpad.InputMethodProbe",
                                 probe_vtable,
                                 NULL);
    if (r < 0) {
        fprintf(stderr, "[probe] Fatal: Failed to register D-Bus vtable: %s\n", strerror(-r));
        sd_bus_unref(g_app.bus);
        zwp_input_method_v1_destroy(g_app.input_method);
        wl_registry_destroy(g_app.registry);
        wl_display_disconnect(g_app.display);
        return 4;
    }

    r = sd_bus_request_name(g_app.bus, "org.archpad.InputMethodProbe", SD_BUS_NAME_REPLACE_EXISTING);
    if (r < 0) {
        fprintf(stderr, "[probe] Fatal: Failed to acquire service name 'org.archpad.InputMethodProbe': %s\n", strerror(-r));
        sd_bus_unref(g_app.bus);
        zwp_input_method_v1_destroy(g_app.input_method);
        wl_registry_destroy(g_app.registry);
        wl_display_disconnect(g_app.display);
        return 5;
    }

    printf("[probe] Initialized successfully. Bound zwp_input_method_v1 and acquired org.archpad.InputMethodProbe.\n");
    fflush(stdout);

    // Main event loop
    while (g_running) {
        while (wl_display_prepare_read(g_app.display) != 0) {
            wl_display_dispatch_pending(g_app.display);
        }
        wl_display_flush(g_app.display);

        r = sd_bus_process(g_app.bus, NULL);
        if (r < 0) {
            fprintf(stderr, "[probe] D-Bus processing error: %s\n", strerror(-r));
            wl_display_cancel_read(g_app.display);
            break;
        }
        if (r > 0) {
            // Further D-Bus requests pending; re-loop immediately
            wl_display_cancel_read(g_app.display);
            continue;
        }

        struct pollfd pfd[2];
        pfd[0].fd = wl_display_get_fd(g_app.display);
        pfd[0].events = POLLIN;
        pfd[0].revents = 0;

        pfd[1].fd = sd_bus_get_fd(g_app.bus);
        pfd[1].events = sd_bus_get_events(g_app.bus);
        pfd[1].revents = 0;

        uint64_t bus_timeout = UINT64_MAX;
        sd_bus_get_timeout(g_app.bus, &bus_timeout);

        int timeout_ms = -1;
        if (bus_timeout != UINT64_MAX) {
            struct timespec now;
            clock_gettime(CLOCK_MONOTONIC, &now);
            uint64_t now_us = (uint64_t)now.tv_sec * 1000000ULL + (uint64_t)now.tv_nsec / 1000ULL;
            if (bus_timeout <= now_us) {
                timeout_ms = 0;
            } else {
                uint64_t diff_ms = (bus_timeout - now_us + 999) / 1000;
                timeout_ms = (diff_ms > INT_MAX) ? INT_MAX : (int)diff_ms;
            }
        }

        int poll_ret = poll(pfd, 2, timeout_ms);
        if (poll_ret < 0) {
            wl_display_cancel_read(g_app.display);
            if (errno == EINTR) {
                continue;
            }
            fprintf(stderr, "[probe] poll error: %s\n", strerror(errno));
            break;
        }

        if (pfd[0].revents & POLLIN) {
            wl_display_read_events(g_app.display);
        } else {
            wl_display_cancel_read(g_app.display);
        }

        wl_display_dispatch_pending(g_app.display);

        if (pfd[1].revents) {
            while ((r = sd_bus_process(g_app.bus, NULL)) > 0);
        }
    }

    printf("[probe] Cleaning up and exiting...\n");
    fflush(stdout);

    if (g_app.ctx_state.context) {
        zwp_input_method_context_v1_destroy(g_app.ctx_state.context);
        g_app.ctx_state.context = NULL;
    }

    if (g_app.input_method) {
        zwp_input_method_v1_destroy(g_app.input_method);
        g_app.input_method = NULL;
    }

    if (g_app.registry) {
        wl_registry_destroy(g_app.registry);
        g_app.registry = NULL;
    }

    if (g_app.display) {
        wl_display_flush(g_app.display);
        wl_display_disconnect(g_app.display);
        g_app.display = NULL;
    }

    if (g_app.bus) {
        sd_bus_release_name(g_app.bus, "org.archpad.InputMethodProbe");
        sd_bus_unref(g_app.bus);
        g_app.bus = NULL;
    }

    printf("[probe] Shutdown complete.\n");
    fflush(stdout);
    return 0;
}
