-- build/scripts/install_parsers.lua
--
-- Provision the canonical treesitter parser set (config.parsers) into the
-- hermetic parser dir.  Run headless UNDER the installed config so it uses the
-- exact same code path the runtime uses: nvim-treesitter's installer, targeting
-- parser_install_dir (= config.env.treesitter_dir), already configured by
-- plugins/treesitter.lua at startup.
--
--   nvim --headless -u <cfg>/init.lua -c 'luafile install_parsers.lua' -c qa
--
-- Behavioral, not forced.  A parser that already LOADS -- bundled by the Neovim
-- binary, found on $VIMRUNTIME, or previously installed -- is left untouched;
-- only the parsers that can-it-load reports missing are compiled.  On a host
-- whose Neovim ships the parsers, nothing is installed and no network or
-- compiler is needed.  On a host that ships none (some minimal builds), the
-- whole set is compiled into the hermetic dir.
--
-- Requires network + a C compiler only for the parsers actually missing.
-- Exits non-zero if any missing parser fails to install (broken install
-- capability is unrecoverable -- same severity as test/ts_install.lua).

local parsers = require("config.parsers").all()

-- Behavioral availability check: can we actually build a parser and parse with
-- it?  Deliberately NOT vim.treesitter.language.add -- that registers the
-- language name and returns true even when the binary ships no usable parser.
local function loads(lang)
  return pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    assert(ok and parser and parser:parse()[1]:root())
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end

local missing = {}
for _, lang in ipairs(parsers) do
  if not loads(lang) then
    missing[#missing + 1] = lang
  end
end

if #missing == 0 then
  io.stdout:write("PARSERS OK: all present, nothing to install\n")
  os.exit(0)
end

io.stdout:write(("PARSERS: installing missing: %s\n"):format(table.concat(missing, ", ")))

-- The same installer the runtime uses (auto_install and :TSInstall funnel
-- through this too).  Synchronous so the parsers exist by process exit.
vim.cmd("TSInstallSync " .. table.concat(missing, " "))

-- Re-verify behaviorally; a parser that compiled but will not load is a failure.
local failed = {}
for _, lang in ipairs(missing) do
  if not loads(lang) then
    failed[#failed + 1] = lang
  end
end

if #failed > 0 then
  io.stderr:write(("PARSERS FAIL: could not install: %s\n"):format(table.concat(failed, ", ")))
  os.exit(1)
end

io.stdout:write(("PARSERS OK: installed and verified: %s\n"):format(table.concat(missing, ", ")))
os.exit(0)
