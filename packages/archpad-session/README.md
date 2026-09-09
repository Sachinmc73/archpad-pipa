# archpad-session

This package owns ArchPad's compositor and graphical-login policy, not the
device kernel or hardware configuration. Version 0.2.0 provides the reversible
Phase 4B session foundation:

- Hyprland at the preferred panel mode and scale 2;
- 22-logical-pixel window rounding (the initial 3.5 mm estimate);
- touchpad/keyboard basics and three-finger workspace navigation;
- a Foot terminal at session start;
- session-bound polkit authentication;
- a dedicated systemd graphical-session service on TTY1;
- no third-party display manager, shell, OSK or rotation daemon yet.

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

Use `Super+Shift+E` for a normal Hyprland logout. The shell, OSK and rotation
daemon remain later, independently packaged layers.
