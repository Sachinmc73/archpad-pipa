# archpad-shell

Version 0.1.0 is the first visible, independently packaged ArchPad shell slice.
It intentionally contains only:

- a 68-logical-pixel top bar with a minute-resolution clock;
- four live Hyprland workspace buttons;
- a centered, touch-sized bottom dock;
- a working Foot launcher;
- honest placeholder feedback for the future app drawer and Overview;
- a visible confirmation that USB SSH is the current recovery path.

The shell runs as a systemd user service attached to UWSM's
`graphical-session.target`. It does not own the compositor, kernel, hardware
configuration or user customisations.

This version reserves the top and bottom panel regions continuously. Dock
auto-hide, app discovery, Overview, status services, quick settings, gestures,
window controls and OSK integration are deliberately deferred to subsequent
testable releases.
