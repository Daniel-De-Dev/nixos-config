---@param client vim.lsp.Client
---@param path string
local function configure_python(client, path)
  client.settings.python = client.settings.python or {}
  client.settings.python.pythonPath = path
  client:notify('workspace/didChangeConfiguration', {
    settings = client.settings,
  })
end

---@param command { args: string }
local function set_python_path(command)
  local clients = vim.lsp.get_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = 'basedpyright',
  })

  for _, client in ipairs(clients) do
    configure_python(client, command.args)
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
    if client.settings.python and client.settings.python.pythonPath then
      return
    end

    local root = client.root_dir or client.config.root_dir
    if not root then return end

    local venv_path = root .. '/.venv/bin/python'
    if vim.fn.executable(venv_path) == 1 then
      configure_python(client, venv_path)
    end
  end,
  on_attach = function(_, bufnr)
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
