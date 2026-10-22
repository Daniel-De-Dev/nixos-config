{
  lib,
  ags,
  astal,
  makeWrapper,
}:
ags.bundle {
  pname = "ags-shell";
  version = "0.1.0";
  src = ./src;
  entry = "app.ts";

  dependencies = [ astal.hyprland ];
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    makeWrapper ${lib.getExe ags} "$out/bin/ags-shell-request" \
      --add-flags "request --instance nixos-shell"
  '';

  meta = {
    description = "AGS desktop shell with a Hyprland window switcher";
    mainProgram = "ags-shell";
    platforms = lib.platforms.linux;
  };
}
