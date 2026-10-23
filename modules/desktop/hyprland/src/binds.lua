-- TODO: Fix lsp to work on lua files here (via a repo specific .nvim file?)
local mainMod = 'SUPER'

-- Expose supported actions to shortcut search alongside their keyboard bindings.
local actions = {}
nixos_shortcuts = {}

function nixos_shortcuts.list()
  local ids = {}
  for id, entry in pairs(actions) do
    if entry.binding.enabled and entry.binding.submap == '' then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  return '[' .. table.concat(ids, ',') .. ']'
end

function nixos_shortcuts.run(id, description)
  local entry = actions[id]
  assert(
    entry
      and entry.binding.enabled
      and entry.binding.submap == ''
      and entry.binding.description == description,
    'Shortcut changed or is unavailable; reopen shortcut search'
  )
  return hl.dispatch(entry.action)
end

-- Keep the complete key specification in native descriptions, including keycodes.
local function bind(keys, action, description, flags, launchable)
  flags = flags or {}
  flags.description = description .. ' [' .. keys .. ']'
  local binding = hl.bind(keys, action, flags)
  if
    binding
    and launchable ~= false
    and not (
      flags.mouse
      or flags.release
      or flags.long_press
      or flags.click
      or flags.drag
      or keys:find('mouse:', 1, true)
      or keys:find('switch:', 1, true)
      or keys == 'catchall'
    )
  then
    actions[tonumber(binding.arg)] = { binding = binding, action = action }
  end
  return binding
end

nixos_shortcuts.bind = bind

-- Core Applications
bind(
  mainMod .. ' + RETURN',
  hl.dsp.exec_cmd('ghostty'),
  'Applications: Open terminal'
)
bind(mainMod .. ' + B', hl.dsp.exec_cmd('brave'), 'Applications: Open browser')
bind(
  mainMod .. ' + E',
  hl.dsp.exec_cmd('ghostty --class=\'yazi-files\' -e yazi'),
  'Applications: Open file manager'
)
-- TODO: Fix "No suitable picker tool found."
bind(
  mainMod .. ' + CTRL + E',
  hl.dsp.exec_cmd('bemoji -t -n -c'),
  'Applications: Open emoji picker'
)
bind(
  mainMod .. ' + CTRL + C',
  hl.dsp.exec_cmd('qalculate-qt'),
  'Applications: Open calculator'
)

-- Planned AGS navigation bindings
-- TODO: SUPER + V: open the clipboard manager.

-- Window State Management
bind(
  mainMod .. ' + Q',
  hl.dsp.window.close(hl.get_active_window()),
  'Windows: Close active window'
)
bind(
  mainMod .. ' + SHIFT + Q',
  hl.dsp.window.kill(hl.get_active_window()),
  'Windows: Force kill active window'
)
bind(
  mainMod .. ' + F',
  hl.dsp.window.fullscreen('fullscreen', 'toggle', hl.get_active_window()),
  'Windows: Toggle fullscreen'
)
bind(
  mainMod .. ' + M',
  hl.dsp.window.fullscreen('maximized', 'toggle', hl.get_active_window()),
  'Windows: Toggle maximized state'
)
bind(
  mainMod .. ' + T',
  hl.dsp.window.float('toggle', hl.get_active_window()),
  'Windows: Toggle floating state'
)
bind(
  mainMod .. ' + J',
  hl.dsp.layout('togglesplit'),
  'Layout: Toggle split orientation'
)
bind(
  mainMod .. ' + K',
  hl.dsp.layout('swapsplit'),
  'Layout: Swap split orientation'
)
bind(
  mainMod .. ' + G',
  hl.dsp.group.toggle(hl.get_active_window()),
  'Windows: Toggle window group'
)

-- Directional Window Management (Focus, Swap, Resize)
local steps = 50
local dirs = {
  left = { dir = 'l', rx = -steps, ry = 0 },
  right = { dir = 'r', rx = steps, ry = 0 },
  up = { dir = 'u', rx = 0, ry = -steps },
  down = { dir = 'd', rx = 0, ry = steps },
}

