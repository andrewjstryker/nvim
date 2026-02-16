# Hermetic Neovim Configuration Build System

This document describes the **design and invariants** of the Neovim
configuration build system. It explains *why* the system is structured the way
it is and what guarantees it provides.

This is **not** an installation guide — see `README.md` for usage.

---

## Summary

We provide a **hermetic, reproducible build** for a Neovim configuration centered
on **rocks.nvim**.

The system is driven by a **Makefile DAG using file targets and pattern rules**.
All transformation work happens **before installation**. The runtime executes
**pure Lua only** — no discovery, probing, or dynamic configuration for concerns
that are known at build time.

Key decisions:

* **Shell**: Bash (strict mode)
* **Stage (build.mk)**: prepares *repo-managed artifacts only* under `stage/nvim/`
* **Seed (seed.mk)**: bootstraps toml-edit via `luarocks`, then syncs all
  plugins from `rocks.toml` using a host Lua script (no Neovim invocation)
* **Install**: copies staged artifacts into `NVIM_CONFIG_DIR`
* **Test**: performs a complete installation and sync using temporary directory
  overrides
* **Templating**: `*.lua.m4 → *.lua` at build time
* **Fennel**: compiled at build time only (`*.fnl → *.lua`)
* **Isolation**: plugins install into a hermetic LuaRocks tree derived from
  `NVIM_CACHE_DIR` (never system Lua)
* **M4 discipline**: all build-time m4 symbols are prefixed with `NV_M4_`
* **Idempotence**: rely on Make's dependency model; use content comparison only
  where timestamps cannot represent change (environment capture)

The runtime remains trivial: **load Lua and run**.

---

## Goals

* **Hermetic** — no dependency on system Lua or global plugin trees
* **Reproducible** — same inputs yield the same runtime
* **Minimal runtime** — no dynamic work for build-known concerns
* **Fail fast** — missing prerequisites or invariants cause immediate failure
* **rocks.nvim first** — plugin management is explicit and deterministic

---

## Probing Policy

This project uses "probing" in four distinct contexts. The key rule is to
**avoid probing internal build outputs to compensate for uncertain build
behavior**, while still supporting **host discovery** and **invariant
verification**.

### 1) Host discovery (desired)

Host systems vary (Linux distros, Homebrew vs apt, different PATH layouts). The
build must be resilient to these differences.

* `environment.mk` may **discover required tools via PATH** (e.g., `command -v`)
  and treat "tool is invokable" as the only requirement.
* We do not care where tools are installed, only that they are available on PATH
  (or provided via override).
* **Lua is part of host discovery**, with an additional compatibility constraint:

  * Acceptable runtimes are **LuaJIT** or **Lua 5.1**.
  * `environment.mk` may select from a small, explicit set of likely command
    names (e.g., `luajit`, `lua` if it is 5.1, `lua5.1`).
  * Users may override the selected command (e.g., `LUA_CMD=...`) to force a
    specific runtime.

**Principle:** Host discovery is not "guessing." It is a portability feature
with explicit constraints and optional user overrides.

### 2) Build-time guarantees (required)

Build-time substitutions and build outputs are treated as **authoritative**.

* Neither build-time Make logic nor runtime Lua/Vim code should **probe internal
  structures to see if build-time substitutions "worked."**
* Avoid patterns like:

  * "Define a path, then check if it exists to decide whether the definition
    was correct."
  * "Try one internal directory layout, then fall back to another if the first
    looks wrong."
  * "Compute derived variables and then conditionally rewrite them based on
    observed filesystem state."

If a build-time substitution is incorrect, that is a **build failure**, not
something to be papered over.

**Principle:** The build should be deterministic. Internal probing is a code
smell that usually indicates missing validation or unclear ownership.

### 3) Testing and verification (desired)

Probing is encouraged in tests and verification targets to enforce invariants.

* A `verify` target (and/or CI checks) should probe to confirm:

  * Required host tools exist and are runnable.
  * Required versions/invariants hold (e.g., LuaJIT or Lua 5.1).
  * Generated artifacts exist and meet expectations (e.g., templated files
    contain no unresolved placeholders, expected directories are created).
* Fail fast with clear error messages that explain what is missing and how to
  fix it.

**Principle:** "Probe to verify invariants" is good. It keeps build/runtime
code simple while still catching mistakes early.

