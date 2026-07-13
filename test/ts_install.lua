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

-- Behavioral availability check: can we build a parser and parse with it?
-- NOT vim.treesitter.language.add -- that returns success on the language name
-- even when no usable parser exists, so it cannot tell "present" from "absent".
local function loads(lang)
  return pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    assert(ok and parser and parser:parse()[1]:root())
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end

-- Probe with a parser that is neither bundled nor in the canonical set
-- (config.parsers), so `make build-parsers` never pre-installs it and this
-- test genuinely exercises installing something absent.
local provisioned = {}
for _, l in ipairs(require("config.parsers").all()) do provisioned[l] = true end
local lang
for _, candidate in ipairs({ "comment", "jsonc", "diff", "cpp" }) do
  if not provisioned[candidate] and not loads(candidate) then
    lang = candidate
    break
  end
end
assert(lang, "no suitable absent probe parser found (all candidates present?)")

local ok, err = pcall(function()
  -- Synchronous install so the parser exists for the checks below.
  vim.cmd("TSInstallSync " .. lang)

  -- It must have landed in the hermetic parser dir (env.treesitter_dir/parser).
  local dir = require("config.env").treesitter_dir
  local so = dir .. "/parser/" .. lang .. ".so"
  assert(vim.uv.fs_stat(so), ("expected installed parser at %s"):format(so))

  -- And it must actually load and parse (content-agnostic: any grammar yields
  -- a root, with ERROR nodes at worst, for arbitrary input).
  assert(loads(lang), "installed parser did not load")
end)

if not ok then
  io.stderr:write(("TSTEST FAIL [install]: %s\n"):format(tostring(err)))
  os.exit(1)
end

io.stdout:write(("TSTEST OK [install]: %q installed into hermetic dir and parses\n"):format(lang))
os.exit(0)
