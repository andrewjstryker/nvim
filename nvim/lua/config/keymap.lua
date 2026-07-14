-- ~/.config/nvim/lua/config/keymap.lua
--
-- A thin, collision-aware wrapper over vim.keymap.set.
--
-- Motivation: mapping overrides in Neovim are silent.  That is how `gs` ended
-- up as a leap motion instead of a git operation -- leap claimed the key and
-- nothing said so.  This config deliberately OWNS a small set of keys; a plugin
-- quietly taking one should be visible, not a mystery to debug months later.
--
-- Not every override is a bug, though.  navigation.lua intentionally replaces
-- <C-h/j/k/l> with tmux-aware versions after keymaps.lua sets the basic ones.
-- So the rule is not "any override is an error"; it is:
--
--   * config re-owning its own key (basic -> tmux nav)      -> fine, silent.
--   * config overwriting a key a PLUGIN mapped globally      -> report.
--   * a plugin's own map stealing a key the config OWNS       -> report (audit).
--
-- To see the middle/last cases, every config-level map site routes through
-- M.set (keymaps.lua, navigation.lua, editing.lua).  Buffer-local maps are
-- never collisions: they legitimately shadow globals (that is exactly how
-- fugitive's in-buffer `s`/`gs` work), so they are ignored here.
--
-- Reports go through vim.notify(WARN) and are collected for :KeymapAudit.
-- Set vim.g.keymap_strict = true (before startup) to raise them to ERROR level.

local M = {}

-- resolved "mode lhs" -> { lhs, mode, desc }  (keys this config declares it owns)
local owned = {}
M.collisions = {}

-- Expand <leader>/<localleader> so maparg lookups match the stored lhs.
local function leader_resolve(lhs)
  local ml  = vim.g.mapleader == " " and " " or (vim.g.mapleader or "\\")
  local mll = vim.g.maplocalleader == " " and " " or (vim.g.maplocalleader or "\\")
  return (lhs:gsub("<[lL]eader>", ml):gsub("<[lL]ocalleader>", mll))
end

-- The current GLOBAL mapping for lhs/mode, or nil (buffer-local maps ignored).
local function global_map(lhs, mode)
  local d = vim.fn.maparg(leader_resolve(lhs), mode, false, true)
  if d and not vim.tbl_isempty(d) and d.buffer == 0 then
    return d
  end
end

local function report(msg)
  M.collisions[#M.collisions + 1] = msg
  local level = vim.g.keymap_strict and vim.log.levels.ERROR or vim.log.levels.WARN
  vim.schedule(function() vim.notify("keymap collision: " .. msg, level) end)
end

-- Drop-in replacement for vim.keymap.set with collision awareness.
-- Extra opt: override = true  -- acknowledge that this deliberately replaces an
-- existing map (e.g. a Neovim default), suppressing the set-time warning.
function M.set(mode, lhs, rhs, opts)
  opts = opts or {}
  local modes = type(mode) == "table" and mode or { mode }
  local acknowledged = opts.override
  opts.override = nil   -- not a vim.keymap.set option; strip before passing on

  for _, m in ipairs(modes) do
    if not opts.buffer and not acknowledged then
      local key = m .. " " .. leader_resolve(lhs)
      local prev = global_map(lhs, m)
      -- Overwriting a live global map we never declared = a plugin's binding.
      if prev and not owned[key] then
        report(("%s %q was mapped to %q (foreign) -- overwriting with %q")
          :format(m, lhs, prev.desc or prev.rhs or "<fn>", opts.desc or "config"))
      end
    end
  end

  vim.keymap.set(mode, lhs, rhs, opts)

  -- Record ownership (last config writer wins; intended re-owns stay silent).
  if not opts.buffer and opts.desc then
    for _, m in ipairs(modes) do
      owned[m .. " " .. leader_resolve(lhs)] = { lhs = lhs, mode = m, desc = opts.desc }
    end
  end
end

-- Verify every owned key still resolves to the mapping the config set for it.
-- Run after all plugins have loaded to catch a plugin that took a key via its
-- own vim.keymap.set (bypassing this wrapper).
function M.audit()
  for _, o in pairs(owned) do
    local d = global_map(o.lhs, o.mode)
    if not d then
      report(("%s %q (%q) is no longer mapped -- something removed it")
        :format(o.mode, o.lhs, o.desc))
    elseif d.desc and d.desc ~= o.desc then
      report(("%s %q should be %q but is now %q -- a plugin took it")
        :format(o.mode, o.lhs, o.desc, d.desc))
    end
  end
end

vim.api.nvim_create_user_command("KeymapAudit", function()
  M.collisions = {}
  M.audit()
  if #M.collisions == 0 then
    vim.notify("KeymapAudit: no collisions on owned keys", vim.log.levels.INFO)
  end
end, { desc = "Re-check that config-owned keys still resolve to their mappings" })

-- One-shot audit once the full plugin set is loaded.
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = M.audit })

return M
