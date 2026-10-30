# Applied through NetworkManager's pre-up dispatcher directory.
[ "${2-}" = "vpn-pre-up" ] || exit 0

# Match the declarative file, including systems where /var/run points to /run.
# A duplicate profile with the same display name must not select this policy.
case "${CONNECTION_FILENAME-}" in
/run/NetworkManager/system-connections/@profileFile@ | /var/run/NetworkManager/system-connections/@profileFile@) ;;
*) exit 0 ;;
esac

if [ -z "${VPN_IP_IFACE-}" ]; then
  printf '%s\n' 'VPN MTU hook: VPN_IP_IFACE is missing' >&2
  exit 1
fi

exec @ip@ link set dev "$VPN_IP_IFACE" mtu @mtu@
