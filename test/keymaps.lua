-- test/keymaps.lua
--
-- Fail if the loaded configuration has keymap collisions on config-owned keys.
-- Run headless under the FULL config so plugin maps are live, using the SAME
-- audit the runtime runs at VimEnter (config.keymap) -- no separate rulebook.
--
--   nvim --headless -u <cfg>/init.lua -c 'luafile test/keymaps.lua' -c qa
--
-- Severity: ERROR.  A silent override (one plugin taking a key the config
-- declared, an unacknowledged clobber of a plugin/default map) is exactly the
-- class of bug this gate exists to stop before install.  Set-time collisions
-- are collected during startup; audit() appends any post-load clobbers.
--
-- NOTE: only sees maps the plugins actually register, so run against a synced
-- plugin tree (make sync) for full coverage.

local ok, km = pcall(require, "config.keymap")
if not ok then
  io.stderr:write("KEYMAP FAIL: config.keymap module not loaded\n")
  os.exit(1)
end

km.audit()

-- de-duplicate (a conflict can surface both at set-time and in the audit)
local seen, uniq = {}, {}
for _, c in ipairs(km.collisions) do
  if not seen[c] then
    seen[c] = true
    uniq[#uniq + 1] = c
  end
end

if #uniq > 0 then
  io.stderr:write("KEYMAP FAIL: keymap collision(s) detected:\n")
  for _, c in ipairs(uniq) do
    io.stderr:write("  - " .. c .. "\n")
  end
  os.exit(1)
end

io.stdout:write("KEYMAP OK: no collisions on config-owned keys\n")
os.exit(0)
