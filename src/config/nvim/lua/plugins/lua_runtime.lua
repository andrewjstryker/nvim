-- Loaded once, on the first Lua or Fennel FileType event, before syntax.
-- Trusted .nvim.lua files can set lua_ls.settings.Lua.runtime.version using
-- vim.lsp.config(). That target applies to both languages for this session.
local config = vim.lsp.config.lua_ls or {}
local target = vim.tbl_get(config, "settings", "Lua", "runtime", "version")

if not target then
  local executable = vim.fn.exepath("lua")
  if executable == "" then
    target = "Lua 5.1"
  else
    local result = vim.system({ executable, "-v" }, { text = true }):wait(2000)
    local output = (result.stdout or "") .. (result.stderr or "")
    assert(result.code == 0, "Cannot determine system Lua version: " .. output)
    if output:match("^LuaJIT") then
      target = "LuaJIT"
    else
      local version = output:match("^Lua (%d+%.%d+)")
      assert(version, "Unrecognized system Lua version: " .. output)
      target = "Lua " .. version
    end
  end
end

local luajit = target == "LuaJIT"
local version = luajit and "5.1" or target:match("^Lua (%d+%.%d+)$")
assert(version, "Expected lua_ls runtime.version to be LuaJIT or Lua <major.minor>")

-- Set both options before packadd: the plugin's own detector does not
-- recognize Lua 5.5. These are session defaults, shared by subsequent files.
vim.g.fennel_lua_version = version
vim.g.fennel_use_luajit = luajit and 1 or 0
vim.cmd("packadd fennel")

-- Neovim already detects .fnl/.fnlm. The plugin's late BufRead detector uses
-- `setlocal filetype`, which repeats FileType after EditorConfig and restores
-- plugin indentation over project settings. Remove only those duplicate
-- extension handlers; its guarded shebang detector can remain.
vim.api.nvim_clear_autocmds({
  group = "filetypedetect",
  event = { "BufReadPost", "BufNewFile" },
  pattern = { "*.fnl", "*.fnlm" },
})

vim.lsp.config("lua_ls", {
  settings = { Lua = { runtime = { version = target } } },
})
vim.lsp.enable("lua_ls")

-- The session's first Fennel buffer looked up its ftplugin, indent and syntax
-- scripts before the package above was on the runtimepath.
if vim.bo.filetype == "fennel" then
  require("config.util").replay_filetype("fennel")
end
