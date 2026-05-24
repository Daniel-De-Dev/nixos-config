# =============================================================================
# Governs the regional identity, language, and units of the machine.
#
# DESIGN CONSTRAINTS:
# 1. All regional data is considered sensitive and is routed through the
#    privacy data bus.
# =============================================================================
{ ... }:
{
  flake.nixosModules.core-locale =
    { config, ... }:
    let
      hostTz = config.my.host.timeZone;
      hostKeyMap = config.my.host.keyMap;

      opDefaultLocale = config.my.operator.locale.default;
      opMeasurementLocale = config.my.operator.locale.measurement;
    in
    {
      # Time Management
      time.timeZone = hostTz;

      # Keyboard Layout
      services.xserver.xkb.layout = hostKeyMap;
      console.keyMap = hostKeyMap;

      # System Language
      i18n.defaultLocale = opDefaultLocale;

      # Unit & Formatting
      i18n.extraLocaleSettings = {
        LC_MEASUREMENT = opMeasurementLocale;
        LC_PAPER = opMeasurementLocale;
        LC_NUMERIC = opMeasurementLocale;
        LC_TIME = opMeasurementLocale;
        LC_MONETARY = opMeasurementLocale;
      };
    };
}
