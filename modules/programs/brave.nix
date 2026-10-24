{ self, ... }: {
  flake.nixosModules.programs-brave =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      # TODO: Seperate from hyprland? need to reconsider dependencices, add assert to hypeland instead?
      cfg = config.my.desktop.hyprland;
      colors = config.my.theme.colors;
      protonPass = "ghmbeldphafepmbegfdlkpapadhbakde";
      removeYTShorts = "mgngbgbhliflggkamjnpdmegbkidiapm";
      metamask = "nkbihfbeogaeaoehlefnkodbefgpgknn";
      desktop = import ../../packages/hyprland/desktop.nix {
        inherit lib pkgs;
        inherit (inputs) wrapper-manager;
      };
    in
    {
      imports = [ self.nixosModules.core-palette ];

      config = lib.mkIf cfg.enable {

        environment.systemPackages = [ desktop.applications.browser ];

        # TODO: look into programs.chromium option

        # TODO: Move file to be under ./brave/?

        environment.etc."brave/policies/managed/default.json".text = builtins.toJSON {
          BrowserThemeColor = colors.background;

          DeveloperToolsAvailability = 1;

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
            "${removeYTShorts};https://clients2.google.com/service/update2/crx"
            "${metamask};https://clients2.google.com/service/update2/crx"
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
