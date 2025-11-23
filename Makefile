#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# Makefile
#
# Build, install, and sync Neovim configuration
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Configure execution
#------------------------------------------------------------------------------#

SHELL := bash
.SHELLFLAGS := --noprofile --norc -euo pipefail -c

#------------------------------------------------------------------------------#
# Includes
#------------------------------------------------------------------------------#

# environment variables (user-facing knobs)
include environment.mk

# project-wide derived variables and structure
include project.mk

# build Lua modules in stage
include build.mk

# seed Lua Rocks (rocks.nvim + rocks-git.nvim and LuaRocks config)
include seed.mk

#------------------------------------------------------------------------------#
# Verify invariants (tools must exist)
#------------------------------------------------------------------------------#

toolset_vars := LUA NVIM RSYNC GIT AWK M4

missing_tools := \
  $(strip \
    $(foreach v,$(toolset_vars), \
      $(if $(strip $($v)),,$v) \
    ) \
  )

ifneq (${missing_tools},)
  $(error Missing required tools: ${missing_tools})
endif

#------------------------------------------------------------------------------#
# Human interface
#------------------------------------------------------------------------------#

.PHONY: help #> Show this help message
help:
	@${AWK} -f ${build_dir}/bin/generate-help.awk ${MAKEFILE_LIST}

.PHONY: show #> Show configuration variables
show:
	@printf '%s\n\n' "Environment:" "${env_summary}"
	@printf '%s\n\n' "Project:" "${project_summary}"
	@printf '%s\n' "Tools:"
	@printf '%s\n' "${toolset_summary}"

#------------------------------------------------------------------------------#
# Build: stage code image (Lua, templates, Fennel)
#------------------------------------------------------------------------------#

.PHONY: build #> Build stage/nvim code image (Lua, templates, Fennel)
build: ${stage_outputs}

#------------------------------------------------------------------------------#
# Build: runtime tree into stage
#------------------------------------------------------------------------------#

.PHONY: runtime #> Copy runtime dirs (after/, ftplugin/, colors/, plugin/) into stage
runtime:
	@mkdir -p "${stage_nvim_dir}"
	@cd "${nvim_src_dir}" && \
	  ${RSYNC} --archive --delete --ignore-missing-args \
	    after ftplugin colors plugin \
	    "${stage_nvim_dir}"

.PHONY: stage #> Construct the entire staging directory
stage: build runtime

#------------------------------------------------------------------------------#
# Seed: rocks.nvim + rocks-git.nvim + hermetic LuaRocks config
#------------------------------------------------------------------------------#

.PHONY: seed #> Clone/pin rocks.nvim + rocks-git.nvim and write LuaRocks config
seed: ${seed_targets}

#------------------------------------------------------------------------------#
# Install: sync stage → NVIM_CONFIG_DIR
#------------------------------------------------------------------------------#

.PHONY: install #> Install staged Neovim config into NVIM_CONFIG_DIR
install: stage seed
	@echo "Installing Neovim config to ${NVIM_CONFIG_DIR}"
	@mkdir -p "${NVIM_CONFIG_DIR}"
	@${RSYNC} --archive --delete \
	  "${stage_nvim_dir}/" \
	  "${NVIM_CONFIG_DIR}/"

#------------------------------------------------------------------------------#
# Sync: run :Rocks sync on installed config (post-install step)
#------------------------------------------------------------------------------#

.PHONY: sync #> Run :Rocks sync using installed config + hermetic rocks tree
sync: install
	@echo "Running Rocks sync on installed Neovim config..."
	@LUAROCKS_CONFIG="${luarocks_config}" \
	  NVIM_CONFIG="${NVIM_CONFIG_DIR}" \
	  ${NVIM} --headless --clean \
	    -u "${NVIM_CONFIG_DIR}/init.lua" \
	    "+Rocks sync" \
	    "+qa"

#------------------------------------------------------------------------------#
# Test: smoke test using temporary config/cache directories
#------------------------------------------------------------------------------#

.PHONY: test #> Smoke test: run sync with temporary NVIM_CONFIG_DIR / NVIM_CACHE_DIR
test: clean
	@tmp_cfg="$$(mktemp -d)"; \
	tmp_cache="$$(mktemp -d)"; \
	echo "Smoke test using:"; \
	echo "  NVIM_CONFIG_DIR=$$tmp_cfg"; \
	echo "  NVIM_CACHE_DIR=$$tmp_cache"; \
	NVIM_CONFIG_DIR="$$tmp_cfg" \
	NVIM_CACHE_DIR="$$tmp_cache" \
	  ${MAKE} sync; \
	status="$$?"; \
	if [ "$$status" -eq 0 ]; then \
	  echo "Smoke test succeeded."; \
	else \
	  echo "Smoke test FAILED (exit $$status)."; \
	fi; \
	rm -rf "$$tmp_cfg" "$$tmp_cache"; \
	exit "$$status"

#------------------------------------------------------------------------------#
# Clean / uninstall
#------------------------------------------------------------------------------#

.PHONY: clean #> Remove stage/ and hermetic rocks cache
clean:
	@printf "\033[1;33mRemoving stage/ and hermetic rocks cache…\033[0m\n"
	@rm -rf "${stage_dir}" "${nvim_rocks_dir}" "${luarocks_config_dir}"
	@printf "\033[1;32mArtifacts removed.\033[0m\n"

.PHONY: uninstall #! Clean artifacts; FORCE=1 also removes ${NVIM_CONFIG_DIR}
uninstall: clean
	@if [[ "${FORCE:-0}" == "1" ]]; then \
		printf "\033[1;33mFORCE=1: removing %s\033[0m\n" "${NVIM_CONFIG_DIR}"; \
		rm -rf "${NVIM_CONFIG_DIR}"; \
	else \
		printf "\033[1;34mConfig preserved. Use FORCE=1 to remove %s.\033[0m\n" \
			"${NVIM_CONFIG_DIR}"; \
	fi

