-- Run once the compositor is ready.
hl.on('hyprland.start', function()
  hl.exec_cmd('@uwsm@ finalize QT_QPA_PLATFORM GDK_BACKEND')
  hl.exec_cmd('@hyprctl@ setcursor @cursorTheme@ @cursorSize@')
end)

-- TODO: Manage Proton VPN startup separately. The old dispatcher-only call
-- never launched it.
