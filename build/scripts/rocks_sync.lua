-- build/scripts/rocks_sync.lua
--
-- Non-interactive sync: parse rocks.toml and install all plugins.
--
-- Runs under the host Lua 5.1 / LuaJIT interpreter (NOT inside Neovim).
-- Requires toml-edit in the hermetic rocks tree (installed during bootstrap).
--
-- This script produces the same on-disk layout that rocks.nvim and
-- rocks-git.nvim would produce via interactive `:Rocks sync`, so that
-- the runtime plugin managers find a fully populated environment on
-- first boot.
--
-- Usage (called by seed.mk rocks-sync target):
--   LUA_PATH=...  LUA_CPATH=...  \
--     lua rocks_sync.lua <rocks.toml> <rocks_dir> <luarocks_cmd> <git> <server>
--
-- Arguments:
--   1  rocks.toml     path to the installed rocks.toml
--   2  rocks_dir      hermetic rocks tree root (nvim_rocks_dir)
--   3  luarocks_cmd   full luarocks invocation (e.g., "lua /usr/bin/luarocks")
--   4  git            path to git binary
--   5  server         luarocks server URL (rocks-binaries)
--
-- Environment (set by caller):
--   LUA_PATH         hermetic Lua module search path
--   LUA_CPATH        hermetic Lua C module search path
--   LUAROCKS_CONFIG  path to hermetic luarocks config.lua

local toml_edit = require("toml_edit")

-- ---------------------------------------------------------------------------
-- Arguments
-- ---------------------------------------------------------------------------

local rocks_toml_path = arg[1]
local rocks_dir       = arg[2]
local luarocks_cmd    = arg[3]
local git_cmd         = arg[4]
local server          = arg[5]

if not (rocks_toml_path and rocks_dir and luarocks_cmd and git_cmd and server) then
  io.stderr:write(
    "Usage: lua rocks_sync.lua"
    .. " <rocks.toml> <rocks_dir> <luarocks_cmd> <git> <server>\n"
  )
  os.exit(1)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function log(msg)
  io.write("[rocks-sync] " .. msg .. "\n")
  io.flush()
end

local function run(cmd)
  local ok = os.execute(cmd)
  -- Lua 5.1: os.execute returns exit code (0 = success)
  -- LuaJIT:  os.execute returns true/nil, reason, code
  if ok == 0 or ok == true then
    return true
  end
  return false
end

--- Check whether a git clone exists at the given path.
--- Works in plain Lua without lfs.
local function clone_exists(path)
  local fh = io.open(path .. "/.git/HEAD", "r")
  if fh then
    fh:close()
    return true
  end
  return false
end

--- Run a git query in the clone at `path` and return the first line of
--- stdout (trimmed), or nil.  stderr is suppressed so an ambiguous ref
--- (a tag and a like-named branch both present) does not leak a warning.
local function git_line(path, args)
  local fh = io.popen("git -C '" .. path .. "' " .. args .. " 2>/dev/null")
  if not fh then return nil end
  local result = fh:read("*l")
  fh:close()
  if result == nil or result == "" then return nil end
  return result
end

--- True if `full_ref` (a fully-qualified ref, e.g. "refs/tags/v3.0.0")
--- exists in the clone at `path`.
local function has_ref(path, full_ref)
  return git_line(path,
    "rev-parse --verify --quiet '" .. full_ref .. "'") ~= nil
end

--- Resolve `ref` (a branch, tag, or SHA) to a commit SHA in the clone at
--- `path`, or nil.  Fully-qualified candidates are tried first — tag, then
--- local branch, then remote-tracking — so a pinned tag resolves cleanly
--- even while a stray like-named local branch still exists, and no bare,
--- ambiguity-prone name is used unless nothing else matches.
local function resolve_ref(path, ref)
  local candidates = {
    "refs/tags/" .. ref,
    "refs/heads/" .. ref,
    "refs/remotes/origin/" .. ref,
    ref,
  }
  for _, r in ipairs(candidates) do
    local sha = git_line(path,
      "rev-parse --verify --quiet '" .. r .. "^{commit}'")
    if sha then return sha end
  end
  return nil
end

--- True if the clone's HEAD (detached or not) is already at `ref`'s commit.
local function at_ref(path, ref)
  local head = git_line(path, "rev-parse --verify --quiet 'HEAD^{commit}'")
  return head ~= nil and head == resolve_ref(path, ref)
end

