-- Dynamically check for a project-local binary first, fallback to the global Nix environment
local local_cmd = vim.fn.getcwd()
  .. '/node_modules/.bin/vscode-html-language-server'
local executable = vim.uv.fs_stat(local_cmd) and local_cmd
  or 'vscode-html-language-server'

-- The HTML LSP explicitly requires snippet support to be declared,
-- otherwise it drops completion items entirely.
---@type lsp.ClientCapabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()

if
  capabilities.textDocument
  and capabilities.textDocument.completion
  and capabilities.textDocument.completion.completionItem
then
  capabilities.textDocument.completion.completionItem.snippetSupport = true
end

---@type vim.lsp.Config
return {
  cmd = { executable, '--stdio' },
  filetypes = { 'html', 'templ' },
  root_markers = { 'package.json', '.git' },

  -- Inject the modified capabilities into the handshake
  capabilities = capabilities,

  settings = {},

  -- Explicitly type the initialization options to satisfy strict EmmyLua rules
  ---@type table
  init_options = {
    -- Allows the LSP to format the document
    provideFormatter = true,
    -- Tells the LSP to analyze inline <style> and <script> blocks
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { 'html', 'css', 'javascript' },
  },
}
