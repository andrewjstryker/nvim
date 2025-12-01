-- env.lua.m4
--
-- Wire Neovim to the hermetic rocks tree and LuaRocks config.
-- Rendered at build time via m4: *.lua.m4 → *.lua.

m4_include(`constants.m4') m4_dnl'
m4_include(`paths.m4') m4_dnl'

local M = {}

-- Build-time injected roots (do not edit in Lua; change via Make/config_env.m4)
M.nvim_rocks_dir       = "NVIM_ROCKS_DIR"
M.luarocks_config = "LUAROCKS_CONFIG"

-- Build-time derived Neovim site / pack directories
M.site_dir   = "NVIM_SITE_DIR"
M.opt_dir    = "NVIM_OPT_DIR"
M.start_dir  = "NVIM_START_DIR"

-- Build-time derived Lua search paths for modules
M.lua_share_dir = "NVIM_ROCKS_DIR/share/lua/LUA_VER"
M.lua_lib_dir  = "NVIM_ROCKS_DIR/lib/lua/LUA_VER"

-- Sanity checks: fail fast if required paths are missing.
-- If these don't exist, the hermetic setup cannot work correctly.
local uv = vim and vim.loop or nil

if uv then
  local function assert_path(path, label)
    local stat = uv.fs_stat(path)
    assert(
      stat and (stat.type == "file" or stat.type == "directory"),
      ("env.lua: %s does not exist: %s"):format(label, path)
    )
  end

  assert_path(M.nvim_rocks_dir,  "nvim_rocks_dir")
  assert_path(M.lua_share_dir,   "lua_share_dir")
  assert_path(M.lua_lib_dir,     "lua_lib_dir")
  assert_path(M.luarocks_config, "luarocks_config")
end

-- Helper: prepend without clobbering existing search paths.
local function prepend_path(current, addition)
  if not addition or addition == "" then
    return current
  end
  if not current or current == "" then
    return addition
  end
  return addition .. ";" .. current
end

local function setup_paths()
  -- 1. Neovim runtimepath / packpath: make hermetic site available,
  --    but do not override user/custom paths.
  if vim and vim.opt then
    vim.opt.runtimepath:prepend(M.site_dir)
    vim.opt.packpath:prepend(M.site_dir)
  end

  -- 2. Lua search paths for modules installed into the hermetic tree.
  package.path = prepend_path(
    package.path,
    M.lua_share_dir .. "/?.lua;" .. M.lua_share_dir .. "/?/init.lua"
  )

  package.cpath = prepend_path(
    package.cpath,
    M.lua_lib_dir .. "/?.so"
  )
end

M.setup_paths = setup_paths

-- Backward-compatible entry point used by init.lua
M.load = setup_paths

-- Contract: requiring this module wires the hermetic paths additively.
setup_paths()

return M

m4_dnl vim: ft=lua
