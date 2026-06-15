# =============================================================================
# Provides an automated Google Drive mount using rclone.
#
# DESIGN CONSTRAINTS:
# 1. Utilizes full VFS caching for offline reads and background uploads.
# 2. Automatically provisions the mount point for the primary operator.
# =============================================================================
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

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.rclone ];

        systemd.user.services.google-drive-mount = {
          description = "Mount Google Drive via rclone";
          wantedBy = [ "default.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];

          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.mountPoint}";
            ExecStart = ''
              ${pkgs.rclone}/bin/rclone mount ${cfg.remoteName}: ${cfg.mountPoint} \
                --vfs-cache-mode full \
                --vfs-cache-max-size 50G \
                --dir-cache-time 72h \
                --vfs-cache-max-age 24h \
                --log-level INFO
            '';
            ExecStop = "/run/wrappers/bin/fusermount -u ${cfg.mountPoint}";
            Restart = "on-failure";
            RestartSec = "10s";
            Environment = [ "PATH=/run/wrappers/bin/:$PATH" ];
          };
        };
      };
    };
}
