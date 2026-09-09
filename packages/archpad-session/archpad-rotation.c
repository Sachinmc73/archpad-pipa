#include <gio/gio.h>
#include <glib-unix.h>
#include <stdlib.h>
#include <string.h>

struct rotation_state {
    GMainLoop *loop;
    GDBusProxy *proxy;
    char *last_orientation;
};

static int orientation_transform(const char *orientation)
{
    if (g_strcmp0(orientation, "normal") == 0)
        return 0;
    if (g_strcmp0(orientation, "left-up") == 0)
        return 1;
    if (g_strcmp0(orientation, "bottom-up") == 0)
        return 2;
    if (g_strcmp0(orientation, "right-up") == 0)
        return 3;
    return -1;
}

static void apply_orientation(struct rotation_state *state,
                              const char *orientation)
{
    const char *output = g_getenv("ARCHPAD_OUTPUT");
    int transform = orientation_transform(orientation);
    g_autofree char *code = NULL;
    g_autofree char *standard_output = NULL;
    g_autofree char *standard_error = NULL;
    g_autoptr(GError) error = NULL;
    int wait_status = 0;
    char *argv[7];

    if (transform < 0 || g_strcmp0(state->last_orientation, orientation) == 0)
        return;

    if (output == NULL || output[0] == '\0')
        output = "DSI-1";

    code = g_strdup_printf(
        "hl.monitor({ output = \"%s\", mode = \"preferred\", "
        "position = \"auto\", scale = 2, transform = %d }); "
        "hl.config({ input = { "
        "touchdevice = { transform = %d, output = \"%s\" }, "
        "tablet = { transform = %d, output = \"%s\" } } })",
        output, transform, transform, output, transform, output);

    argv[0] = "hyprctl";
    argv[1] = "-i";
    argv[2] = "0";
    argv[3] = "eval";
    argv[4] = code;
    argv[5] = NULL;

    if (!g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL,
                      &standard_output, &standard_error, &wait_status, &error)) {
        g_warning("failed to execute hyprctl: %s", error->message);
        return;
    }

    if (!g_spawn_check_wait_status(wait_status, &error)) {
        g_warning("hyprctl rejected orientation %s: %s%s%s%s%s",
                  orientation, error->message,
                  standard_output != NULL ? ": " : "",
                  standard_output != NULL ? standard_output : "",
                  standard_error != NULL ? ": " : "",
                  standard_error != NULL ? standard_error : "");
        return;
    }

    g_free(state->last_orientation);
    state->last_orientation = g_strdup(orientation);
    g_message("orientation %s applied as transform %d", orientation, transform);
}

static void on_properties_changed(GDBusProxy *proxy,
                                  GVariant *changed_properties,
                                  const char *const *invalidated_properties,
                                  gpointer user_data)
{
    struct rotation_state *state = user_data;
    const char *orientation = NULL;

    (void)proxy;
    (void)invalidated_properties;

    if (g_variant_lookup(changed_properties, "AccelerometerOrientation", "&s",
                         &orientation))
        apply_orientation(state, orientation);
}

static gboolean stop_main_loop(gpointer user_data)
{
    struct rotation_state *state = user_data;

    g_main_loop_quit(state->loop);
    return G_SOURCE_REMOVE;
}

int main(void)
{
    struct rotation_state state = {0};
    g_autoptr(GDBusConnection) bus = NULL;
    g_autoptr(GVariant) reply = NULL;
    g_autoptr(GVariant) initial = NULL;
    g_autoptr(GError) error = NULL;
    const char *orientation = NULL;

    bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (bus == NULL) {
        g_printerr("archpad-rotation: system bus: %s\n", error->message);
        return EXIT_FAILURE;
    }

    state.proxy = g_dbus_proxy_new_sync(
        bus, G_DBUS_PROXY_FLAGS_NONE, NULL, "net.hadess.SensorProxy",
        "/net/hadess/SensorProxy", "net.hadess.SensorProxy", NULL, &error);
    if (state.proxy == NULL) {
        g_printerr("archpad-rotation: sensor proxy: %s\n", error->message);
        return EXIT_FAILURE;
    }

    g_signal_connect(state.proxy, "g-properties-changed",
                     G_CALLBACK(on_properties_changed), &state);

    reply = g_dbus_proxy_call_sync(state.proxy, "ClaimAccelerometer", NULL,
                                   G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &error);
    if (reply == NULL) {
        g_printerr("archpad-rotation: claim accelerometer: %s\n", error->message);
        g_object_unref(state.proxy);
        return EXIT_FAILURE;
    }

    initial = g_dbus_proxy_get_cached_property(state.proxy,
                                                "AccelerometerOrientation");
    if (initial != NULL) {
        orientation = g_variant_get_string(initial, NULL);
        apply_orientation(&state, orientation);
    }

    state.loop = g_main_loop_new(NULL, FALSE);
    g_unix_signal_add(SIGTERM, stop_main_loop, &state);
    g_unix_signal_add(SIGINT, stop_main_loop, &state);
    g_main_loop_run(state.loop);

    g_dbus_proxy_call_sync(state.proxy, "ReleaseAccelerometer", NULL,
                           G_DBUS_CALL_FLAGS_NONE, 2000, NULL, NULL);
    g_main_loop_unref(state.loop);
    g_object_unref(state.proxy);
    g_free(state.last_orientation);
    return EXIT_SUCCESS;
}
