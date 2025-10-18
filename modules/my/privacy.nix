{
  lib,
  config,
  inputs,
  hostName,
  ...
}:
{
  options.my.privacy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to load private data for this host from the privacy input.";
    };

    data = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "The private data loaded from the privacy flake input for this host.";
    };

    gitRepo = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to configure an SSH rule for accessing the private repository.

          This creates an SSH host alias named "nixos-privacy". You must use this alias
          in your flake.nix URL, for example:
          `url = "git+ssh://nixos-privacy/<user>/<repo>.git";`

          **First-Time Setup (if repo is private):**
          For the initial build on a new machine, you must:
          1. Comment out the `privacy` input in your `flake.nix`.
          2. Set `my.privacy.gitRepo.enable = true;` in your configuration.
          3. Run `nixos-rebuild switch`. This applies the SSH rule.
          4. Uncomment the `privacy` input in your `flake.nix`.
          5. Run `nixos-rebuild switch` again. The build will now succeed.
        '';
      };

      sshKey = lib.mkOption {
        type = lib.types.str;
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
    };
  };

  config = lib.mkMerge [
    {
      my.privacy.data =
        # It's filled with data when enabled, otherwise it's an empty set.
        if config.my.privacy.enable && (inputs ? privacy) then
          (
            let
              privacyRoot = inputs.privacy;

              hostPrivacyFile = privacyRoot + "/hosts/${hostName}.nix";

              rawPrivacy =
                if builtins.pathExists hostPrivacyFile then
                  let
                    imported = import hostPrivacyFile;
                  in
                  if builtins.isFunction imported then imported { inherit hostName; } else imported
                else
                  builtins.throw ''
                    my.privacy.enable is true, but the privacy file was not found for host "${hostName}".
                    Nix looked for the file at: ${hostPrivacyFile}
                  '';
            in
            if builtins.isAttrs rawPrivacy then
              rawPrivacy
            else
              builtins.throw ''
                The privacy file for host "${hostName}" did not return an attribute set.
              ''
          )
        else if config.my.privacy.enable && !(inputs ? privacy) then
          lib.warn ''
            my.privacy.enable is true, but the 'privacy' flake input was not found.
            Returning empty set for my.privacy.data.
            (This is normal and can be ignored if you are bootstrapping a new system).
          '' { }
        else
          { };
    }

    (lib.mkIf config.my.privacy.gitRepo.enable {
      assertions = [
        {
          assertion = config.my.privacy.gitRepo.sshKey != null;
          message = ''
            my.privacy.gitRepo.enable is true, but 'my.privacy.gitRepo.sshKey' is not set.
            Please provide the absolute path to your SSH private key.
          '';
        }
      ];

      # Add the host's configuration to the target system's SSH config.
      programs.ssh.extraConfig = ''
        Host nixos-privacy
          HostName ${config.my.privacy.gitRepo.hostname}
          User ${config.my.privacy.gitRepo.user}
          IdentityFile ${config.my.privacy.gitRepo.sshKey}
          IdentitiesOnly yes
      '';
    })
  ];
}
