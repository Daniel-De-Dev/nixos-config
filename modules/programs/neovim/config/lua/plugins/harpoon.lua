local harpoon = require('harpoon')

harpoon:setup({
  settings = {
    save_on_toggle = true,
    sync_on_ui_close = true,
    key = function() return vim.fn.getcwd() end,
  },
})

-- Global Keymaps
local map = function(mode, lhs, rhs, opts) vim.keymap.set(mode, lhs, rhs, opts) end

map('n', '<leader>a', function()
  harpoon:list():add()
  vim.notify('File added to Harpoon', vim.log.levels.INFO)
end, { desc = 'Harpoon: Add File (Mark)' })

map(
  'n',
  '<C-e>',
  function()
    harpoon.ui:toggle_quick_menu(harpoon:list(), {
      border = 'rounded',
      title = ' Harpoon ',
      title_pos = 'center',
      ui_width_ratio = 0.6,
    })
  end,
  { desc = 'Harpoon: Toggle Menu (List/UI)' }
)

map(
  'n',
  '<leader>1',
  function() harpoon:list():select(1) end,
  { desc = 'Harpoon: Go to File 1 (Jump)' }
)
map(
  'n',
  '<leader>2',
  function() harpoon:list():select(2) end,
  { desc = 'Harpoon: Go to File 2 (Jump)' }
)
map(
  'n',
  '<leader>3',
  function() harpoon:list():select(3) end,
  { desc = 'Harpoon: Go to File 3 (Jump)' }
)
map(
  'n',
  '<leader>4',
  function() harpoon:list():select(4) end,
  { desc = 'Harpoon: Go to File 4 (Jump)' }
)

map(
  'n',
  '<leader>hn',
  function() harpoon:list():next() end,
  { desc = 'Harpoon: Next File (Cycle)' }
)
map(
  'n',
  '<leader>hp',
  function() harpoon:list():prev() end,
  { desc = 'Harpoon: Previous File (Cycle)' }
)

map('n', '<leader>hc', function()
  harpoon:list():clear()
  vim.notify('Harpoon list cleared', vim.log.levels.INFO)
end, { desc = 'Harpoon: Clear All Marks' })
