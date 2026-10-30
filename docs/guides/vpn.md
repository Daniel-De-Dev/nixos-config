# OpenConnect VPN

`my.services.vpn.enable` installs the NetworkManager VPN plugins and starts
`nm-applet` with the graphical session. The applet provides OpenConnect's
interactive authentication dialog, including browser login and MFA. In Hyprland,
the UWSM session supplies its Wayland environment to the user service.

## Private Profile Data

Gateways, login paths, connection IDs and internal DNS domains belong in the
private `data.nix` input. Add `network.vpnProfiles` to a selected private profile
or an existing host entry. For example, inside `hosts.box-01`:

```nix
network.vpnProfiles.example-vpn = {
  gateway = "vpn.example.invalid/private";
  protocol = "anyconnect";
  authGroup = "private";
  userAgent = "AnyConnect";
  mtu = 1200;
  dnsSearch = [ "~example.invalid" ];
};
```

The attribute name is also the connection ID. Use a name without spaces, such as
`example-vpn`. `protocol` defaults to `anyconnect`, `userAgent`, `mtu` and
`dnsSearch` can be omitted unless the gateway requires them. Selected private
profiles and host overrides use the existing
[data precedence](privacy.md#data-mapping-and-overrides).

`authGroup` is optional and selects a group in the AnyConnect main login form.
The URL path and the form's Group selection are separate. Use the server's exact
group value.

After changing private data, update the private input and rebuild.

Keep passwords, MFA codes and session cookies out of `data.nix`. Private input
data still enters the local Nix store. It is private from public source control,
not a secret-storage mechanism.
