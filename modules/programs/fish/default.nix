# =============================================================================
# Configures the Fish shell and sets it as the default interactive environment.
#
# DESIGN CONSTRAINTS:
# 1. Must be added to `environment.shells` to be valid as a login shell.
# =============================================================================
{ ... }:
{
  flake.nixosModules.programs-fish =
    {
      pkgs,
      config,
      inputs,
      lib,
      ...
    }:
    let
      cfg = config.my.programs.fish;
      opUsername = config.my.operator.username;

      # -----------------------------------------------------------------------
      # 1. Core Configuration File
      # -----------------------------------------------------------------------
      compiledFishConfig = pkgs.writeText "config.fish" ''
        # Disable the default greeting
        set -g fish_greeting ""

        # Construct a simple prompt featuring a 24-hour European time format
        function fish_prompt
            set_color cyan
            echo -n "["(date +%H:%M)"] "
            set_color blue
            echo -n (prompt_pwd)
            set_color normal
            echo -n ' > '
        end
      '';

      # -----------------------------------------------------------------------
      # 2. Wrapper Engine
      # -----------------------------------------------------------------------
      wm-eval = inputs.wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.fish = {
              basePackage = pkgs.fish;
              
              # wrapper-manager handles aliases natively, preventing the need
              # to hardcode them into the config script.
              aliases = {
                ".." = "cd ..";
                "..." = "cd ../..";
                ll = "ls -lh";
                la = "ls -lha";
              };

              # Inject the configuration file directly into the shell on startup
              prependFlags = [
                "--init-command" "source ${compiledFishConfig}"
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
        # REQUIRED: Generates NixOS environment hooks so $PATH populates correctly.
        programs.fish.enable = true;

        # Expose the wrapped shell to the user profile
        users.users.${opUsername}.packages = [ wrappedFish ];

        # Register the wrapped binary as a valid system login shell
        environment.shells = [ wrappedFish ];

        # Set the wrapped binary as the default shell for the operator
        users.users.${opUsername}.shell = wrappedFish;
      };
    };
}
