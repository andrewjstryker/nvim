#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# environment.mk
#
# Purpose:
# - Define overridable environment knobs (?=)
# - Perform host discovery for required tools (PATH lookup)
# - Apply "reasonable" checks where required to ensure a tool is *expected to work*
#
# Probing policy:
# - Host discovery is desired (PATH varies across systems).
# - Build-time guarantees are assumed; we do not probe internal build outputs here.
# - "Reasonable checks" are allowed to ensure an externally discovered tool meets a
#   minimal compatibility contract.
#
# Lua contract (reasonable check):
# - Accept either LuaJIT or Lua 5.1.
# - Note: `lua -v` writes to stderr; `luajit -v` writes to stdout.
#   We therefore capture stdout+stderr when checking the version text.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

# Concern recipes and smoke tests use Bash's EXIT trap and pipefail. The shared
# protocol preserves this caller policy and its portable recipes run unchanged.
SHELL := bash
.SHELLFLAGS := --noprofile --norc -euo pipefail -c

#------------------------------------------------------------------------------#
#
# XDG and installation locations
#
#------------------------------------------------------------------------------#

XDG_CONFIG_HOME ?= ${HOME}/.config
XDG_CACHE_HOME  ?= ${HOME}/.cache

NVIM_CONFIG_DIR ?= ${XDG_CONFIG_HOME}/nvim
NVIM_CACHE_DIR  ?= ${XDG_CACHE_HOME}/nvim

#------------------------------------------------------------------------------#
#
# Summarize variable values
#
#------------------------------------------------------------------------------#

define env_summary
  XDG_CONFIG_HOME............. ${XDG_CONFIG_HOME}
  XDG_CACHE_HOME.............. ${XDG_CACHE_HOME}
  NVIM_CONFIG_DIR............. ${NVIM_CONFIG_DIR}
  NVIM_CACHE_DIR.............. ${NVIM_CACHE_DIR}
endef

#------------------------------------------------------------------------------#
#
# Tool discovery (host discovery)
#
# Convention: tools are set to their resolved path if present, else empty.
#
#------------------------------------------------------------------------------#

NVIM      ?= $(shell command -v nvim)

RSYNC     ?= $(shell command -v rsync)
GIT       ?= $(shell command -v git)
AWK       ?= $(shell command -v awk)
M4        ?= $(shell command -v m4)

# Used only by the test drivers, to bound a headless Neovim run.  A hung
# session -- an autocommand that re-enters itself, a language server that never
# answers -- has to become a failure rather than a wedged build.
TIMEOUT   ?= $(shell command -v timeout)

# luarocks command (used directly — see "LuaRocks isolation" in design.md)
LUAROCKS ?= $(shell command -v luarocks)

#------------------------------------------------------------------------------#
#
# Treesitter capability discovery (host discovery + reasonable check)
#
# Treesitter parsers are a synchronization invariant. Discovery resolves the
# compiler tools here; the protocol's sync preflight rejects missing values
# before plugin or parser provisioning begins.
#
# Compiling one parser needs two things, so the capability is their conjunction:
#
#   TREE_SITTER  — nvim-treesitter's `main` branch shells out to
#                  `tree-sitter build` for every parser.
#   C_COMPILER   — which in turn needs a C compiler.
#
# Gating on the CLI alone would leave a hole: a host with the CLI and no
# compiler would pass the gate and then fail while compiling.
#
# Reasonable check on the CLI: the plugin requires >= 0.26.1 and older CLIs fail
# with unhelpful errors, so a too-old binary is treated as absent.
# `tree-sitter --version` prints "tree-sitter <semver>" on stdout.
#
# Result convention (as with LUA): each variable is either a resolved executable
# path expected to work, or empty.
#
# Wrapped in ifndef + := so the version probe runs at most once per make
# invocation, and so a user override (TREE_SITTER=/path/to/tree-sitter) wins.
#
#------------------------------------------------------------------------------#

TREE_SITTER_MIN_VERSION ?= 0.26.1

ifndef TREE_SITTER
TREE_SITTER := $(shell \
  cmd="$$(command -v tree-sitter 2>/dev/null)"; \
  if [ -z "$$cmd" ]; then \
    echo ""; \
    exit 0; \
  fi; \
  ver="$$( "$$cmd" --version 2>/dev/null | awk '{print $$2}' )"; \
  if [ -z "$$ver" ]; then \
    echo ""; \
    exit 0; \
  fi; \
  min='${TREE_SITTER_MIN_VERSION}'; \
  oldest="$$(printf '%s\n%s\n' "$$min" "$$ver" | sort -V | head -n 1)"; \
  [ "$$oldest" = "$$min" ] && echo "$$cmd" || echo "" \
)
endif

