-- Global Default Capabilities
---@type lsp.ClientCapabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()

-- blink.cmp capabilities are merged to receive snippets and auto-imports
local has_blink, blink = pcall(require, 'blink.cmp')
if has_blink then capabilities = blink.get_lsp_capabilities(capabilities) end

vim.lsp.config('*', { capabilities = capabilities })

-- Global Diagnostics Config
vim.diagnostic.config({
  signs = true,
  underline = true,
  virtual_text = true,
  update_in_insert = false,
  severity_sort = true,
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
    map('n', 'K', vim.lsp.buf.hover, 'LSP: Hover Documentation')
    map(
      'n',
      '<leader>ld',
      vim.diagnostic.open_float,
      'LSP: Show Line Diagnostics'
    )
    map('n', '<leader>rn', vim.lsp.buf.rename, 'LSP: Rename Symbol')
    map({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, 'LSP: Code Action')
    map('n', 'gr', vim.lsp.buf.references, 'LSP: References')

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

local activation_group =
  vim.api.nvim_create_augroup('LspActivation', { clear = true })

for server_name, executable in pairs(servers) do
  -- Load the configuration table from lua/lsp/<server_name>.lua
  ---@type boolean, vim.lsp.Config
  local ok, server_config = pcall(require, 'lsp.' .. server_name)

  if ok then
    -- Register the configuration natively
    vim.lsp.config(server_name, server_config)

    -- If the config specifies filetypes, defer the executable check and enablement
    if server_config.filetypes then
      vim.api.nvim_create_autocmd('FileType', {
        group = activation_group,
        pattern = server_config.filetypes,
        callback = function()
          -- Check for the binary only when opening a matching file
          if vim.fn.executable(executable) == 1 then
            vim.lsp.enable(server_name)
          end
          return true
        end,
      })
    else
      -- Fallback if no filetypes are defined in the modular config file
      if vim.fn.executable(executable) == 1 then vim.lsp.enable(server_name) end
    end
  else
    -- If the configuration file itself is missing
    vim.notify(
      'Warning: No config file found at lua/lsp/' .. server_name .. '.lua',
      vim.log.levels.WARN
    )
  end
end
