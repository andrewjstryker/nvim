-- test/ts_shipped.lua
--
-- Check that the treesitter parsers Neovim is expected to BUNDLE are present
-- and usable under the installed configuration.  (vimdoc is the load-bearing
-- one: ftplugin/help.lua asserts it synchronously, so its absence crashes any
-- help buffer.)
--
-- Severity: WARNING, not error.  Missing bundled parsers are "expected content"
-- the nvim install failed to provide -- unexpected, but recoverable in
-- principle (a parser can be installed).  The hard error is reserved for a
-- broken *install* capability; see ts_install.lua.
--
-- Run headless under the installed config.  Always exits 0; prints a loud
-- warning to stderr listing any missing parser.

-- The parsers a standard Neovim install ships (0.11).
local expected = { "vimdoc", "markdown", "markdown_inline", "lua", "vim", "query", "c" }

local missing = {}
for _, lang in ipairs(expected) do
  local ok = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local parser = vim.treesitter.get_parser(buf, lang)
    assert(parser, "get_parser returned nil")
    local tree = parser:parse()[1]
    assert(tree and tree:root(), "parse produced no syntax tree")
  end)
  if not ok then
    missing[#missing + 1] = lang
  end
end

if #missing > 0 then
  io.stderr:write("============================================================\n")
  io.stderr:write(("TSTEST WARNING [bundled]: missing parser(s): %s\n")
    :format(table.concat(missing, ", ")))
  io.stderr:write("  A standard Neovim install ships these; this binary did not.\n")
  io.stderr:write("  Help buffers (vimdoc) will error until the parser is present.\n")
  io.stderr:write("  Repair/reinstall nvim so $VIMRUNTIME/parser is populated, or\n")
  io.stderr:write("  install the parser(s) with :TSInstall.\n")
  io.stderr:write("============================================================\n")
  os.exit(0) -- warning only: missing content does not fail the build
end

io.stdout:write(("TSTEST OK [bundled]: all expected parsers present (%s)\n")
  :format(table.concat(expected, ", ")))
os.exit(0)
