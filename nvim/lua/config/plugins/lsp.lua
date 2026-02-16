-- ~/.config/nvim/lua/plugins/lsp.lua
-- Plugins: nvim-treesitter, nvim-lspconfig, conform.nvim

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
-- LSP
---------------------------------------------------------------------------
local ok_lsp, lspconfig = pcall(require, "lspconfig")
if ok_lsp then
  -- Shared capabilities: advertise cmp-nvim-lsp completions to all servers
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp_lsp then
    capabilities = cmp_lsp.default_capabilities(capabilities)
  end

  -- Shared on_attach: buffer-local LSP keymaps
  local function on_attach(_, bufnr)
    local map = vim.keymap.set
    local opts = function(desc)
      return { buffer = bufnr, desc = desc }
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
  end

  local servers = {
    -- Python: install with `pip install ruff-lsp pyright`
    pyright  = {},
    ruff_lsp = {},

    -- R: install with `R -e 'install.packages("languageserver")'`
    r_language_server = {},

    -- SQL: install with `npm i -g sql-language-server`
    sqlls = {},

    -- Markdown: install with `brew install marksman` or cargo
    marksman = {},

    -- Lua (for your Neovim config): install with `brew install lua-language-server`
    lua_ls = {
      settings = {
        Lua = {
          runtime    = { version = "LuaJIT" },
          workspace  = { library = { vim.env.VIMRUNTIME } },
          diagnostics = { globals = { "vim" } },
          telemetry  = { enable = false },
        },
      },
    },
  }

  for server, config in pairs(servers) do
    -- Only configure servers that are actually installed
    if vim.fn.executable(lspconfig[server].document_config.default_config.cmd[1]) == 1 then
      lspconfig[server].setup(vim.tbl_extend("force", {
        capabilities = capabilities,
        on_attach    = on_attach,
      }, config))
    end
  end
end

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
