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
* **Stage (protocol + build.mk)**: prepares the XDG image under
  `stage/config/nvim/`
* **Seed (seed.mk)**: bootstraps toml-edit via `luarocks`, then syncs all
  plugins from `rocks.toml` using a host Lua script (no Neovim invocation)
* **Install**: copies staged artifacts into `NVIM_CONFIG_DIR`
* **Test**: performs a complete installation and sync using temporary directory
  overrides
* **Templating**: `*.lua.m4 → *.lua` at build time
* **Fennel**: optional `*.fnl → *.lua` compilation through the protocol's
  claimed-source/output seam
* **Isolation**: plugins install into a hermetic LuaRocks tree derived from
  `NVIM_CACHE_DIR` (never system Lua)
* **M4 discipline**: all build-time m4 symbols are prefixed with `M4_`
* **Idempotence**: rely on Make's dependency model and use content comparison
  for renderer context and output stability

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
* **VIMRUNTIME** — Neovim's own runtime directory. The Neovim installation is
  outside the scope of this build system; `env.lua` reads `vim.env.VIMRUNTIME`
  (which Neovim always sets) rather than discovering it at build time.
* **The rocks.nvim versioned directory** — see "M4_ROCKS_RTP" below.

Runtime probing should not be used to "repair" or reinterpret the build output.

**Principle:** Runtime probing is for *optional or inherently dynamic*
conditions, not for validating the build pipeline.

### Summary

* **Host discovery:** yes (including Lua), with explicit constraints and
  overrides.
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
│  │   │   ├─ vscode.lua
│  │   │   ├─ vscode_env.lua.m4
│  │   │   ├─ options.lua
│  │   │   ├─ keymaps.lua
│  │   │   ├─ autocmds.lua
│  │   │   ├─ plugins.lua
│  │   │   └─ util.lua
│  │   └─ plugins/
│  │       ├─ completion.lua
│  │       ├─ editing.lua
│  │       ├─ formatting.lua
│  │       ├─ git.lua
│  │       ├─ lsp.lua
│  │       ├─ navigation.lua
│  │       ├─ sql.lua
│  │       ├─ treesitter.lua
│  │       ├─ ui.lua
│  │       └─ writing.lua
│  ├─ after/ ftplugin/ colors/ plugin/   # optional runtime dirs
├─ build/
│  ├─ m4/        # static m4 macros (constants.m4, paths.m4, common.m4)
│  └─ scripts/   # build-time helper scripts (e.g., rocks_sync.lua)
├─ vendor/
│  └─ build/fennel/  # pinned compiler script; never installed
├─ stage/        # build outputs (gitignored)
│  ├─ config/nvim/ # assembled config image
│  └─ .build/      # private protocol renderer context
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

### Plugin configuration layout

Plugin configuration uses a concern-based organization under `nvim/lua/plugins/`.
Each file groups related plugins by concern (editing, git, treesitter, lsp,
formatting, etc.) rather than one file per plugin. `nvim/lua/config/plugins.lua`
is the loader that requires each concern file.

### Plugin manifest

`rocks.toml` is the **single canonical plugin manifest**. It lives at
`src/config/nvim/rocks.toml` is copied to `stage/config/nvim/rocks.toml`
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

All m4 symbols that survive outside a local template use the protocol's `M4_`
prefix. Values such as `NVIM_ROCKS_DIR`, `NVIM_CONFIG_DIR`, and
`NVIM_TREESITTER_DIR` are declared through `m4_vars` and become
`M4_NVIM_ROCKS_DIR`, `M4_NVIM_CONFIG_DIR`, and `M4_NVIM_TREESITTER_DIR`.
Static macros under `build/m4/` derive `M4_SITE_DIR`, `M4_OPT_DIR`,
`M4_START_DIR`, and `M4_ROCKS_RTP` from that context.

The prefix prevents collisions with m4 builtins and keeps build-time values out
of the runtime configuration namespace.

### Quoting convention

