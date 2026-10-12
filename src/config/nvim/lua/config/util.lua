-- ~/.config/nvim/lua/config/util.lua
local M = {}

function M.safe_require(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    vim.notify(("Module not loaded: %s\n%s"):format(mod, err), vim.log.levels.WARN)
  end
  return ok
end

-- Neovim's own FileType handlers (filetypeplugin, filetypeindent, syntaxset)
-- run before this configuration's.  A plugin packadd'ed from a FileType
-- autocmd therefore misses the buffer that triggered it: its ftplugin, indent
-- and syntax scripts were looked up before it was on the runtimepath.  Replay
-- those three groups for the current buffer.  Re-firing FileType itself would
-- re-enter the `once` autocmd that called us, so target the groups directly,
-- and clear 'syntax' first because SynSet is a no-op when the option is
-- assigned its current value.  The loaders clear the did_ftplugin/did_indent
-- guards only when an undo string exists, and some bundled scripts (csv) set
-- the guard without one, so clear the guards here.
function M.replay_filetype(ft)
  vim.b.did_ftplugin, vim.b.did_indent = nil, nil
  vim.bo.syntax = ""
  for _, group in ipairs({ "filetypeplugin", "filetypeindent", "syntaxset" }) do
    if vim.fn.exists("#" .. group .. "#FileType") == 1 then
      vim.cmd("doautocmd <nomodeline> " .. group .. " FileType " .. ft)
    end
  end
end

-- Hot-reload your config quickly
vim.api.nvim_create_user_command("ReloadConfig", function()
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^env") then
      package.loaded[name] = nil
    end
  end
  local config_root = vim.fn.stdpath("config")
  dofile(config_root .. "/init.lua")
  print("Config reloaded")
end, {})

return M
