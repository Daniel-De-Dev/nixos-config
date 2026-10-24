preview_mod=SUPER
case "${1:-}" in
--help | -h)
  cat <<'HELP'
Usage: nix run .#hyprland [-- --mod SUPER|ALT]
Requires an existing Wayland session on NixOS.
Starts an empty desktop using the shared Hyprland configuration.
The preview modifier+CTRL+SHIFT+Escape closes the preview.
--print-config prints the generated Lua path.
HELP
  exit 0
  ;;
--print-config)
  printf '%s\n' '@config@'
  exit 0
  ;;
--mod)
  if [[ ${2:-} != SUPER && ${2:-} != ALT ]]; then
    echo 'Expected --mod SUPER or --mod ALT.' >&2
    exit 2
  fi
  preview_mod=$2
  shift 2
  ;;
esac
if [[ $# -ne 0 ]]; then
  echo 'Unsupported argument; use --help.' >&2
  exit 2
fi
if [[ -z ${WAYLAND_DISPLAY:-} || -z ${XDG_RUNTIME_DIR:-} ]]; then
  echo 'Run this preview from an existing Wayland session on NixOS.' >&2
  exit 1
fi
parent_display=$WAYLAND_DISPLAY
if [[ $parent_display != /* ]]; then
  parent_display="$XDG_RUNTIME_DIR/$parent_display"
fi
if [[ ! -S $parent_display ]]; then
  printf 'Cannot find the parent Wayland socket: %s\n' "$parent_display" >&2
  exit 1
fi

# Keep IPC paths short. The user scope owns all preview processes, even those
# that detach into another process group (applications launched by Hyprland).
preview_dir=$(mktemp -d "$XDG_RUNTIME_DIR/hp.XXXXXX")
preview_scope="hyprland-preview-${preview_dir##*/}.scope"
cleanup() {
  systemctl --user stop "$preview_scope" >/dev/null 2>&1 || true
  rm -rf -- "$preview_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
mkdir -p "$preview_dir/home/.config" "$preview_dir/home/.local/share"
printf '%s\n' com.mitchellh.ghostty.desktop >"$preview_dir/home/.config/xdg-terminals.list"
echo 'Opening Hyprland preview. Close its window or use the preview exit shortcut.'
systemd-run --user --scope --quiet --collect --expand-environment=no --unit="$preview_scope" \
  env -u DISPLAY -u XAUTHORITY -u HYPRLAND_INSTANCE_SIGNATURE -u HYPRLAND_CMD \
  -u WAYLAND_SOCKET -u UWSM_ID -u UWSM_FINALIZE_VARNAMES \
  -u DBUS_SESSION_BUS_ADDRESS -u DBUS_SESSION_BUS_PID -u DBUS_STARTER_ADDRESS -u DBUS_STARTER_BUS_TYPE \
  -u XDG_SESSION_ID -u XDG_SEAT -u XDG_VTNR \
  HOME="$preview_dir/home" SHELL='@bash@' XDG_RUNTIME_DIR="$preview_dir" \
  XDG_CONFIG_HOME="$preview_dir/home/.config" XDG_CONFIG_DIRS="$preview_dir/home/.config" \
  XDG_DATA_HOME="$preview_dir/home/.local/share" \
  XDG_STATE_HOME="$preview_dir/home/.local/state" XDG_CACHE_HOME="$preview_dir/home/.cache" \
  WAYLAND_DISPLAY="$parent_display" NIXOS_HYPRLAND_MOD="$preview_mod" \
  XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland \
  HYPRLAND_NO_SD_VARS=1 AGS_SHELL_LAUNCH_MODE=direct GSETTINGS_BACKEND=memory \
  LIBSEAT_BACKEND=seatd SEATD_SOCK="$preview_dir/no-seatd.sock" \
  '@dbusRunSession@' -- '@startHyprland@' --no-nixgl --path '@hyprland@' -- -c '@config@'
