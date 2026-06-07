-- Dynamically check for the project-local binary first, fallback to global
local local_cmd = vim.fn.getcwd()
  .. '/node_modules/.bin/css-variables-language-server'
local executable = vim.uv.fs_stat(local_cmd) and local_cmd
  or 'css-variables-language-server'

---@type vim.lsp.Config
return {
  cmd = { executable, '--stdio' },
  filetypes = { 'css', 'scss', 'less', 'html', 'astro' },

  root_markers = {
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'bun.lockb',
    'package.json',
    '.git',
  },

  -- Explicitly hardcoded to bypass the server's failure to load its own defaults
  ---@type table
  settings = {
    cssVariables = {
      lookupFiles = { '**/*.less', '**/*.scss', '**/*.sass', '**/*.css' },
      blacklistFolders = {
        '**/.cache',
        '**/.DS_Store',
        '**/.git',
        '**/.hg',
        '**/.next',
        '**/.svn',
        '**/bower_components',
        '**/CVS',
        '**/dist',
        '**/node_modules',
        '**/tests',
        '**/tmp',
      },
    },
  },
}