-- ---------------------------------------------------------------------------
-- Parse rocks.toml
-- ---------------------------------------------------------------------------

local fh, err = io.open(rocks_toml_path, "r")
if not fh then
  io.stderr:write("[rocks-sync] Cannot open " .. rocks_toml_path
    .. ": " .. tostring(err) .. "\n")
  os.exit(1)
end
local content = fh:read("*a")
fh:close()

local parse_ok, tbl = pcall(toml_edit.parse_as_tbl, content)
if not parse_ok then
  io.stderr:write("[rocks-sync] Failed to parse " .. rocks_toml_path
    .. ": " .. tostring(tbl) .. "\n")
  os.exit(1)
end

local plugins = tbl.plugins or {}

-- ---------------------------------------------------------------------------
-- Collect entries by type
--
-- TOML dotted keys create nested tables.  For example:
--
--   [plugins.gitsigns.nvim]
--   git = "lewis6991/gitsigns.nvim"
--
-- parses as  plugins["gitsigns"]["nvim"] = { git = "..." }
-- NOT as     plugins["gitsigns.nvim"]    = { git = "..." }
--
-- We walk the plugins table recursively.  A table with a "git" key is a
-- git plugin spec.  A table without "git" whose values are themselves
-- tables represents a dotted-key intermediate — we descend and reconstruct
-- the full dotted name.
--
-- Flat string values (e.g., "rocks.nvim" = "2.45.1") are native rocks.
-- ---------------------------------------------------------------------------

local pinned_rocks   = {}  -- { {name, version}, ... }  — explicit version pin
local unpinned_rocks = {}  -- { {name, version}, ... }  — "scm", "dev", etc.
local git_plugins    = {}  -- { {name, repo, "start"|"opt"}, ... }

--- True if the version string is a concrete pin (not floating).
local function is_pinned(version)
  return version ~= "scm" and version ~= "dev"
end

local function collect(tbl_node, prefix)
  for key, spec in pairs(tbl_node) do
    local full_name = prefix and (prefix .. "." .. key) or key

    if type(spec) == "string" then
      -- Flat luarocks entry: "rocks.nvim" = "2.45.1"
      local dest = is_pinned(spec) and pinned_rocks or unpinned_rocks
      table.insert(dest, { name = full_name, version = spec })

    elseif type(spec) == "table" then
      if spec.git then
        -- Git plugin spec (has a "git" key)
        local kind = spec.opt and "opt" or "start"
        table.insert(git_plugins, {
          name   = full_name,
          repo   = spec.git,
          kind   = kind,
          branch = spec.branch,  -- optional: pin to a specific branch
        })
      else
        -- Intermediate dotted-key table — descend
        collect(spec, full_name)
      end
    end
  end
end

collect(plugins, nil)

-- Sort each group for deterministic output
table.sort(pinned_rocks,   function(a, b) return a.name < b.name end)
table.sort(unpinned_rocks, function(a, b) return a.name < b.name end)
table.sort(git_plugins,    function(a, b) return a.name < b.name end)

-- ---------------------------------------------------------------------------
-- Install native rocks via luarocks (two passes)
--
-- Pass 1: pinned rocks (explicit version like "2.45.1").
-- Pass 2: unpinned rocks ("scm", "dev").
--
-- Pinned rocks are installed first so that when luarocks resolves transitive
-- dependencies for unpinned rocks, any pinned version already present
-- satisfies the constraint — avoiding install-then-replace churn.
--
-- Example: rocks.toml pins rocks.nvim = "2.45.1" and declares
-- rocks-config.nvim = "scm" (which depends on rocks.nvim >= 2.32.1).
-- Installing rocks.nvim 2.45.1 first means rocks-config.nvim finds it
-- already present and doesn't pull the latest.
-- ---------------------------------------------------------------------------

local errors = {}
local total_rocks = #pinned_rocks + #unpinned_rocks

--- Install a list of rocks.
local function install_rocks(rocks, label)
  for _, rock in ipairs(rocks) do
    local cmd = luarocks_cmd
      .. " --lua-version=5.1"
      .. " --tree " .. rocks_dir
      .. " --server='" .. server .. "'"
      .. " install " .. rock.name
    if is_pinned(rock.version) then
      cmd = cmd .. " " .. rock.version
    end

    log("  luarocks: " .. rock.name .. " " .. rock.version
      .. (label and (" [" .. label .. "]") or ""))
    if not run(cmd) then
      local msg = "Failed to install rock: " .. rock.name
      log("  ERROR: " .. msg)
      table.insert(errors, msg)
    end
  end
