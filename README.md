# Hermetic Neovim Configuration (Make-driven, Rocks-first)

This repository provides a **hermetic, reproducible Neovim configuration**
powered by a **Makefile DAG** and a **fully isolated Rocks (LuaRocks) tree**.
The system builds the runtime *before* install so Neovim loads **pure Lua**
with no dynamic discovery or probing.

The common stage/install/uninstall lifecycle is supplied by the repository-local
`protocol/` unit. It is copied into the tree today at the path intended for a
future submodule.

If all required tools are present, `make install` followed by `make sync`
yields a working configuration. The collection driver exposes that ordered
operation as `home apply nvim`.

---

## Quick Install

### Prerequisites

| Tool         | Role                                    |
| ------------ | --------------------------------------- |
| `nvim`       | runtime                                 |
| `lua` / `luajit` | host Lua 5.1 for build-time sync   |
| `luarocks`   | package manager for Neovim rocks        |
| `m4`         | template rendering (`*.lua.m4 → *.lua`) |
| `git`        | cloning git-based plugins               |
| `rsync`      | atomic install and stage copy           |
| `awk`        | minor tooling                           |
| `tree-sitter` >= 0.26.1 | compiling configured parsers      |
| C compiler   | compiling configured parsers             |

### Optional: formatters

Formatters (`prettier`, `stylua`, `ruff`, `black`, `sql_formatter`, `styler`)
are optional. Whichever are present on PATH when `make install` stages the
configuration are wired into conform.nvim; filetypes with no formatter
installed fall through to LSP formatting. Re-run `make install` (or the
collection driver's apply operation) after adding one. See
[`FORMATTERS.md`](./FORMATTERS.md) for installation and verification steps.

### Install

```bash
git clone <this repo>
cd <repo>
make install
make sync
```

This:

1. builds the stage image (`stage/config/nvim/`)
2. installs the config into `NVIM_CONFIG_DIR`
3. bootstraps `toml-edit` into the hermetic rocks tree
4. parses `rocks.toml` and installs all plugins (native rocks via `luarocks`,
   git plugins via `git clone`)

---

## Install-time vs runtime plugin management

The build system and the runtime plugin managers operate on the **same
contract**: the same directory layout, the same `rocks.toml` manifest, and
the same hermetic rocks tree.

**At install time**, the build system populates the environment
non-interactively. A Lua script (`rocks_sync.lua`) runs under the host Lua
interpreter — not Neovim — and uses `toml-edit` to parse `rocks.toml`. It
installs native rocks via `luarocks` and clones git plugins into the pack
directory. No interactive prompts, no Neovim invocation.

**At runtime**, `rocks.nvim` and `rocks-git.nvim` are fully functional for
interactive use: `:Rocks install`, `:Rocks update`, `:Rocks sync`, etc.
They find a fully populated environment on first boot and manage it from
there.

---

## Daily Usage

### Lua and Fennel projects

The first Lua or Fennel buffer initializes support for both languages once per
Neovim session, including loading the optional Fennel syntax package. Its Lua
target comes from `lua_ls`'s `settings.Lua.runtime.version`, if configured;
otherwise it comes from `lua -v` on PATH (Lua 5.1 if `lua` is absent).
Subsequent files reuse that target. Start a new session to change targets.

Project configuration uses Neovim's built-in `exrc` support, enabled here.
For example, a Neovim project can place this in `.nvim.lua`:

```lua
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { library = { vim.env.VIMRUNTIME } },
      diagnostics = { globals = { "vim" } },
    },
  },
})
```

For standalone Lua, set `runtime.version` to, for example, `"Lua 5.5"` and
omit the Neovim library/globals. Open the project configuration and use
`:trust`, then restart Neovim from the project directory. Neovim owns local
config discovery and trust; this configuration does not scan each buffer's
ancestors or parse custom modelines. A `.luarc.json` remains a LuaLS-specific
configuration file; use `.nvim.lua` for a target shared with Fennel highlighting.

After updating, run `make install` and `make sync`; sync moves an existing
Fennel checkout from `start` to `opt` while preserving local edits.

### Update plugins

```bash
make sync
```

### Run smoke test (full install into temp directories)

```bash
make test
```

`make test` needs the network: it syncs plugins and parsers into temp
directories, then runs every check against that install. `make check` runs
the same checks that work offline, against the already-synced cache, in
seconds — it is the one to run before installing:

```bash
make check                     # staged artifacts + every offline check
make check CHECKS=lua_runtime  # narrow it while iterating
```

The check names are `keymaps`, `ts_works`, `lua_runtime`, `vscode` and
(network only) `ts_install`. Adding a check does not add a make target: it
goes in the list
in `test.mk`.

### Remove the config only

```bash
make uninstall
```

Uninstall is conservative: it removes only files that still match the current
manifest and leaves locally modified files in place.

### Remove the config *and* hermetic Rocks cache

```bash
make uninstall-cache
```

---

## Troubleshooting

### Strange `require()` / module-loading errors

Neovim's byte-compiled Lua cache lives outside the hermetic tree at
`~/.cache/nvim/luac/`.  Stale entries from a prior Neovim build can cause
modules to load with unexpected return values — for example, a `require()`
returning `true` instead of a table, leading to "attempt to index a boolean
value" errors deep inside an unrelated plugin.  If you see this kind of
error after upgrading Neovim or moving between configurations:

```bash
rm -rf ~/.cache/nvim/luac
```

then restart Neovim.

---

## Configuration knobs

Only two environment variables are documented and supported:

| Variable          | Meaning                                               |
| ----------------- | ----------------------------------------------------- |
| `NVIM_CONFIG_DIR` | Where the final Neovim configuration is installed     |
| `NVIM_CACHE_DIR`  | Used to derive the hermetic Rocks tree                |

Everything else in the build system is intentionally **not user-configurable**
to protect reproducibility and correctness.

Defaults:

```bash
NVIM_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/nvim
NVIM_CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/nvim
```

---

## Design

The build obeys three principles:

| Principle       | Interpretation                                                  |
| --------------- | --------------------------------------------------------------- |
| Hermetic        | No dependence on system Lua or global plugins                   |
| Reproducible    | Build logic expressed as a Makefile DAG, not runtime heuristics |
| Minimal runtime | All work happens before install; Neovim loads plain Lua         |

Full architecture, invariants, and conventions are documented in
[`design.md`](./design.md).
