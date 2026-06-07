local lualine = require('lualine')

local function macro_recording()
  local reg = vim.fn.reg_recording()
  if reg == '' then return '' end
  return '  Recording @' .. reg
end

local function lsp_clients()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return '' end
  local client_names = {}
  for _, client in ipairs(clients) do
    table.insert(client_names, client.name)
  end
  return '⚙ ' .. table.concat(client_names, ', ')
end

lualine.setup({
  options = {
    theme = 'auto',
    globalstatus = true,
    component_separators = { left = '│', right = '│' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = { 'fzf' },
    },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = {
      {
        'filename',
        path = 1,
        symbols = { modified = '●', readonly = '󰌾', unnamed = '[No Name]' },
      },
    },
    lualine_x = {
      { macro_recording, color = { fg = '#ff9e64' } },
      lsp_clients,
      'encoding',
      'fileformat',
      'filetype',
    },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  extensions = { 'oil', 'lazy', 'quickfix' },
})
