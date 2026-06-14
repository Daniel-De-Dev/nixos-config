hl.config({
  general = {
    -- Window spacing
    gaps_in = 3,
    gaps_out = 5,
    border_size = 1,

    ['col.active_border'] = '@activeColor@',
    ['col.inactive_border'] = '@inactiveColor@',

    layout = 'dwindle',
  },

  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 0.85,

    blur = {
      enabled = true,
      size = 2,
      passes = 2,
    },

    shadow = {
      enabled = true,
      range = 20,
      render_power = 4,
      color = 'rgba(0, 0, 0, 0.65)',
    },
  },
})