for key, data in pairs(dirs) do
  -- Move Focus
  bind(
    mainMod .. ' + ' .. key,
    hl.dsp.focus({ direction = data.dir }),
    'Windows: Focus ' .. key
  )

  -- Swap Window
  bind(
    mainMod .. ' + ALT + ' .. key,
    hl.dsp.window.swap({ direction = data.dir }),
    'Windows: Swap ' .. key
  )

  -- Resize Window
  bind(
    mainMod .. ' + SHIFT + ' .. key,
    hl.dsp.window.resize({
      x = data.rx,
      y = data.ry,
      relative = true,
      window = hl.get_active_window(),
    }),
    'Windows: Resize ' .. key,
    { repeating = true }
  )
end

-- Mouse Window Control
bind(
  mainMod .. ' + mouse:272',
  hl.dsp.window.drag(),
  'Windows: Drag with mouse',
  { mouse = true }
)
bind(
  mainMod .. ' + mouse:273',
  hl.dsp.window.resize(),
  'Windows: Resize with mouse',
  { mouse = true }
)

-- Workspaces & Navigation
for i = 1, 10 do
  local code = i + 9
  local ws = i

  -- Open workspace
  bind(
    mainMod .. ' + code:' .. code,
    hl.dsp.focus({ workspace = ws, on_current_monitor = false }),
    'Workspaces: Open workspace ' .. ws
  )

  -- Move active window to workspace
  bind(
    mainMod .. ' + SHIFT + code:' .. code,
    hl.dsp.window.move({ workspace = ws, follow = true }),
    'Workspaces: Move window to workspace ' .. ws
  )

  -- Move workspace to active monitor and focus on it
  bind(
    mainMod .. ' + CTRL + code:' .. code,
    hl.dsp.workspace.move({ workspace = ws, monitor = 'current' }),
    'Workspaces: Move workspace ' .. ws .. ' to current monitor'
  )
end

-- Special Workspace
bind(
  mainMod .. ' + SHIFT + S',
  hl.dsp.window.move({ workspace = 'special:magic', follow = true }),
  'Workspaces: Move window to special workspace'
)

-- For toggling special workspace
bind(
  mainMod .. ' + S',
  hl.dsp.workspace.toggle_special('magic'),
  'Workspaces: Toggle special workspace'
)

-- Workspace Navigation
bind(
  mainMod .. ' + Tab',
  hl.dsp.focus({ workspace = 'm+1' }),
  'Workspaces: Next on current monitor'
)
bind(
  mainMod .. ' + SHIFT + Tab',
  hl.dsp.focus({ workspace = 'm-1' }),
  'Workspaces: Previous on current monitor'
)

-- Workspace Navigation
bind(
  mainMod .. ' + mouse_down',
  hl.dsp.focus({ workspace = 'e+1' }),
  'Workspaces: Scroll to next workspace'
)
bind(
  mainMod .. ' + mouse_up',
  hl.dsp.focus({ workspace = 'e-1' }),
  'Workspaces: Scroll to previous workspace'
)

-- Empty Workspace
bind(
  mainMod .. ' + CTRL + down',
  hl.dsp.focus({ workspace = 'empty' }),
  'Workspaces: Open empty workspace'
)

-- System & Media Controls (Function Keys)
-- Volume
bind(
  'XF86AudioRaiseVolume',
  hl.dsp.exec_cmd('wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+'),
  'Audio: Raise volume',
  { repeating = true }
)
bind(
  'XF86AudioLowerVolume',
  hl.dsp.exec_cmd('wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'),
  'Audio: Lower volume',
  { repeating = true }
)
bind(
  'XF86AudioMute',
  hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'),
  'Audio: Toggle output mute'
)
bind(
  'XF86AudioMicMute',
  hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_SOURCE@ toggle'),
  'Audio: Toggle microphone mute'
)

