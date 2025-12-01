-- lua/config/bootstrap.lua

local M = {}

-- We assume config.env exists and is correct. Any failure here is a hard error.
local function setup_env()
  require("config.env")
end

local function sync_rocks()
  local ok, rocks = pcall(require, "rocks")
  if not ok then
    error("Required plugin 'rocks.nvim' is missing: " .. tostring(rocks))
  end

  -- Use the public command interface; this is stable and clear.
  vim.cmd("Rocks sync")
end

--- Non-interactive bootstrap + sync for `make sync`.
function M.auto_setup()
  setup_env()
  sync_rocks()
end

return M
