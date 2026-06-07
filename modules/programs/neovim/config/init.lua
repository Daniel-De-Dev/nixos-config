vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require('core.options')
require('core.keymaps')

-- Initialize Plugins
require('plugins.darkvoid')
require('plugins.treesitter')
require('plugins.gitsigns')
require('plugins.autopairs')
require('plugins.surround')
require('plugins.fzf-lua')
require('plugins.blink-cmp')
require('plugins.oil')
require('plugins.fidget')
require('plugins.lazydev')
require('plugins.lualine')
require('plugins.todo-comments')
require('plugins.harpoon')

require('core.lsp')
