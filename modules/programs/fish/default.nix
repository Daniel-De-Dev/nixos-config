# =============================================================================
# Configures the Fish shell and sets it as the default interactive environment.
# =============================================================================
{ ... }: {
  flake.nixosModules.programs-fish =
    {
      pkgs,
      config,
      inputs,
      lib,
      machine,
      ...
    }:
    let
      cfg = config.my.programs.fish;
      opUsername = config.my.operator.username;

      confDir = ./conf.d;

      rawFishFiles = builtins.filter (
        name: lib.hasSuffix ".fish" name && name != "30-abbr.fish"
      ) (builtins.attrNames (builtins.readDir confDir));

      sortedRawFiles = builtins.sort builtins.lessThan rawFishFiles;

      dynamicSources = lib.concatMapStringsSep "\n" (
        name: "source ${confDir}/${name}"
      ) sortedRawFiles;

      processedAbbr = pkgs.replaceVars ./conf.d/30-abbr.fish { machine = machine; };

      compiledInit = pkgs.writeText "fish-init.fish" ''
        set -p fish_function_path ${pkgs.fishPlugins.fzf-fish}/share/fish/vendor_functions.d
        source ${pkgs.fishPlugins.fzf-fish}/share/fish/vendor_conf.d/fzf.fish

        # Source the root configuration
        source ${./config.fish}

        ${dynamicSources}

        source ${processedAbbr}
      '';

      wm-eval = inputs.wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.fish = {
              basePackage = pkgs.fish;

              pathAdd = with pkgs; [
                starship
                eza
                bat
                zoxide
                fzf
                fd
                ripgrep
                tldr
              ];

              # Lock the Starship configuration globally
              env.STARSHIP_CONFIG.value = toString ./starship.toml;

              # Pass a single, clean instruction to bypass bash array issues
              prependFlags = [
                "--init-command"
                "source ${compiledInit}"
              ];
            };
          }
        ];
      };

      wrappedFish = wm-eval.config.wrappers.fish.wrapped;
    in
    {
      options.my.programs.fish.enable = lib.mkEnableOption "Fish shell";

      config = lib.mkIf cfg.enable {
        programs.fish = {
          enable = true;
          package = wrappedFish;
        };

        users.users.${opUsername}.shell = wrappedFish;
      };
    };
}