-- Media Control
bind(
  'XF86AudioPlay',
  hl.dsp.exec_cmd('playerctl play-pause'),
  'Media: Play or pause'
)
bind('XF86AudioPause', hl.dsp.exec_cmd('playerctl pause'), 'Media: Pause')
bind('XF86AudioNext', hl.dsp.exec_cmd('playerctl next'), 'Media: Next track')
bind(
  'XF86AudioPrev',
  hl.dsp.exec_cmd('playerctl previous'),
  'Media: Previous track'
)

-- Brightness
bind(
  'XF86MonBrightnessUp',
  hl.dsp.exec_cmd('brightnessctl -q s +10%'),
  'Display: Increase brightness'
)
bind(
  'XF86MonBrightnessDown',
  hl.dsp.exec_cmd('brightnessctl -q s 10%-'),
  'Display: Decrease brightness'
)

-- Misc
bind(
  'XF86Calculator',
  hl.dsp.exec_cmd('qalculate-qt'),
  'Applications: Open calculator'
)
bind(
  'XF86ScreenSaver',
  hl.dsp.exec_cmd('loginctl lock-session'),
  'Session: Lock screen'
)

-- Utilities, Scripts & Visuals
bind(
  mainMod .. ' + CTRL + L',
  hl.dsp.exec_cmd('loginctl lock-session'),
  'Session: Lock screen'
)

-- Planned AGS utility bindings
-- TODO: SUPER + CTRL + Q: open the power menu.
-- TODO: SUPER + SHIFT + B: reload or restart the shell.

bind(
  mainMod .. ' + SHIFT + W',
  hl.dsp.exec_cmd('awww random'),
  'Wallpaper: Random image'
)
bind(
  mainMod .. ' + CTRL + W',
  hl.dsp.exec_cmd('awww select'),
  'Wallpaper: Select image'
)

local sc_script = '@scScriptPath@'
local rec_script = '@recScriptPath@'

-- Screenshots
bind(
  mainMod .. ' + PRINT',
  hl.dsp.exec_cmd(sc_script .. ' screen'),
  'Capture: Screenshot screen'
)
bind(
  mainMod .. ' + ALT + S',
  hl.dsp.exec_cmd(sc_script .. ' area'),
  'Capture: Screenshot area'
)
bind(
  mainMod .. ' + ALT + F',
  hl.dsp.exec_cmd(sc_script .. ' active'),
  'Capture: Screenshot active window'
)

-- Screen Recording
bind(
  mainMod .. ' + ALT + R',
  hl.dsp.exec_cmd(rec_script .. ' screen'),
  'Capture: Record screen or stop recording'
)
bind(
  mainMod .. ' + SHIFT + R',
  hl.dsp.exec_cmd(rec_script .. ' area'),
  'Capture: Record area or stop recording'
)

-- TODO: Implement Blue light filter logic (time based and binds)

-- Helper function to dynamically calculate and apply the new zoom level
local function adjust_zoom(step)
  local current_zoom = hl.get_config('cursor:zoom_factor')

  if not current_zoom then current_zoom = 1.0 end

  local new_zoom = current_zoom + step

  -- Prevent zooming out past the default 1.0 scale
  if new_zoom < 1.0 then new_zoom = 1.0 end

  -- Apply the new zoom factor
  hl.config({
    cursor = {
      zoom_factor = new_zoom,
    },
  })
end

-- Increase display zoom
bind(
  mainMod .. ' + SHIFT + mouse_down',
  function() adjust_zoom(0.5) end,
  'Display: Zoom in'
)

-- Decrease display zoom
bind(
  mainMod .. ' + SHIFT + mouse_up',
  function() adjust_zoom(-0.5) end,
  'Display: Zoom out'
)

-- Reset display zoom
bind(
  mainMod .. ' + SHIFT + Z',
  function()
    hl.config({
      cursor = {
        zoom_factor = 1.0,
      },
    })
  end,
  'Display: Reset zoom'
)

-- Planned AGS keyboard preview binding
-- TODO: SUPER + I: show the layout preview on press and hide it on release.
