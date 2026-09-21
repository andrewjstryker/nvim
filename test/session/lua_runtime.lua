-- test/session/lua_runtime.lua
--
-- Verify the REQUIRED BEHAVIOR of the lazy Lua/Fennel setup: the session
-- resolves one Lua target on the first Lua or Fennel buffer, every later
-- buffer reuses it, and Fennel highlights -- including the buffer that
-- triggered the resolve.
--
-- That last clause is the whole reason this file exists.  The Fennel syntax
-- package is optional (packadd, from lua/plugins/lua.lua), and Neovim's own
-- FileType handlers -- filetypeplugin, filetypeindent, syntaxset -- are
-- registered before this configuration's, because config.env runs packloadall
-- and the start plugins turn syntax on before config.autocmds is required.
-- So for the buffer that triggers the packadd, the syntax lookup has already
-- happened and found nothing.  Asserting only on a SECOND Fennel buffer passes
-- while the first one in every session sits unhighlighted.
--
-- Severity: ERROR.  A silently unhighlighted first buffer is invisible to
-- every other check here: the config loads, no error is raised, and the
-- session looks healthy.
--
-- Driven by test/lua_runtime.sh, which supplies the scenario through the
-- environment and owns everything a single session cannot see (which Lua is on
-- PATH, whether the interpreter was probed at all, project-local trust).
--
-- Run headless under the installed config.  Exits non-zero on failure.

-- Read inside the protected body below, never at the top level: dying before
-- os.exit() leaves Neovim running for the driver's timeout to kill, which is
-- a slow way to learn that a variable was misspelled.
local function scenario()
  local function required(name)
    local value = vim.env[name]
    assert(value ~= nil and value ~= "", name .. " unset")
    return value
  end
  return {
    -- "set"  -- nothing is open yet; this script opens the first buffer
    --           itself, so it can also assert what is true BEFORE one exists.
    -- "open" -- a Fennel file was on the command line, so the resolve already
    --           happened during startup and the current buffer is that file.
    mode    = required("LUA_TEST_MODE"),
    first   = required("LUA_TEST_FIRST"),
    version = required("LUA_TEST_VERSION"),
    target  = required("LUA_TEST_TARGET"),
    luajit  = assert(tonumber(required("LUA_TEST_JIT")), "LUA_TEST_JIT is not a number"),
  }
end

local enabled = 0

local function before_first_buffer(first)
  assert(not package.loaded["plugins.lua"],
    "plugins.lua loaded before any Lua or Fennel buffer")
  assert(#vim.api.nvim_get_runtime_file("syntax/fennel.vim", false) == 0,
    "the Fennel package is on the runtimepath before any Lua or Fennel buffer")

  vim.cmd("setfiletype text")
  assert(not package.loaded["plugins.lua"],
    "plugins.lua loaded for an unrelated filetype")

  -- Count enablement instead of performing it: starting a real language
  -- server is not what is under test, and its absence must not be a failure.
  vim.lsp.enable = function(name)
    assert(name == "lua_ls", "unexpected server enabled: " .. tostring(name))
    enabled = enabled + 1
  end

  vim.cmd("enew")
  vim.cmd("setfiletype " .. first)
end

-- Startup noise from an unrelated plugin must not fail this check, and must
-- not disappear either.  Take what is already there, hand it back to the
-- caller to report, and assert only that the buffers THIS script opens raise
-- nothing new.
local function take_errmsg()
  local inherited = vim.v.errmsg
  vim.v.errmsg = ""
  return inherited
end

local function check()
  local s = scenario()
  local mode, first, version, target, luajit =
    s.mode, s.first, s.version, s.target, s.luajit
  local inherited = take_errmsg()

  if mode == "set" then
    before_first_buffer(first)
  end

  -- The buffer that triggered the resolve: the one the ordering bug leaves
  -- dark.  In "open" mode it is the file from the command line.
  if first == "fennel" then
    assert(vim.b.current_syntax == "fennel", "the first Fennel buffer has no syntax")
  end

  assert(vim.g.fennel_lua_version == version,
    ("fennel_lua_version is %q, want %q"):format(
      tostring(vim.g.fennel_lua_version), version))
  assert(vim.g.fennel_use_luajit == luajit,
    ("fennel_use_luajit is %s, want %d"):format(
      tostring(vim.g.fennel_use_luajit), luajit))

  local resolved = vim.tbl_get(vim.lsp.config.lua_ls or {},
    "settings", "Lua", "runtime", "version")
  assert(resolved == target,
    ("lua_ls runtime.version is %q, want %q"):format(tostring(resolved), target))

  if mode == "set" then
    assert(enabled == 1, ("lua_ls enabled %d times, want 1"):format(enabled))
  end

  -- A later buffer reuses the session's target -- first file wins -- and
  -- still highlights, now that the package is on the runtimepath.
  vim.cmd("enew")
  vim.cmd("setfiletype fennel")
  assert(vim.b.current_syntax == "fennel", "a subsequent Fennel buffer has no syntax")
  assert(vim.g.fennel_lua_version == version, "a later buffer changed the session target")
  if mode == "set" then
    assert(enabled == 1, ("lua_ls enabled %d times, want 1"):format(enabled))
  end

  assert(vim.v.errmsg == "", "Neovim reported: " .. vim.v.errmsg)
  return inherited
end

local ok, inherited = pcall(check)
if not ok then
  io.stderr:write(("LUATEST FAIL: %s\n"):format(tostring(inherited)))
  os.exit(1)
end

io.stdout:write(("LUATEST OK [%s]: target %s, Fennel highlights from the first buffer\n")
  :format(tostring(vim.env.LUA_TEST_MODE), tostring(vim.g.fennel_lua_version)))
if inherited ~= "" then
  io.stdout:write(("  note: startup left v:errmsg = %s\n"):format(inherited))
end
os.exit(0)
