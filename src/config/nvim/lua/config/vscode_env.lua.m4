m4_dnl vscode_env.lua.m4
m4_dnl
m4_dnl VS Code environment wiring.
m4_dnl Rendered at build time: vscode_env.lua.m4 → vscode_env.lua
m4_dnl
m4_dnl Counterpart to env.lua.m4 for use when Neovim runs inside VS Code
m4_dnl (vscode-neovim extension).  The key difference: env.lua REPLACES
m4_dnl runtimepath and packpath with a hermetic set; this module APPENDS
m4_dnl the hermetic paths to Neovim's defaults so that vscode.internal
m4_dnl (and other extension-provided modules) remain discoverable.
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
-- config/vscode_env.lua (generated from vscode_env.lua.m4 -- do not edit)
--
-- Wires the hermetic rocks tree into Neovim when running inside VS Code.
--
-- Unlike config/env.lua (which replaces rtp/packpath entirely), this module
-- APPENDS the hermetic paths to Neovim's defaults.  This preserves the
-- vscode-neovim extension's internal module paths (vscode.internal, etc.)
-- while making hermetic plugins (e.g., vim-fugitive) available.

local M = {}

-- Build-time constants supplied by the protocol renderer context.
M.nvim_rocks_dir = "M4_NVIM_ROCKS_DIR"
M.config_dir     = "M4_NVIM_CONFIG_DIR"

-- Derived constants supplied by paths.m4.
M.rocks_site     = "M4_SITE_DIR"
M.treesitter_dir = "M4_NVIM_TREESITTER_DIR"
M.lua_share_dir  = "M4_NVIM_ROCKS_DIR/share/lua/M4_LUA_VER"
M.lua_lib_dir    = "M4_NVIM_ROCKS_DIR/lib/lua/M4_LUA_VER"

-- Prepend a semicolon-separated path string (Lua package path style)
local function prepend_path(original, prefix)
  if not original or original == "" then
    return prefix
  end
  return prefix .. ";" .. original
end

local function setup_paths()
  if not vim then
    return
  end

  ---------------------------------------------------------------------------
  -- 1) Wire Lua module search paths to the hermetic rocks tree.
  --    Identical to env.lua — native rocks need these entries.
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
  -- 2) APPEND hermetic paths to Neovim's default rtp and packpath.
  --
  --    Unlike env.lua (which replaces rtp/packpath entirely), we append
  --    so that VS Code's extension paths remain intact.  The vscode-neovim
  --    extension adds entries to rtp that provide vscode.internal and other
  --    modules — replacing them breaks the extension.
  --
  --    Appended to runtimepath:
  --      config_dir          -- lua/config/, lua/plugins/, after/, ftplugin/
  --      rocks_site          -- git-cloned plugins runtime files
  --      config_dir/after    -- user after/ overrides
  --
  --    Appended to packpath:
  --      rocks_site          -- pack/rocks/{start,opt}/ for git-cloned plugins
  ---------------------------------------------------------------------------

  vim.opt.runtimepath:append(M.config_dir)
  vim.opt.runtimepath:append(M.rocks_site)
  vim.opt.runtimepath:append(M.config_dir .. "/after")

  vim.opt.packpath:append(M.rocks_site)

  ---------------------------------------------------------------------------
  -- 3) Treesitter parsers and queries.
  --
  --    VS Code owns highlighting, so this is not about highlighting.  Four of
  --    Neovim's own ftplugins -- markdown, lua, help, query -- open with a
  --    bare vim.treesitter.start(), which ASSERTS when no parser can be
  --    created.  Neovim here ships no bundled parsers, and the provisioned
  --    ones live in the hermetic treesitter tree, so without this entry every
  --    markdown or Lua buffer raises E5113 inside VS Code.
  --
  --    In the normal path lua/plugins/treesitter.lua is the sole owner of this
  --    rtp entry, via nvim-treesitter's setup({ install_dir = ... }).  VS Code
  --    mode never loads config.plugins, so it must wire the same directory
  --    itself -- prepended, as setup() does, so both modes resolve parsers and
  --    queries in the same order.
  --
  --    The path is stamped at build time like every other entry here, and
  --    nothing is created or probed: VS Code mode only ever READS parsers.
  --    lua/plugins/treesitter.lua does mkdir its install_dir first, but that
  --    is a provisioning concern -- nvim-treesitter WRITES there, and
  --    clean-parsers followed by sync cleans and re-provisions within one
  --    process.  An absent directory here only means sync has not run, and
  --    creating an empty one would repair nothing: a missing runtimepath
  --    entry is kept in the option and simply yields no files.
  ---------------------------------------------------------------------------

  vim.opt.runtimepath:prepend(M.treesitter_dir)

  ---------------------------------------------------------------------------
  -- 4) Trigger pack scanning so plugins in the appended packpath are found.
  ---------------------------------------------------------------------------
  vim.cmd("packloadall")
end

-- Public API (mirrors env.lua)
M.setup_paths = setup_paths
M.load = setup_paths

-- Requiring this module wires the paths immediately.
setup_paths()

return M
m4_dnl vim: ft=lua
