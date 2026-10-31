# Session-only clipboard history shared by the installed desktop and preview.
{
  lib,
  cliphist,
  ffmpeg-headless,
  python3,
  wl-clipboard,
  writeShellApplication,
}:
let
  python = python3.withPackages (ps: [ ps.pillow ]);
  clipboard = wl-clipboard.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./wl-clipboard-mime.patch ];
  });
in
writeShellApplication {
  name = "ags-clipboard";
  runtimeInputs = [
    clipboard
    cliphist
    ffmpeg-headless
  ];
  text = ''
    exec ${lib.getExe python} ${./clipboard.py} "$@"
  '';
  meta.description = "Bounded, session-only Wayland clipboard history";
}
