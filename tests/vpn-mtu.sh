set -eu

template=$1
bash_path=$2
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
export MTU_LOG="$temporary/ip-call"

printf '#!%s\n' "$bash_path" >"$temporary/ip"
cat >>"$temporary/ip" <<'EOF'
printf '%s\n' "$@" > "$MTU_LOG"
exit "${MTU_FAIL:-0}"
EOF
chmod +x "$temporary/ip"

sed -e "s|@profileFile@|'example-vpn.nmconnection'|g" \
  -e 's|@mtu@|1200|g' \
  -e "s|@ip@|'$temporary/ip'|g" \
  "$template" >"$temporary/hook"

run_hook() {
  env CONNECTION_ID=example-vpn CONNECTION_FILENAME="$1" \
    VPN_IP_IFACE="$2" DEVICE_IP_IFACE=wlan0 \
    MTU_FAIL="${MTU_FAIL:-0}" \
    "$bash_path" "$temporary/hook" wlan0 "${3:-vpn-pre-up}"
}

# Both runtime path spellings work, and the tunnel can have any interface name.
for root in /run /var/run; do
  rm -f "$MTU_LOG"
  run_hook "$root/NetworkManager/system-connections/example-vpn.nmconnection" tun7
  printf '%s\n' link set dev tun7 mtu 1200 >"$temporary/expected"
  cmp "$temporary/expected" "$MTU_LOG"
done

# Same display name is insufficient: other, copied and persistent files are ignored.
for filename in \
  /run/NetworkManager/system-connections/other-vpn.nmconnection \
  /run/NetworkManager/system-connections/example-vpn-11111111-2222-3333-4444-555555555555.nmconnection \
  /etc/NetworkManager/system-connections/example-vpn.nmconnection \
  ''; do
  rm -f "$MTU_LOG"
  run_hook "$filename" tun7
  test ! -e "$MTU_LOG"
done

managed=/run/NetworkManager/system-connections/example-vpn.nmconnection
for action in pre-up up vpn-up vpn-down; do
  rm -f "$MTU_LOG"
  run_hook "$managed" tun7 "$action"
  test ! -e "$MTU_LOG"
done

# A missing tunnel must never fall back to changing the parent interface.
if run_hook "$managed" '' 2>"$temporary/error"; then
  exit 1
fi
test ! -e "$MTU_LOG"

# Surface failures from ip so they can be diagnosed in the dispatcher journal.
if MTU_FAIL=19 run_hook "$managed" tun7; then
  exit 1
else
  test "$?" -eq 19
fi

printf '%s\n' 'VPN MTU hook: 12 cases passed'
