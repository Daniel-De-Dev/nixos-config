{
  lib,
  nixosSystem,
  modules,
}:
let
  evaluate =
    extra:
    (nixosSystem {
      system = "x86_64-linux";
      modules = [
        modules.core-identity
        modules.services-vpn
        {
          boot.isContainer = true;
          system.stateVersion = "26.11";
          networking.networkmanager.enable = true;
          networking.useHostResolvConf = false;
          services.resolved.enable = true;
          my.services.vpn.enable = true;
        }
        extra
      ];
    }).config;

  configured = evaluate {
    my.host.network.vpnProfiles.example-vpn = {
      gateway = "vpn.example.invalid/private";
      authGroup = "private";
      userAgent = "AnyConnect";
      mtu = 1200;
      dnsSearch = [ "~example.invalid" ];
    };
  };
  profile =
    configured.networking.networkmanager.ensureProfiles.profiles.example-vpn;
  minimal = evaluate {
    my.host.network.vpnProfiles.other-vpn.gateway = "other.example.invalid";
  };
  disabled = evaluate {
    my.services.vpn.enable = lib.mkForce false;
    my.host.network.vpnProfiles.example-vpn.gateway = "vpn.example.invalid";
  };
in
lib.runTests {
  testValidConfiguration = {
    expr = lib.all (entry: entry.assertion) configured.assertions;
    expected = true;
  };

  testSystemWideProfileWithTransientSecrets = {
    expr = {
      inherit (profile.connection) id permissions autoconnect;
      inherit (profile.vpn)
        cookie-flags
        gateway-flags
        gwcert-flags
        resolve-flags
        ;
    };
    expected = {
      id = "example-vpn";
      permissions = "";
      autoconnect = false;
      cookie-flags = "2";
      gateway-flags = "2";
      gwcert-flags = "2";
      resolve-flags = "2";
    };
  };

  testTunnelMtuIsRequestedAndEnforced = {
    expr = {
      inherit (profile.vpn)
        gateway
        protocol
        useragent
        mtu
        ;
      dnsSearch = profile.ipv4.dns-search;
      dispatcherTypes = lib.catAttrs "type" configured.networking.networkmanager.dispatcherScripts;
    };
    expected = {
      gateway = "vpn.example.invalid/private";
      protocol = "anyconnect";
      useragent = "AnyConnect";
      mtu = "1200";
      dnsSearch = "~example.invalid";
      dispatcherTypes = [ "pre-up" ];
    };
  };

  testAppletStartsWithGraphicalSession = {
    expr = {
      enabled = configured.programs.nm-applet.enable;
      environment =
        configured.systemd.user.services.nm-applet.environment.WEBKIT_DISABLE_DMABUF_RENDERER;
      session = builtins.elem "graphical-session.target" configured.systemd.user.services.nm-applet.wantedBy;
      restart = configured.systemd.user.services.nm-applet.serviceConfig.Restart;
    };
    expected = {
      enabled = true;
      environment = "1";
      session = true;
      restart = "on-failure";
    };
  };

  testLoginGroupUsesPluginFormAnswer = {
    expr = {
      host = profile.vpn-secrets.lasthost;
      selection = profile.vpn-secrets."form:main:group_list";
      unsupportedDataKey = profile.vpn ? authgroup;
      unconfigured =
        minimal.networking.networkmanager.ensureProfiles.profiles.other-vpn.vpn-secrets
          ? "form:main:group_list";
    };
    expected = {
      host = "vpn.example.invalid/private";
      selection = "private";
      unsupportedDataKey = false;
      unconfigured = false;
    };
  };

  testOptionalGatewaySettingsAreOmitted = {
    expr =
      let
        vpn = minimal.networking.networkmanager.ensureProfiles.profiles.other-vpn.vpn;
      in
      {
        mtu = vpn ? mtu;
        useragent = vpn ? useragent;
        dispatcherScripts = minimal.networking.networkmanager.dispatcherScripts;
      };
    expected = {
      mtu = false;
      useragent = false;
      dispatcherScripts = [ ];
    };
  };

  testDisabledModuleDoesNotCreateProfilesOrApplet = {
    expr = {
      profiles = disabled.networking.networkmanager.ensureProfiles.profiles;
      applet = disabled.programs.nm-applet.enable;
      dispatcherScripts = disabled.networking.networkmanager.dispatcherScripts;
    };
    expected = {
      profiles = { };
      applet = false;
      dispatcherScripts = [ ];
    };
  };

  testProfileIdWithSpacesIsRejected = {
    expr =
      lib.all (entry: entry.assertion)
        (evaluate {
          my.host.network.vpnProfiles."invalid name".gateway = "vpn.example.invalid";
        }).assertions;
    expected = false;
  };
}
