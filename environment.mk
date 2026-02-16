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

# luarocks script path (resolved after LUA discovery below)
LUAROCKS_SCRIPT ?= $(shell command -v luarocks)

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
# LuaRocks: run under the validated Lua 5.1 / LuaJIT
#
# The system `luarocks` CLI is a Lua script.  If the system default Lua is
# 5.4+ (which makes for-loop variables const), luarocks' own code may fail
# with "attempt to assign to const variable" errors.
#
# We avoid this by invoking the luarocks script explicitly under our
# validated LUA binary:  $(LUA) $(LUAROCKS_SCRIPT)
#
# LUAROCKS is the ready-to-use command; seed.mk calls it directly.
#
#------------------------------------------------------------------------------#

LUAROCKS := ${LUA} ${LUAROCKS_SCRIPT}

#------------------------------------------------------------------------------#
#
# Summarize tools
#
#------------------------------------------------------------------------------#

define toolset_summary
  NVIM........................ ${NVIM}
  LUA......................... ${LUA}
  LUAROCKS.................... ${LUAROCKS}
  RSYNC....................... ${RSYNC}
  GIT......................... ${GIT}
  AWK......................... ${AWK}
  M4.......................... ${M4}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
