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
      profiles = config.my.host.network.vpnProfiles;

      # The embedded SSO browser needs GIO's separately packaged TLS backend.
      openconnectPlugin = pkgs.networkmanager-openconnect.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];
        postFixup = (old.postFixup or "") + ''
          wrapProgram "$out/libexec/nm-openconnect-auth-dialog" \
            --prefix GIO_EXTRA_MODULES : "${pkgs.glib-networking}/lib/gio/modules"
        '';
      });
    in
    {
      options.my.services.vpn.enable = lib.mkEnableOption "VPN support";

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
        ]
        ++ lib.mapAttrsToList (name: _: {
          assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9_.-]*" name != null;
          message = "VPN profile IDs must use letters, digits, dots, underscores or hyphens.";
        }) profiles;

        programs.nm-applet.enable = true;

        systemd.user.services.nm-applet = {
          environment.WEBKIT_DISABLE_DMABUF_RENDERER = "1";
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        networking.networkmanager = {
          plugins = [
            openconnectPlugin
            pkgs.networkmanager-openvpn
          ];

          # OpenConnect requests an MTU. Enforce the actual tunnel MTU as well.
          dispatcherScripts = lib.mapAttrsToList (name: profile: {
            type = "pre-up";
            source = pkgs.writeShellScript "vpn-mtu-${name}" (
              lib.replaceStrings
                [ "@profileFile@" "@mtu@" "@ip@" ]
                [
                  (lib.escapeShellArg "${name}.nmconnection")
                  (toString profile.mtu)
                  (lib.escapeShellArg "${pkgs.iproute2}/bin/ip")
                ]
                (builtins.readFile ./vpn/mtu.sh)
            );
          }) (lib.filterAttrs (_: profile: profile.mtu != null) profiles);

          ensureProfiles.profiles = lib.mapAttrs (name: profile: {
            connection = {
              id = name;
              type = "vpn";
              autoconnect = false;
              permissions = "";

              dns-over-tls = 0;
              dnssec = 0;
            };

            vpn = {
              service-type = "org.freedesktop.NetworkManager.openconnect";
              inherit (profile) gateway protocol;

              # These are short-lived authentication results, never saved secrets.
              cookie-flags = "2";
              gateway-flags = "2";
              gwcert-flags = "2";
              resolve-flags = "2";
            }
            // lib.optionalAttrs (profile.userAgent != null) {
              useragent = profile.userAgent;
            }
            // lib.optionalAttrs (profile.mtu != null) {
              # Request this MTU during negotiation.
              mtu = toString profile.mtu;
            };

            ipv4 = {
              method = "auto";
              dns-search = lib.concatStringsSep ";" profile.dnsSearch;
            };

            ipv6.method = "auto";
            vpn-secrets = {
              # Prefer the configured URL over a previously selected VPN host.
              lasthost = profile.gateway;
            }
            // lib.optionalAttrs (profile.authGroup != null) {
              "form:main:group_list" = profile.authGroup;
            };
          }) profiles;
        };

        environment.systemPackages = [ pkgs.openconnect ];
      };
    };
}
