{
  lib,
  config,
  inputs,
  hostName,
  ...
}:
let
  cfg = config.my.privacy;
in
{
  options.my.privacy = {
    enable = lib.mkEnableOption "loading private data from the 'privacy' flake input";

    bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable this only for the initial "Stage 1" build.
        When true, this module will only set up the SSH alias
        and will skip attempting to load the private data.
        Set to `false` for normal operation.
      '';
    };

    sshAliasConfig = {
      enable = lib.mkEnableOption ''
        Whether to configure an SSH rule for accessing a private repository.

        First-Time Setup (if repo is remote & private):
        1. Comment out the `privacy` input in your `flake.nix`.
        2. Set `my.privacy.enable = true;`
        3. Set `my.privacy.bootstrap = true;`
        4. Set `my.privacy.sshAliasConfig.enable = true;` (and set `sshKey` and the other attributes).
        5. Run `nixos-rebuild switch`. This applies the SSH rule.
        6. Uncomment the `privacy` input in your `flake.nix`.
        7. Set `my.privacy.bootstrap = false;`
        8. Run `nixos-rebuild switch` again. The build will now succeed (might need sudo based on key permissions).
      '';

      sshKey = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "^/.*");
        default = null;
        description = "Absolute path to the SSH private key with read access to the repository `privacy.url` points to.";
        example = "/etc/nixos/secrets/id_ed25519_privacy";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "github.com";
        description = "The actual hostname of the Git provider.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "git";
        description = "The SSH user for the connection.";
      };

      alias = lib.mkOption {
        type = lib.types.str;
        default = "nixos-privacy";
        description = "SSH host alias used in the generated configuration.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Load Private Data
      (lib.mkIf (!cfg.bootstrap) (
        let
          privacyInputExists = inputs ? privacy;
        in
        if !privacyInputExists then
          {
            assertions = [
              {
                assertion = false;
                message = "my.privacy.enable is true and my.privacy.bootstrap is false, but the 'privacy' flake input is not found. Add it as input or disable the privacy module.";
              }
            ];
          }
        else
          let
            privacyFile = "${inputs.privacy}/hosts/${hostName}.nix";
            imported = import privacyFile;
            configValue =
              if builtins.isFunction imported then
                imported {
                  inherit
                    config
                    lib
                    inputs
                    ;
                }
              else
                imported;
          in
          configValue
      ))

      (lib.mkIf cfg.bootstrap {
        warnings = [
          "my.privacy is in bootstrap mode. Skipping private data load. `my.host` will use defaults."
        ];
      })

      (lib.mkIf cfg.sshAliasConfig.enable {
        assertions = [
          {
            assertion = cfg.sshAliasConfig.sshKey != null;
            message = "my.privacy.sshAliasConfig.enable is true, but 'sshKey' is not set.";
          }
          {
            assertion = lib.stringLength cfg.sshAliasConfig.host > 0;
            message = "my.privacy.sshAliasConfig.host must not be an empty string.";
          }
          {
            assertion = lib.stringLength cfg.sshAliasConfig.alias > 0;
            message = "my.privacy.sshAliasConfig.alias must not be an empty string.";
          }
          {
            assertion = lib.stringLength cfg.sshAliasConfig.user > 0;
            message = "my.privacy.sshAliasConfig.user must not be an empty string.";
          }
        ];

        programs.ssh.extraConfig = lib.mkAfter ''
          Host ${cfg.sshAliasConfig.alias}
            HostName ${cfg.sshAliasConfig.host}
            User ${cfg.sshAliasConfig.user}
            IdentityFile ${cfg.sshAliasConfig.sshKey}
            IdentitiesOnly yes
        '';
      })
    ]
  );
}
