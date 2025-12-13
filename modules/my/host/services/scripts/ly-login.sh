#!/usr/bin/env bash
set -eu
cmd="$*"

case "$cmd" in
*uwsm*)
  systemctl --user stop \
    graphical-session.target \
    graphical-session-pre.target \
    xdg-desktop-autostart.target \
    2>/dev/null || true

  systemctl --user stop 'wayland-wm@*.service' 2>/dev/null || true
  systemctl --user reset-failed 2>/dev/null || true
  ;;
esac
exec "$@"
