{
  lib,
  config,
  ...
}:
let
  cfg = config.my.host.hardware.gpu;
in
{
  options.my.host.hardware.gpu = {
    type = lib.mkOption {
      type = lib.types.enum [
        "null"
        "nvidia"
      ];
      default = "null";
      description = "The GPU for this host.";
    };
  };

  config = lib.mkMerge [
    # Common Graphics Settings
    (lib.mkIf (cfg.type != "null") {
      # Enable OpenGL/Vulkan
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    # NVIDIA Configuration
    (lib.mkIf (cfg.type == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        open = false;

        # Select the specific driver version
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })
  ];
}
