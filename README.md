# Hermetic Neovim Configuration (Make-driven, Rocks-first)

This repository provides a **hermetic, reproducible Neovim configuration**
powered by a **Makefile DAG** and a **fully isolated Rocks (LuaRocks) tree**.
The system builds the runtime *before* install so Neovim loads **pure Lua**
with no dynamic discovery or probing.

If all required tools are present,
**`make sync` always yields a working configuration.**

---

## Quick Install

### Prerequisites

| Tool    | Role                                    |
| ------- | --------------------------------------- |
| `nvim`  | runtime                                 |
| `lua` / `luajit` | fallback for Rocks bootstrap  |
| `m4`    | template rendering (`*.lua.m4 → *.lua`) |
| `git`   | submodule checkout                      |
| `rsync` | atomic install and stage copy           |
| `awk`   | minor tooling                           |

### Install

```bash
git clone --recurse-submodules <this repo>
cd <repo>
make sync
```

This:

1. builds the stage image (`stage/nvim/`)
2. copies vendored seed plugins into `pack/rocks/start/`
3. installs the config into `NVIM_CONFIG_DIR`
4. runs a headless `:Rocks sync` to install plugins

### If you already cloned without `--recurse-submodules`

```bash
git submodule update --init
```

---

## Daily Usage

### Update plugins

```bash
make sync
```

### Run smoke test (full install into temp directories)

```bash
make test
```

### Remove the config only

```bash
make uninstall FORCE=1
```

### Remove the config *and* hermetic Rocks cache

```bash
make uninstall-cache FORCE=1
```

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

## Updating seed plugins

Seed plugin managers (`rocks.nvim` and `rocks-git.nvim`) are vendored as
git submodules under `vendor/`. To update:

```bash
cd vendor/rocks.nvim
git fetch && git checkout v2.46.0   # or whatever version
cd ../..
git add vendor/rocks.nvim
git commit -m "bump rocks.nvim to v2.46.0"
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
