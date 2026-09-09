-- ArchPad Phase 4B compositor proof configuration.
-- Keep this intentionally small until display, input and recovery are proven.

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 2,
})

hl.env("XCURSOR_SIZE", "48")
hl.env("HYPRCURSOR_SIZE", "48")

hl.config({
    general = {
        gaps_in        = 0,
        gaps_out       = 0,
        border_size    = 0,
        resize_on_border = true,
        allow_tearing  = false,
        layout         = "dwindle",
    },

    decoration = {
        rounding       = 22,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = false,
    },

    dwindle = {
        preserve_split = true,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- foot"))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprshutdown"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i,
        hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),
    { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(),
    { mouse = true })

hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true, repeating = true })

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- foot")
end)
