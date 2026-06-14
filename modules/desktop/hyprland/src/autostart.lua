-- Force GTK applications to prefer the dark theme variant
hl.dsp.exec_cmd(
  'gsettings set org.gnome.desktop.interface color-scheme \'prefer-dark\''
)

-- Cursor Configuration
hl.dsp.exec_cmd('hyprctl setcursor @cursorTheme@ @cursorSize@')

-- Application Autostart
hl.dsp.exec_cmd('[workspace special silent] protonvpn-app')
