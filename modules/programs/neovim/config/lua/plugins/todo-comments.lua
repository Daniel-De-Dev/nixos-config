vim.api.nvim_create_autocmd('BufReadPost', {
  group = vim.api.nvim_create_augroup('TodoCommentsLazyLoad', { clear = true }),
  callback = function()
    local todo = require('todo-comments')

    todo.setup({
      signs = true,
      highlight = {
        multiline = true,
        keyword = 'wide',
        after = 'fg',
        pattern = [[.*<(KEYWORDS)\s*:]],
      },
      search = {
        command = 'rg',
        args = {
          '--color=never',
          '--no-heading',
          '--with-filename',
          '--line-number',
          '--column',
        },
        pattern = [[\b(KEYWORDS):]],
      },
    })

    -- Global Keymaps
    local map = function(mode, lhs, rhs, opts)
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    map(
      'n',
      '<leader>st',
      '<cmd>TodoFzfLua<cr>',
      { desc = 'Fzf: Search TODOs' }
    )
    map(
      'n',
      '<leader>sT',
      '<cmd>TodoFzfLua keywords=TODO,FIXME<cr>',
      { desc = 'Fzf: Search TODO/FIXME only' }
    )

    map(
      'n',
      ']t',
      function() todo.jump_next() end,
      { desc = 'Next TODO comment' }
    )
    map(
      'n',
      '[t',
      function() todo.jump_prev() end,
      { desc = 'Previous TODO comment' }
    )

    return true
  end,
})
