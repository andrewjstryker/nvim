-- build/scripts/install_parsers.lua
--
-- Provision the canonical treesitter parser set (config.parsers) into the
-- hermetic parser dir.  Run headless UNDER the installed config so it uses the
-- exact same code path the runtime uses: nvim-treesitter's installer, targeting
-- install_dir (= config.env.treesitter_dir), already configured by
-- plugins/treesitter.lua at startup.
--
--   nvim --headless -u <cfg>/init.lua -c 'luafile install_parsers.lua' -c qa
--
-- Idempotency is the installer's job, not ours.  nvim-treesitter's `main`
-- branch records the installed grammar revision per language and skips any
-- parser already at that revision with its queries linked, so re-runs only
-- compile what changed.  We deliberately do NOT gate on a can-it-load check
-- first: under `main` the queries for a language are installed alongside it,
-- so a parser that loads says nothing about whether its queries are present.
--
-- Requires the tree-sitter CLI, network, and a C compiler for the parsers
-- actually missing or stale.  Exits non-zero if any canonical parser fails to
-- install (a broken install capability is unrecoverable -- same severity as
-- test/ts_install.lua).
--
-- This is the step that ESTABLISHES the parser invariant the runtime assumes,
-- so it probes hard and fails loudly (design.md probing policy, §3).

local parsers = require("config.parsers").all()

-- pcall + explicit exit, not because the plugin's presence is in doubt (sync
-- guarantees it) but because `nvim --headless -c luafile` swallows Lua errors:
-- it prints them and still runs the following `-c qa`, exiting 0.  Every
-- failure path here must set the status itself or the build passes silently.
-- The tree-sitter CLI is NOT re-checked -- check-treesitter-cli owns that.
local ok_ts, ts = pcall(require, "nvim-treesitter")
if not ok_ts then
  io.stderr:write("PARSERS FAIL: nvim-treesitter is not installed (run `make sync`)\n")
  os.exit(1)
end

-- Behavioral verification: a provisioned language must be able to do the thing
-- it was provisioned for -- parse a buffer AND highlight it.  Both halves are
-- load-bearing, and a parser alone is not enough:
--
--   * Deliberately NOT vim.treesitter.language.add -- that registers the
--     language name and returns true even when no usable parser exists.
--   * Deliberately NOT "the .so is on disk" -- nvim-treesitter's installer
--     treats any .so already in the install dir as "installed" and skips the
--     language entirely, queries included.  A parser left behind by an earlier
--     install (say, the pre-`main` layout, which had no queries dir at all)
--     therefore loads and parses perfectly while highlighting nothing.
--
-- query.get() resolves highlights.scm over the runtimepath, so it accepts
-- queries from either the install dir or $VIMRUNTIME -- which is the real
-- invariant: highlighting works, regardless of who supplies the queries.
local function parses(lang)
  return pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    assert(ok and parser and parser:parse()[1]:root())
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end

local function highlights(lang)
  local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  return ok and query ~= nil
end

io.stdout:write(("PARSERS: provisioning %s\n"):format(table.concat(parsers, ", ")))

-- Asynchronous by design; wait so the parsers exist by process exit.  The
-- timeout is generous: a cold run compiles every grammar in the set.
local ok_install, err = pcall(function()
  return ts.install(parsers, { summary = true }):wait(15 * 60 * 1000)
end)

if not ok_install then
  io.stderr:write(("PARSERS FAIL: install errored: %s\n"):format(tostring(err)))
  os.exit(1)
end

-- Re-verify behaviorally.  This is the step that ESTABLISHES the invariant the
-- runtime assumes, so it reports the two halves separately: they have different
-- causes and different fixes.
local no_parser, no_queries = {}, {}
for _, lang in ipairs(parsers) do
  if not parses(lang) then
    no_parser[#no_parser + 1] = lang
  elseif not highlights(lang) then
    no_queries[#no_queries + 1] = lang
  end
end

if #no_parser > 0 then
  io.stderr:write(("PARSERS FAIL: no usable parser: %s\n")
    :format(table.concat(no_parser, ", ")))
end

if #no_queries > 0 then
  io.stderr:write(("PARSERS FAIL: parser installed but no highlight queries: %s\n")
    :format(table.concat(no_queries, ", ")))
  io.stderr:write("  The installer skips any language whose parser is already\n")
  io.stderr:write("  on disk, so a stale parser dir suppresses its own queries.\n")
  io.stderr:write("  Fix: `make clean-parsers build-parsers` to reprovision.\n")
end

if #no_parser > 0 or #no_queries > 0 then
  os.exit(1)
end

io.stdout:write(("PARSERS OK: installed and verified: %s\n"):format(table.concat(parsers, ", ")))
os.exit(0)
