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
  python = true,
  c_sharp = true,
}

vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  group = vim.api.nvim_create_augroup('TreesitterNative', { clear = true }),
  pattern = '*',
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if not supported_filetypes[ft] then return end

    if args.event == 'FileType' then pcall(vim.treesitter.start, args.buf) end

    vim.bo[args.buf].indentexpr =
      'v:lua.require\'nvim-treesitter\'.indentexpr()'
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})
