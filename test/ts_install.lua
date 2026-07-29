-- test/ts_install.lua
--
-- Verify the REQUIRED CAPABILITY: this environment can install a treesitter
-- language it does not already have, and what comes out the other side is
-- usable -- it parses, and it highlights.
--
-- The test is deliberately blind to WHERE anything lands.  A .so at a given
-- path is not the capability we depend on; "the language works afterwards" is.
-- Asserting on install paths would also re-test the build's own substitutions,
-- which the probing policy (design.md §2) says to treat as authoritative.
--
-- Severity: ERROR.  If install is broken, every language the canonical set does
-- not already cover becomes unreachable.  Its companion is ts_works.lua, which
-- asks the other half of the question: do the languages we already promised
-- actually work?
--
-- Run headless under the installed config, after `make sync` (plugins present):
--   nvim --headless -u <cfg>/init.lua -c 'luafile test/ts_install.lua' -c qa
-- Requires the tree-sitter CLI, network, and a C compiler.  Exits non-zero on
-- failure.

-- Can we build a syntax tree for this language?  NOT
-- vim.treesitter.language.add -- that returns success on the language name even
-- when no usable parser exists, so it cannot tell "present" from "absent".
local function parses(lang)
  return pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    assert(ok and parser and parser:parse()[1]:root())
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end

-- Can we highlight it?  query.get() resolves highlights.scm over the
-- runtimepath, so it is indifferent to which directory supplied the queries --
-- exactly the right altitude for "does this language work".
local function highlights(lang)
  local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  return ok and query ~= nil
end

-- Probe with a language that is neither already usable nor in the canonical set
-- (config.parsers), so `make build-parsers` never pre-installs it and this test
-- genuinely exercises installing something absent.
local provisioned = {}
for _, l in ipairs(require("config.parsers").all()) do provisioned[l] = true end
local lang
for _, candidate in ipairs({ "comment", "jsonc", "diff", "cpp" }) do
  if not provisioned[candidate] and not parses(candidate) then
    lang = candidate
    break
  end
end
assert(lang, "no suitable absent probe parser found (all candidates present?)")

local ok, err = pcall(function()
  -- Wait on the install so the language is ready for the checks below.
  assert(require("nvim-treesitter").install({ lang }):wait(5 * 60 * 1000),
    "install reported failure")

  -- Content-agnostic: any grammar yields a root, with ERROR nodes at worst,
  -- for arbitrary input.
  assert(parses(lang), "installed language cannot parse")

  -- A parser without queries highlights nothing, and highlighting is the
  -- reason to install a language at all.
  assert(highlights(lang), "installed language has no highlight queries")
end)

if not ok then
  io.stderr:write(("TSTEST FAIL [install]: %s\n"):format(tostring(err)))
  os.exit(1)
end

io.stdout:write(("TSTEST OK [install]: %q installed, parses, and highlights\n"):format(lang))
os.exit(0)
