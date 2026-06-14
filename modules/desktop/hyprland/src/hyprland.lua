-- Core Configuration
dofile('@inputConfPath@')
dofile('@autostartConfPath@')
dofile('@themeConfPath@')
dofile('@layoutConfPath@')
dofile('@miscConfPath@')
dofile('@bindsConfPath@')
dofile('@monitorsConfPath@')
-- dofile("rulesConfPath")

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },
})
