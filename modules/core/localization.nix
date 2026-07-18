_: {
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
      console.useXkbConfig = true;

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
