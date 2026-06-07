local oil = require('oil')

oil.setup({
  default_file_explorer = true,
  delete_to_trash = true,
  skip_confirm_for_simple_edits = true,
  prompt_save_on_select_new_entry = true,

  view_options = {
    show_hidden = true,
    natural_order = true,
    is_always_hidden = function(name, _) return name == '..' or name == '.git' end,
  },

  constrain_cursor = 'name',

  lsp_file_methods = {
    autosave_changes = true,
  },

  keymaps = {
    ['<C-h>'] = false,
    ['<C-l>'] = false,

    ['<C-s>'] = {
      'actions.select',
      opts = { vertical = true },
      desc = 'Oil: Open Split (Vertical)',
    },
    ['<M-h>'] = {
      'actions.select_split',
      desc = 'Oil: Open Split (Horizontal)',
    },
    ['<C-p>'] = { 'actions.preview', desc = 'Oil: Preview File' },

    ['<C-r>'] = { 'actions.refresh', desc = 'Oil: Refresh View (Reload)' },
    ['q'] = { 'actions.close', desc = 'Oil: Close Window (Quit)' },
    ['g.'] = { 'actions.toggle_hidden', desc = 'Oil: Toggle Hidden Files' },

    ['yp'] = {
      callback = function()
        local entry = oil.get_cursor_entry()
        if entry then
          local path = oil.get_current_dir() .. entry.name
          vim.fn.setreg('+', path)
          vim.notify('Path copied to clipboard')
        end
      end,
      desc = 'Oil: Copy Path (System Clipboard)',
    },

    ['<leader>ff'] = {
      callback = function()
        local dir = oil.get_current_dir()
        if dir then require('fzf-lua').files({ cwd = dir }) end
      end,
      desc = 'Oil: Find Files (Current Directory)',
    },

    ['<leader>t'] = {
      callback = function()
        local dir = oil.get_current_dir()
        if dir then
          vim.cmd('split')
          vim.cmd('lcd ' .. vim.fn.fnameescape(dir))
          vim.cmd('terminal ' .. (os.getenv('SHELL') or '/bin/sh'))
        end
      end,
      desc = 'Oil: Open Terminal (Shell)',
    },
  },

  columns = {
    'icon',
    'permissions',
    'size',
    'mtime',
  },

  float = {
    padding = 2,
    max_width = 120,
    max_height = 0.8,
    border = 'rounded',
    win_options = {
      winblend = 0,
    },
  },
})

-- Global Keymaps
local map = function(mode, lhs, rhs, opts) vim.keymap.set(mode, lhs, rhs, opts) end

map(
  'n',
  '-',
  '<CMD>Oil<CR>',
  { desc = 'Oil: Open Parent Directory (File Explorer)' }
)
map(
  'n',
  '<leader>-',
  function() oil.toggle_float() end,
  { desc = 'Oil: Toggle Float Explorer' }
)
