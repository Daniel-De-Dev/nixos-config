-- Synchronously resolve the local compiler binary if it exists
local local_cmd = vim.fn.getcwd()
  .. '/node_modules/.bin/typescript-language-server'
local executable = vim.uv.fs_stat(local_cmd) and local_cmd
  or 'typescript-language-server'

---@type vim.lsp.Config
return {
  cmd = { executable, '--stdio' },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
  },
  init_options = { hostInfo = 'neovim' },

  -- Native synchronous root resolution with Deno exclusion
  -- This prevents ts_ls from crashing into denols if you ever open a Deno project.
  ---@type fun(fname: string, bufnr: integer): string|nil
  root_dir = function(fname)
    ---@type string|nil
    local deno_root =
      vim.fs.root(fname, { 'deno.json', 'deno.jsonc', 'deno.lock' })

    ---@type string|nil
    local project_root = vim.fs.root(fname, {
      'package-lock.json',
      'yarn.lock',
      'pnpm-lock.yaml',
      'package.json',
      '.git',
    })

    -- If a Deno configuration is closer to the current file than a package.json, abort attachment.
    if deno_root and (not project_root or #deno_root >= #project_root) then
      return nil
    end

    return project_root or vim.fn.getcwd()
  end,

  -- Strict Inlay Hints Integration
  settings = {
    typescript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayVariableTypeHints = true,
      },
    },
  },

  -- Custom Server Handlers
  handlers = {
    -- Intercepts the TS-specific rename event to automatically jump to the renamed symbol
    ['_typescript.rename'] = function(_, result, ctx)
      ---@cast result { textDocument: { uri: string }, position: table }
      ---
      ---@type vim.lsp.Client
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      vim.lsp.util.show_document({
        uri = result.textDocument.uri,
        range = {
          start = result.position,
          ['end'] = result.position,
        },
      }, client.offset_encoding)
      vim.lsp.buf.rename()
      return vim.NIL
    end,
  },

  on_init = function()
    -- Registers the VS Code native "showReferences" command into Neovim's quickfix list
    ---@param command { title: string, arguments: any[] }
    ---@param ctx { client_id: integer, bufnr: integer }
    vim.lsp.commands['editor.action.showReferences'] = function(command, ctx)
      ---@type vim.lsp.Client
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))

      local file_uri, position, references = unpack(command.arguments)
      ---@cast file_uri string
      ---@cast position table
      ---@cast references table[]

      ---@type vim.quickfix.entry[]
      local quickfix_items =
        vim.lsp.util.locations_to_items(references, client.offset_encoding)

      vim.fn.setqflist({}, ' ', {
        title = command.title,
        items = quickfix_items,
        context = { command = command, bufnr = ctx.bufnr },
      })

      vim.lsp.util.show_document({
        uri = file_uri,
        range = { start = position, ['end'] = position },
      }, client.offset_encoding)

      vim.cmd('botright copen')
    end
  end,

  on_attach = function(client, bufnr)
    -- Command: Apply whole-file source actions (like organizing imports)
    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspTypescriptSourceAction',
      function()
        ---@type string[]
        local kinds = client.server_capabilities.codeActionProvider.codeActionKinds
          or {}

        ---@type fun(action: string): boolean
        local filter_fn = function(action)
          return vim.startswith(action, 'source.')
        end

        ---@type string[]
        local source_actions = vim.tbl_filter(filter_fn, kinds)

        vim.lsp.buf.code_action({
          context = { only = source_actions, diagnostics = {} },
        })
      end,
      { desc = 'Trigger TS source actions' }
    )

    -- Command: Bypass .d.ts definitions and jump directly to the JS/TS implementation
    vim.api.nvim_buf_create_user_command(
      bufnr,
      'LspTypescriptGoToSourceDefinition',
      function()
        local win = vim.api.nvim_get_current_win()
        ---@type { textDocument: { uri: string }, position: { line: integer, character: integer } }
        local params =
          vim.lsp.util.make_position_params(win, client.offset_encoding)

        client:request('workspace/executeCommand', {
          command = '_typescript.goToSourceDefinition',
          arguments = { params.textDocument.uri, params.position },
        }, function(err, result)
          if err then
            vim.notify(
              'Go to source definition failed: ' .. err.message,
              vim.log.levels.ERROR
            )
            return
          end
          if not result or vim.tbl_isempty(result) then
            vim.notify('No source definition found', vim.log.levels.INFO)
            return
          end
          vim.lsp.util.show_document(
            result[1],
            client.offset_encoding,
            { focus = true }
          )
        end, bufnr)
      end,
      { desc = 'Go to source definition' }
    )
  end,
}
