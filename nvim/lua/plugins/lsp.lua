-- ~/.config/nvim/lua/plugins/lsp.lua
-- Plugins: nvim-treesitter, nvim-lspconfig (config provider), conform.nvim
--
-- Neovim 0.12 native LSP: nvim-lspconfig provides default configs via its
-- lsp/ directory on the runtimepath.  We customize with vim.lsp.config()
-- and activate with vim.lsp.enable().  No require('lspconfig') needed.

---------------------------------------------------------------------------
-- Treesitter
---------------------------------------------------------------------------
local ok_ts, ts_configs = pcall(require, "nvim-treesitter.configs")
if ok_ts then
  ts_configs.setup({
    -- Install parsers for your main languages; others on demand via :TSInstall
    ensure_installed = {
      "python", "r", "sql",
      "markdown", "markdown_inline",
      "lua", "vim", "vimdoc",
      "bash", "dockerfile", "json", "yaml", "toml", "csv",
    },
    highlight = { enable = true },
    indent    = { enable = true },
  })
end

---------------------------------------------------------------------------
-- LSP: shared config for all servers
---------------------------------------------------------------------------

-- Advertise cmp-nvim-lsp capabilities to all servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp_lsp then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

vim.lsp.config("*", {
  capabilities = capabilities,
  root_markers = { ".git" },
})

-- Buffer-local LSP keymaps (set once when any server attaches)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
  callback = function(ev)
    local map = vim.keymap.set
    local opts = function(desc)
      return { buffer = ev.buf, desc = desc }
    end

    map("n", "gd",         vim.lsp.buf.definition,      opts("Go to definition"))
    map("n", "gD",         vim.lsp.buf.declaration,      opts("Go to declaration"))
    map("n", "gr",         vim.lsp.buf.references,       opts("References"))
    map("n", "gi",         vim.lsp.buf.implementation,   opts("Implementation"))
    map("n", "K",          vim.lsp.buf.hover,            opts("Hover docs"))
    map("n", "<leader>rn", vim.lsp.buf.rename,           opts("Rename symbol"))
    map("n", "<leader>ca", vim.lsp.buf.code_action,      opts("Code action"))
    map("n", "[d",         vim.diagnostic.goto_prev,     opts("Prev diagnostic"))
    map("n", "]d",         vim.diagnostic.goto_next,     opts("Next diagnostic"))
  end,
})

---------------------------------------------------------------------------
-- LSP: per-server overrides
--
-- nvim-lspconfig provides sensible defaults for each server (cmd,
-- filetypes, root_markers) via its lsp/ directory.  We only need to
-- override where our setup differs from those defaults.
---------------------------------------------------------------------------

-- Python: install with `pip install pyright ruff`
-- (ruff_lsp is deprecated; ruff has a native LSP server now)
vim.lsp.config("ruff", {
  -- ruff handles formatting and linting; disable hover to let pyright own it
  on_attach = function(client, _)
    client.server_capabilities.hoverProvider = false
  end,
})

-- Lua: for editing this Neovim config
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime    = { version = "LuaJIT" },
      workspace  = { library = { vim.env.VIMRUNTIME } },
      diagnostics = { globals = { "vim" } },
      telemetry  = { enable = false },
    },
  },
})

-- Enable all servers (nvim-lspconfig supplies cmd, filetypes, root_markers)
-- Each server auto-starts only when its filetypes are opened.
vim.lsp.enable({
  "pyright",
  "ruff",
  "r_language_server",
  "sqlls",
  "marksman",
  "lua_ls",
})

---------------------------------------------------------------------------
-- Conform (auto-format)
---------------------------------------------------------------------------
local ok_conform, conform = pcall(require, "conform")
if ok_conform then
  conform.setup({
    formatters_by_ft = {
      python   = { "ruff_format", "black", stop_after_first = true },
      r        = { "styler" },
      sql      = { "sql_formatter" },
      markdown = { "prettier" },
      lua      = { "stylua" },
      json     = { "prettier" },
      yaml     = { "prettier" },
    },
    -- Format on save (async, with 500ms timeout)
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  })
end
