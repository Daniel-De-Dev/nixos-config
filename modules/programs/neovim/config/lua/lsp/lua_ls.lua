---@type vim.lsp.Config
return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = {
    { '.emmyrc.json', '.luarc.json', '.luarc.jsonc' },
    {
      '.luacheckrc',
      '.stylua.toml',
      'stylua.toml',
      'selene.toml',
      'selene.yml',
    },
    { '.git' },
  },
  on_init = function(client)
    -- Dynamically inject Neovim runtime only if we are in a Neovim config context
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
        path ~= vim.fn.stdpath('config')
        and (
          vim.uv.fs_stat(path .. '/.luarc.json')
          or vim.uv.fs_stat(path .. '/.luarc.jsonc')
        )
      then
        return
      end
    end

    local current_settings = client.config.settings.Lua or {}
    ---@cast current_settings table

    local library = { vim.env.VIMRUNTIME }
    local hyprland_stubs = os.getenv('HYPRLAND_STUBS')

    if hyprland_stubs and vim.uv.fs_stat(hyprland_stubs) then
      table.insert(library, hyprland_stubs)
    end

    client.config.settings.Lua =
      vim.tbl_deep_extend('force', current_settings, {
        runtime = {
          version = 'LuaJIT',
          path = {
            'lua/?.lua',
            'lua/?/init.lua',
          },
        },
        workspace = {
          checkThirdParty = false,
          library = library,
        },
      })
  end,
  settings = {
    Lua = {
      diagnostics = {
        disable = { 'spell-check', 'name-style-check', 'codestyle-check' },
        globals = { 'vim' },
        groupFileStatus = {
          strong = 'Opened',
          await = 'Opened',
          codestyle = 'Opened',
          luadoc = 'Opened',
        },
        neededFileStatus = {
          ['global-elements'] = 'Opened',
        },
        groupSeverity = {
          ['type-check'] = 'Error',
          ambiguity = 'Error',
          global = 'Error',
          unbalanced = 'Error',
          strong = 'Error',
          await = 'Error',
          unused = 'Warning',
          redefined = 'Warning',
          codestyle = 'Hint',
          luadoc = 'Information',
        },
        severity = {
          ['lowercase-global'] = 'Warning',
        },
      },
      completion = {
        callSnippet = 'Replace',
      },
      type = {
        castNumberToInteger = true,
        inferParamType = true,
      },
      hint = {
        enable = true,
        setType = true,
        awaitPropagate = true,
      },
      format = {
        enable = false,
        defaultConfig = {
          indent_size = '2',
        },
      },
    },
  },
}
