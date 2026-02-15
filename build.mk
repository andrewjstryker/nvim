#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
#
# build.mk
#
# Build the stage image under ${stage_nvim_dir}:
#   - Copy top-level files (init.lua, rocks.toml)
#   - Transform *.lua.m4 → *.lua via m4
#   - Compile *.fnl → *.lua via fennel
#   - Copy optional runtime dirs (after/, ftplugin/, colors/, plugin/)
#
# This file defines only file targets and internal variables.
# The .PHONY interface targets (e.g., "stage") live in the top-level Makefile.
#
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#

#------------------------------------------------------------------------------#
# Build-specific internals
#------------------------------------------------------------------------------#

# Vendored fennel script and shared m4 macros live under ${build_dir}.
# These are implementation details, not user knobs.
fennel         := ${build_dir}/bin/fennel
m4_include_dir := ${build_dir}/m4

#------------------------------------------------------------------------------#
# Source discovery
#------------------------------------------------------------------------------#

# Top-level files (always copied 1:1)
top_src := \
  ${nvim_src_dir}/init.lua \
  ${nvim_src_dir}/rocks.toml

top_out := $(patsubst ${nvim_src_dir}/%,${stage_nvim_dir}/%,${top_src})

# Single logical module tree: nvim/lua/**
# Three implementation forms:
#   - plain Lua:    foo.lua
#   - templated:    foo.lua.m4
#   - Fennel:       foo.fnl

# Recursive wildcard: $(call rwildcard,DIR,pattern)
# Example: $(call rwildcard,${nvim_src_dir}/lua/,*.lua)
rwildcard = $(wildcard $1$2) \
            $(foreach d,$(wildcard $1*/), \
              $(call rwildcard,$d,$2))

# m4 macro files (all *.m4 under build/m4/); lazy expansion is intentional
# so that config_env.m4 is picked up even when generated after parse.
m4_src           = $(call rwildcard,${build_dir}/m4/,*.m4)

# All *.lua.m4 under nvim/lua
lua_m4_src      := $(call rwildcard,${nvim_src_dir}/lua/,*.lua.m4)

# Plain Lua = all *.lua under nvim/lua
lua_plain_src   := $(call rwildcard,${nvim_src_dir}/lua/,*.lua)

# All *.fnl under nvim/lua
fnl_src         := $(call rwildcard,${nvim_src_dir}/lua/,*.fnl)

# Outputs for each source form (all end up as *.lua under stage_nvim_dir/lua)
lua_plain_out := $(patsubst ${nvim_src_dir}/lua/%,${stage_nvim_dir}/lua/%,${lua_plain_src})
lua_m4_out    := $(patsubst ${nvim_src_dir}/lua/%.lua.m4,${stage_nvim_dir}/lua/%.lua,${lua_m4_src})
fnl_out       := $(patsubst ${nvim_src_dir}/lua/%.fnl,${stage_nvim_dir}/lua/%.lua,${fnl_src})

# Combined set of staged Lua outputs (used for duplicate detection & orchestration)
stage_lua_all := ${lua_plain_out} ${lua_m4_out} ${fnl_out}

# All outputs that define the "code" part of a stage image.
stage_outputs := \
  ${top_out} \
  ${stage_lua_all}

#------------------------------------------------------------------------------#
# Optional runtime directories (after/, ftplugin/, colors/, plugin/)
#
# These are rsync'd wholesale if they exist in the source tree.
# The .PHONY "runtime" target is defined here (not in the top-level Makefile)
# because only build.mk knows which dirs to look for.
#------------------------------------------------------------------------------#

runtime_dirs := after ftplugin colors plugin
runtime_src  := $(foreach d,${runtime_dirs},$(wildcard ${nvim_src_dir}/$d))

.PHONY: runtime
runtime:
	$(if ${runtime_src}, \
	  $(foreach d,${runtime_src}, \
	    ${RSYNC} --archive --delete \
	      "$d/" "${stage_nvim_dir}/$(notdir $d)/" && \
	  ) true, \
	  @true)

#------------------------------------------------------------------------------#
# Duplicate target guard (module-path uniqueness)
#------------------------------------------------------------------------------#

# Assert that a list of targets contains no duplicates.
# Usage:
#   $(call assert-unique,LIST,ERROR_MESSAGE)
define assert-unique
  $(if $(filter-out $(words $(sort ${1})),$(words ${1})), \
    $(error ${2} (list: ${1})) \
  )
endef

# Fail at parse time if multiple sources map to the same staged Lua path
# (e.g., foo.lua, foo.lua.m4, and/or foo.fnl all producing the same module)
$(call assert-unique,${stage_lua_all},Duplicate staged Lua targets detected)

#------------------------------------------------------------------------------#
# Top-level files (init.lua, rocks.toml)
#------------------------------------------------------------------------------#

${stage_nvim_dir}:
	@mkdir -p "${stage_nvim_dir}"

${stage_nvim_dir}/init.lua: ${nvim_src_dir}/init.lua | ${stage_nvim_dir}
	cp "$<" "$@"

${stage_nvim_dir}/rocks.toml: ${nvim_src_dir}/rocks.toml | ${stage_nvim_dir}
	cp "$<" "$@"

#------------------------------------------------------------------------------#
# Lua modules: plain Lua, m4-templated Lua, and Fennel→Lua
#------------------------------------------------------------------------------#

# 1. Plain Lua copy
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua
	mkdir -p "$(dir $@)"
	cp "$<" "$@"

# 2. m4 templates → Lua
#    Depends on all m4 macro files (lazy m4_src) via order-only for config_env.m4
#    and normal deps for static macros.  In practice, m4_src covers both;
#    config_env.m4's PHONY nature means m4 templates rebuild when env changes.
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua.m4 ${m4_src}
	mkdir -p "$(dir $@)"
	"${M4}" -P -I "${m4_include_dir}" "$<" > "$@"

# 3. Fennel → Lua
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.fnl
	mkdir -p "$(dir $@)"
	"${fennel}" --compile "$<" > "$@"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
