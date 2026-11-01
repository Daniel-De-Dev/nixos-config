# Semantic theme roles are shared with Hyprland and AGS.
{
  lib,
  theme,
  wallpaper,
  blurSize,
  blurPasses,
  fingerprint,
  dateCommand,
  batteryCommand,
}:
let
  inherit (theme) colors fonts fontSizes;
  color = value: "rgb(${lib.removePrefix "#" value})";
  label =
    {
      text,
      y,
      size ? fontSizes.body,
      font ? fonts.sans,
      tint ? colors.textMuted,
    }:
    ''
      label {
          monitor =
          text = ${text}
          color = ${color tint}
          font_family = ${font}
          font_size = ${toString size}
          position = 0, ${toString y}
          halign = center
          valign = center
          zindex = 2
      }
    '';
in
''
  general {
      hide_cursor = true
      ignore_empty_input = true
      immediate_render = true
  }

  animations {
      enabled = false
  }

  auth {
      pam:enabled = true
      pam:module = hyprlock
      fingerprint:enabled = ${lib.boolToString fingerprint}
      fingerprint:ready_message = Scan fingerprint to unlock
      fingerprint:present_message = Scanning fingerprint…
  }

  # Use the wallpaper file directly: application windows are never captured.
  # Empty monitor selectors cover every connected display.
  background {
      monitor =
      path = ${wallpaper}
      color = ${color colors.background}
      blur_size = ${toString blurSize}
      blur_passes = ${toString blurPasses}
      brightness = 0.6
      contrast = 0.9
      vibrancy = 0.1
  }

  shape {
      monitor =
      size = 440, 500
      color = rgba(${lib.removePrefix "#" colors.background}ee)
      border_color = ${color colors.borderStrong}
      border_size = 1
      rounding = 0
      position = 0, 0
      halign = center
      valign = center
      zindex = 0
  }

  shape {
      monitor =
      size = 440, 3
      color = ${color colors.accent}
      rounding = 0
      position = 0, 250
      halign = center
      valign = center
      zindex = 1
  }

  input-field {
      monitor =
      size = 360, 52
      position = 0, -48
      halign = center
      valign = center
      inner_color = ${color colors.surface}
      outer_color = ${color colors.focus}
      font_color = ${color colors.text}
      font_family = ${fonts.sans}
      outline_thickness = 2
      rounding = 0
      dots_size = 0.2
      dots_spacing = 0.3
      fade_on_empty = false
      placeholder_text = Password
      check_color = ${color colors.accent}
      check_text = Checking…
      fail_color = ${color colors.danger}
      fail_text = Authentication failed ($ATTEMPTS)
      capslock_color = ${color colors.danger}
      zindex = 2
  }
''
+ lib.concatMapStringsSep "\n" label (
  [
    {
      text = "Session locked";
      y = 212;
    }
    {
      text = "$TIME";
      y = 132;
      size = 64;
      font = fonts.monospace;
      tint = colors.text;
    }
    {
      text = "cmd[update:60000] ${dateCommand}";
      y = 77;
    }
    {
      text = "$USER";
      y = 12;
      size = fontSizes.heading;
      tint = colors.text;
    }
    {
      text = "Keyboard: $LAYOUT";
      y = -104;
      size = fontSizes.small;
    }
    {
      text = "cmd[update:10000] ${batteryCommand}";
      y = -201;
    }
  ]
  ++ lib.optional fingerprint {
    text = "$FPRINTPROMPT";
    y = -140;
    size = fontSizes.small;
    tint = colors.accent;
  }
)
