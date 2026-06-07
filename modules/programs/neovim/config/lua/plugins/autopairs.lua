vim.api.nvim_create_autocmd('InsertEnter', {
  group = vim.api.nvim_create_augroup('MiniPairsLazyLoad', { clear = true }),
  callback = function()
    require('mini.pairs').setup({})
    return true
  end,
})
