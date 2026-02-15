m4_dnl env.lua.m4
m4_dnl
m4_dnl Hermetic Neovim environment wiring.
m4_dnl Rendered at build time: env.lua.m4 -> env.lua
m4_dnl
m4_dnl Include order matters:
m4_dnl   1. constants.m4   (default quoting) — defines NV_M4_LUA_VER
m4_dnl   2. paths.m4       (default quoting) — includes config_env.m4,
m4_dnl                      defines SITE/OPT/START via eager expansion
m4_dnl   3. common.m4      — switches to -<-< / >->- quoting so that
m4_dnl                      backticks, single-quotes, and double-quotes
m4_dnl                      in the Lua body are inert to m4
m4_dnl
m4_dnl After common.m4, all NV_M4_* macros are already defined and expand
m4_dnl as bare identifiers in the Lua body below.
m4_dnl
m4_include(`constants.m4')m4_dnl
m4_include(`paths.m4')m4_dnl
m4_include(`common.m4')m4_dnl
-- config/env.lua (generated from env.lua.m4 -- do not edit)
--
-- Wires Neovim to the hermetic rocks tree and LuaRocks config.
-- All paths are stamped at build time via m4. No runtime probing.

local M = {}

-- Build-time injected roots
M.nvim_rocks_dir  = "NV_M4_NVIM_ROCKS_DIR"
M.luarocks_config = "NV_M4_LUAROCKS_CONFIG"

-- Build-time derived Neovim site / pack directories
M.site_dir  = "NV_M4_SITE_DIR"
M.opt_dir   = "NV_M4_OPT_DIR"
M.start_dir = "NV_M4_START_DIR"

-- Lua module directories under the hermetic rocks tree
M.lua_share_dir = "NV_M4_NVIM_ROCKS_DIR/share/lua/NV_M4_LUA_VER"
M.lua_lib_dir   = "NV_M4_NVIM_ROCKS_DIR/lib/lua/NV_M4_LUA_VER"

-- Prepend a semicolon-separated path string (Lua package path style)
local function prepend_path(original, prefix)
  if not original or original == "" then
    return prefix
  end
  return prefix .. ";" .. original
end

local function setup_paths()
  -- Allow requiring this module outside Neovim without error.
  if not vim then
    return
  end

  ---------------------------------------------------------------------------
  -- 1) Export LUAROCKS_CONFIG into the Neovim process environment.
  --    The `luarocks` CLI reads this when rocks.nvim shells out.
  ---------------------------------------------------------------------------
  vim.env.LUAROCKS_CONFIG = M.luarocks_config

  ---------------------------------------------------------------------------
  -- 2) Wire Neovim runtimepath / packpath to the hermetic site dir.
  ---------------------------------------------------------------------------
  vim.opt.runtimepath:prepend(M.site_dir)
  vim.opt.packpath:prepend(M.site_dir)

  ---------------------------------------------------------------------------
  -- 3) Wire Lua module search paths to the hermetic rocks tree.
  ---------------------------------------------------------------------------
  do
    local lua_paths = table.concat({
      M.lua_share_dir .. "/?.lua",
      M.lua_share_dir .. "/?/init.lua",
    }, ";")
    package.path = prepend_path(package.path, lua_paths)
  end

  do
    local c_paths = table.concat({
      M.lua_lib_dir .. "/?.so",
      M.lua_lib_dir .. "/?.dylib",
      M.lua_lib_dir .. "/?.dll",
    }, ";")
    package.cpath = prepend_path(package.cpath, c_paths)
  end

  ---------------------------------------------------------------------------
  -- 4) Merge hermetic config into vim.g.rocks_nvim.
  --
  --    Only rocks_path is set here.  rocks.nvim derives luarocks_config
  --    internally from rocks_path.  Setting luarocks_config as a string is
  --    deprecated as of rocks.nvim 3.0 (it now expects a table).
  --
  --    Layer onto any existing table instead of clobbering it.
  ---------------------------------------------------------------------------
  local existing = vim.g.rocks_nvim
  if type(existing) ~= "table" then
    existing = {}
  end

  vim.g.rocks_nvim = vim.tbl_extend("force", existing, {
    rocks_path = M.nvim_rocks_dir,
  })
end

-- Public API
M.setup_paths = setup_paths
M.load = setup_paths

-- Requiring this module wires the hermetic paths immediately.
setup_paths()

return M
m4_dnl vim: ft=lua
