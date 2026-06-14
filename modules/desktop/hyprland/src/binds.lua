local mainMod = 'SUPER'

-- Core Applications
hl.bind(mainMod .. ' + RETURN', hl.dsp.exec_cmd('ghostty'))
hl.bind(mainMod .. ' + B', hl.dsp.exec_cmd('brave'))
hl.bind(
  mainMod .. ' + E',
  hl.dsp.exec_cmd('ghostty --class=\'yazi-files\' -e yazi')
)
hl.bind(mainMod .. ' + CTRL + E', hl.dsp.exec_cmd('bemoji -t -n -c'))
hl.bind(mainMod .. ' + CTRL + C', hl.dsp.exec_cmd('qalculate-qt'))

-- Dynamic Fuzzy Navigation
-- Open the fuzzy window tracker to search/type keywords for open applications
hl.bind(mainMod .. ' + Tab', hl.dsp.exec_cmd('ags -t \'window-switcher\''))
-- Open the standard application launcher
hl.bind(
  mainMod .. ' + CTRL + RETURN',
  hl.dsp.exec_cmd('ags -t \'app-launcher\'')
)
-- Open a unified clipboard manager menu inside AGS
hl.bind(mainMod .. ' + V', hl.dsp.exec_cmd('ags -t \'clipboard-manager\''))
-- TODO: Add fuzzy navigation for keybind search for hyprland keybinds
-- SUPER + S + K

-- Window State Management
hl.bind(mainMod .. ' + Q', hl.dsp.window.close(hl.get_active_window()))
hl.bind(mainMod .. ' + SHIFT + Q', hl.dsp.window.kill(hl.get_active_window()))
hl.bind(
  mainMod .. ' + F',
  hl.dsp.window.fullscreen('fullscreen', 'toggle', hl.get_active_window())
)
hl.bind(
  mainMod .. ' + M',
  hl.dsp.window.fullscreen('maximized', 'toggle', hl.get_active_window())
)
hl.bind(
  mainMod .. ' + T',
  hl.dsp.window.float('toggle', hl.get_active_window())
)
hl.bind(mainMod .. ' + J', hl.dsp.layout('togglesplit'))
hl.bind(mainMod .. ' + K', hl.dsp.layout('swapsplit'))
hl.bind(mainMod .. ' + G', hl.dsp.group.toggle(hl.get_active_window()))

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
  hl.bind(mainMod .. ' + ' .. key, hl.dsp.focus({ direction = data.dir }))

  -- Swap Window
  hl.bind(
    mainMod .. ' + ALT + ' .. key,
    hl.dsp.window.swap({ direction = data.dir })
  )

  -- Resize Window
  hl.bind(
    mainMod .. ' + SHIFT + ' .. key,
    hl.dsp.window.resize({
      x = data.rx,
      y = data.ry,
      relative = true,
      window = hl.get_active_window(),
    }),
    { repeating = true }
  )
end

-- Mouse Window Control
hl.bind(mainMod .. ' + mouse:272', hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. ' + mouse:273', hl.dsp.window.resize(), { mouse = true })

-- Workspaces & Navigation
for i = 1, 10 do
  local code = i + 9
  local ws = i

  -- Open workspace
  hl.bind(
    mainMod .. ' + code:' .. code,
    hl.dsp.focus({ workspace = ws, on_current_monitor = false })
  )

  -- Move active window to workspace
  hl.bind(
    mainMod .. ' + SHIFT + code:' .. code,
    hl.dsp.window.move({ workspace = ws, follow = true })
  )

  -- Move workspace to active monitor and focus on it
  hl.bind(
    mainMod .. ' + CTRL + code:' .. code,
    hl.dsp.workspace.move({ workspace = ws, monitor = 'current' })
  )
end

-- Special Workspace
hl.bind(
  mainMod .. ' + SHIFT + S',
  hl.dsp.window.move({ workspace = 'special:magic', follow = true })
)

-- For toggling special workspace
hl.bind(mainMod .. ' + S', hl.dsp.workspace.toggle_special('magic'))

-- Workspace Navigation
hl.bind(mainMod .. ' + Tab', hl.dsp.focus({ workspace = 'm+1' }))
hl.bind(mainMod .. ' + SHIFT + Tab', hl.dsp.focus({ workspace = 'm-1' }))

