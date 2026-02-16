-- ~/.config/nvim/lua/config/util.lua
local M = {}

function M.safe_require(mod)
  local ok, _ = pcall(require, mod)
  if not ok then
    vim.notify(("Module not loaded: %s"):format(mod), vim.log.levels.DEBUG)
  end
  return ok
end

-- Hot-reload your config quickly
vim.api.nvim_create_user_command("ReloadConfig", function()
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^env") then
      package.loaded[name] = nil
    end
  end
  local config_root = vim.env.NVIM_CONFIG_DIR or vim.fn.stdpath("config")
  dofile(config_root .. "/init.lua")
  print("Config reloaded")
end, {})

return M
