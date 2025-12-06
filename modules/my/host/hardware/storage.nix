{
  lib,
  config,
  ...
}:
let
  cfg = config.my.host.hardware;

  getDiskType =
    deviceName:
    let
      # 1. Check if it's a direct physical disk
      physical = cfg.disks.${deviceName} or null;
      # 2. Check if it's a LUKS mapper, and look up its parent
      luks = cfg.luks.${deviceName} or null;
      parentDisk = if luks != null then cfg.disks.${luks.device} or null else null;
    in
    if physical != null then
      physical.type
    else if parentDisk != null then
      parentDisk.type
    else
      null;

  stripDevPrefix = path: lib.removePrefix "/dev/" path;
in
{
  options.my.host.hardware = {
    disks = lib.mkOption {
      description = "Map of PHYSICAL devices (UUIDs) to hardware properties.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.type = lib.mkOption {
            type = lib.types.enum [
              "ssd"
              "hdd"
            ];
          };
        }
      );
      default = { };
    };

    luks = lib.mkOption {
      description = "Map of LUKS mapper names to their underlying physical device.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.device = lib.mkOption {
            type = lib.types.str;
            description = "The key in 'disks' that backs this encrypted volume.";
          };
        }
      );
      default = { };
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            type = lib.mkOption { type = lib.types.str; };
            device = lib.mkOption { type = lib.types.str; };
            compress = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to apply compression optimizations (Btrfs only atm).";
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkMerge [
    # Global SSD Optimizations (fstrim)
    (lib.mkIf (lib.any (d: d.type == "ssd") (lib.attrValues cfg.disks)) {
      services.fstrim.enable = true;
    })

    # Filesystem Options Btrfs
    {
      fileSystems = lib.mapAttrs (
        mountPoint: mountCfg:
        let
          hwType = getDiskType mountCfg.device;
        in
        {
          options = lib.mkMerge [
            [ "noatime" ]
            # Only apply compression if fs is btrfs AND compress is true
            (lib.mkIf (mountCfg.type == "btrfs" && mountCfg.compress) [
              "compress-force=zstd:1"
              "space_cache=v2"
            ])
            # SSD-specific FS flags
            (lib.mkIf (hwType == "ssd" && mountCfg.type == "btrfs") [ "ssd" ])
          ];
        }
      ) cfg.mounts;
    }

    # LUKS Optimizations (Discard/Trim)
    # Iterate over the logical LUKS definitions.
    # If the PARENT disk is an SSD, we enable discard.
    {
      boot.initrd.luks.devices = lib.mkMerge (
        lib.mapAttrsToList (
          mapperName: luksCfg:
          let
            parentDisk = cfg.disks.${luksCfg.device} or null;
          in
          if parentDisk != null && parentDisk.type == "ssd" then
            {
              "${mapperName}" = {
                allowDiscards = true;
                bypassWorkqueues = true;
              };
            }
          else
            { }
        ) cfg.luks
      );
    }

    # Udev Scheduler Rules (Physical Disks Only)
    {
      services.udev.extraRules = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          devPath: diskCfg:
          if lib.hasPrefix "/dev/" devPath then
            let
              matchKey = stripDevPrefix devPath;
              scheduler = if diskCfg.type == "ssd" then "none" else "bfq";
            in
            ''ACTION=="add|change", SUBSYSTEM=="block", SYMLINK=="${matchKey}", ATTR{queue/scheduler}="${scheduler}"''
          else
            ""
        ) cfg.disks
      );
    }
  ];
}