### 4) Runtime probing (allowed only for non-guaranteed concerns)

Runtime code may probe only for concerns that **cannot** be guaranteed at build
time, or for optional integrations.

Examples:

* Optional developer tools or features that may not exist on every system.
* Runtime environment differences that appear after installation (e.g.,
  user-specific PATH changes, editor running in constrained environments).
* Graceful degradation when a non-essential dependency is missing.

Runtime probing should not be used to "repair" or reinterpret the build output.

**Principle:** Runtime probing is for *optional or inherently dynamic*
conditions, not for validating the build pipeline.

### Summary

* **Host discovery:** yes (including Lua), with explicit constraints and overrides.
* **Build-time guarantees:** no internal probing to see if the build "worked."
* **Testing:** yes—probe hard to verify invariants and fail fast.
* **Runtime:** probe only for what build-time cannot guarantee (optional/dynamic concerns).

---

## Repository layout

### Source tree

```
repo/
├─ nvim/
│  ├─ init.lua
│  ├─ rocks.toml
│  ├─ lua/
│  │   ├─ config/
│  │   │   ├─ env.lua.m4
│  │   │   ├─ options.lua
│  │   │   ├─ keymaps.lua
│  │   │   ├─ autocmds.lua
│  │   │   └─ util.lua
│  ├─ after/ ftplugin/ colors/ plugin/   # optional runtime dirs
├─ build/
│  ├─ bin/       # vendored tools (e.g., fennel)
│  ├─ m4/        # shared m4 macros + generated env capture
│  └─ scripts/   # build-time helper scripts (e.g., rocks_sync.lua)
├─ stage/        # build outputs (gitignored)
├─ Makefile
├─ environment.mk
├─ project.mk
├─ build.mk
└─ seed.mk
```

### Module uniqueness invariant

For a given Lua module path (e.g., `config.session`), **exactly one**
implementation exists in `nvim/lua/**`:

* `module.lua`
* `module.lua.m4`
* `module.fnl`

This invariant is enforced by Make at parse time by detecting duplicate staged
targets.

### Plugin manifest

`rocks.toml` is the **single canonical plugin manifest**. It lives at
`nvim/rocks.toml` in the source tree and is copied to `stage/nvim/rocks.toml`
during build. There is no second manifest.

---

## Destination paths

We respect XDG base directory variables:

```make
XDG_CONFIG_HOME ?= ${HOME}/.config
XDG_CACHE_HOME  ?= ${HOME}/.cache

NVIM_CONFIG_DIR ?= ${XDG_CONFIG_HOME}/nvim
NVIM_CACHE_DIR  ?= ${XDG_CACHE_HOME}/nvim
```

The hermetic LuaRocks tree is derived internally:

```make
nvim_rocks_dir := ${NVIM_CACHE_DIR}/rocks
```

Only `NVIM_CONFIG_DIR` and `NVIM_CACHE_DIR` are documented overrides.
All other paths are intentionally internal and non-configurable.

---

## M4 symbol conventions

All m4 symbols that survive outside a local template file are prefixed with
`NV_M4_`.

There are two layers of m4 usage:

1. **Static macros** under `build/m4/`

   * e.g., `NV_M4_LUA_VER` (in `constants.m4`)
   * e.g., `NV_M4_SITE_DIR`, `NV_M4_OPT_DIR`, `NV_M4_START_DIR`
     (in `paths.m4`)

2. **Generated macros** written during the build to `build/m4/config_env.m4`

   * `NV_M4_NVIM_ROCKS_DIR`
   * `NV_M4_LUAROCKS_CONFIG_DIR`
   * `NV_M4_LUAROCKS_CONFIG`

The prefix rule prevents collisions with m4 builtins, third-party macros, and
accidental reuse across templates.

### Quoting convention

All `.m4` files under `build/m4/` use **m4 default quoting** (backtick /
single-quote). The `common.m4` helper macros use `changequote` to `-<-< / >->-`
and are intended for inclusion **only from `.lua.m4` templates**, where Lua's
own use of quotes would otherwise collide with m4 syntax. Static macro files
(`constants.m4`, `paths.m4`, `config_env.m4`) are included *before*
`common.m4` or use default quoting.

### Macro expansion in paths.m4

`paths.m4` defines derived path macros using eager expansion. The macro
name referenced inside the definition body must be **outside quotes** so that
m4 expands it at define time (which is correct because `config_env.m4` has
already been included and its values are available):

