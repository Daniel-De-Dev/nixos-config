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

    -- Custom toggle for intent-to-add
    local function toggle_intent_to_add()
      local file = vim.api.nvim_buf_get_name(0)
      if file == '' then return end

      -- Check if the file is currently tracked by Git
      local check =
        vim.system({ 'git', 'ls-files', '--error-unmatch', file }):wait()

      if check.code ~= 0 then
        -- Add intent-to-track
        vim.system({ 'git', 'add', '--intent-to-add', file }):wait()
        vim.notify(
          'Tracking intent added: ' .. vim.fn.fnamemodify(file, ':t'),
          vim.log.levels.INFO
        )
      else
        -- Untrack it
        vim.system({ 'git', 'rm', '--cached', file }):wait()
        vim.notify(
          'Untracked: ' .. vim.fn.fnamemodify(file, ':t'),
          vim.log.levels.INFO
        )
      end

      require('gitsigns').refresh()
    end

    map(
      'n',
      '<leader>gi',
      toggle_intent_to_add,
      { desc = 'Git: Toggle Intent-to-Add' }
    )

    return true
  end,
})
