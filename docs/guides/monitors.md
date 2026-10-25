# Host Monitor Configuration

Declare monitors once in the host's `my.hardware.monitors` list. The hardware
module defines the shared schema and generates Linux console `video=` parameters.

`description` is the monitor's EDID description, including its serial when
available. On Hyprland, copy the `description` from `hyprctl monitors all`,
without `desc:` or a trailing connector in parentheses. Matching by description
avoids depending on compositor connector numbering, which can differ
from kernel DRM numbering.

`connector` is the kernel DRM connector name, such as `DP-1` or `HDMI-A-2`.
Check the connected outputs with:

```sh
for output in /sys/class/drm/card*-*; do
  if [ -r "$output/status" ]; then
    printf '%s: ' "${output##*/}"
    cat "$output/status"
  fi
done
```

For example, `card1-DP-1` means `connector = "DP-1"`. Do not copy a compositor's
port name here without checking the kernel name. A description-only entry does
not request a console mode. A connector-only entry uses that connector for
desktop matching too; this requires the compositor to use the same name.

Desktop widths and heights are physical pixels. Positions are logical pixels
after scaling, so a 2560-pixel-wide display at scale 2 occupies 1280 units in the
desktop layout. Scale is a positive number, not a quoted string. Negative
positions are supported. Unlisted displays get a preferred-mode fallback.

References:

- [Hyprland monitor configuration](https://wiki.hypr.land/Configuring/Basics/Monitors/)
- [Linux DRM framebuffer sizing](https://github.com/torvalds/linux/blob/v6.17/drivers/gpu/drm/drm_fb_helper.c#L1479-L1598)
