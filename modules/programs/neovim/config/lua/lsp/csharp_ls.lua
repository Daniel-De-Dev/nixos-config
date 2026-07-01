---@type vim.lsp.Config
return {
  cmd = { 'csharp-ls' },
  filetypes = { 'cs' },

  root_dir = vim.fs.root(0, { '.sln', '.csproj', '.git' }),

  init_options = {
    AutomaticWorkspaceInit = true,
  },

  settings = {
    csharp = {
      inlayHints = {
        enableInlayHintsForParameters = true,
        enableInlayHintsForLiteralParameters = true,
        enableInlayHintsForTypes = true,
        enableInlayHintsForIndexerParameters = true,
        enableInlayHintsForObjectCreationParameters = true,
      },
    },
  },
}
