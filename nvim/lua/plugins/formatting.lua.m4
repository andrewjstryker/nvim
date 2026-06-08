m4_include(`config_env.m4')m4_dnl
-- ~/.config/nvim/lua/plugins/formatting.lua  (generated from formatting.lua.m4)
-- Plugin: conform.nvim
--
-- Formatter binaries are discovered at build time (see environment.mk).
-- Only binaries found on PATH during "make sync" are stamped here, so this
-- file will differ across hosts.  To pick up a newly-installed formatter,
-- re-run "make sync" to re-probe the environment.

local ok, conform = pcall(require, "conform")
if not ok then return end

conform.setup({
  -- Override the command path for each discovered formatter so conform
  -- invokes the exact binary found at build time, not whatever the runtime
  -- PATH happens to resolve to.
  formatters = {
m4_ifdef(`NV_M4_PRETTIER',      `    prettier      = { command = "NV_M4_PRETTIER" },
')m4_dnl
m4_ifdef(`NV_M4_STYLUA',        `    stylua        = { command = "NV_M4_STYLUA" },
')m4_dnl
m4_ifdef(`NV_M4_RUFF',          `    ruff_format   = { command = "NV_M4_RUFF" },
')m4_dnl
m4_ifdef(`NV_M4_BLACK',         `    black         = { command = "NV_M4_BLACK" },
')m4_dnl
m4_ifdef(`NV_M4_STYLER',        `    styler        = { command = "NV_M4_STYLER" },
')m4_dnl
m4_ifdef(`NV_M4_SQL_FORMATTER', `    sql_formatter = { command = "NV_M4_SQL_FORMATTER" },
')m4_dnl
  },
  formatters_by_ft = {
m4_ifdef(`NV_M4_RUFF',
  `m4_ifdef(`NV_M4_BLACK',
    `    python   = { "ruff_format", "black", stop_after_first = true },
',
    `    python   = { "ruff_format" },
')',
  `m4_ifdef(`NV_M4_BLACK',
    `    python   = { "black" },
', `')')m4_dnl
m4_ifdef(`NV_M4_STYLER',        `    r        = { "styler" },
')m4_dnl
m4_ifdef(`NV_M4_SQL_FORMATTER', `    sql      = { "sql_formatter" },
')m4_dnl
m4_ifdef(`NV_M4_PRETTIER',      `    markdown = { "prettier" },
    json     = { "prettier" },
    yaml     = { "prettier" },
')m4_dnl
m4_ifdef(`NV_M4_STYLUA',        `    lua      = { "stylua" },
')m4_dnl
  },
  -- Format on save (async, with 500ms timeout).  lsp_fallback lets the
  -- LSP format files whose filetype has no formatter configured above.
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
})
m4_dnl vim: ft=lua
