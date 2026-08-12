require('typst-preview').setup({
  dependencies_bin = {
    tinymist = 'tinymist',
    websocat = 'websocat',
  },

  get_main_file = function(path_of_buffer)
    local root = vim.fs.root(path_of_buffer, { 'typst.toml', '.git' })
    if not root then return path_of_buffer end

    local main_file = root .. '/main.typ'

    if vim.fn.filereadable(main_file) == 1 then return main_file end

    return path_of_buffer
  end,

  invert_colors = 'auto',
})

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('TypstPreviewKeymaps', { clear = true }),
  pattern = 'typst',

  callback = function(args)
    vim.keymap.set('n', '<leader>tp', '<cmd>TypstPreviewToggle<CR>', {
      buffer = args.buf,
      desc = 'Typst: Toggle Preview',
    })
  end,
})