# The C compiler `tree-sitter build` invokes.  Deliberately NOT named CC: GNU
# make predefines CC with origin "default", so `CC ?= ...` would never assign.
C_COMPILER ?= $(shell command -v cc || command -v gcc || command -v clang)

# Optional formatter binaries (conform.nvim dispatches to whatever is on PATH
# at build time). Empty → the formatter is absent; project.mk omits the
# corresponding m4 define and the generated formatting.lua drops any filetype
# mapping that depends on it. Install → re-run `make install` to re-probe.
#
# Each variable holds the absolute path of the command conform should invoke.
# For standalone formatters, that is the formatter binary itself.  For
# library-style formatters (e.g. R's styler package, invoked via R), it is
# the hosting runtime's path — see STYLER below.
#
# See FORMATTERS.md for install recipes.
PRETTIER      ?= $(shell command -v prettier)
STYLUA        ?= $(shell command -v stylua)
RUFF          ?= $(shell command -v ruff)
BLACK         ?= $(shell command -v black)
SQL_FORMATTER ?= $(shell command -v sql_formatter)

# styler is an R package, not a standalone CLI.  conform's built-in styler
# formatter invokes R with `-s -e 'styler::style_file(...)'`, so we detect
# "styler is available" by verifying R is on PATH AND the styler package is
# installed.  When both hold, stamp the absolute R path; otherwise empty.
#
# Wrapped in ifndef + := so the R probe (with ~200 ms startup) runs at most
# once per make invocation instead of on every ${STYLER} expansion.
ifndef STYLER
STYLER := $(shell \
  if command -v R >/dev/null 2>&1 && \
     R -s -e 'if (!requireNamespace("styler", quietly=TRUE)) quit(status=1)' \
       >/dev/null 2>&1; then \
    command -v R; \
  fi)
endif

#------------------------------------------------------------------------------#
#
# Lua discovery in two stages
#
# Stage 1: select a candidate command name (or empty)
#   - user override (LUA_CMD) wins if supplied
#   - else: luajit > lua5.1 > lua > empty
#
# Stage 2: "reasonable" compatibility check on version text
#   - candidate empty -> empty
#   - resolve candidate
#   - run: <candidate> -v (capture stdout+stderr)
#   - accept if output matches either "LuaJIT" or "Lua 5.1"
#   - return candidate if accepted else empty
#
#------------------------------------------------------------------------------#

# Stage 1 (candidate): allow user override; otherwise choose best available
LUA_CMD ?= $(shell \
  if command -v luajit >/dev/null 2>&1; then \
    echo luajit; \
  elif command -v lua5.1 >/dev/null 2>&1; then \
    echo lua5.1; \
  elif command -v lua >/dev/null 2>&1; then \
    echo lua; \
  else \
    echo ""; \
  fi \
)

# Stage 2 (validate candidate by version text; capture stdout+stderr)
# Result convention: LUA is either a resolved executable path that is expected to work,
# or empty.
ifndef LUA
LUA := $(shell \
  cand='$(strip $(LUA_CMD))'; \
  if [ -z "$$cand" ]; then \
    echo ""; \
    exit 0; \
  fi; \
  cmd="$$(command -v "$$cand" 2>/dev/null)"; \
  if [ -z "$$cmd" ]; then \
    echo ""; \
    exit 0; \
  fi; \
  out="$$( "$$cmd" -v 2>&1 )"; \
  echo "$$out" | grep -Eq 'LuaJIT|Lua 5\.1' && echo "$$cmd" || echo "" \
)
endif

#------------------------------------------------------------------------------#
#
# Summarize tools
#
#------------------------------------------------------------------------------#

define toolset_summary
  NVIM........................ ${NVIM}
  LUA......................... ${LUA}
  LUAROCKS.................... ${LUAROCKS}
  TREE_SITTER................. ${TREE_SITTER}
  C_COMPILER.................. ${C_COMPILER}
  RSYNC....................... ${RSYNC}
  GIT......................... ${GIT}
  AWK......................... ${AWK}
  M4.......................... ${M4}
  PRETTIER.................... ${PRETTIER}
  STYLUA...................... ${STYLUA}
  RUFF........................ ${RUFF}
  BLACK....................... ${BLACK}
  STYLER...................... ${STYLER}
  SQL_FORMATTER............... ${SQL_FORMATTER}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
