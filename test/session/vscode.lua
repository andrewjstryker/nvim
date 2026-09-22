-- test/session/vscode.lua
--
-- Verify the REQUIRED BEHAVIOR of the VS Code entry point: inside the
-- vscode-neovim extension, `init.lua` takes a different branch and wires a
-- different runtimepath, and that branch has to keep two promises at once.
--
--   1. The extension's own runtimepath entries survive.  config.vscode_env
--      APPENDS to Neovim's defaults where config.env REPLACES them, because
--      the extension puts vscode.internal and friends on the runtimepath and
--      replacing them breaks it.
--   2. The provisioned treesitter parsers are reachable.  Four of Neovim's own
--      ftplugins -- markdown, lua, help, query -- open with a bare
--      vim.treesitter.start(), which ASSERTS when no parser can be created.  A
--      Neovim that bundles no parsers therefore raises E5113 on every markdown
--      or Lua buffer unless the hermetic treesitter tree is on the rtp, and
--      VS Code mode never loads config.plugins, which owns that entry in the
--      normal path.
--
-- Severity: ERROR.  Promise 2 broke in exactly this way and the only symptom
-- was an error dialog in the editor; nothing in the build or the other tiers
-- noticed, because they all exercise the other branch.
--
-- Driven by test/vscode.sh, which owns what a session cannot arrange for
-- itself: the `vim.g.vscode` gate, a stub for the extension's own Lua module,
-- and a sentinel runtimepath entry standing in for the extension's.
--
-- Nothing here inspects a path except that sentinel, which IS the contract.
-- Whether the parsers came from the hermetic tree or anywhere else is not a
-- property worth testing; "a markdown buffer opens without erroring" is.
--
-- Run headless under the installed config.  Exits non-zero on failure.

-- The four filetypes whose bundled ftplugin starts treesitter, all of them in
-- the canonical parser set (config.parsers).
local TREESITTER_FTPLUGINS = { "markdown", "lua", "help", "query" }

local function opens_cleanly(ft)
  local buf = vim.api.nvim_create_buf(false, true)
  local ok, err = pcall(vim.api.nvim_set_option_value, "filetype", ft, { buf = buf })
  local attached = ok and vim.treesitter.highlighter.active[buf] ~= nil
  vim.api.nvim_buf_delete(buf, { force = true })
  if not ok then
    return false, tostring(err):gsub("%s+", " ")
  end
  if not attached then
    return false, "no highlighter attached"
  end
  return true
end

local function check()
  local inherited = vim.v.errmsg
  vim.v.errmsg = ""

  -- The gate took the VS Code branch: its env module ran and the normal one
  -- did not.  Without this, everything below could be passing for the wrong
  -- configuration entirely.
  assert(package.loaded["config.vscode_env"], "config.vscode_env was not loaded")
  assert(not package.loaded["config.env"],
    "config.env was loaded -- this is not the VS Code branch")

  -- Promise 1: appending, not replacing.
  local sentinel = assert(vim.g.vscode_test_sentinel, "driver set no sentinel")
  local kept = false
  for _, entry in ipairs(vim.opt.runtimepath:get()) do
    if entry == sentinel then kept = true end
  end
  assert(kept, "the extension's runtimepath entry was dropped: " .. sentinel)

  -- Promise 2, as behavior rather than as a path.
  assert(#vim.api.nvim_get_runtime_file("parser/markdown.so", false) > 0,
    "no markdown parser on the runtimepath (has `make sync` run?)")

  local broken = {}
  for _, ft in ipairs(TREESITTER_FTPLUGINS) do
    local ok, why = opens_cleanly(ft)
    if not ok then
      broken[#broken + 1] = ("%s (%s)"):format(ft, why)
    end
  end
  assert(#broken == 0, "ftplugin starts treesitter and fails for: "
    .. table.concat(broken, ", "))

  -- The stated reason this branch exists at all: Fugitive, from the hermetic
  -- packpath, which only works if the append and packloadall both happened.
  assert(vim.fn.exists(":Git") == 2, "Fugitive is not available (:Git missing)")

  assert(vim.v.errmsg == "", "Neovim reported: " .. vim.v.errmsg)
  return inherited
end

local ok, inherited = pcall(check)
if not ok then
  io.stderr:write(("VSCODE FAIL: %s\n"):format(tostring(inherited)))
  os.exit(1)
end

io.stdout:write(("VSCODE OK: extension rtp kept, %d treesitter ftplugin(s) clean, Fugitive live\n")
  :format(#TREESITTER_FTPLUGINS))
if inherited ~= "" then
  io.stdout:write(("  note: startup left v:errmsg = %s\n"):format(inherited))
end
os.exit(0)
