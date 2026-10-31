-- Project specific lint integration
local root = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local ags = vim.fs.joinpath(root, 'packages', 'ags-shell')

vim.lsp.config('ags_eslint', {
  cmd = { 'vscode-eslint-language-server', '--stdio' },
  filetypes = { 'typescript', 'typescriptreact' },
  root_dir = function(bufnr, on_dir)
    local file = vim.api.nvim_buf_get_name(bufnr)
    if vim.fs.root(file, 'eslint.config.mjs') == ags then on_dir(ags) end
  end,
  settings = {
    validate = 'on',
    run = 'onType',
    format = false,
    quiet = false,
    onIgnoredFiles = 'off',
    nodePath = vim.fs.joinpath(ags, 'node_modules'),
    workingDirectory = { mode = 'location' },
    codeActionOnSave = { enable = false, mode = 'all' },
    rulesCustomizations = {},
  },
})

if vim.fn.executable('vscode-eslint-language-server') == 1 then
  vim.lsp.enable('ags_eslint')
end
