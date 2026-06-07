---@type vim.lsp.Config
return {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'sh', 'bash' },
  root_markers = { '.git' },
  settings = {
    bashIde = {
      shellcheckArguments = {
        '--enable=all',
        '--external-sources',
      },
      globPattern = '*@(.sh|.inc|.bash|.command)',
    },
  },
}
