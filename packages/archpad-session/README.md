# archpad-session

This package owns ArchPad's compositor and graphical-login policy, not the
device kernel or hardware configuration. Version 0.3.0 provides the reversible
Phase 4B/4C session foundation:

- Hyprland at the preferred panel mode and scale 2;
- 22-logical-pixel window rounding (the initial 3.5 mm estimate);
- touchpad/keyboard basics and three-finger workspace navigation;
- a Foot terminal available from the dock and `Super+Return`, without forcing
  an application open at login;
- session-bound polkit authentication;
- a dedicated systemd graphical-session service on TTY1;
- a safe interim systemd-logind vendor policy that ignores the power key until
  the PAM-backed lock/suspend path and shell-owned long-press menu are installed;
- direct D-Bus accelerometer monitoring with synchronized display, touch and
  pen transforms, including clean waiting for hardware discovery and across
  SensorProxy restarts;
- no third-party display manager; the shell and OSK remain separate packages.

`archpad-graphical-session.service` starts `archpad-session` as the unprivileged
`archpad` user through PAM, providing a normal logind session. It deliberately
conflicts with only `getty@tty1.service`; USB networking and SSH remain
independent recovery paths. The service restarts after logout because the
tablet currently has no graphical greeter.

Recovery over USB SSH:

```sh
systemctl disable --now archpad-graphical-session.service
systemctl set-default multi-user.target
systemctl start getty@tty1.service
```

Use `Super+Shift+E` for a normal Hyprland logout. The shell and OSK remain
independently packaged layers; a user-facing rotation lock will be added with
the quick-settings control.
