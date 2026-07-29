-- test/ts_works.lua
--
-- Verify the REQUIRED FUNCTIONALITY: treesitter actually works for every
-- language the build promises.
--
-- "Works" is measured the way a user experiences it, in two parts that together
-- cover the whole chain end to end:
--
--   1. Open a buffer of the language's filetype and a live highlighter is
--      attached to it.  This proves the parser exists, can build a tree for the
--      buffer, and that lua/plugins/treesitter.lua wired the FileType autocmd
--      to the right language for that filetype.
--
--   2. The language's highlight query resolves.  This is NOT implied by (1):
--      Neovim attaches a highlighter whether or not any query is found, so a
--      language with missing or mismatched queries passes the attach check and
--      still highlights nothing.  Resolving the query also compiles it against
--      the installed grammar, so a parser/query version mismatch -- the failure
--      that the pre-`main` parser tree produced -- shows up here as an error.
--
-- Nothing here inspects the filesystem.  Which directory supplied the parser or
-- the queries -- the hermetic install dir, $VIMRUNTIME, anywhere else -- is not
-- a property worth testing: it is a build-time substitution, authoritative by
-- the probing policy (design.md §2), and the user cannot tell the difference.
-- Whether a .so landed at an expected path is a proxy; this is the real thing.
--
-- Severity: ERROR.  config.parsers is a build-time contract that
-- `make build-parsers` refuses to leave unsatisfied, so a language in the
-- canonical set that does not highlight means the contract was broken after
-- the fact -- not a merely missing optional extra.
--
-- Run headless under the installed config, after `make sync` (parsers
-- provisioned):
--   nvim --headless -u <cfg>/init.lua -c 'luafile test/ts_works.lua' -c qa
-- No network required.  Exits non-zero on failure.

local langs = require("config.parsers").all()

-- Scratch buffers, not :edit/:enew -- setting 'filetype' on a scratch buffer
-- fires FileType exactly as a real one does, without dragging in swapfiles,
-- windows, or the ftplugins that spawn external processes for some filetypes.
local function highlighter_attaches(lang, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x" })
  vim.api.nvim_set_option_value("filetype", ft, { buf = buf })
  local live = vim.treesitter.highlighter.active[buf] ~= nil
  vim.api.nvim_buf_delete(buf, { force = true })
  return live
end

-- Resolving highlights.scm over the runtimepath is indifferent to which
-- directory supplied it, and compiling it against the loaded grammar is what
-- turns a parser/query mismatch into a visible failure.
local function highlight_query_resolves(lang)
  local ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  return ok and query ~= nil
end

local broken = {}
for _, lang in ipairs(langs) do
  -- A language can serve several filetypes (bash -> sh, vimdoc -> help); the
  -- first is enough to prove the wiring, and Neovim owns the mapping.
  local ft = vim.treesitter.language.get_filetypes(lang)[1]

  local why
  if not ft then
    why = "no filetype registered"
  elseif not highlighter_attaches(lang, ft) then
    why = ("no highlighter attached to a %s buffer"):format(ft)
  elseif not highlight_query_resolves(lang) then
    why = "highlight query does not resolve"
  end

  if why then
    broken[#broken + 1] = ("%s (%s)"):format(lang, why)
  end
end

if #broken > 0 then
  io.stderr:write(("TSTEST FAIL [works]: no treesitter highlighting for: %s\n")
    :format(table.concat(broken, ", ")))
  io.stderr:write("  These are in config.parsers, so the build promised them.\n")
  io.stderr:write("  Fix: `make clean-parsers build-parsers` to reprovision.\n")
  os.exit(1)
end

io.stdout:write(("TSTEST OK [works]: treesitter highlights all %d canonical languages\n")
  :format(#langs))
os.exit(0)
