#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# seed.mk
#
# Responsibilities:
#   - Prepare a hermetic LuaRocks config under ${nvim_rocks_dir}.
#   - Bootstrap toml-edit so the sync script can parse rocks.toml.
#   - Sync all plugins declared in rocks.toml:
#       * Native rocks via the host luarocks CLI
#       * Git-based plugins via git clone into the pack directory
#
# Design:
#   The sync script (rocks_sync.lua) runs under the host Lua interpreter
#   (not Neovim).  It uses toml-edit to parse rocks.toml, then shells out
#   to luarocks and git to install each entry.
#
#   rocks.toml is the single authority for package versions.  Bootstrap
#   installs only toml-edit (one rock); everything else is installed by
#   the sync script from rocks.toml.
#
#   This produces the on-disk layout that Neovim's packpath expects:
#   native rocks in the luarocks tree and git plugins under
#   pack/rocks/{start,opt}/.
#
# Assumptions:
#   - environment.mk has defined:
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR, NVIM, GIT, LUA, LUAROCKS,
#       RSYNC, ...
#   - project.mk has defined:
#       nvim_rocks_dir, luarocks_config_dir, luarocks_config, luarocks_server,
#       lua_share_dir, lua_lib_dir, hermetic_lua_path, hermetic_lua_cpath,
#       scripts_dir
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Hermetic LuaRocks config
#
# This config tells LuaRocks to install into the hermetic rocks tree
# (nvim_rocks_dir) rather than any system location.
#------------------------------------------------------------------------------#

${luarocks_config_dir}:
	mkdir -p "$@"

${luarocks_config}: | ${luarocks_config_dir}
	@echo "Writing hermetic LuaRocks config to $@"
	@mkdir -p "${lua_share_dir}" "${lua_lib_dir}"
	@printf '%s\n' \
	  'rocks_trees = {' \
	  '  { name = "user", root = "${nvim_rocks_dir}" }' \
	  '}' \
	  'variables = {' \
	  '  LUA = "${LUA}",' \
	  '  LUA_BINDIR = "$(dir ${LUA})",' \
	  '}' \
	  > "$@"

#------------------------------------------------------------------------------#
# Bootstrap: install toml-edit
#
# The sync script needs toml-edit to parse rocks.toml.  We install it
# directly as the minimal bootstrap — one rock, no version conflicts.
#
# Everything else (all user plugins) is installed by the sync script
# from rocks.toml.  rocks.toml is the single authority for package versions.
#
# Idempotent: luarocks skips already-installed packages.
#------------------------------------------------------------------------------#

.PHONY: rocks-bootstrap
rocks-bootstrap: check-sync-tools ${luarocks_config}
	@echo "Bootstrapping toml-edit into ${nvim_rocks_dir}..."
	@LUAROCKS_CONFIG="${luarocks_config}" \
	  LUA_PATH="${hermetic_lua_path};;" \
	  LUA_CPATH="${hermetic_lua_cpath};;" \
	  ${LUAROCKS} --lua-version=5.1 \
	    --tree "${nvim_rocks_dir}" \
	    --server='${luarocks_server}' \
	    install toml-edit
	@echo "Bootstrap complete (toml-edit now available)."

#------------------------------------------------------------------------------#
# Full plugin sync
#
# Parse rocks.toml with the host Lua interpreter + toml-edit, then:
#   - Install native rocks via luarocks
#   - Clone git-based plugins into the Neovim pack directory
#
# The sync script runs under plain Lua (not Neovim).  It uses toml-edit
# (available after rocks-bootstrap) to parse rocks.toml and shells out to
# luarocks and git for each entry.
#
# Pack path structure (matches M4_START_DIR / M4_OPT_DIR in paths.m4):
#   ${nvim_rocks_dir}/share/nvim/site/pack/rocks/{start,opt}/
#
# Idempotent: luarocks skips installed packages; existing clones are skipped.
#------------------------------------------------------------------------------#

.PHONY: rocks-sync
rocks-sync: rocks-bootstrap
	@echo "Syncing plugins from rocks.toml..."
	@LUAROCKS_CONFIG="${luarocks_config}" \
	  LUA_PATH="${hermetic_lua_path};;" \
	  LUA_CPATH="${hermetic_lua_cpath};;" \
	  ${LUA} ${scripts_dir}/rocks_sync.lua \
	    "${NVIM_CONFIG_DIR}/rocks.toml" \
	    "${nvim_rocks_dir}" \
	    "${LUAROCKS}" \
	    "${GIT}" \
	    "${luarocks_server}"

#------------------------------------------------------------------------------#
# Exported targets
#
# The top-level Makefile depends on these.
#   - rocks-bootstrap:  installs toml-edit for rocks.toml parsing
#   - rocks-sync:       installs all plugins from rocks.toml
#------------------------------------------------------------------------------#

# Cache is runtime state and intentionally outside the protocol manifest.
.PHONY: clean-cache #> Remove the hermetic rocks cache
clean-cache:
	$(if ${DRY_RUN}, \
	  printf 'would remove %s/ and %s/\n' \
	    '${nvim_rocks_dir}' '${luarocks_config_dir}', \
	  printf '\033[1;33mRemoving hermetic rocks cache…\033[0m\n'; \
	  rm -rf '${nvim_rocks_dir}' '${luarocks_config_dir}'; \
	  printf '\033[1;32mCache removed.\033[0m\n')

.PHONY: uninstall-cache #> Remove installed config and hermetic cache
uninstall-cache: uninstall clean-cache

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
