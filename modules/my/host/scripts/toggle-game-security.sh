#!/usr/bin/env bash
set -euo pipefail

is_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Run as root (use sudo)." >&2
    exit 1
  fi
}

get_proc_opts() {
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -nro OPTIONS -T /proc
    return 0
  fi

  echo "findmnt is not installed on system, failed toggle"
  exit 1
}

strip_hidepid() {
  # remove hidepid=<anything>
  echo "$1" | sed -E '
    s/(^|,)hidepid=[^,]+(,|$)/\1/g;
    s/,,+/,/g;
    s/^,|,$//g
  '
}

current_mode() {
  local opts val
  opts="$(get_proc_opts)"
  if [[ $opts =~ (^|,)hidepid=([^,]+) ]]; then
    val="${BASH_REMATCH[2]}"
    case "$val" in
    0 | off) echo "open" ;;
    *) echo "restricted" ;;
    esac
  else
    echo "open"
  fi
}

apply_hidepid() {
  local new="$1" opts base
  opts="$(get_proc_opts)"
  base="$(strip_hidepid "$opts")"

  if [[ -n $base ]]; then
    mount -t proc -o "remount,${base},hidepid=${new}" proc /proc
  else
    mount -t proc -o "remount,hidepid=${new}" proc /proc
  fi
  echo "Mode: $(current_mode)"
}

toggle() {
  if [[ "$(current_mode)" == "open" ]]; then
    echo "Switching to RESTRICTED (hidepid=2)"
    apply_hidepid 2
  else
    echo "Switching to OPEN (hidepid=0)"
    apply_hidepid 0
  fi
}

status() {
  echo "Current /proc options: $(get_proc_opts)"
  echo "Mode: $(current_mode)"
}

main() {
  is_root
  case "${1:-toggle}" in
  toggle) toggle ;;
  on) apply_hidepid 2 ;;
  off) apply_hidepid 0 ;;
  status) status ;;
  *)
    echo "Usage: $0 [toggle|status|on|off]" >&2
    exit 2
    ;;
  esac
}

main "$@"
