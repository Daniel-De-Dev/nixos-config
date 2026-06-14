{ ... }: {
  flake.nixosModules.brave =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.desktop.hyprland;
      palette = cfg.palette;
      protonPass = "ghmbeldphafepmbegfdlkpapadhbakde";
    in
    {
      config = lib.mkIf cfg.enable {

        environment.systemPackages = with pkgs; [
          (brave.override {
            commandLineArgs = [
              "--force-dark-mode"
              "--enable-features=WebUIDarkMode"
              "--ozone-platform-hint=auto"
              "--enable-wayland-ime"
            ];
          })
        ];

        environment.etc."brave/policies/managed/default.json".text = builtins.toJSON {
          BrowserThemeColor = "#${palette.bg}";

          # Workflow & Interface Defaults
          PromptForDownloadLocation = true;
          RestoreOnStartup = 1;
          NewTabPageLocation = "about:blank";
          HardwareAccelerationModeEnabled = true;

          # Disable Built-in Managers
          PasswordManagerEnabled = false;
          AutofillAddressEnabled = false;
          AutofillCreditCardEnabled = false;

          # Privacy & Search
          BlockThirdPartyCookies = true;
          DefaultSearchProviderEnabled = true;
          DefaultSearchProviderSearchURL = "https://search.brave.com/search?q={searchTerms}";
          SearchSuggestEnabled = false;

          # Strip Bloatware completely
          BraveWalletDisabled = true;
          BraveVPNButtonVisible = false;
          BraveRewardsDisabled = true;
          PromotionalTabsEnabled = false;
          TorDisabled = true;

          # UI and Visuals
          ShowBookmarksBar = false;
          ShowHomeButton = false;
          SyncDisabled = false;

          # Search and Privacy
          SafeBrowsingProtectionLevel = 1;
          MetricsReportingEnabled = false;

          ExtensionInstallForcelist = [
            "${protonPass};https://clients2.google.com/service/update2/crx"
          ];

          ExtensionSettings = {
            "${protonPass}" = {
              "toolbar_pin" = "force_pinned";
            };
          };
        };
      };
    };
}
