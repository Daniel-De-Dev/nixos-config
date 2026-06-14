-- Global Input Configuration
hl.config({
  input = {
    -- Keyboard Layout
    kb_layout = '@kbLayout@,real-prog-dvorak',
    kb_variant = ',real-prog-dvorak',
    kb_options = 'grp:alt_shift_toggle',

    -- Ensure bindings trigger based on the layout symbol, not the physical key
    resolve_binds_by_sym = 1,

    -- Focus Behavior
    follow_mouse = 1,
    mouse_refocus = false,

    -- Pointer Settings
    sensitivity = 0.0,
    accel_profile = 'flat',

    touchpad = {
      natural_scroll = true,
      scroll_factor = 1.0,
    },
  },
})

-- 3-finger horizontal swipe to switch workspaces seamlessly
hl.gesture({ fingers = 3, direction = 'horizontal', action = 'workspace' })

-- 3-finger swipe down to close the active window
hl.gesture({ fingers = 3, direction = 'down', action = 'close' })

-- 4-finger swipe up to toggle fullscreen
hl.gesture({ fingers = 4, direction = 'up', action = 'fullscreen' })

-- 2-finger pinch to zoom the cursor
hl.gesture({
  fingers = 2,
  direction = 'pinch',
  action = 'cursorZoom',
  zoom_level = 1.2,
  mode = 'mult',
})
