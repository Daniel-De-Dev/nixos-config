# Purpose: Hardware abstraction for audio processing and routing.
# Scope: System-wide sound server configuration via PipeWire.
_: {
  flake.nixosModules.hardware-audio =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.audio;
    in
    {
      options.my.hardware.audio.enable = lib.mkEnableOption "PipeWire audio server";

      config = lib.mkIf cfg.enable {
        services.pulseaudio.enable = false;
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber.enable = true;
        };
        services.playerctld.enable = true;
      };
    };
}
