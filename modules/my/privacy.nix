{
  lib,
  config,
  inputs,
  hostName,
  ...
}:
let
  privacyInputAvailable = inputs ? privacy;
  hostPrivacyFile = if privacyInputAvailable then inputs.privacy + "/hosts/${hostName}.nix" else null;
  hostPrivacyFileExists =
    if privacyInputAvailable then builtins.pathExists hostPrivacyFile else false;
in
{
  options.my.privacy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to load private data for this host from the privacy input.";
    };

    data = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      description = "The private data loaded from the privacy flake input for this host.";
    };

    sshAliasConfig = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to configure an SSH rule for accessing a private repository.

          NOTE: If you have the option to point to a local repo, use:
          `url = "git+file:///absolute/path/to/repository";`

          This creates an SSH host alias.
          Use this alias in your flake.nix URL, for example:
          `url = "git+ssh://<alias>/<user>/<repo>.git";`

          **First-Time Setup (if repo is private):**
          For the initial build on a new machine, you must:
          1. Comment out the `privacy` input in your `flake.nix`.
          2. Set `my.privacy.sshAliasConfig.enable = true;` in your configuration.
          3. Run `nixos-rebuild switch`. This applies the SSH rule.
          4. Uncomment the `privacy` input in your `flake.nix`.
          5. Run `nixos-rebuild switch` again. The build will now succeed.
        '';
      };

      sshKey = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "^/.*");
        default = null;
        description = "Absolute path to the SSH private key with read access to the repository `privacy.url` points to.";
        example = "/etc/nixos/secrets/id_ed25519_privacy";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "github.com";
        description = "The actual hostname of the Git provider.";
        example = ''"github.com"'';
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

  config =
    let
      shouldLoadPrivacy = config.my.privacy.enable && privacyInputAvailable;
      loadPrivacy =
        if shouldLoadPrivacy then
          if hostPrivacyFileExists then
            let
              importResult = builtins.tryEval (import hostPrivacyFile);
            in
            if importResult.success then
              let
                resolvedResult =
                  if builtins.isFunction importResult.value then
                    builtins.tryEval (importResult.value { inherit hostName; })
                  else
                    {
                      success = true;
                      value = importResult.value;
                    };
              in
              if resolvedResult.success then
                {
                  success = true;
                  value = resolvedResult.value;
                  errorMessage = "";
                }
              else
                {
                  success = false;
                  value = { };
                  errorMessage = ''
                    Evaluating the privacy file for host "${hostName}" failed.
                    Check ${hostPrivacyFile} for errors.
                  '';
                }
            else
              {
                success = false;
                value = { };
                errorMessage = ''
                  Importing the privacy file for host "${hostName}" failed.
                  Check ${hostPrivacyFile} for syntax or evaluation errors.
                '';
              }
          else
            {
              success = true;
              value = null;
              errorMessage = "";
            }
        else
          {
            success = true;
            value = { };
            errorMessage = "";
          };
      rawPrivacy = loadPrivacy.value;
      privacyIsAttrset =
        if shouldLoadPrivacy then rawPrivacy != null && builtins.isAttrs rawPrivacy else true;
      privacyData = if shouldLoadPrivacy then if privacyIsAttrset then rawPrivacy else { } else { };
    in
    lib.mkMerge [
      {
        my.privacy.data = privacyData;
      }

      (lib.mkIf shouldLoadPrivacy {
        assertions = [
          {
            assertion = hostPrivacyFileExists;
            message = ''
              my.privacy.enable is true, but the privacy file was not found for host "${hostName}".
              Nix looked for the file at: ${hostPrivacyFile}
            '';
          }
          {
            assertion = privacyIsAttrset;
            message = ''
              The privacy file for host "${hostName}" must return an attribute set.
            '';
          }
        ]
        ++ lib.optional (!loadPrivacy.success) {
          assertion = loadPrivacy.success;
          message = loadPrivacy.errorMessage;
        };
      })

      (lib.mkIf (config.my.privacy.enable && !privacyInputAvailable) {
        warnings = [
          ''
            my.privacy.enable is true, but the 'privacy' flake input was not found.
            Returning empty set for my.privacy.data.
            (This is normal and can be ignored if you are bootstrapping a new system).
          ''
        ];
      })

      (lib.mkIf (!config.my.privacy.enable && hostPrivacyFileExists) {
        warnings = [
          ''
            A privacy file for host "${hostName}" exists at ${hostPrivacyFile}, but `my.privacy.enable` is false.
            If this is intentional you can ignore this warning; otherwise consider enabling `my.privacy.enable`.
          ''
        ];
      })

      (lib.mkIf config.my.privacy.sshAliasConfig.enable (
        let
          keyPath = config.my.privacy.sshAliasConfig.sshKey;
          keyProvided = keyPath != null;
        in
        {
          assertions = [
            {
              assertion = keyProvided;
              message = ''
                my.privacy.sshAliasConfig.enable is true, but 'my.privacy.sshAliasConfig.sshKey' is not set.
                Please provide the absolute path to your SSH private key.
              '';
            }
            {
              assertion = lib.stringLength config.my.privacy.sshAliasConfig.hostname > 0;
              message = "my.privacy.sshAliasConfig.hostname must not be an empty string when sshAliasConfig.enable is true.";
            }
            {
              assertion = lib.stringLength config.my.privacy.sshAliasConfig.alias > 0;
              message = "my.privacy.sshAliasConfig.alias must not be an empty string when sshAliasConfig.enable is true.";
            }
          ];

          # Add the host's configuration to the target system's SSH config.
          programs.ssh.extraConfig = lib.mkAfter ''
            Host ${config.my.privacy.sshAliasConfig.alias}
              HostName ${config.my.privacy.sshAliasConfig.hostname}
              User ${config.my.privacy.sshAliasConfig.user}
              IdentityFile ${config.my.privacy.sshAliasConfig.sshKey}
              IdentitiesOnly yes
          '';
        }
      ))
    ];
}
