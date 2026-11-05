-- Verify the actual wrapped editor after its normal startup sequence.
local ok, err = pcall(function()
  assert(vim.v.errmsg == '', 'startup error: ' .. vim.v.errmsg)
  assert(package.loaded['core.lsp'], 'repository configuration was not loaded')
  assert(vim.g.colors_name == 'darkvoid', 'repository theme was not loaded')
  assert(
    vim.env.NVIM_APPNAME == 'nixos-config-nvim',
    'app data is not isolated'
  )
  assert(not vim.g.unexpected_user_plugin, 'user plugins leaked into the app')

  local project_config = vim.env.NVIM_TEST_PROJECT_CONFIG
  if project_config then
    local expected = project_config == 'trusted'
    assert(
      (vim.g.nvim_project_config_loaded == true) == expected,
      'project configuration did not respect native trust'
    )
  end

  for _, executable in ipairs({ 'git', 'bat', 'nixd', 'fzf' }) do
    assert(
      vim.fn.executable(executable) == 1,
      'missing runtime tool: ' .. executable
    )
  end
end)

if not ok then
  vim.api.nvim_err_writeln(tostring(err))
  vim.cmd('cquit 1')
else
  vim.cmd('qa!')
end
