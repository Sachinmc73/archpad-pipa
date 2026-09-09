# archpad-session

This package owns ArchPad's compositor policy, not the device kernel or
hardware configuration. Version 0.1.0 is deliberately limited to the reversible
Phase 4B proof:

- Hyprland at the preferred panel mode and scale 2;
- 22-logical-pixel window rounding (the initial 3.5 mm estimate);
- touchpad/keyboard basics and three-finger workspace navigation;
- a Foot terminal at session start;
- session-bound polkit authentication;
- no display manager, graphical boot target, shell, OSK or rotation daemon.

Log in as `archpad` on TTY1 and run `archpad-session`. Use
`Super+Shift+E` for the normal Hyprland logout UI. If the compositor fails,
switch to another TTY or use SSH; `multi-user.target` remains the boot default.
