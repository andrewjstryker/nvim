m4_dnl env.lua.m4
m4_dnl
m4_dnl Hermetic Neovim environment wiring.
m4_dnl Rendered at build time: env.lua.m4 → env.lua
m4_dnl
m4_dnl Includes constants.m4 and paths.m4 (both use default m4 quoting).
m4_dnl Macro references are placed outside quotes so they expand at render time.
m4_dnl
m4_dnl NOTE: This file does NOT include common.m4 (no backticks in the Lua body).
m4_dnl The default m4 quoting (backtick/single-quote) is fine here because Lua
m4_dnl strings use double quotes, and m4 does not treat " as special.
m4_dnl
m4_include(`constants.m4')m4_dnl
m4_include(`paths.m4')m4_dnl
-- config/env.lua (generated from env.lua.m4 -- do not edit)
--
-- Wires Neovim to the hermetic luarocks tree.
-- All paths are stamped at build time via m4. No runtime probing.
--
-- The build system installs native rocks (via luarocks) and git plugins
-- (via git clone) into a hermetic tree under NVIM_CACHE_DIR/rocks/.
-- This module wires package.path/cpath so native Lua/C modules load,
-- then replaces rtp and packpath with a minimal hermetic set so only
-- build-controlled locations are searched at runtime.

local M = {}

-- Build-time constants (stamped by config_env.m4 via project.mk)
M.nvim_rocks_dir = "NV_M4_NVIM_ROCKS_DIR"
M.config_dir     = "NV_M4_NVIM_CONFIG_DIR"
M.treesitter_dir = "NV_M4_TREESITTER_DIR"

-- Derived constants (stamped by paths.m4 from config_env.m4 values)
M.rocks_site    = "NV_M4_SITE_DIR"
M.lua_share_dir = "NV_M4_NVIM_ROCKS_DIR/share/lua/NV_M4_LUA_VER"
M.lua_lib_dir   = "NV_M4_NVIM_ROCKS_DIR/lib/lua/NV_M4_LUA_VER"

-- rocks.nvim versioned directory (glob — version suffix unknown at build time)
M.rocks_rtp_glob = "NV_M4_ROCKS_RTP"

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
  -- 1) Wire Lua module search paths to the hermetic rocks tree.
  --    Native rocks (toml-edit, fzy, etc.) install their Lua and C modules
  --    here.  Without these entries, require() cannot find them.
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
  -- 2) Set hermetic runtimepath and packpath.
  --
  --    Replace the Neovim defaults (which include dozens of XDG, flatpak,
  --    and system-wide paths) with the minimal set this build controls:
  --
  --    runtimepath:
  --      config_dir          -- lua/config/, lua/plugins/, after/, ftplugin/
  --      rocks_site          -- git-cloned plugins runtime files
  --      treesitter_dir      -- parser/*.so installed by :TSInstall
  --      vim.env.VIMRUNTIME  -- Neovim own runtime (syntax, ftplugin, etc.)
  --      config_dir/after    -- user after/ overrides
  --
  --    packpath:
  --      rocks_site          -- pack/rocks/{start,opt}/ for git-cloned plugins
  --
  --    This is intentionally exclusive.  If a directory is not listed here,
  --    Neovim will not search it.  This prevents stale system plugins,
  --    user-global installations, and flatpak artifacts from leaking in.
  ---------------------------------------------------------------------------

  -- Resolve rocks.nvim versioned directory (glob → concrete path).
  -- The version suffix (e.g., 2.47.4-1/) is unknown at build time.
  local rocks_rtp = vim.fn.glob(M.rocks_rtp_glob)

  local rtp = {
    M.config_dir,
    M.rocks_site,
    M.treesitter_dir,
    vim.env.VIMRUNTIME,
    M.config_dir .. "/after",
  }
  -- Insert rocks_rtp after config_dir (position 2) when available.
  if rocks_rtp ~= "" then
    table.insert(rtp, 2, rocks_rtp)
  end

  -- Ensure the treesitter parser dir exists so nvim-treesitter's TSInstall
  -- has a writable target and nvim's rtp scan doesn't skip it on first run.
  vim.fn.mkdir(M.treesitter_dir .. "/parser", "p")

  vim.opt.runtimepath = rtp

  vim.opt.packpath = {
    M.rocks_site,
  }

  ---------------------------------------------------------------------------
  -- 3) Trigger pack scanning for the new packpath.
  --
  --    Neovim scans packpath once, early in startup, to discover
  --    pack/*/start/ plugins.  By the time init.lua runs (and this
  --    module is required), that initial scan has already completed
  --    against the default packpath -- which is now replaced above.
  --
  --    packloadall re-scans the current packpath so git-cloned plugins
  --    under rocks_site/pack/rocks/{start,opt}/ become visible.
  ---------------------------------------------------------------------------
  vim.cmd("packloadall")
end

-- Public API
M.setup_paths = setup_paths
M.load = setup_paths

-- Requiring this module wires the hermetic paths immediately.
setup_paths()

return M
m4_dnl vim: ft=lua
