-- test/ts_install.lua
--
-- Verify the REQUIRED FUNCTIONALITY: a treesitter parser that does NOT ship
-- with Neovim can be installed through the config's nvim-treesitter setup,
-- lands in the hermetic parser dir (which env.lua puts on the runtimepath),
-- and then loads.
--
-- Severity: ERROR.  If install is broken, every missing parser -- bundled or
-- not -- becomes unrecoverable, so this is a hard failure (unlike a merely
-- missing bundled parser, which ts_shipped.lua only warns about).
--
-- Run headless under the installed config, after `make sync` (plugins present):
--   nvim --headless -u <cfg>/init.lua -c 'luafile test/ts_install.lua' -c qa
-- Requires network + a C compiler.  Exits non-zero on failure.

local lang = "json" -- not among Neovim's bundled parsers

local ok, err = pcall(function()
  -- Guard: if it is somehow already available the test proves nothing.
  local already = pcall(vim.treesitter.language.add, lang)
  assert(not already,
    ("%q is already available; choose a parser Neovim does not bundle"):format(lang))

  -- Synchronous install so the parser exists for the checks below.
  vim.cmd("TSInstallSync " .. lang)

  -- It must have landed in the hermetic parser dir (env.treesitter_dir/parser).
  local dir = require("config.env").treesitter_dir
  local so = dir .. "/parser/" .. lang .. ".so"
  assert(vim.uv.fs_stat(so), ("expected installed parser at %s"):format(so))

  -- And it must actually load and parse.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '{ "a": 1 }' })
  local parser = vim.treesitter.get_parser(buf, lang)
  assert(parser and parser:parse()[1]:root(), "installed parser did not parse")
end)

if not ok then
  io.stderr:write(("TSTEST FAIL [install]: %s\n"):format(tostring(err)))
  os.exit(1)
end

io.stdout:write(("TSTEST OK [install]: %q installed into hermetic dir and parses\n"):format(lang))
os.exit(0)
