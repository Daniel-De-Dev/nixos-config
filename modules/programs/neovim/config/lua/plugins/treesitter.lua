local supported_filetypes = {
  lua = true,
  nix = true,
  bash = true,
  markdown = true,
  gitconfig = true,
  diff = true,
  rust = true,
  javascript = true,
  typescript = true,
  typescriptreact = true,
  css = true,
  html = true,
  astro = true,
  svelte = true,
  python = true,
  c_sharp = true,
}

vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  group = vim.api.nvim_create_augroup('TreesitterNative', { clear = true }),
  pattern = '*',
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if not supported_filetypes[ft] then return end

    -- Retry when entering a buffer if its parser was unavailable at FileType.
    if not vim.treesitter.highlighter.active[args.buf] then
      local ok, err = pcall(vim.treesitter.start, args.buf)
      if not ok then
        vim.notify_once('Tree-sitter: ' .. tostring(err), vim.log.levels.WARN)
        return
      end
    end

    vim.bo[args.buf].indentexpr =
      'v:lua.require\'nvim-treesitter\'.indentexpr()'
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})
