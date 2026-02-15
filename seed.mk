#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# seed.mk
#
# Responsibilities:
#   - Copy vendored seed plugin managers into stage:
#       * vendor/rocks.nvim      → stage/nvim/pack/rocks/start/rocks.nvim
#       * vendor/rocks-git.nvim  → stage/nvim/pack/rocks/start/rocks-git.nvim
#   - Prepare a hermetic LuaRocks tree under ${nvim_rocks_dir}.
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
#   Make's dependency model handles invalidation automatically.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Internal paths
#------------------------------------------------------------------------------#

seed_pack_dir       := ${stage_nvim_dir}/pack/rocks/start
seed_rocks_nvim_dir := ${seed_pack_dir}/rocks.nvim
seed_rocks_git_dir  := ${seed_pack_dir}/rocks-git.nvim

# All file/directory targets that must exist after seeding.
# The top-level Makefile depends on ${seed_targets}.
seed_targets := \
  ${seed_rocks_nvim_dir} \
  ${seed_rocks_git_dir} \
  ${luarocks_config}

#------------------------------------------------------------------------------#
# Seed plugin managers: copy from vendor/ into stage
#------------------------------------------------------------------------------#

${seed_pack_dir}:
	mkdir -p "$@"

${seed_rocks_nvim_dir}: ${vendor_dir}/rocks.nvim | ${seed_pack_dir}
	@echo "Seeding rocks.nvim into $@"
	@${RSYNC} --archive --delete "$</" "$@/"

${seed_rocks_git_dir}: ${vendor_dir}/rocks-git.nvim | ${seed_pack_dir}
	@echo "Seeding rocks-git.nvim into $@"
	@${RSYNC} --archive --delete "$</" "$@/"

#------------------------------------------------------------------------------#
# Hermetic LuaRocks config
#
# This config tells LuaRocks to install into the hermetic rocks tree
# (nvim_rocks_dir) rather than any system location.
#------------------------------------------------------------------------------#

# Directories that env.lua expects to exist (even before anything is installed)
lua_share_dir := ${nvim_rocks_dir}/share/lua/5.1
lua_lib_dir   := ${nvim_rocks_dir}/lib/lua/5.1

${luarocks_config_dir}:
	mkdir -p "$@"

${luarocks_config}: | ${luarocks_config_dir}
	@echo "Writing hermetic LuaRocks config to $@"
	@mkdir -p "${lua_share_dir}" "${lua_lib_dir}"
	@printf 'rocks_trees = {\n  { name = "user", root = "%s" }\n}\n' \
	  "${nvim_rocks_dir}" > "$@"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