```m4
m4_include(`config_env.m4')
m4_define(`NV_M4_SITE_DIR',  NV_M4_NVIM_ROCKS_DIR`/share/nvim/site')
m4_define(`NV_M4_OPT_DIR',   NV_M4_SITE_DIR`/pack/rocks/opt')
m4_define(`NV_M4_START_DIR', NV_M4_SITE_DIR`/pack/rocks/start')
```

This ensures that when a `.lua.m4` template expands `NV_M4_SITE_DIR`, it
receives the fully resolved path.

---

## Environment capture (`build/m4/config_env.m4`)

Some build inputs are derived from the user's environment and cannot be tracked
purely via Make's timestamp-based dependency graph (because the environment can
change while file mtimes do not).

To address this, `project.mk` generates `build/m4/config_env.m4` that captures
the derived install/cache paths as m4 symbols.

**Idempotence rule for env capture:** the generator must not rewrite the file if
the content is byte-identical. This is implemented by writing a temporary file
and using `cmp` before replacing the target.

**PHONY discipline:** `config_env` is marked `.PHONY` so its recipe runs every
time (environment is not a file). Downstream targets that depend on it should
use **order-only prerequisites** (`| ${config_env}`) to avoid unconditional
rebuilds. The actual rebuild trigger for downstream targets is the file's mtime,
which only changes when the content changes (thanks to the `cmp` guard).

Downstream m4 templates include this file and therefore correctly rebuild when
the environment meaningfully changes.

---

## Build and installation phases

The system is deliberately split into **preparation** and **installation**
phases.

### Preparation (repo-managed artifacts only)

`build.mk` produces `stage/nvim/` containing only artifacts derived from the
repo:

* copy top-level runtime files (`init.lua`, `rocks.toml`)
* render `*.lua.m4 → *.lua`
* compile `*.fnl → *.lua`

No network access, no third-party clones, and no runtime state appear in stage.

### Installation (destination-specific)

`install` copies `stage/nvim/** → NVIM_CONFIG_DIR/**` via rsync.

### Sync (build-time plugin installation)

`seed.mk` handles all plugin installation at build time using the host Lua
interpreter (not Neovim). The process has two stages:

1. **Bootstrap**: install `toml-edit` via `luarocks` into the hermetic rocks
   tree. This is the minimal bootstrap — one rock, no transitive baggage.
   `toml-edit` is needed to parse `rocks.toml`.

2. **Sync script** (`build/scripts/rocks_sync.lua`): runs under the host
   LuaJIT / Lua 5.1 interpreter and uses `toml-edit` to parse `rocks.toml`.
   For each entry:
   * **Native rocks** (e.g., `"rocks.nvim" = "2.45.1"`): installed via
     `luarocks install` into the hermetic tree. Pinned versions are installed
     before unpinned (`scm`, `dev`) to prevent transitive dependency resolution
     from pulling newer versions of already-pinned packages.
   * **Git plugins** (e.g., `git = "lewis6991/gitsigns.nvim"`): cloned via
     `git clone` into the Neovim pack directory at
     `${nvim_rocks_dir}/share/nvim/site/pack/rocks/{start,opt}/`.

`rocks.toml` is the **single authority** for package versions. The bootstrap
installs only `toml-edit`; everything else — including `rocks.nvim`,
`rocks-git.nvim`, and `rocks-config.nvim` — is installed by the sync script
from `rocks.toml`.

This produces the same on-disk layout that `rocks.nvim` and `rocks-git.nvim`
would produce via interactive `:Rocks sync`, so the runtime plugin managers
find a fully populated environment on first boot.

This is the **only** step that requires network access.

### Runtime plugin management

At runtime, `rocks.nvim` and `rocks-git.nvim` are fully functional for
interactive use: `:Rocks install`, `:Rocks update`, `:Rocks sync`, etc. The
build system and the runtime plugin managers operate on the same contract
(same directory layout, same `rocks.toml` manifest). The build system
populates the environment; the runtime managers maintain it.

### Test (smoke)

`test` performs a **complete installation and sync** using temporary
directories:

* `NVIM_CONFIG_DIR=$(mktemp -d …)`
* `NVIM_CACHE_DIR=$(mktemp -d …)`
* run the same build → install → sync pipeline
* verify that Neovim starts headlessly without errors

This ensures that **test and install use identical logic**, differing only by
their destination roots. The test is the smoke test — if sync completes and
Neovim starts, the project is working.

---

## Seed plugins (luarocks-first bootstrap)

### Rationale

Plugin managers (`rocks.nvim`, `rocks-git.nvim`, `rocks-config.nvim`) and all
user plugins are installed via the host `luarocks` CLI and `git` at build time.
No vendored submodules are needed. This provides:

* **Single source of truth.** `rocks.toml` declares all plugins and their
  versions. The build system reads it directly — there are no separate pins
  to keep in sync.
* **Minimal bootstrap.** Only `toml-edit` is installed before the sync script
  runs. Everything else comes from `rocks.toml`.
* **No version conflicts.** Pinned rocks are installed before unpinned ones,
  so transitive dependency resolution never pulls a version that conflicts
  with a pin.
* **Reproducibility.** The same `rocks.toml` produces the same installed tree.

### seed.mk responsibility

`seed.mk` has three concerns:

1. **LuaRocks config**: write a hermetic `config.lua` that points luarocks at
   `nvim_rocks_dir`. This is an install-time concern (writes to
   `NVIM_CACHE_DIR`, not `stage/`).

2. **LuaRocks wrapper**: generate a wrapper script that runs luarocks under
   the validated Lua 5.1 / LuaJIT binary. Consumed by `rocks.nvim` at
   runtime for subprocess calls.

3. **Bootstrap + sync**: install `toml-edit`, then run the sync script to
   install all plugins from `rocks.toml`.

### Sync script design

`rocks_sync.lua` runs under plain Lua (not Neovim). It:

* parses `rocks.toml` via `toml_edit.parse_as_tbl()`
* handles TOML dotted keys (e.g., `[plugins.gitsigns.nvim]` parses as nested
  tables, not a flat key) via recursive traversal
* partitions native rocks into pinned and unpinned groups
* installs pinned rocks first, then unpinned, to satisfy transitive constraints
* clones git plugins into `pack/rocks/{start,opt}/` based on the `opt` flag
* is idempotent: luarocks skips installed packages; existing clones are skipped

### Abandoned approach: headless `:Rocks sync`

The original design ran a headless Neovim that loaded `rocks.nvim` and
executed `:Rocks sync` to install plugins. This was abandoned because
`rocks.nvim` fires an interactive confirmation prompt via `nio` (async tasks)
during headless sync. Multiple attempts to suppress the prompt — overriding
`vim.fn.confirm`, `vim.ui.select`, and related functions — failed because the
prompt fires asynchronously after overrides are restored. The `nio` task
scheduler yields and resumes outside the scope of any synchronous wrapper.

The shell+Lua approach avoids this entirely: it replicates the on-disk layout
that `rocks.nvim` and `rocks-git.nvim` would produce, without invoking Neovim
at all. The sync script shells out to `luarocks` and `git` directly, which are
non-interactive by nature.

---

## Mermaid overview

```mermaid
flowchart TD
  subgraph Prep["Preparation (repo-managed artifacts)"]
    E["env-capture: build/m4/config_env.m4"]
    E -.->|"order-only"| B["build.mk: stage/nvim (copy + m4 + fennel)"]
  end

  subgraph Install["Installation (destination-specific)"]
    I["install: stage/nvim → NVIM_CONFIG_DIR"]
    LR["luarocks_config → NVIM_CACHE_DIR/rocks"]
    BT["bootstrap: luarocks install toml-edit"]
    SY["rocks_sync.lua: parse rocks.toml, install all plugins"]
    I --> BT
    LR --> BT
    BT --> SY
  end

  B --> I

  subgraph Test["Test (same pipeline, different roots)"]
    T["test: override NVIM_CONFIG_DIR + NVIM_CACHE_DIR (mktemp)"]
    T --> T2["make sync (recursive, with overridden vars)"]
  end

  subgraph Verify["Verification (standalone)"]
    V["verify: grep for unexpanded NV_M4_ tokens"]
  end
```

Notes:

* The test pipeline runs the **same** `make sync` target, just with overridden
  `NVIM_CONFIG_DIR` and `NVIM_CACHE_DIR`. Stage is rebuilt with temp paths so
  m4-rendered files contain the correct roots.
* The sync script runs under the host Lua interpreter, not Neovim. It uses
  `toml-edit` (installed during bootstrap) to parse `rocks.toml` and shells
  out to `luarocks` and `git` for each entry.
* The `luarocks_config` target writes to `NVIM_CACHE_DIR` (install-time), not `stage/`.
* Env capture is the only place we use content comparison to avoid spurious
  timestamp churn. Downstream targets use order-only prerequisites on it.
* `verify` is standalone — run it manually or in CI to check for unexpanded tokens.

---

## Installed runtime (post-install + sync)

```
NVIM_CONFIG_DIR/
├─ init.lua
├─ rocks.toml
├─ lua/
│  └─ config/
│     ├─ env.lua         (rendered from env.lua.m4)
│     ├─ options.lua
│     ├─ keymaps.lua
│     ├─ autocmds.lua
│     └─ util.lua
├─ after/ plugin/ ...

NVIM_CACHE_DIR/rocks/
├─ luarocks/
│  └─ config.lua         (hermetic luarocks config)
├─ bin/
│  └─ luarocks-wrapper   (runs luarocks under validated Lua 5.1)
├─ lib/lua/5.1/          (native C modules: toml_edit.so, fzy, etc.)
├─ share/lua/5.1/        (pure Lua modules: rocks.nvim, nio, etc.)
└─ share/nvim/site/
   └─ pack/rocks/
      ├─ start/           (git plugins loaded at startup)
      │  ├─ gitsigns.nvim/
      │  ├─ which-key.nvim/
      │  └─ ...
      └─ opt/             (git plugins loaded on demand)
         ├─ Nvim-R/
         ├─ vimwiki/
         └─ ...
```

`NVIM_CONFIG_DIR` contains only repo-managed artifacts (config files and
rendered templates). All plugin code lives under `NVIM_CACHE_DIR/rocks/` —
native rocks in the luarocks tree, git plugins in the pack directory. The
runtime `env.lua` wires `package.path`, `package.cpath`, and Neovim's
`rtp`/`packpath` to these locations.

---

## Idempotence and change detection

For normal build steps (copying files, rendering templates, compiling Fennel),
the system relies on **Make's standard dependency and timestamp semantics**.

Explicit content comparison (`cmp`) is used **only** for environment capture
(`build/m4/config_env.m4`) because environment changes cannot be modeled by
file mtimes alone.

This ensures:

* repeated `make stage` runs are no-ops when inputs are unchanged
* environment changes propagate correctly
* timestamp churn is avoided without over-complicating rules

---

## Makefile interface

Human-facing `.PHONY` targets are intentionally few and stable:

| Target             | Purpose                                          |
| ------------------ | ------------------------------------------------ |
| `help`             | list available commands                          |
| `show`             | display resolved paths and variables             |
| `build`            | build `stage/nvim/` code image (Lua + m4 + fnl)  |
| `stage`            | prepare staged artifacts (code + runtime + seeds) |
| `install`          | install staged artifacts into `NVIM_CONFIG_DIR`  |
| `sync`             | install + sync all plugins from `rocks.toml`     |
| `test`             | full sync into temp directories (smoke test)     |
| `verify`           | check staged Lua for unexpanded m4 tokens        |
| `clean`            | remove `stage/`                                  |
| `uninstall`        | remove installed config (requires `FORCE=1`)     |
| `uninstall-cache`  | remove config + hermetic rocks cache             |

All real work is expressed as **file targets and pattern rules**.

---

## Invariants

The system enforces the following invariants:

1. Exactly one implementation per module path
2. All required tools must exist
3. No generated code appears in `nvim/`
4. Stage contains only repo-managed artifacts (no plugin code)
5. `rocks.toml` is the single authority for all plugin versions
6. Plugin installation uses the host Lua interpreter and luarocks, not Neovim
7. Test and install differ only by destination directories
8. A hermetic LuaRocks tree is always used for plugin installation
9. All exported m4 symbols are prefixed with `NV_M4_`

---

## Mental model summary

| Phase   | Responsibility                                     |
| ------- | -------------------------------------------------- |
| Build   | Transform repo sources into stage                  |
| Install | Copy staged artifacts into destination              |
| Sync    | Bootstrap toml-edit, install all plugins (network)  |
| Runtime | Load pure Lua; rocks.nvim manages updates           |
| Test    | Install + sync in temp dirs; smoke test             |

Complexity is intentionally moved **left** into the build so runtime behavior
remains simple, fast, and predictable.
