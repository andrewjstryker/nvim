#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# seed.mk
#
# Install seed plugin managers into ${NVIM_CONFIG} and perform a hermetic
# rocks.nvim lock/sync using a dedicated LuaRocks tree under ${NVIM_ROCKS}.
#
# This file defines only file targets and internal variables.
# The .PHONY "seed" target is defined in the top-level Makefile and should
# depend on ${seed_targets}.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Public knobs (expected from top-level)
#------------------------------------------------------------------------------#
# NVIM_CONFIG and NVIM_ROCKS are defined in the top-level Makefile, using
# XDG_* defaults. They are treated here as inputs and not re-derived.

# NVIM_CONFIG ?= ...
# NVIM_ROCKS  ?= ...

#------------------------------------------------------------------------------#
# Internal paths (not meant to be overridden)
#------------------------------------------------------------------------------#

nvim_config_dir := ${NVIM_CONFIG}
nvim_rocks_dir  := ${NVIM_ROCKS}

# Derive a "cache root" from NVIM_ROCKS, e.g. /.../nvim/
nvim_cache_dir       := $(dir ${nvim_rocks_dir})
luarocks_config_dir  := ${nvim_cache_dir}/luarocks
luarocks_config_file := ${luarocks_config_dir}/config.lua

seed_pack_dir       := ${nvim_config_dir}/pack/rocks/start
seed_rocks_nvim_dir := ${seed_pack_dir}/rocks.nvim
seed_rocks_git_dir  := ${seed_pack_dir}/rocks-git.nvim

# A simple stamp to record that rocks lock/sync has been run hermetically.
# (We cannot easily enumerate all plugin files, so a stamp is reasonable here.)
rocks_sync_stamp := ${nvim_cache_dir}/.rocks-synced

# All targets that must exist after `make seed`
seed_targets := \
  ${seed_rocks_nvim_dir} \
  ${seed_rocks_git_dir} \
  ${nvim_rocks_dir} \
  ${luarocks_config_file} \
  ${rocks_sync_stamp}

#------------------------------------------------------------------------------#
# Directory targets
#------------------------------------------------------------------------------#

${nvim_config_dir}:
	mkdir -p "$@"

${seed_pack_dir}: | ${nvim_config_dir}
	mkdir -p "$@"

${nvim_rocks_dir}:
	mkdir -p "$@"

${luarocks_config_dir}: | ${nvim_rocks_dir}
	mkdir -p "$@"

#------------------------------------------------------------------------------#
# Seed plugin managers: rocks.nvim and rocks-git.nvim
#------------------------------------------------------------------------------#

${seed_rocks_nvim_dir}: | ${seed_pack_dir}
	@if [ ! -d "$@" ]; then \
	  echo "Cloning rocks.nvim into $@"; \
	  ${GIT} clone "${ROCKS_NVIM_REPO}" "$@"; \
	  if [ "${ROCKS_NVIM_REF}" != "HEAD" ]; then \
	    echo "Checking out rocks.nvim ref ${ROCKS_NVIM_REF}"; \
	    ${GIT} -C "$@" checkout "${ROCKS_NVIM_REF}"; \
	  fi; \
	else \
	  echo "rocks.nvim already present at $@"; \
	fi

${seed_rocks_git_dir}: | ${seed_pack_dir}
	@if [ ! -d "$@" ]; then \
	  echo "Cloning rocks-git.nvim into $@"; \
	  ${GIT} clone "${ROCKS_GIT_REPO}" "$@"; \
	  if [ "${ROCKS_GIT_REF}" != "HEAD" ]; then \
	    echo "Checking out rocks-git.nvim ref ${ROCKS_GIT_REF}"; \
	    ${GIT} -C "$@" checkout "${ROCKS_GIT_REF}"; \
	  fi; \
	else \
	  echo "rocks-git.nvim already present at $@"; \
	fi

#------------------------------------------------------------------------------#
# Hermetic LuaRocks config
#------------------------------------------------------------------------------#

${luarocks_config_file}: | ${luarocks_config_dir}
	@echo "Writing hermetic LuaRocks config to $@"
	@{ \
	  echo 'rocks_trees = {'; \
	  echo '  { name = "user", root = "'"${nvim_rocks_dir}"'" },'; \
	  echo '}'; \
	} > "$@"

#------------------------------------------------------------------------------#
# Hermetic rocks.nvim lock/sync (headless Neovim)
#------------------------------------------------------------------------------#

${rocks_sync_stamp}: ${seed_rocks_nvim_dir} ${seed_rocks_git_dir} ${luarocks_config_file}
	@echo "Running hermetic rocks.nvim lock/sync..."
	@LUAROCKS_CONFIG="${luarocks_config_file}" \
	  NVIM_CONFIG="${nvim_config_dir}" \
	  ${NVIM} --headless --clean \
	    -u "${nvim_config_dir}/init.lua" \
	    "+Rocks lock" \
	    "+Rocks sync" \
	    "+qa"
	@touch "$@"
