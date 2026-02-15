#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# seed.mk
#
# Responsibilities:
#   - Copy vendored seed plugin managers into stage:
#       * vendor/rocks.nvim      → stage/nvim/pack/rocks/start/rocks.nvim
#       * vendor/rocks-git.nvim  → stage/nvim/pack/rocks/start/rocks-git.nvim
#
# The hermetic LuaRocks config (luarocks_config) is also defined here but is
# NOT a seed_target.  It is an install-time concern consumed by `sync` in the
# top-level Makefile.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR, NVIM, GIT, LUA, RSYNC, ...
#   - project.mk has defined:
#       vendor_dir, stage_nvim_dir, nvim_rocks_dir,
#       luarocks_config_dir, luarocks_config
#
# Pin management:
#   Seed plugins are vendored as git submodules under vendor/.
#   Updating a pin is:
#     cd vendor/rocks.nvim && git checkout <ref> && cd ../..
#     git add vendor/rocks.nvim && git commit
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Internal paths
#------------------------------------------------------------------------------#

seed_pack_dir       := ${stage_nvim_dir}/pack/rocks/start
seed_rocks_nvim_dir := ${seed_pack_dir}/rocks.nvim
seed_rocks_git_dir  := ${seed_pack_dir}/rocks-git.nvim

# Targets consumed by the top-level "stage" target.
# These are PHONY because directory mtimes are unreliable after
# `git submodule update`.  Rsync is idempotent and fast for these
# small trees (~50 files each), so always running is cheap and correct.
seed_targets := seed-rocks-nvim seed-rocks-git

#------------------------------------------------------------------------------#
# Seed plugin managers: copy from vendor/ into stage
#------------------------------------------------------------------------------#

${seed_pack_dir}:
	mkdir -p "$@"

.PHONY: seed-rocks-nvim
seed-rocks-nvim: | ${seed_pack_dir}
	@${RSYNC} --archive --delete "${vendor_dir}/rocks.nvim/" "${seed_rocks_nvim_dir}/"

.PHONY: seed-rocks-git
seed-rocks-git: | ${seed_pack_dir}
	@${RSYNC} --archive --delete "${vendor_dir}/rocks-git.nvim/" "${seed_rocks_git_dir}/"

#------------------------------------------------------------------------------#
# Hermetic LuaRocks config
#
# This config tells LuaRocks to install into the hermetic rocks tree
# (nvim_rocks_dir) rather than any system location.
#
# This is an install-time artifact (writes to NVIM_CACHE_DIR, not stage/).
# The top-level Makefile's `sync` target depends on ${luarocks_config}.
#------------------------------------------------------------------------------#

${luarocks_config_dir}:
	mkdir -p "$@"

${luarocks_config}: | ${luarocks_config_dir}
	@echo "Writing hermetic LuaRocks config to $@"
	@printf 'rocks_trees = {\n  { name = "user", root = "%s" }\n}\n' \
	  "${nvim_rocks_dir}" > "$@"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
