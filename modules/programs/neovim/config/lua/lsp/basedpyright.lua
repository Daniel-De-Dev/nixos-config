-- Dynamically swaps the Python executable path and restarts the analysis tree
---@param command { args: string }
local function set_python_path(command)
  local path = command.args

  ---@type vim.lsp.Client[]
  local clients = vim.lsp.get_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'basedpyright',
  })

  for _, client in ipairs(clients) do
    if client.settings then
      ---@diagnostic disable-next-line: param-type-mismatch
      client.settings.basedpyright = vim.tbl_deep_extend(
        'force',
        client.settings.basedpyright or {},
        { pythonPath = path }
      )
    else
      client.config.settings = vim.tbl_deep_extend(
        'force',
        client.config.settings,
        { basedpyright = { pythonPath = path } }
      )
    end
    client:notify('workspace/didChangeConfiguration', { settings = nil })
  end
end

---@type vim.lsp.Config
return {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = {
    'uv.lock',
    'pyproject.toml',
    'setup.py',
    'requirements.txt',
    '.git',
  },
  ---@type table
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = 'openFilesOnly',
        typeCheckingMode = 'recommended',
      },
    },
  },
  on_init = function(client)
    local venv_path = vim.fn.getcwd() .. '/.venv/bin/python'
    if vim.uv.fs_stat(venv_path) then
      local current_settings = client.config.settings.basedpyright or {}
      ---@cast current_settings table
      current_settings.pythonPath = venv_path
      client.config.settings.basedpyright = current_settings
    end
  end,
  on_attach = function(_, bufnr)
    -- Provides the runtime command to point the LSP at a specific /nix/store/ python binary
    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspPyrightSetPythonPath',
      set_python_path,
      {
        desc = 'Reconfigure basedpyright with the provided python path',
        nargs = 1,
        complete = 'file',
      }
    )
  end,
}
