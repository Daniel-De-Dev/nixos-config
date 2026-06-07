require('blink.cmp').setup({
  completion = {
    keyword = {
      range = 'full',
    },
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 250,
      window = { border = 'rounded' },
    },
    ghost_text = {
      enabled = true,
      show_without_selection = true,
    },
    list = {
      selection = {
        preselect = false,
        auto_insert = true,
      },
    },
    menu = {
      border = 'rounded',
      draw = {
        treesitter = { 'lsp' },
      },
    },
  },

  keymap = {
    preset = 'enter',
    ['<C-u>'] = { 'scroll_documentation_up', 'fallback' },
    ['<C-d>'] = { 'scroll_documentation_down', 'fallback' },
  },

  signature = {
    enabled = true,
    window = { border = 'rounded' },
  },

  cmdline = {
    completion = {
      menu = {
        auto_show = true,
      },
    },
  },

  fuzzy = {
    sorts = {
      'exact',
      'score',
      'sort_text',
    },
  },

  sources = {
    default = { 'lsp', 'path', 'snippets', 'buffer' },
    per_filetype = {
      lua = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
    },
    providers = {
      buffer = {
        min_keyword_length = 3,
      },
      lazydev = {
        name = 'LazyDev',
        module = 'lazydev.integrations.blink',
        score_offset = 100,
      },
    },
  },
})
