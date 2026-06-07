vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('FidgetLazyLoad', { clear = true }),
  callback = function()
    require('fidget').setup({})
    return true
  end,
})
