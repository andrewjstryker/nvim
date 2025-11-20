#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# seed.mk
#
# Responsibilities:
#   - Install seed plugin managers into ${NVIM_CONFIG_DIR}:
#       * rocks.nvim
#       * rocks-git.nvim
#   - Prepare a hermetic LuaRocks tree under ${nvim_rocks_dir}.
#   - Provide a helper target for running rocks.nvim lock/sync headlessly.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR,
#       ROCKS_NVIM_REPO, ROCKS_NVIM_REF,
#       ROCKS_GIT_REPO,  ROCKS_GIT_REF,
#       NVIM, GIT, LUA, ...
#   - project.mk has defined:
#       nvim_rocks_dir
#
# The top-level Makefile should:
#   - include this file,
#   - use ${seed_targets} for file dependencies,
#   - and wire a .PHONY "seed" target that also calls "seed_rocks_sync".
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Internal paths (derived from env + project vars)
#------------------------------------------------------------------------------#

# Install location for seed plugins (XDG-config based)
seed_pack_dir       := ${NVIM_CONFIG_DIR}/pack/rocks/start
seed_rocks_nvim_dir := ${seed_pack_dir}/rocks.nvim
seed_rocks_git_dir  := ${seed_pack_dir}/rocks-git.nvim

# Hermetic LuaRocks tree lives under ${nvim_rocks_dir} (from project.mk)
# Derive a "cache root" and LuaRocks config path from it.
nvim_cache_root      := $(dir ${nvim_rocks_dir})
luarocks_config_dir  := ${nvim_cache_root}/luarocks
luarocks_config_file := ${luarocks_config_dir}/config.lua

# All file targets that must exist after seeding.
# The top-level Makefile can depend on ${seed_targets}.
seed_targets := \
  ${seed_rocks_nvim_dir} \
  ${seed_rocks_git_dir} \
  ${nvim_rocks_dir} \
  ${luarocks_config_file}

#------------------------------------------------------------------------------#
# Directory targets
#------------------------------------------------------------------------------#

${NVIM_CONFIG_DIR}:
	mkdir -p "$@"

${seed_pack_dir}: | ${NVIM_CONFIG_DIR}
	mkdir -p "$@"

${nvim_rocks_dir}:
	mkdir -p "$@"

${luarocks_config_dir}: | ${nvim_rocks_dir}
	mkdir -p "$@"

#------------------------------------------------------------------------------#
# Seed plugin managers: rocks.nvim and rocks-git.nvim
#------------------------------------------------------------------------------#

${seed_rocks_nvim_dir}: | ${seed_pack_dir}
	@echo "Seeding rocks.nvim into $@"
	@if [ ! -d "$@" ]; then \
	  ${GIT} clone "${ROCKS_NVIM_REPO}" "$@"; \
	else \
	  echo "rocks.nvim already present, updating remote..."; \
	  ${GIT} -C "$@" fetch --all --tags; \
	fi; \
	if [ "${ROCKS_NVIM_REF}" != "HEAD" ]; then \
	  echo "Checking out rocks.nvim ref ${ROCKS_NVIM_REF}"; \
	  ${GIT} -C "$@" checkout "${ROCKS_NVIM_REF}"; \
	else \
	  echo "Leaving rocks.nvim at HEAD"; \
	fi

${seed_rocks_git_dir}: | ${seed_pack_dir}
	@echo "Seeding rocks-git.nvim into $@"
	@if [ ! -d "$@" ]; then \
	  ${GIT} clone "${ROCKS_GIT_REPO}" "$@"; \
	else \
	  echo "rocks-git.nvim already present, updating remote..."; \
	  ${GIT} -C "$@" fetch --all --tags; \
	fi; \
	if [ "${ROCKS_GIT_REF}" != "HEAD" ]; then \
	  echo "Checking out rocks-git.nvim ref ${ROCKS_GIT_REF}"; \
	  ${GIT} -C "$@" checkout "${ROCKS_GIT_REF}"; \
	else \
	  echo "Leaving rocks-git.nvim at HEAD"; \
	fi

#------------------------------------------------------------------------------#
# Hermetic LuaRocks config
#------------------------------------------------------------------------------#

${luarocks_config_file}: | ${luarocks_config_dir}
	@echo "Writing hermetic LuaRocks config to $@"
	@echo "rocks_trees = {" > "$@"
	@echo "{ name = \"user\", root = \"${nvim_rocks_dir}\" }" >> "$@"
	@echo "}" >> "$@"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