-- Workspace Navigation
hl.bind(mainMod .. ' + mouse_down', hl.dsp.focus({ workspace = 'e+1' }))
hl.bind(mainMod .. ' + mouse_up', hl.dsp.focus({ workspace = 'e-1' }))

-- Empty Workspace
hl.bind(mainMod .. ' + CTRL + down', hl.dsp.focus({ workspace = 'empty' }))

-- System & Media Controls (Function Keys)
-- Volume
hl.bind(
  'XF86AudioRaiseVolume',
  hl.dsp.exec_cmd('wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+'),
  { repeating = true }
)
hl.bind(
  'XF86AudioLowerVolume',
  hl.dsp.exec_cmd('wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'),
  { repeating = true }
)
hl.bind(
  'XF86AudioMute',
  hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle')
)
hl.bind(
  'XF86AudioMicMute',
  hl.dsp.exec_cmd('wpctl set-mute @DEFAULT_SOURCE@ toggle')
)

-- Media Control
hl.bind('XF86AudioPlay', hl.dsp.exec_cmd('playerctl play-pause'))
hl.bind('XF86AudioPause', hl.dsp.exec_cmd('playerctl pause'))
hl.bind('XF86AudioNext', hl.dsp.exec_cmd('playerctl next'))
hl.bind('XF86AudioPrev', hl.dsp.exec_cmd('playerctl previous'))

-- Brightness
hl.bind('XF86MonBrightnessUp', hl.dsp.exec_cmd('brightnessctl -q s +10%'))
hl.bind('XF86MonBrightnessDown', hl.dsp.exec_cmd('brightnessctl -q s 10%-'))

-- Misc
hl.bind('XF86Calculator', hl.dsp.exec_cmd('qalculate-qt'))
hl.bind('XF86ScreenSaver', hl.dsp.exec_cmd('loginctl lock-session'))

-- Utilities, Scripts & Visuals
hl.bind(mainMod .. ' + CTRL + L', hl.dsp.exec_cmd('loginctl lock-session'))

hl.bind(mainMod .. ' + CTRL + Q', hl.dsp.exec_cmd('ags -t \'powermenu\''))
hl.bind(mainMod .. ' + SHIFT + B', hl.dsp.exec_cmd('killall -SIGUSR2 ags'))

hl.bind(mainMod .. ' + SHIFT + W', hl.dsp.exec_cmd('awww random'))
hl.bind(mainMod .. ' + CTRL + W', hl.dsp.exec_cmd('awww select'))

local sc_script = '@scScriptPath@'
local rec_script = '@recScriptPath@'

-- Screenshots
hl.bind(mainMod .. ' + PRINT', hl.dsp.exec_cmd(sc_script .. ' screen'))
hl.bind(mainMod .. ' + ALT + S', hl.dsp.exec_cmd(sc_script .. ' area'))
hl.bind(mainMod .. ' + ALT + F', hl.dsp.exec_cmd(sc_script .. ' active'))

-- Screen Recording
hl.bind(mainMod .. ' + ALT + R', hl.dsp.exec_cmd(rec_script .. ' screen'))
hl.bind(mainMod .. ' + SHIFT + R', hl.dsp.exec_cmd(rec_script .. ' area'))

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
hl.bind(mainMod .. ' + SHIFT + mouse_down', function() adjust_zoom(0.5) end)

-- Decrease display zoom
hl.bind(mainMod .. ' + SHIFT + mouse_up', function() adjust_zoom(-0.5) end)

-- Reset display zoom
hl.bind(
  mainMod .. ' + SHIFT + Z',
  function()
    hl.config({
      cursor = {
        zoom_factor = 1.0,
      },
    })
  end
)

-- Show keyboard layout on key press
hl.bind(
  mainMod .. ' + I',
  hl.dsp.exec_cmd('ags -r "App.openWindow(\'layout-preview\')"')
)

-- Hide keyboard layout on key release
hl.bind(
  mainMod .. ' + I',
  hl.dsp.exec_cmd('ags -r "App.closeWindow(\'layout-preview\')"'),
  { release = true }
)
