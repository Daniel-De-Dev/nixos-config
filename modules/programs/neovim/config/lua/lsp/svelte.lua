---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local executable = 'svelteserver'
    if config.root_dir then
      local local_cmd = config.root_dir .. '/node_modules/.bin/svelteserver'
      if vim.fn.executable(local_cmd) == 1 then executable = local_cmd end
    end
    return vim.lsp.rpc.start({ executable, '--stdio' }, dispatchers)
  end,
  filetypes = { 'svelte' },
  root_markers = {
    {
      'svelte.config.js',
      'svelte.config.ts',
      'svelte.config.mjs',
      'svelte.config.cjs',
      'package.json',
    },
    '.git',
  },

  before_init = function(params)
    -- Neovim 0.11 cannot refresh pull diagnostics after an imported file changes.
    local workspace = params.capabilities.workspace or {}
    if not (workspace.diagnostics and workspace.diagnostics.refreshSupport) then
      params.capabilities.textDocument.diagnostic = nil
    end
  end,
  on_init = function(client)
    -- Server 0.18 advertises pull diagnostics even when push mode was selected.
    if not client.capabilities.textDocument.diagnostic then
      client.server_capabilities.diagnosticProvider = nil
    end
  end,

  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = 'all' },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
  },

  on_attach = function(client, bufnr)
    vim.keymap.set(
      'n',
      '<leader>lf',
      function() vim.lsp.buf.format({ bufnr = bufnr, id = client.id }) end,
      { buffer = bufnr, desc = 'LSP: Format Svelte' }
    )

    -- Svelte needs an explicit notification when an imported JS/TS file changes.
    -- One watcher per client avoids duplicate notifications with many components.
    local group = vim.api.nvim_create_augroup(
      'SvelteTsJsChanges_' .. client.id,
      { clear = true }
    )
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = group,
      pattern = {
        '*.js',
        '*.jsx',
        '*.mjs',
        '*.cjs',
        '*.ts',
        '*.tsx',
        '*.mts',
        '*.cts',
      },
      callback = function(args)
        if client:is_stopped() then return true end
        local root = client.config.root_dir
        local path = vim.fs.normalize(args.match)
        if root and vim.startswith(path, vim.fs.normalize(root) .. '/') then
          client:notify('$/onDidChangeTsOrJsFile', {
            uri = vim.uri_from_fname(path),
          })
        end
      end,
    })
  end,
}
