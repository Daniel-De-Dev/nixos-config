local function switch_source_header(bufnr, client)
  local method_name = 'textDocument/switchSourceHeader'
  if not client or not client:supports_method(method_name) then
    return vim.notify(
      ('method %s is not supported'):format(method_name),
      vim.log.levels.WARN
    )
  end
  local params = vim.lsp.util.make_text_document_params(bufnr)
  client:request(method_name, params, function(err, result)
    if err then error(tostring(err)) end
    if not result then
      return vim.notify('corresponding file cannot be determined')
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end

local function symbol_info(bufnr, client)
  local method_name = 'textDocument/symbolInfo'
  if not client or not client:supports_method(method_name) then
    return vim.notify('Clangd client not found', vim.log.levels.ERROR)
  end
  local win = vim.api.nvim_get_current_win()
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
  client:request(method_name, params, function(err, res)
    if err or #res == 0 then return end
    local container = string.format('container: %s', res[1].containerName)
    local name = string.format('name: %s', res[1].name)
    vim.lsp.util.open_floating_preview({ name, container }, '', {
      height = 2,
      width = math.max(string.len(name), string.len(container)),
      focusable = false,
      focus = false,
      title = 'Symbol Info',
    })
  end, bufnr)
end

---@type vim.lsp.Config
return {
  cmd = {
    'clangd',
    '--background-index',
    '--clang-tidy',
    -- Force aggressive linting for modern practices and safety
    '--clang-tidy-checks=bugprone-*,cert-*,misc-*,performance-*,readability-*,modernize-*,-readability-magic-numbers',
    '--header-insertion=iwyu',
    '--completion-style=detailed',
    '--function-arg-placeholders',
    '--fallback-style=llvm',
  },

  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },

  root_markers = {
    '.clangd',
    '.clang-tidy',
    '.clang-format',
    'compile_commands.json',
    'compile_flags.txt',
    'configure.ac',
    '.git',
  },

  get_language_id = function(_, ftype)
    local t =
      { objc = 'objective-c', objcpp = 'objective-cpp', cuda = 'cuda-cpp' }
    return t[ftype] or ftype
  end,

  capabilities = {
    offsetEncoding = { 'utf-8', 'utf-16' },
  },

  on_init = function(client, init_result)
    if init_result.offsetEncoding then
      client.offset_encoding = init_result.offsetEncoding
    end
  end,

  on_attach = function(client, bufnr)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspClangdSwitchSourceHeader',
      function() switch_source_header(bufnr, client) end,
      { desc = 'Clangd: Switch between source and header' }
    )

    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspClangdShowSymbolInfo',
      function() symbol_info(bufnr, client) end,
      { desc = 'Clangd: Show symbol info' }
    )
  end,
}
