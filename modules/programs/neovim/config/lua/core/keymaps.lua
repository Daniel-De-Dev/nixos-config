-- Fixes the EmmyLua type inference error for `vim.keymap.set`
local map = function(mode, lhs, rhs, opts) vim.keymap.set(mode, lhs, rhs, opts) end

-- Normal mode mappings
map('n', '<leader>w', '<cmd>w<CR>', { desc = 'Buffer: Save (Write)' })
map('n', '<leader>qq', '<cmd>q<CR>', { desc = 'Editor: Quit Neovim' })
map(
  'n',
  '<Esc>',
  '<cmd>nohlsearch<CR>',
  { desc = 'Editor: Clear Search Highlight' }
)
map(
  'n',
  '<leader>x',
  '<cmd>bp<bar>bd #<CR>',
  { desc = 'Buffer: Close (Delete)' }
)

-- Remap switching between windows
map('n', '<C-h>', '<C-w>h', { desc = 'Window: Focus Left' })
map('n', '<C-j>', '<C-w>j', { desc = 'Window: Focus Down' })
map('n', '<C-k>', '<C-w>k', { desc = 'Window: Focus Up' })
map('n', '<C-l>', '<C-w>l', { desc = 'Window: Focus Right' })

map('n', '<C-d>', '<C-d>zz', { desc = 'Scroll Down & Center' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Scroll Up & Center' })
map('n', 'n', 'nzzzv', { desc = 'Next Search Result & Center' })
map('n', 'N', 'Nzzzv', { desc = 'Prev Search Result & Center' })

map('v', 'J', ':m \'>+1<CR>gv=gv', { desc = 'Move Selection Down' })
map('v', 'K', ':m \'<-2<CR>gv=gv', { desc = 'Move Selection Up' })

map('v', 'p', '"_dP', { desc = 'Paste Over (Keep Register)' })

-- Disable arrow keys in normal, visual, and insert modes
local modes = { 'n', 'v', 'i' }
for _, m in ipairs(modes) do
  map(
    m,
    '<Up>',
    '<Nop>',
    { silent = true, desc = 'Editor: Disable Up Arrow (Hard Mode)' }
  )
  map(
    m,
    '<Down>',
    '<Nop>',
    { silent = true, desc = 'Editor: Disable Down Arrow (Hard Mode)' }
  )
  map(
    m,
    '<Left>',
    '<Nop>',
    { silent = true, desc = 'Editor: Disable Left Arrow (Hard Mode)' }
  )
  map(
    m,
    '<Right>',
    '<Nop>',
    { silent = true, desc = 'Editor: Disable Right Arrow (Hard Mode)' }
  )
end
