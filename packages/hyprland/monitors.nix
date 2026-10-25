# Translate the shared host monitor data into Hyprland's Lua API.
{ lib, monitors }:
map (
  m:
  "hl.monitor(${
    lib.generators.toLua { } {
      output = if m.description != null then "desc:${m.description}" else m.connector;
      mode = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
      position = "${toString m.x}x${toString m.y}";
      inherit (m) scale;
    }
  })"
) monitors
++ [
  # Give unlisted displays a usable mode.
  ''hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })''
]
