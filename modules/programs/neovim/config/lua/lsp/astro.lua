-- Dynamically check for a project-local language server binary
local local_cmd = vim.fn.getcwd() .. '/node_modules/.bin/astro-ls'
local executable = vim.uv.fs_stat(local_cmd) and local_cmd or 'astro-ls'

-- Dynamically resolve the TypeScript compiler SDK path
local function resolve_tsdk()
  -- Project-local TypeScript compiler
  local local_ts = vim.fn.getcwd() .. '/node_modules/typescript/lib'
  if vim.uv.fs_stat(local_ts) then return local_ts end

  -- Shell environment variable override
  return os.getenv('ASTRO_TSDK_PATH')
end

---@type vim.lsp.Config
return {
  cmd = { executable, '--stdio' },
  filetypes = { 'astro' },
  root_markers = { 'astro.config.mjs', 'package.json', 'tsconfig.json', '.git' },

  -- Astro strictly requires the TypeScript SDK path at startup
  ---@type table
  init_options = {
    typescript = {
      tsdk = resolve_tsdk(),
    },
  },
}
