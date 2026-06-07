-- Global Default Capabilities
---@type lsp.ClientCapabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()

vim.lsp.config('*', { capabilities = capabilities })

-- Global Diagnostics Config
vim.diagnostic.config({
  signs = true,
  underline = true,
  virtual_text = true,
})

-- Universal LSP Attach Behaviour
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', { clear = true }),
  callback = function(args)
    local bufnr = args.buf

    ---@type vim.lsp.Client|nil
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then return end

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map('n', 'gd', vim.lsp.buf.definition, 'LSP: Goto Definition')
    map(
      'n',
      '<leader>ld',
      vim.diagnostic.open_float,
      'LSP: Show Line Diagnostics'
    )

    -- Inlay Hints
    if client:supports_method('textDocument/inlayHint', bufnr) then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

      map(
        'n',
        '<leader>th',
        function()
          vim.lsp.inlay_hint.enable(
            not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
            { bufnr = bufnr }
          )
        end,
        'LSP: Toggle Inlay Hints'
      )
    end
  end,
})

-- Server Activation Layer
local servers = {
  lua_ls = 'lua-language-server',
  nixd = 'nixd',
  bashls = 'bash-language-server',
  fish_lsp = 'fish-lsp',
  marksman = 'marksman',
  basedpyright = 'basedpyright-langserver',
  ruff = 'ruff',
  rust_analyzer = 'rust-analyzer',
  html = 'vscode-html-language-server',
  ts_ls = 'typescript-language-server',
  astro = 'astro-ls',
  css_variables = 'css-variables-language-server',
}

for server_name, executable in pairs(servers) do
  if vim.fn.executable(executable) == 1 then
    -- Load the configuration table from lua/lsp/<server_name>.lua
    ---@type boolean, vim.lsp.Config
    local ok, server_config = pcall(require, 'lsp.' .. server_name)

    if ok then
      vim.lsp.config(server_name, server_config)
    else
      vim.notify(
        'Warning: No config file found at lua/lsp/' .. server_name .. '.lua',
        vim.log.levels.WARN
      )
    end

    vim.lsp.enable(server_name)
  else
    vim.notify(
      'LSP executable not found in PATH: ' .. executable,
      vim.log.levels.WARN
    )
  end
end
