-- ~/.config/nvim/lua/plugins/formatting.lua
-- Plugin: conform.nvim

local ok, conform = pcall(require, "conform")
if not ok then return end

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
