#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# project.mk
#
# Shared internal project structure.
#
# Responsibilities:
#   - Derive internal paths (repo root, nvim src, build, stage).
#   - Bridge user-facing knobs from environment.mk into the variables expected
#     by other *.mk files (e.g., NVIM_CONFIG, NVIM_ROCKS).
#   - Provide a summary block suitable for "make show".
#
# Assumptions:
#   - environment.mk has already been included and defines:
#       XDG_CONFIG_HOME, XDG_CACHE_HOME,
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR,
#       ROCKS_NVIM_REPO, ROCKS_NVIM_REF,
#       tool variables (NVIM, LUA, RSYNC, GIT, AWK, M4, ...)
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Repository layout (internal, not meant to be overridden)
#------------------------------------------------------------------------------#

# Root of the repository (assumed to be where Make is invoked)
repo_root      := ${CURDIR}

# Neovim source tree within the repo
nvim_src_dir   := ${repo_root}/nvim

# Build assets (e.g., m4 macros, vendored tools)
build_dir      := ${repo_root}/build
build_bin      := ${build_dir}/bin
m4_dir         := ${build_dir}/m4

# Stage root and staged Neovim tree (assembled image)
stage_dir      := ${repo_root}/stage
stage_nvim_dir := ${stage_dir}/nvim

#------------------------------------------------------------------------------#
# Hermetic rocks tree + config bridge
#------------------------------------------------------------------------------#

# Derive the hermetic LuaRocks tree root from NVIM_CACHE_DIR.
config_env     := ${m4_dir}/config_env.m4
#
# Hermetic LuaRocks tree lives under ${nvim_rocks_dir} (from project.mk)
# Derive a "cache root" and LuaRocks config path from it.
nvim_rocks_dir := ${NVIM_CACHE_DIR}/rocks
nvim_cache_root      := ${nvim_rocks_dir}
luarocks_config_dir  := ${nvim_cache_root}/luarocks
luarocks_config := ${luarocks_config_dir}/config.lua

#------------------------------------------------------------------------------#
# Stamp configuration into a file
#------------------------------------------------------------------------------#

.PHONY: ${config_env} #> Generate LuaRocks config environment m4
${config_env}:
	@mkdir -p "$(dir $@)"
	@{ \
	  echo "m4_dnl Auto-generated; do not edit"; \
	  echo "m4_define(\`NVIM_ROCKS_DIR', \`${nvim_rocks_dir}')"; \
	  echo "m4_define(\`LUAROCKS_CONFIG_DIR', \`${luarocks_config_dir}')"; \
	  echo "m4_define(\`LUAROCKS_CONFIG', \`${luarocks_config}')"; \
	} > "$@.tmp"
	@if [ ! -f "$@" ] || ! cmp -s "$@.tmp" "$@"; then \
	  mv "$@.tmp" "$@"; \
	else \
	  rm "$@.tmp"; \
	fi

#------------------------------------------------------------------------------#
# Project summary (for "make show" or similar)
#------------------------------------------------------------------------------#

define project_summary
  Repository root............ ${repo_root}

  # Source / build layout
  Neovim source.............. ${nvim_src_dir}
  Build dir.................. ${build_dir}
  M4 template dir............ ${m4_dir}
  Stage dir.................. ${stage_dir}
  Stage Neovim............... ${stage_nvim_dir}

  # Install / cache layout
  NVIM_CONFIG_DIR (input).... ${NVIM_CONFIG_DIR}
  NVIM_CACHE_DIR (input)..... ${NVIM_CACHE_DIR}

  # Seed plugin pins
  ROCKS_NVIM_REPO............ ${ROCKS_NVIM_REPO}
  ROCKS_NVIM_REF............. ${ROCKS_NVIM_REF}
  ROCKS_GIT_REPO............. ${ROCKS_GIT_REPO}
  ROCKS_GIT_REF.............. ${ROCKS_GIT_REF}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
