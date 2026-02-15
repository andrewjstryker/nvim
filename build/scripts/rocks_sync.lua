-- build/scripts/rocks_sync.lua
--
-- Headless Rocks sync for `make sync`.
--
-- Invoked as:
--   LUAROCKS_CONFIG=... NVIM_CONFIG_DIR=... nvim --headless -u NONE \
--     +"luafile build/scripts/rocks_sync.lua" +qa
--
-- Why -u NONE + manual wiring:
--   We run without a vimrc so Neovim doesn't try to load a half-installed
--   config.  Instead we manually:
--     1) prepend NVIM_CONFIG_DIR to rtp/packpath
--     2) require config.env (wires hermetic paths, sets vim.g.rocks_nvim)
--     3) packadd rocks.nvim
--     4) run :Rocks sync
--
--   This duplicates some of what init.lua does, but that's intentional:
--   init.lua assumes a fully installed config; this script bootstraps from
--   a bare Neovim with only NVIM_CONFIG_DIR and LUAROCKS_CONFIG set.

local function log(msg)
  vim.api.nvim_out_write("[rocks-sync] " .. msg .. "\n")
end

----------------------------------------------------------------------
-- 1. Wire rtp/packpath to the installed config
----------------------------------------------------------------------

local config_dir = vim.env.NVIM_CONFIG_DIR
if not config_dir or config_dir == "" then
  error("[rocks-sync] NVIM_CONFIG_DIR environment variable must be set")
end

log("NVIM_CONFIG_DIR = " .. config_dir)
vim.opt.rtp:prepend(config_dir)
vim.opt.packpath:prepend(config_dir)

----------------------------------------------------------------------
-- 2. Wire hermetic env via config.env (rendered from env.lua.m4)
----------------------------------------------------------------------

log("Loading config.env...")
local ok_env, env_err = pcall(require, "config.env")
if not ok_env then
  error("[rocks-sync] Failed to load config.env: " .. tostring(env_err))
end
log("config.env loaded")

----------------------------------------------------------------------
-- 3. Enable auto_sync (merge into existing vim.g.rocks_nvim)
--
--    vim.g.rocks_nvim returns a COPY, so we must read-modify-write
--    the whole table, not assign to a field.
----------------------------------------------------------------------

local rocks_cfg = vim.g.rocks_nvim or {}
rocks_cfg.auto_sync = true
vim.g.rocks_nvim = rocks_cfg
log("vim.g.rocks_nvim.auto_sync = true")

----------------------------------------------------------------------
-- 4. Load rocks.nvim and run :Rocks sync
----------------------------------------------------------------------

log("Running :packadd rocks.nvim")
local ok_packadd, pack_err = pcall(vim.cmd, "packadd rocks.nvim")
if not ok_packadd then
  error("[rocks-sync] :packadd rocks.nvim failed: " .. tostring(pack_err))
end

if vim.fn.exists(":Rocks") ~= 2 then
  error("[rocks-sync] :Rocks command not found after packadd")
end

log("Running :Rocks sync")
local ok_sync, sync_err = pcall(vim.cmd, "Rocks sync")
if not ok_sync then
  error("[rocks-sync] :Rocks sync failed: " .. tostring(sync_err))
end

log("Done")
