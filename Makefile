#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Makefile
#
# Build and install Neovim configuration
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
#
# Configuration
#
#------------------------------------------------------------------------------#

SHELL := bash
.SHELLFLAGS := --noprofile --norc -euo pipefail -c

#------------------------------------------------------------------------------#
#
# Include concern specfic files
#
#------------------------------------------------------------------------------#

# environment variables
include environment.mk

NVIM_CONFIG_DIR ?= ${XDG_CONFIG_HOME}/nvim
NVIM_CACHE_DIR  ?= ${XDG_CACHE_HOME}/nvim

# rocks.nvim: cloned once, pinned via ROCKS_NVIM_REF (default: HEAD)
ROCKS_NVIM_REPO ?= https://github.com/nvim-neorocks/rocks.nvim.git
ROCKS_NVIM_REF  ?= HEAD

define env_summary
  XDG_CONFIG_HOME............. ${XDG_CONFIG_HOME}
  XDG_CACHE_HOME.............. ${XDG_CACHE_HOME}
  NVIM_CONFIG_DIR............. ${NVIM_CONFIG_DIR}
  NVIM_CACHE_DIR.............. ${NVIM_CACHE_DIR}
  ROCKS_NVIM_REPO............. ${ROCKS_NVIM_REPO}
  ROCKS_NVIM_REF.............. ${ROCKS_NVIM_REF}
endef

ifneq (${SHOW_DEFS},)
  #$(shell "printf \033[1;34mConfiguration variables:\033[0m\n")
  $(info Configuration variables:)
  $(info ${env_summary})
endif

# Set tool commands
NVIM            ?= $(shell command -v nvim)
RSYNC           ?= $(shell command -v rsync)
GIT             ?= $(shell command -v git)
AWK             ?= $(shell command -v awk)
M4              ?= $(shell command -v m4)

# Prefer luajit; fall back to lua 5.1
LUA             ?= $(shell \
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

define toolset_summary
  LUA......................... ${LUA}
  NVIM........................ ${NVIM}
  RSYNC....................... ${RSYNC}
  GIT......................... ${GIT}
  AWK......................... ${AWK}
  M4.......................... ${M4}
endef

toolset_vars := LUA NVIM RSYNC GIT AWK M4

missing_tools := \
  $(strip \
    $(foreach v,$(toolset_vars), \
      $(if $(strip $($v)),,$v) \
    ) \
  )

ifneq (${missing_tools},)
$(error Missing required tools: \
${toolset_summary} \
)
endif

ifneq (${SHOW_DEFS},)
$(info ${toolset_summary})
endif

include stage.mk
include seed.mk

#------------------------------------------------------------------------------#
#
# Public targets
#
#------------------------------------------------------------------------------#

.PHONY: help #> Show this help message
help:
	@${AWK} -f ${HELP_AWK} ${MAKEFILE_LIST}

.PHONY: show #> Show configuration variables
show:
ifeq (${SHOW_DEFS},)
	@$(MAKE) SHOW_DEFS=1 show
else
	@:
endif

.PHONY: stage #> Build the Neovim configuration in stage
stage: ${staged_files}

.PHONY: runtime #> Copy the runtime to stage
runtime: | ${stage_nvim_dir}
	@cd "${nvim_src_dir}" && \
	  ${RSYNC} --archive --delete --ignore-missing-args \
	    after ftplugin colors plugin \
	    "${stage_nvim_dir}/"

.PHONY: seed #> Initialize Rocks seed packages
seed: ${seed_targets}

.PHONY: install #> Install the built configuration into ${NVIM_CONFIG_DIR}
install: stage seed runtime
	@${RSYNC} --archive --delete ${stage_nvim_dir} ${NVIM_CONFIG_DIR}

.PHONY: smoke #> Run headless sanity check against installed config
test: stage
	@${HEADLESS_ENV} ${NVIM} --headless +"lua print('ok')" +qall &>/dev/null || { \
		echo >&2 "Smoke test failed"; exit 1; }
	@printf "\033[1;32mSmoke test passed.\033[0m\n"

.PHONY: clean #> Remove stage/ and hermetic rocks caches
clean:
	@printf "\033[1;33mRemoving stage/ and hermetic rocks…\033[0m\n"
	@rm -rf "${STAGE_ROOT}"
	@rm -rf "${ROCKS_TREE}" "${LUAROCKS_DIR}"
	@printf "\033[1;32mArtifacts removed.\033[0m\n"

.PHONY: clean #! Clean artifacts; FORCE=1 also removes ${NVIM_CONFIG_DIR}
uninstall: clean
	@if [[ "${FORCE:-0}" == "1" ]]; then \
		printf "\033[1;33mFORCE=1: removing %s\033[0m\n" "${NVIM_CONFIG_DIR}"; \
		rm -rf "${NVIM_CONFIG_DIR}"; \
	else \
		printf "\033[1;34mConfig preserved. Use FORCE=1 to remove %s.\033[0m\n" \
			"${NVIM_CONFIG_DIR}"; \
	fi

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
