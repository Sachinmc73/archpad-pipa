#include <gio/gio.h>
#include <glib-unix.h>
#include <stdlib.h>
#include <string.h>

struct rotation_state {
    GMainLoop *loop;
    GDBusConnection *bus;
    GDBusProxy *proxy;
    gboolean claimed;
    guint discovery_check_id;
    char *last_orientation;
};

static void claim_accelerometer(struct rotation_state *state);

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
    gboolean has_accelerometer = FALSE;

    (void)proxy;
    (void)invalidated_properties;

    if (g_variant_lookup(changed_properties, "AccelerometerOrientation", "&s",
                         &orientation))
        apply_orientation(state, orientation);

    if (g_variant_lookup(changed_properties, "HasAccelerometer", "b",
                         &has_accelerometer) && has_accelerometer)
        claim_accelerometer(state);
}

static gboolean stop_main_loop(gpointer user_data)
{
    struct rotation_state *state = user_data;

    g_main_loop_quit(state->loop);
    return G_SOURCE_REMOVE;
}

static void release_proxy(struct rotation_state *state)
{
    if (state->discovery_check_id != 0) {
        g_source_remove(state->discovery_check_id);
        state->discovery_check_id = 0;
    }

    if (state->proxy == NULL)
        return;

    if (state->claimed)
        g_dbus_proxy_call_sync(state->proxy, "ReleaseAccelerometer", NULL,
                               G_DBUS_CALL_FLAGS_NONE, 2000, NULL, NULL);
    state->claimed = FALSE;
    g_clear_object(&state->proxy);
    g_clear_pointer(&state->last_orientation, g_free);
}

static void claim_accelerometer(struct rotation_state *state)
{
    g_autoptr(GVariant) reply = NULL;
    g_autoptr(GVariant) initial = NULL;
    g_autoptr(GError) error = NULL;
    const char *orientation = NULL;

    if (state->proxy == NULL || state->claimed)
        return;

    reply = g_dbus_proxy_call_sync(state->proxy, "ClaimAccelerometer", NULL,
                                   G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &error);
    if (reply == NULL) {
        g_warning("could not claim accelerometer: %s", error->message);
        return;
    }

    state->claimed = TRUE;
    initial = g_dbus_proxy_get_cached_property(state->proxy,
                                                "AccelerometerOrientation");
    if (initial != NULL) {
        orientation = g_variant_get_string(initial, NULL);
        apply_orientation(state, orientation);
    }
    g_message("accelerometer claimed");
}

static gboolean check_accelerometer_discovery(gpointer user_data)
{
    struct rotation_state *state = user_data;
    g_autoptr(GVariant) reply = NULL;
    g_autoptr(GVariant) value = NULL;
    g_autoptr(GError) error = NULL;

    if (state->proxy == NULL || state->claimed) {
        state->discovery_check_id = 0;
        return G_SOURCE_REMOVE;
    }

    reply = g_dbus_connection_call_sync(
        state->bus, "net.hadess.SensorProxy", "/net/hadess/SensorProxy",
        "org.freedesktop.DBus.Properties", "Get",
        g_variant_new("(ss)", "net.hadess.SensorProxy", "HasAccelerometer"),
        G_VARIANT_TYPE("(v)"), G_DBUS_CALL_FLAGS_NONE, 2000, NULL, &error);
    if (reply == NULL)
        return G_SOURCE_CONTINUE;

    g_variant_get(reply, "(v)", &value);
    if (g_variant_get_boolean(value)) {
        claim_accelerometer(state);
        if (state->claimed) {
            state->discovery_check_id = 0;
            return G_SOURCE_REMOVE;
        }
    }

    return G_SOURCE_CONTINUE;
}

static void on_sensor_proxy_appeared(GDBusConnection *connection,
                                     const char *name,
                                     const char *name_owner,
                                     gpointer user_data)
{
    struct rotation_state *state = user_data;
    g_autoptr(GVariant) has_accelerometer_value = NULL;
    g_autoptr(GError) error = NULL;
    gboolean has_accelerometer = FALSE;

    (void)connection;
    (void)name;
    (void)name_owner;

    release_proxy(state);
    state->proxy = g_dbus_proxy_new_sync(
        state->bus, G_DBUS_PROXY_FLAGS_NONE, NULL, "net.hadess.SensorProxy",
        "/net/hadess/SensorProxy", "net.hadess.SensorProxy", NULL, &error);
    if (state->proxy == NULL) {
        g_warning("could not connect to sensor proxy: %s", error->message);
        return;
    }

    g_signal_connect(state->proxy, "g-properties-changed",
                     G_CALLBACK(on_properties_changed), state);
    has_accelerometer_value = g_dbus_proxy_get_cached_property(
        state->proxy, "HasAccelerometer");
    if (has_accelerometer_value != NULL)
        has_accelerometer = g_variant_get_boolean(has_accelerometer_value);

    if (has_accelerometer)
        claim_accelerometer(state);
    else {
        g_message("sensor proxy connected; waiting for accelerometer discovery");
        state->discovery_check_id = g_timeout_add(
            250, check_accelerometer_discovery, state);
    }
}

static void on_sensor_proxy_vanished(GDBusConnection *connection,
                                     const char *name,
                                     gpointer user_data)
{
    struct rotation_state *state = user_data;

    (void)connection;
    (void)name;
    release_proxy(state);
    g_message("waiting for sensor proxy");
}

int main(void)
{
    struct rotation_state state = {0};
    g_autoptr(GDBusConnection) bus = NULL;
    g_autoptr(GError) error = NULL;
    guint watch_id;

    bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &error);
    if (bus == NULL) {
        g_printerr("archpad-rotation: system bus: %s\n", error->message);
        return EXIT_FAILURE;
    }

    state.bus = bus;
    state.loop = g_main_loop_new(NULL, FALSE);
    watch_id = g_bus_watch_name_on_connection(
        bus, "net.hadess.SensorProxy", G_BUS_NAME_WATCHER_FLAGS_NONE,
        on_sensor_proxy_appeared, on_sensor_proxy_vanished, &state, NULL);
    g_unix_signal_add(SIGTERM, stop_main_loop, &state);
    g_unix_signal_add(SIGINT, stop_main_loop, &state);
    g_main_loop_run(state.loop);

    g_bus_unwatch_name(watch_id);
    release_proxy(&state);
    g_main_loop_unref(state.loop);
    return EXIT_SUCCESS;
}
