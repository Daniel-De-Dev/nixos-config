---@module 'fzf-lua'
---@type table
local fzf = require('fzf-lua')

fzf.setup({
  winopts = {
    height = 0.85,
    width = 0.9,
    preview = {
      default = 'bat',
      hidden = 'nohidden',
      layout = 'flex',
      flip_columns = 120,
    },
  },

  -- FZF binary specific overrides (Smart case, history, ignores)
  fzf_opts = {
    ['--history'] = vim.fn.stdpath('data') .. '/fzf_history',
    ['--bind'] = 'ctrl-up:previous-history,ctrl-down:next-history',
  },

  -- Picker specific overrides
  files = {
    hidden = true,
    fd_opts = '--color=never --type f --hidden --follow --exclude .git',
  },

  grep = {
    rg_opts = '--hidden --glob "!.git/*" --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e',
  },

  buffers = {
    previewer = false,
    sort_mru = true,
    ignore_current_buffer = true,
    winopts = {
      width = 0.5,
      height = 0.4,
    },
    actions = {
      ['ctrl-d'] = { fzf.actions.buf_del, fzf.actions.resume },
    },
  },

  lsp = {
    symbols = {
      symbol_style = 1,
    },
  },
})

fzf.register_ui_select()

-- Global Keymaps
local map = function(mode, lhs, rhs, opts) vim.keymap.set(mode, lhs, rhs, opts) end

map('n', '<leader>ff', fzf.files, { desc = 'Fzf: Find Files (Root)' })
map('n', '<leader>fb', fzf.buffers, { desc = 'Fzf: Open Buffers' })
map('n', '<leader>fh', fzf.help_tags, { desc = 'Fzf: Help Tags' })
map('n', '<leader>/', fzf.blines, { desc = 'Fzf: Fuzzy Find in Buffer' })

map('n', '<leader>fr', fzf.resume, { desc = 'Fzf: Resume Last Search' })
map('n', '<leader>fo', fzf.oldfiles, { desc = 'Fzf: Old Files (History)' })

map(
  'n',
  '<leader>sn',
  function() fzf.files({ cwd = vim.fn.stdpath('config') }) end,
  { desc = 'Fzf: Search Neovim Config (Dotfiles)' }
)

map(
  'n',
  '<leader>fg',
  fzf.live_grep,
  { desc = 'Fzf: Live Grep (Project Search)' }
)
map('n', '<leader>sk', fzf.keymaps, { desc = 'Fzf: Keymaps' })
map(
  'n',
  '<leader>sd',
  fzf.lsp_document_symbols,
  { desc = 'Fzf: Document Symbols (LSP)' }
)
map(
  'n',
  '<leader>sw',
  fzf.lsp_workspace_symbols,
  { desc = 'Fzf: Workspace Symbols (LSP)' }
)

map('n', '<leader>fd', function()
  fzf.fzf_exec('fd --type d --hidden --exclude .git', {
    prompt = 'Directories❯ ',
    actions = {
      ['default'] = function(selected)
        if selected and #selected > 0 then require('oil').open(selected[1]) end
      end,
    },
  })
end, { desc = 'Fzf: Find Directories (Oil)' })
