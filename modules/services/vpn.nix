# Purpose: VPN client support and managed VPN profiles.
# Scope: NetworkManager VPN integration.
_: {
  flake.nixosModules.services-vpn =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.services.vpn;
      operator = config.my.operator.username;
    in
    {
      options.my.services.vpn = {
        enable = lib.mkEnableOption "VPN support";

        uit.enable = lib.mkEnableOption "UiT VPN";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.networking.networkmanager.enable;
            message = "my.services.vpn requires NetworkManager.";
          }
          {
            assertion = config.services.resolved.enable;
            message = "my.services.vpn requires systemd-resolved.";
          }
        ];

        networking.networkmanager = {
          plugins = [
            pkgs.networkmanager-openconnect
            pkgs.networkmanager-openvpn
          ];

          dispatcherScripts = lib.optionals cfg.uit.enable [
            {
              source = pkgs.writeShellScript "uit-vpn-mtu" ''
                if [ "$2" = "vpn-pre-up" ] && [ "$CONNECTION_ID" = "UiT VPN" ]; then
                  ${lib.getExe' pkgs.iproute2 "ip"} link set dev "$1" mtu 1200
                fi
              '';

              type = "pre-up";
            }
          ];

          ensureProfiles.profiles = lib.mkIf cfg.uit.enable {
            uit-vpn = {
              connection = {
                id = "UiT VPN";
                type = "vpn";
                autoconnect = false;
                permissions = "user:${operator}:;";

                dns-over-tls = 0;
                dnssec = 0;
              };

              vpn = {
                service-type = "org.freedesktop.NetworkManager.openconnect";

                gateway = "vpn.uit.no/employee";
                protocol = "anyconnect";
                useragent = "AnyConnect";

                mtu = "1200";
              };

              ipv4 = {
                method = "auto";
                dns-search = "~uit.no";
              };

              ipv6.method = "auto";
            };
          };
        };

        environment.systemPackages = [ pkgs.openconnect ];
      };
    };
}
