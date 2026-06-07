vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('LazyDevLoad', { clear = true }),
  pattern = 'lua',
  callback = function()
    require('lazydev').setup({
      library = {},
    })
    return true
  end,
})