All `.m4` files under `build/m4/` use **m4 default quoting** (backtick /
single-quote). The `common.m4` helper macros use `changequote` to `-<-< / >->-`
and are intended for inclusion **only from `.lua.m4` templates**, where Lua's
own use of quotes would otherwise collide with m4 syntax. Static macro files
(`constants.m4`, `paths.m4`) are included *before* `common.m4` or use default
quoting.

**Template rule:** In `.lua.m4` files that include `constants.m4` and `paths.m4`
but do **not** include `common.m4`, backtick characters must not appear anywhere
in the Lua body (including comments). m4 interprets backticks as quote openers,
causing "end of file in string" errors. Use double-quotes in Lua comments
instead. If backticks are needed, include `common.m4` after the static macro
files to switch to `-<-<`/`>->-` quoting.

### Macro expansion in paths.m4

`paths.m4` defines derived path macros from protocol context values. A referenced
macro name must be **outside quotes** so m4 expands it when the definition is
used:

```m4
m4_define(`M4_SITE_DIR',  M4_NVIM_ROCKS_DIR`/share/nvim/site')
m4_define(`M4_OPT_DIR',   M4_SITE_DIR`/pack/rocks/opt')
m4_define(`M4_START_DIR', M4_SITE_DIR`/pack/rocks/start')
```

This ensures that when a `.lua.m4` template expands `M4_SITE_DIR`, it
receives the fully resolved path.

### M4_ROCKS_RTP — the glob exception

`M4_ROCKS_RTP` is defined in `paths.m4` with a trailing `/*` glob:

```m4
m4_define(`M4_ROCKS_RTP', M4_NVIM_ROCKS_DIR`/lib/luarocks/rocks-5.1/rocks.nvim/*')
```

This is the **one symbol that does not resolve to a concrete path** at render
time. The glob exists because the rocks.nvim versioned directory (e.g.,
`2.47.4-1/`) does not exist when `env.lua` is rendered — `make install` runs
before `make rocks-sync`. The version can also change at runtime via
`:Rocks update`.

The design principle is: **render what is known at build time**. The base path
(`M4_NVIM_ROCKS_DIR/lib/luarocks/rocks-5.1/rocks.nvim/`) is known and
stamped. The version suffix is not known, so it is left as a glob for runtime
resolution via `vim.fn.glob()`. This falls under probing policy §4
(inherently dynamic concern).

---

## Renderer context

Environment-derived render values cannot be represented by source-file mtimes.
The protocol reconciles them into the private `stage/.build/m4-context` file,
replacing it only when its content changes. Every ordinary m4 output has that
real file as a normal prerequisite, so changed values invalidate templates and
unchanged values leave their mtimes stable. `protocol/bin/gen` transports values
from that context without shell interpolation and replaces a rendered output
only when its bytes or executable declaration change.

Neovim adds `build/m4/` through `M4FLAGS` and makes its static macro files normal
prerequisites of each Lua template. It does not own a second renderer or
environment-capture path.

---

## Hermetic rtp and packpath

`env.lua` **replaces** (not appends to) the Neovim default `runtimepath` and
`packpath` with a minimal hermetic set. This prevents stale system plugins,
user-global installations, and flatpak artifacts from leaking in.

Two values are resolved at runtime rather than build time:

* **VIMRUNTIME** — read from `vim.env.VIMRUNTIME` (Neovim installation is
  outside scope; Neovim always provides this value)
* **rocks_rtp** — resolved from `M4_ROCKS_RTP` glob via `vim.fn.glob()`
  (version suffix unknown at build time)

All other rtp/packpath entries are fully resolved at build time via m4.

**runtimepath** (5 entries):

| Entry | Source | Content |
|---|---|---|
| `config_dir` | `M4_NVIM_CONFIG_DIR` | lua/config/, lua/plugins/, ftplugin/ |
| `rocks_rtp` | `M4_ROCKS_RTP` (glob-resolved) | rocks.nvim plugin/rocks.lua |
| `rocks_site` | `M4_SITE_DIR` | git-cloned plugins runtime files |
| `vimruntime` | `vim.env.VIMRUNTIME` (runtime) | Neovim built-in runtime (syntax, ftplugin) |
| `config_dir/after` | derived | user after/ overrides |

**packpath** (1 entry):

| Entry | Source | Content |
|---|---|---|
| `rocks_site` | `M4_SITE_DIR` | pack/rocks/{start,opt}/ |

**packloadall requirement:** Neovim performs its initial pack scan early in
startup, before `init.lua` runs. Since `env.lua` replaces `packpath` during
`init.lua`, the initial scan found nothing in our hermetic path. `env.lua`
must call `vim.cmd("packloadall")` after setting `packpath` to trigger a
re-scan so that git-cloned plugins (including colorschemes) are discovered.

---

## Build and installation phases

The system is deliberately split into **preparation** and **installation**
phases.

### Preparation (repo-managed artifacts only)

The protocol produces `stage/config/nvim/` from ordinary sources while
`build.mk` supplies static m4 prerequisites, module validation, and the claimed
Fennel rule:

* copy top-level runtime files (`init.lua`, `rocks.toml`)
* render `*.lua.m4 → *.lua`
* compile claimed `*.fnl → *.lua`

No network access, no third-party clones, and no runtime state appear in stage.

### Installation (destination-specific)

`install` copies `stage/config/nvim/** → NVIM_CONFIG_DIR/**` via rsync.

### Sync (runtime-state provisioning)

`seed.mk` handles all plugin installation at build time. The process has
two stages:

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
     The `git` field supports both GitHub shorthand (`owner/repo`) and full
     URLs (`https://codeberg.org/user/repo`).

`rocks.toml` is the **single authority** for package versions. The bootstrap
installs only `toml-edit`; everything else — including `rocks.nvim`,
`rocks-git.nvim`, and `rocks-config.nvim` — is installed by the sync script
from `rocks.toml`.

This produces the same on-disk layout that `rocks.nvim` and `rocks-git.nvim`
would produce via interactive `:Rocks sync`, so the runtime plugin managers
find a fully populated environment on first boot.

#### Treesitter parsers

Treesitter parsers **are** installed during synchronization. `make sync` clones
`nvim-treesitter` (via rocks_sync) and then runs `provision-parsers`, which
executes `build/scripts/install_parsers.lua` under headless Neovim to install
the canonical set in `lua/config/parsers.lua` — parsers *and* their queries —
into the hermetic treesitter dir. A parser that cannot be installed **fails
the build**.

This is a deliberate application of the probing policy: the parser set is an
invariant **established before installation**, so runtime assumes it holds.
`plugins/treesitter.lua` enables `vim.treesitter.start()` and the indent
expression for exactly the filetypes that set serves, and does no probing,
no repair, and no install-on-use. Adding a language is a build-time act: edit
`config.parsers`, re-run `make sync`.

The plugin tracks nvim-treesitter's **`main`** branch (the v1.0 rewrite). The
legacy `master` branch is locked at Neovim ≤ 0.11 — its query directives index
`match[capture_id]` as a single node, while Neovim 0.12 passes a *list* of
nodes per capture id, so every markdown injection raises `attempt to call
method 'range' (a nil value)`. `main` requires the `tree-sitter` CLI
(≥ `TREE_SITTER_MIN_VERSION`) to compile parsers; `environment.mk` discovers it
as `TREE_SITTER` (host discovery, §1) and `check-treesitter-cli` gates
`provision-parsers` on it. The guard is scoped to that target, so `build`,
`install`, and `test-fast` still work on a host without the CLI.

The cost of this arrangement is a C compiler and the tree-sitter CLI at build
time, plus a dependency on nvim-treesitter's install API. What it buys is that
a working install never depends on the Neovim binary happening to bundle the
parsers it needs, and that the runtime stays free of provisioning logic.

Sync is the **only** phase that requires network access.

### Runtime plugin management

At runtime, `rocks.nvim` and `rocks-git.nvim` are fully functional for
interactive use: `:Rocks install`, `:Rocks update`, `:Rocks sync`, etc. The
build system and the runtime plugin managers operate on the same contract
(same directory layout, same `rocks.toml` manifest). The build system
populates the environment; the runtime managers maintain it.

### Test (smoke)

Two tiers:

* **`test-fast`** — build + install into temp dirs, verify Neovim starts
  (no network, seconds). Useful during development iteration.
* **`test`** — full sync (network required), then verify Neovim starts.
  This is the comprehensive check.

Both tiers:

* create temp directories `$tmp/config/nvim` and `$tmp/cache/nvim`
* run the pipeline with overridden `NVIM_CONFIG_DIR` / `NVIM_CACHE_DIR`
* launch headless Neovim there, assert `config.env` loaded, and check stderr
  for errors

This ensures that **test and install use identical logic**, differing only by
their destination roots.

#### Tiers are preconditions; checks are a list

There are three test entry points, and they differ only in **precondition** —
the one thing a caller cannot infer:

| target | needs | runs |
|---|---|---|
| `test-fast` | nothing | build + install, does Neovim start? |
| `check` | a prior `make sync` | + `verify` and every offline check |
| `test` | the network | + a full sync and `ts_install` |

Which checks a tier runs is a **list in `test.mk`**, not a target. Adding a
check must not add an entry point; a target per check turns the Makefile into
a test selector, which is not its job. `CHECKS=` narrows either tier while
iterating.

`check` is the protocol's own extension point — "stage and run concern-defined
checks" — so the offline tier hooks into it rather than growing siblings
beside it. Note that `check-*` is the protocol's namespace for tool preflight
(`check-tools`, `check-stage-tools`), so a new `check-something` would read as
preflight rather than as a test.

#### One harness

`test.mk` holds no test logic. It hands the work to one driver under `test/`,
written in POSIX shell like `protocol/tests/staging.sh`:

* **`test/checks.sh`** — install into a throwaway root, prove Neovim starts
  clean, run the named checks against that single install.
* **`test/lua_runtime.sh`** — sourced by the driver; the one check that needs
  whole sessions of its own.
* **`test/lib.sh`** — the single implementation of "throwaway XDG root, real
  build into it, headless Neovim against it".

There was once one such implementation per target — two in Make and a third in
Python — which is how the harness came to contradict itself.

The split between a driver and a `test/session/*.lua` script is not stylistic.
A session script asserts what is true **inside one running Neovim**; only Lua
can ask whether a highlighter is attached to a buffer. A driver owns what
**differs between sessions**, and nothing inside a session can observe: which
`lua` is on `PATH` and what it reports, whether it was probed at all, a
trusted project-local `.nvim.lua`, or a file on the command line. Neither can
do the other's job.

#### A session script owns its exit

Each `test/session/*.lua` ends in `os.exit(0)` or `os.exit(1)`, and the driver
appends **no** `-c qa`. Quitting for the script would make Neovim exit 0 even
when the script died before reaching its own exit — on a typo, or an error
outside its `pcall` — and a check that asserts nothing would be reported as a
pass. `NVIM_TIMEOUT` is the backstop for a script that never exits at all:
slow, but a failure rather than a lie.

For the same reason the drivers name no `-u init.lua`. `XDG_CONFIG_HOME`
already points Neovim at the installed config, and naming the init file
explicitly suppresses `exrc` — which quietly turned the project-local
`.nvim.lua` scenarios into duplicates of the plain ones.

#### What the treesitter checks assert

The `test` tier adds two post-sync checks, both stated as **behavior a user
depends on**, never as file layout:

* **`ts_works`** — does treesitter work for every language the build promised?
  Measured as a user experiences it: open a buffer of the language's filetype
  and a live highlighter is attached. One assertion covers the parser, its
  queries, their mutual compatibility, and the `FileType` wiring.
* **`ts_install`** — can this environment install a language it does not have?
  The installed language must then parse *and* highlight.

Neither inspects the filesystem. Whether a `.so` or a query file landed at some
expected path is a build-time substitution — authoritative under the probing
policy (§2), invisible to the user, and a mere proxy for the thing that
matters. A parser that loads while its queries are missing or mismatched
satisfies every path assertion and still highlights nothing, which is exactly
the failure the migration to `main` uncovered.

`test-fast` runs no treesitter check at all: it installs the config without
provisioning plugins or parsers, so the only honest assertion at that point is
that Neovim starts cleanly.

#### What the Lua/Fennel scenarios assert

`lua_runtime` covers the one-shot resolve in `lua/plugins/lua.lua`: the
session settles on a single Lua target at the first Lua or Fennel buffer,
later buffers reuse it, and Fennel highlights — **including the buffer that
triggered the resolve**.

That last clause is the whole point. The Fennel syntax package is optional, so
it arrives by `packadd` from a `FileType` autocommand, and Neovim's own
`FileType` handlers are registered first: `config.env` runs `packloadall`, the
start plugins turn syntax on, and only then is `config.autocmds` required. For
the buffer that triggers the `packadd`, the syntax lookup has already happened
and found nothing. A check that opens a second Fennel buffer passes while the
first one in every session sits unhighlighted, which is exactly what happened.

The scenarios also assert a negative the same code makes easy to get wrong: a
project-local target must make probing the interpreter **unnecessary**, not
merely override its result. The driver counts invocations of a fake `lua` on
`PATH` — a property no session can see from the inside.

#### Headless Neovim must be XDG-isolated

Every headless Neovim the build launches runs with `XDG_CONFIG_HOME` and
`XDG_CACHE_HOME` exported from `NVIM_CONFIG_DIR` / `NVIM_CACHE_DIR`
(`nvim_xdg_config`, `nvim_xdg_cache` in `project.mk`). Neovim's *default*
runtimepath includes `$XDG_CONFIG_HOME/nvim`, so `-u <target>/init.lua` alone
does **not** isolate: `require("config.env")` resolves against the user's real
`~/.config/nvim` and the build silently operates on the wrong tree. For a
normal install the derived values equal the defaults, so this is invisible;
it only bites when the directories are overridden — which is precisely what
the test tiers do.

#### XDG overrides and the `/nvim` invariant

The temp directory structure (`$tmp/config/nvim`, `$tmp/cache/nvim`) and the
smoke-test XDG overrides (`XDG_CONFIG_HOME=$tmp/config`) depend on
`NVIM_CONFIG_DIR` and `NVIM_CACHE_DIR` ending with `/nvim`.  The build uses
`$(dir ...)` to strip the trailing component and derive the XDG base
directory.  This invariant is **enforced at parse time** — Make errors
immediately if either path does not end with `/nvim`.

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

`seed.mk` has two concerns:

1. **LuaRocks config**: write a hermetic `config.lua` that points luarocks at
   `nvim_rocks_dir`. This is an install-time concern (writes to
   `NVIM_CACHE_DIR`, not `stage/`).

2. **Bootstrap + sync**: install `toml-edit`, then run the sync script to
   install all plugins from `rocks.toml`.

### LuaRocks isolation

The system `luarocks` command is typically a **shell wrapper** that embeds its
own Lua invocation (e.g., `exec lua5.1 -e '...' /path/to/luarocks "$@"`).
Running it under a different Lua via `${LUA} ${LUAROCKS_SCRIPT}` fails because
the wrapper is a shell script, not a Lua script.

Instead, `environment.mk` uses the system `luarocks` command **directly**.
Hermeticity comes from three environment-level guards, not from controlling
which Lua interprets luarocks:

1. **`LUAROCKS_CONFIG`** — env var pointing at the hermetic `config.lua`.
   This tells luarocks to install into `nvim_rocks_dir` instead of any
   system location.

2. **`LUA_PATH` / `LUA_CPATH`** — scoped to the hermetic rocks tree with
   **no trailing `;;`**, intentionally excluding system-global Lua modules
   that might be built for a different Lua version.

3. **`--lua-version=5.1`** — passed to every `luarocks install` invocation
   so the correct rock tree is targeted regardless of what Lua the luarocks
   wrapper itself runs under.

At runtime, `rocks.nvim` discovers and invokes `luarocks` on its own.  The
hermetic `config.lua` is already in place at `NVIM_CACHE_DIR/rocks/luarocks/`
so `rocks.nvim` finds it via standard LuaRocks config resolution.  No
separate wrapper script is needed.

### Sync script design

`rocks_sync.lua` runs under plain Lua (not Neovim). It:

* parses `rocks.toml` via `toml_edit.parse_as_tbl()`
* handles TOML dotted keys (e.g., `[plugins.gitsigns.nvim]` parses as nested
  tables, not a flat key) via recursive traversal
* partitions native rocks into pinned and unpinned groups
* installs pinned rocks first, then unpinned, to satisfy transitive constraints
* clones git plugins into `pack/rocks/{start,opt}/` based on the `opt` flag
* supports full URLs (e.g., Codeberg) in addition to GitHub shorthand
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
    E["protocol context: stage/.build/m4-context"]
    E -->|"normal prereq (mtime)"| B["protocol stage + claimed Fennel"]
    B --> V["verify: grep for unexpanded M4_ tokens"]
  end

  subgraph Install["Installation (destination-specific)"]
    I["install: stage/config/nvim → NVIM_CONFIG_DIR"]
    LR["luarocks_config → NVIM_CACHE_DIR/rocks/luarocks/config.lua"]
    BT["bootstrap: luarocks install toml-edit"]
    SY["rocks_sync.lua: parse rocks.toml, install all plugins"]
    I --> BT
    LR --> BT
    BT --> SY
  end

  V --> I

  subgraph Test["Test (same pipeline, different roots)"]
    TF["test-fast: build + install (no network)"]
    T["test: install + sync (network required)"]
    TF --> TS["nvim --headless smoke check"]
    T --> TS
  end
```

Notes:

* The test pipeline runs `make install` and `make sync` in shallow sub-Makes
  with overridden `NVIM_CONFIG_DIR` and `NVIM_CACHE_DIR`. Stage is rebuilt with
  temp paths so m4-rendered files contain the correct roots. The temp directory structure
  is `$tmp/config/nvim` and `$tmp/cache/nvim` so that XDG overrides produce
  correct `stdpath()` values.
* The sync script runs under the host Lua interpreter, not Neovim. It uses
  `toml-edit` (installed during bootstrap) to parse `rocks.toml` and shells
  out to `luarocks` and `git` for each entry.
* The `luarocks_config` target writes to `NVIM_CACHE_DIR` (install-time), not `stage/`.
  Build-time luarocks hermeticity comes from environment variables
  (`LUAROCKS_CONFIG`, `LUA_PATH`, `LUA_CPATH`) and the `--lua-version=5.1`
  flag, not from controlling which Lua interprets the luarocks command.
* The protocol context uses content comparison to avoid spurious timestamp
  churn and is a normal prerequisite of ordinary m4 outputs.
* `verify` extends the explicit `check` surface and can also be run standalone.

---

## Installed runtime (sync)

```
NVIM_CONFIG_DIR/
├─ init.lua
├─ rocks.toml
├─ lua/
│  ├─ config/
│  │  ├─ env.lua         (rendered from env.lua.m4)
│  │  ├─ vscode.lua
│  │  ├─ vscode_env.lua  (rendered from vscode_env.lua.m4)
│  │  ├─ options.lua
│  │  ├─ keymaps.lua
│  │  ├─ autocmds.lua
│  │  ├─ plugins.lua
│  │  └─ util.lua
│  └─ plugins/
│     ├─ completion.lua
│     ├─ editing.lua
│     ├─ formatting.lua
│     ├─ git.lua
│     ├─ lsp.lua
│     ├─ navigation.lua
│     ├─ sql.lua
│     ├─ treesitter.lua
│     ├─ ui.lua
│     └─ writing.lua
├─ after/ plugin/ ...

NVIM_CACHE_DIR/rocks/
├─ luarocks/
│  └─ config.lua         (hermetic luarocks config)
├─ lib/luarocks/rocks-5.1/
│  └─ rocks.nvim/
│     └─ <version>/      (rocks.nvim runtime: plugin/rocks.lua)
├─ lib/lua/5.1/          (native C modules: toml_edit.so, fzy, etc.)
├─ share/lua/5.1/        (pure Lua modules: rocks.nvim, nio, etc.)
└─ share/nvim/site/
   └─ pack/rocks/
      ├─ start/           (git plugins loaded at startup)
      │  ├─ solarized.nvim/
      │  ├─ gitsigns.nvim/
      │  ├─ which-key.nvim/
      │  └─ ...
      └─ opt/             (git plugins loaded on demand)
         ├─ Nvim-R/
         └─ ...
```

`NVIM_CONFIG_DIR` contains only repo-managed artifacts (config files and
rendered templates). All plugin code lives under `NVIM_CACHE_DIR/rocks/` —
native rocks in the luarocks tree, git plugins in the pack directory. The
runtime `env.lua` wires `package.path`, `package.cpath`, and Neovim's
`rtp`/`packpath` to these locations.

---

## Idempotence and change detection

Plain copies and claimed Fennel compilation rely on Make's standard dependency
and timestamp semantics. The protocol compares its reconciled renderer context
and rendered output bytes because environment values have no source-file mtime
and a changed context need not change every template's output.

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
| `build`            | compatibility alias for `stage`                   |
| `stage`            | prepare the complete staged manifest              |
| `install`          | install staged artifacts into `NVIM_CONFIG_DIR`  |
| `sync`             | sync plugins and parsers for installed config    |
| `test-fast`        | quick smoke test: build + install (no network)   |
| `check`            | staged artifacts + every offline check            |
| `test`             | full smoke test: install + sync + every check    |
| `verify`           | check staged Lua for unexpanded m4 tokens        |
| `clean`            | remove `stage/`                                  |
| `uninstall`        | conservatively remove the installed manifest     |
| `uninstall-cache`  | remove config + hermetic rocks cache             |

The top-level `Makefile` is strictly orchestration: it loads environment and
project declarations, includes the protocol, loads concern implementations,
and supplies compatibility aliases or dependency composition. Build, seed,
treesitter, and test recipes remain in their owning fragments. Staged
transformations are expressed as file targets and pattern rules; lifecycle
targets compose those transformations with installation or runtime-state work.

---

## Invariants

The system enforces the following invariants:

1. Exactly one implementation per module path
2. All required tools must exist
3. No generated code appears in `src/config/nvim/`
4. Stage contains only repo-managed artifacts (no plugin code)
5. `rocks.toml` is the single authority for all plugin versions
6. Plugin installation uses the host Lua interpreter, luarocks, and git;
   Neovim is invoked only during parser synchronization and runtime tests.
7. Test and install differ only by destination directories
8. A hermetic LuaRocks tree is always used for plugin installation
9. All exported m4 symbols are prefixed with `M4_`

---

## Mental model summary

| Phase   | Responsibility                                     |
| ------- | -------------------------------------------------- |
| Build   | Transform repo sources into stage                  |
| Install | Copy staged artifacts into destination              |
| Sync    | Bootstrap toml-edit, install plugins (net)            |
| Runtime | Load pure Lua and use the parser set established by synchronization |
| Test    | Install + sync in temp dirs; smoke test (fast / full) |

Complexity is intentionally moved **left** into the build so runtime behavior
remains simple, fast, and predictable.
