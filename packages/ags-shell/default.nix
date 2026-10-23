{
  lib,
  ags,
  astal,
  makeWrapper,
  symlinkJoin,
  uwsm,
  writeText,
  xdg-terminal-exec,
  theme ? import ../../themes/carbon-dark.nix,
}:
let
  stylesheet = writeText "ags-shell.css" (
    import ./style.nix { inherit lib theme; }
  );
  bundle = ags.bundle {
    pname = "ags-shell";
    version = "0.2.0";
    src = lib.fileset.toSource {
      root = ./src;
      fileset = lib.fileset.fileFilter (file: file.hasExt "ts") ./src;
    };
    entry = "app.ts";

    dependencies = [ astal.hyprland ];
    nativeBuildInputs = [ makeWrapper ];

    postInstall = ''
      makeWrapper ${lib.getExe ags} "$out/bin/ags-shell-request" \
        --add-flags "request --instance nixos-shell"
    '';

    meta = {
      description = "AGS desktop shell with window, shortcut, and application search";
      mainProgram = "ags-shell";
      platforms = lib.platforms.linux;
    };
  };
in
symlinkJoin {
  inherit (bundle) name;
  paths = [ bundle ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/ags-shell" \
      --set AGS_SHELL_STYLE ${stylesheet} \
      --prefix PATH : ${
        lib.makeBinPath [
          uwsm
          xdg-terminal-exec
        ]
      }
  '';
  passthru = { inherit bundle stylesheet; };
  inherit (bundle) meta;
}
