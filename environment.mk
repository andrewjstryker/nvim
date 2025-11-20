#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Define environment variables
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
#
# XDG and installation locations
#
#------------------------------------------------------------------------------#

# Follow XDG Base Directory Specification, preferring environment variables if
# set or defaulting to standard locations if not
XDG_CONFIG_HOME ?= ${HOME}/.config
XDG_CACHE_HOME  ?= ${HOME}/.cache

NVIM_CONFIG_DIR ?= ${XDG_CONFIG_HOME}/nvim
NVIM_CACHE_DIR  ?= ${XDG_CACHE_HOME}/nvim

#------------------------------------------------------------------------------#
#
# Nvim Rocks
#
#------------------------------------------------------------------------------#

# rocks.nvim: cloned once, pinned via ROCKS_NVIM_REF (default: HEAD)
ROCKS_NVIM_REPO ?= https://github.com/nvim-neorocks/rocks.nvim.git
ROCKS_NVIM_REF  ?= HEAD

ROCKS_GIT_REPO  ?= https://github.com/nvim-neorocks/rocks-git.nvim.git
ROCKS_GIT_REF   ?= HEAD

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
  ROCKS_NVIM_REPO............. ${ROCKS_NVIM_REPO}
  ROCKS_NVIM_REF.............. ${ROCKS_NVIM_REF}
endef

#------------------------------------------------------------------------------#
#
# Pin tools
#
#------------------------------------------------------------------------------#

# Prefer luajit; fall back to lua 5.1
LUA_CMD         ?= $(shell \
  if command -v luajit >/dev/null 2>&1; then \
    echo luajit; \
  elif command -v lua >/dev/null 2>&1 && \
       lua -v 2>&1 | grep -q 'Lua 5\.1'; then \
    echo lua; \
  elif command -v lua5.1 >/dev/null 2>&1; then \
    echo lua5.1; \
  else \
    echo ""; \
  fi \
)

# Set tool commands
NVIM            ?= $(shell command -v nvim)
LUA             ?= $(shell command -v ${LUA_CMD})
RSYNC           ?= $(shell command -v rsync)
GIT             ?= $(shell command -v git)
AWK             ?= $(shell command -v awk)
M4              ?= $(shell command -v m4)

#------------------------------------------------------------------------------#
#
# Summarize tools
#
#------------------------------------------------------------------------------#

define toolset_summary
  NVIM........................ ${NVIM}
  LUA......................... ${LUA}
  RSYNC....................... ${RSYNC}
  GIT......................... ${GIT}
  AWK......................... ${AWK}
  M4.......................... ${M4}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