end

if total_rocks > 0 then
  log("Installing " .. total_rocks .. " native rock(s)...")
  install_rocks(pinned_rocks,   "pinned")
  install_rocks(unpinned_rocks, "unpinned")
end

-- ---------------------------------------------------------------------------
-- Clone git plugins
--
-- Pack path structure (matches NV_M4_START_DIR / NV_M4_OPT_DIR in paths.m4):
--   ${rocks_dir}/share/nvim/site/pack/rocks/{start,opt}/<n>/
-- ---------------------------------------------------------------------------

local site_pack = rocks_dir .. "/share/nvim/site/pack/rocks"

if #git_plugins > 0 then
  log("Syncing " .. #git_plugins .. " git plugin(s)...")
  for _, plug in ipairs(git_plugins) do
    local dest = site_pack .. "/" .. plug.kind .. "/" .. plug.name
    if clone_exists(dest) then
      -- A pinned ref (`branch`) may name a branch OR a tag.  We treat it as
      -- an opaque ref, check it out in DETACHED HEAD, and consider the clone
      -- in-sync when HEAD's commit matches the ref's commit.  We never create
      -- a local branch named after the ref: a local branch sharing a tag's
      -- name (e.g. the `v3.0.0` tag copilot.lua pins) makes every `git
      -- <ref>` lookup ambiguous, and a subsequent `fetch <ref>:<ref>` fails
      -- with "Refusing to fetch into current branch".
      if plug.branch then
        -- Heal a pre-existing tag/branch name collision left by older sync
        -- runs: when both refs/tags/<ref> and refs/heads/<ref> exist, detach
        -- and delete the stray branch so the tag becomes unambiguous again.
        if has_ref(dest, "refs/tags/" .. plug.branch)
           and has_ref(dest, "refs/heads/" .. plug.branch) then
          run(git_cmd .. " -C " .. dest .. " checkout --detach --quiet HEAD")
          run(git_cmd .. " -C " .. dest .. " branch -D " .. plug.branch
            .. " >/dev/null 2>&1")
        end

        if at_ref(dest, plug.branch) then
          log("  [skip] " .. plug.name
            .. " (already at " .. plug.branch .. ")")
        else
          log("  [checkout] " .. plug.name .. " (-> " .. plug.branch .. ")")
          -- Fetch the ref into FETCH_HEAD and check it out detached.  This
          -- works uniformly for branches and tags and leaves no local branch
          -- to collide with a same-named tag.  The fetch also updates the
          -- remote-tracking ref / tag, so the next sync resolves it and skips.
          local fetch = git_cmd .. " -C " .. dest
            .. " fetch --depth=1 origin " .. plug.branch
          local checkout = git_cmd .. " -C " .. dest
            .. " checkout --detach --quiet FETCH_HEAD"
          if not (run(fetch) and run(checkout)) then
            local msg = "Failed to check out ref: " .. plug.name
              .. " (-> " .. plug.branch .. ")"
            log("  ERROR: " .. msg)
            table.insert(errors, msg)
          end
        end
      else
        log("  [skip] " .. plug.name .. " (already cloned)")
      end
    else
      log("  [clone] " .. plug.name .. " <- " .. plug.repo
        .. (plug.branch and (" [branch=" .. plug.branch .. "]") or ""))
      -- If the repo value is already a full URL, use it directly.
      -- Otherwise treat it as a GitHub owner/repo shorthand.
      local url
      if plug.repo:match("^https?://") then
        url = plug.repo
      else
        url = "https://github.com/" .. plug.repo .. ".git"
      end
      local branch_flag = plug.branch and (" --branch " .. plug.branch) or ""
      local cmd = git_cmd
        .. " clone --depth=1"
        .. branch_flag
        .. " " .. url
        .. " " .. dest
      if not run(cmd) then
        local msg = "Failed to clone: " .. plug.name
          .. " (" .. plug.repo .. ")"
        log("  ERROR: " .. msg)
        table.insert(errors, msg)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

if #errors > 0 then
  log(#errors .. " error(s) during sync:")
  for _, e in ipairs(errors) do
    log("  - " .. e)
  end
  os.exit(1)
end

log("Done. "
  .. total_rocks .. " rock(s) ("
  .. #pinned_rocks .. " pinned, "
  .. #unpinned_rocks .. " unpinned), "
  .. #git_plugins .. " git plugin(s).")
