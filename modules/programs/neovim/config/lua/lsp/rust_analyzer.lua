local function reload_workspace(bufnr)
  ---@type vim.lsp.Client[]
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'rust_analyzer' })

  for _, client in ipairs(clients) do
    vim.notify('Reloading Cargo Workspace', vim.log.levels.INFO)

    ---@diagnostic disable-next-line: param-type-mismatch
    client:request('rust-analyzer/reloadWorkspace', nil, function(err)
      if err then error(tostring(err)) end
      vim.notify('Cargo workspace reloaded', vim.log.levels.INFO)
    end, 0)
  end
end

---@type vim.lsp.Config
return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },

  -- rust-analyzer requires settings to be passed here during the initial handshake
  ---@type table
  initializationOptions = {
    lens = {
      debug = { enable = true },
      enable = true,
      implementations = { enable = true },
      references = {
        adt = { enable = true },
        enumVariant = { enable = true },
        method = { enable = true },
        trait = { enable = true },
      },
      run = { enable = true },
      updateTest = { enable = true },
    },
  },

  on_init = function()
    -- Native execution handler for the 'Run' codelens
    ---@param command table
    vim.lsp.commands['rust-analyzer.runSingle'] = function(command)
      ---@type { args: { cargoArgs: string[], executableArgs?: string[], cwd?: string, environment?: table } }
      local r = command.arguments[1]
      local cmd = { 'cargo', unpack(r.args.cargoArgs) }

      if r.args.executableArgs and #r.args.executableArgs > 0 then
        vim.list_extend(cmd, { '--', unpack(r.args.executableArgs) })
      end

      local proc =
        vim.system(cmd, { cwd = r.args.cwd, env = r.args.environment })
      local result = proc:wait()

      if result.code == 0 then
        vim.notify(result.stdout, vim.log.levels.INFO)
      else
        vim.notify(result.stderr, vim.log.levels.ERROR)
      end
    end
  end,

  on_attach = function(_, bufnr)
    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspCargoReload',
      function() reload_workspace(bufnr) end,
      { desc = 'Reload current cargo workspace' }
    )
  end,
}
