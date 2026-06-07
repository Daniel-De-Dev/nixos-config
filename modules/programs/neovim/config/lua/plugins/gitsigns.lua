vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('GitsignsLazyLoad', { clear = true }),
  callback = function()
    local gs = require('gitsigns')

    gs.setup({
      numhl = true,
      attach_to_untracked = true,
      preview_config = {
        border = 'rounded',
      },
    })

    local map = function(mode, lhs, rhs, opts)
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    -- Hunk navigation
    map(
      'n',
      '<leader>gj',
      function() gs.nav_hunk('next') end,
      { desc = 'Git: Next Hunk (Jump)' }
    )
    map(
      'n',
      '<leader>gk',
      function() gs.nav_hunk('prev') end,
      { desc = 'Git: Previous Hunk (Jump)' }
    )
    map('n', '<leader>gK', function()
      vim.cmd.normal({ 'gg0', bang = true })
      gs.nav_hunk('next')
    end, { desc = 'Git: First Hunk (Top)' })
    map('n', '<leader>gJ', function()
      vim.cmd.normal({ 'G$', bang = true })
      gs.nav_hunk('prev')
    end, { desc = 'Git: Last Hunk (Bottom)' })

    -- Hunk actions
    map(
      { 'n', 'v' },
      '<leader>gs',
      gs.stage_hunk,
      { desc = 'Git: Toggle Stage Hunk' }
    )
    map(
      'n',
      '<leader>gS',
      gs.stage_buffer,
      { desc = 'Git: Stage Buffer (All)' }
    )
    map(
      { 'n', 'v' },
      '<leader>gr',
      gs.reset_hunk,
      { desc = 'Git: Reset Hunk (Undo)' }
    )
    map(
      'n',
      '<leader>gR',
      gs.reset_buffer,
      { desc = 'Git: Reset Buffer (Undo All)' }
    )
    map('n', '<leader>gp', gs.preview_hunk, { desc = 'Git: Preview Hunk' })

    -- Blame & diff
    map(
      'n',
      '<leader>gb',
      gs.toggle_current_line_blame,
      { desc = 'Git: Toggle Line Blame' }
    )
    map('n', '<leader>gd', gs.diffthis, { desc = 'Git: Diff against Index' })
    map(
      'n',
      '<leader>gD',
      function() gs.diffthis('~') end,
      { desc = 'Git: Diff against Last Commit (HEAD~1)' }
    )

    return true
  end,
})
