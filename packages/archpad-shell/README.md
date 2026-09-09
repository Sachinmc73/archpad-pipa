# archpad-shell

Version 0.2.0 is the first desktop-shaped, independently packaged ArchPad shell
slice. It contains:
It intentionally contains only:

- a lightweight full-screen background layer suitable for a future selectable
  wallpaper;
- a compact 38-logical-pixel top bar with a minute-resolution clock;
- four live Hyprland workspace buttons;
- a centered, touch-sized bottom dock whose narrow layer surface overlays the
  desktop and reserves no application space;
- a first quick-settings panel opened from the top-right status capsule, with
  live battery state, kernel backlight control, native PipeWire volume/mute,
  iwd Wi-Fi power and native BlueZ Bluetooth power;
- a working Foot launcher;
- honest placeholder feedback for the future app drawer and Overview;
- a visible confirmation that USB SSH is the current recovery path.

The shell runs as a systemd user service attached to UWSM's
`graphical-session.target`. It does not own the compositor, kernel, hardware
configuration or user customisations.

This version reserves only the compact top bar. Rotation lock and the Settings,
Lock and Power actions remain visibly unavailable until their proper backends
are packaged. Dock auto-hide, selectable wallpapers, desktop shortcuts/widgets,
app discovery, Overview, gestures, window controls and OSK integration are
deliberately deferred to subsequent testable releases.
