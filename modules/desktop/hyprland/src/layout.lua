hl.config({
  dwindle = {
    preserve_split = true,
    smart_split = false,
  },

  master = {
    new_status = 'master',
    mfact = 0.50,
  },

  -- Global Binding Behaviors
  binds = {
    workspace_back_and_forth = false,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },
})
