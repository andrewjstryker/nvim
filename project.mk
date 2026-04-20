#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# project.mk
#
# Shared internal project structure.
#
# Responsibilities:
#   - Derive internal paths (repo root, nvim src, build, stage, vendor).
#   - Bridge user-facing knobs from environment.mk into the variables expected
#     by other *.mk files (e.g., NVIM_ROCKS_DIR, LUAROCKS_CONFIG).
#   - Define hermetic Lua search paths (LUA_PATH / LUA_CPATH) for build-time
#     luarocks and sync script isolation.
#   - Generate stage/m4/config_env.m4 with content-comparison idempotence.
#   - Provide a summary block suitable for "make show".
#
# Assumptions:
#   - environment.mk has already been included and defines:
#       XDG_CONFIG_HOME, XDG_CACHE_HOME,
#       NVIM_CONFIG_DIR, NVIM_CACHE_DIR,
#       tool variables (NVIM, LUA, LUAROCKS, RSYNC, GIT, AWK, M4, ...)
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Repository layout (internal, not meant to be overridden)
#------------------------------------------------------------------------------#

# Root of the repository (assumed to be where Make is invoked)
repo_root      := ${CURDIR}

# Neovim source tree within the repo
nvim_src_dir   := ${repo_root}/nvim

# Build assets (e.g., m4 macros, vendored tools, helper scripts)
build_dir      := ${repo_root}/build
build_bin      := ${build_dir}/bin
m4_dir         := ${build_dir}/m4
scripts_dir    := ${build_dir}/scripts

# Vendored items (git submodules)
vendor_dir     := ${repo_root}/vendor

# Stage root and staged Neovim tree (assembled image)
stage_dir      := ${repo_root}/stage
stage_nvim_dir := ${stage_dir}/nvim

# Generated m4 macros live under stage/ (build output, not source tree).
# Static m4 macros live under build/m4/ (source tree, checked in).
stage_m4_dir   := ${stage_dir}/m4

#------------------------------------------------------------------------------#
# Hermetic rocks tree + bridge knobs
#------------------------------------------------------------------------------#

# Derive a cache root from NVIM_CACHE_DIR (user-facing knob from environment.mk).
nvim_cache_root     := ${NVIM_CACHE_DIR}

# Hermetic LuaRocks tree lives under ${nvim_rocks_dir}.
nvim_rocks_dir      := ${nvim_cache_root}/rocks
luarocks_config_dir := ${nvim_rocks_dir}/luarocks
luarocks_config     := ${luarocks_config_dir}/config.lua

# Stable aliases so other *.mk files don't need to re-derive paths.
NVIM_ROCKS_DIR      := ${nvim_rocks_dir}
LUAROCKS_CONFIG_DIR := ${luarocks_config_dir}
LUAROCKS_CONFIG     := ${luarocks_config}

# rocks-binaries server for pre-built binary rocks (avoids compiling on install)
luarocks_server := https://nvim-neorocks.github.io/rocks-binaries/

#------------------------------------------------------------------------------#
# Hermetic Lua search paths
#
# These define the Lua module search paths rooted at the hermetic rocks tree.
# Used by seed.mk: exported as LUA_PATH / LUA_CPATH so the sync script
# and luarocks subprocess see hermetic modules at build time.
#
# No trailing ";;" — we intentionally exclude user-global / system trees to
# prevent leakage of incompatible module versions (e.g., luarocks 3.13
# installed under ~/.local/share/lua/5.1/ built for Lua 5.4).
#------------------------------------------------------------------------------#

lua_share_dir      := ${nvim_rocks_dir}/share/lua/5.1
lua_lib_dir        := ${nvim_rocks_dir}/lib/lua/5.1

hermetic_lua_path  := ${lua_share_dir}/?.lua;${lua_share_dir}/?/init.lua
hermetic_lua_cpath := ${lua_lib_dir}/?.so;${lua_lib_dir}/?.dylib;${lua_lib_dir}/?.dll

#------------------------------------------------------------------------------#
# Stamp configuration into a file
#
# config_env.m4 is generated into stage/m4/ so the source tree stays
# read-only during build.  The m4 command in build.mk uses two -I flags
# to search both build/m4/ (static) and stage/m4/ (generated).
#
# paths.m4 (in build/m4/) does m4_include(`config_env.m4') — m4 finds
# it via the include path, regardless of which directory it lives in.
#
# Symbols stamped here:
#   NV_M4_NVIM_ROCKS_DIR       — hermetic rocks tree root
#   NV_M4_NVIM_CONFIG_DIR      — Neovim config directory (for hermetic rtp)
#------------------------------------------------------------------------------#

config_env := ${stage_m4_dir}/config_env.m4

# SENTINEL PATTERN (content-comparison idempotence):
#   ${config_env} is .PHONY so its recipe runs every invocation, but the
#   recipe only replaces the file when its content actually changes (via
#   cmp -s).  This bridges environment changes into Make's mtime graph:
#
#   - Environment unchanged → file untouched → mtime unchanged → no rebuild
#   - Environment changed   → file replaced  → mtime updated  → dependents rebuild
#
#   Any target that should rebuild when the environment changes MUST depend
#   on ${config_env} as a NORMAL prerequisite:
#
#     some_target: other_prereqs ${config_env} | stage-dirs
#
#   Do NOT use it as order-only (after |), or environment changes will not
#   propagate.
#
.PHONY: ${config_env}
${config_env}:
	@mkdir -p "$(dir $@)"
	@set -eu; \
	  tmp="$$(mktemp "$(dir $@)/.config_env.m4.XXXXXX")"; \
	  { \
	    echo "m4_dnl Auto-generated by project.mk; do not edit"; \
	    echo "m4_define(\`NV_M4_NVIM_ROCKS_DIR', \`${nvim_rocks_dir}')"; \
	    echo "m4_define(\`NV_M4_NVIM_CONFIG_DIR', \`${NVIM_CONFIG_DIR}')"; \
	  } > "$$tmp"; \
	  if [ ! -f "$@" ] || ! cmp -s "$$tmp" "$@"; then \
	    mv "$$tmp" "$@"; \
	  else \
	    rm -f "$$tmp"; \
	  fi

#------------------------------------------------------------------------------#
# Project summary (for "make show" or similar)
#------------------------------------------------------------------------------#

define project_summary
  Repository root............ ${repo_root}

  # Source / build layout
  Neovim source.............. ${nvim_src_dir}
  Build dir.................. ${build_dir}
  M4 static dir.............. ${m4_dir}
  M4 generated dir........... ${stage_m4_dir}
  Vendor dir................. ${vendor_dir}
  Stage dir.................. ${stage_dir}
  Stage Neovim............... ${stage_nvim_dir}

  # Install / cache layout
  NVIM_CONFIG_DIR............ ${NVIM_CONFIG_DIR}
  NVIM_CACHE_DIR............. ${NVIM_CACHE_DIR}
  NVIM_ROCKS_DIR............. ${NVIM_ROCKS_DIR}
  LUAROCKS_CONFIG_DIR........ ${LUAROCKS_CONFIG_DIR}
  LUAROCKS_CONFIG............ ${LUAROCKS_CONFIG}
  Luarocks server............ ${luarocks_server}
  config_env.m4.............. ${config_env}

  # Hermetic Lua paths
  hermetic LUA_PATH.......... ${hermetic_lua_path}
  hermetic LUA_CPATH......... ${hermetic_lua_cpath}
endef

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
