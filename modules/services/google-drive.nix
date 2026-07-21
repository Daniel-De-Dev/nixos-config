# Purpose: Automated Google Drive mount using rclone.
# Scope: Primary operator mount provisioning.
# Invariants:
# - Requires full VFS caching.
_: {
  flake.nixosModules.services-google-drive =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.services.google-drive;
      opUsername = config.my.operator.username;
    in
    {
      options.my.services.google-drive = {
        enable = lib.mkEnableOption "Google Drive automatic sync/mount";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/home/${opUsername}/GoogleDrive";
          description = "Absolute path where Google Drive will be mounted.";
        };
        remoteName = lib.mkOption {
          type = lib.types.str;
          default = "gdrive";
          description = "The name of the rclone remote configuration.";
        };
      };

      # TODO: Other than the path name there is nothing else suggesting this is
      # google drive spesific, so could just be renamed to genereic rclone or
      # remote disk module

      # TODO: Make the config file encrypted or password protected
      # There was an password option in config maybe use that and share the file
      # via sops?

      config = lib.mkIf cfg.enable {
        # TODO: see if needed
        # boot.kernelModules = [ "fuse" ];

        environment.systemPackages = [ pkgs.rclone ];

        programs.fuse = {
          enable = true;
          userAllowOther = true;
        };

        systemd.user.services.google-drive-mount = {
          description = "Mount Google Drive via rclone";
          wantedBy = [ "default.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];

          serviceConfig = {
            ExecStartPre = [
              "-/run/wrappers/bin/fusermount3 -u -q -z ${cfg.mountPoint}"
              "${pkgs.coreutils}/bin/mkdir -p ${cfg.mountPoint}"
            ];
            ExecStart = ''
              ${pkgs.rclone}/bin/rclone mount ${cfg.remoteName}: ${cfg.mountPoint} \
                --vfs-cache-mode full \
                --vfs-cache-max-size 50G \
                --vfs-cache-max-age 24h \
                --vfs-write-back 30s \
                --vfs-fast-fingerprint \
                --dir-cache-time 8760h \
                --attr-timeout 8760h \
                --poll-interval 10s \
                --log-level INFO
            '';
            ExecStop = "-/run/wrappers/bin/fusermount3 -u -q -z ${cfg.mountPoint}";
            Restart = "on-failure";
            RestartSec = "10s";
            Environment = [ "PATH=/run/wrappers/bin/:$PATH" ];
          };
        };
      };
    };
}
