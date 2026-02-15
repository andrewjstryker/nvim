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

# m4 include paths:
#   - m4_include_dir (build/m4/) contains static, checked-in macros
#   - stage_m4_dir   (stage/m4/) contains generated macros (config_env.m4)
# Both are passed via -I so that m4_include(`config_env.m4') in paths.m4
# finds the generated file regardless of which directory it lives in.
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

# Static m4 macro files (constants.m4, paths.m4, common.m4, etc.)
# These live in build/m4/ (source tree) and are NOT .PHONY.
# config_env.m4 is NOT here — it lives in stage/m4/ (generated).
m4_static_src := $(call rwildcard,${build_dir}/m4/,*.m4)

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
# Stage directory structure
#
# Create every needed output directory once, up front.  All file targets
# depend on stage-dirs as an order-only prerequisite instead of running
# mkdir in their recipes.
#
# $(sort ...) deduplicates, so this is always the minimal set.
#------------------------------------------------------------------------------#

stage_dirs := ${stage_nvim_dir} $(sort $(dir ${stage_lua_all}))

.PHONY: stage-dirs
stage-dirs:
	@mkdir -p ${stage_dirs}

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
	@for d in ${runtime_src}; do \
	  ${RSYNC} --archive --delete "$$d/" "${stage_nvim_dir}/$$(basename $$d)/"; \
	done

#------------------------------------------------------------------------------#
# Duplicate target guard (module-path uniqueness)
#------------------------------------------------------------------------------#

# Assert that a list of targets contains no duplicates.
# Works because $(filter-out A,B) is non-empty when the strings A and B
# differ — i.e., when $(words $(sort LIST)) < $(words LIST).
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

${stage_nvim_dir}/init.lua: ${nvim_src_dir}/init.lua | stage-dirs
	cp "$<" "$@"

${stage_nvim_dir}/rocks.toml: ${nvim_src_dir}/rocks.toml | stage-dirs
	cp "$<" "$@"

#------------------------------------------------------------------------------#
# Lua modules: plain Lua, m4-templated Lua, and Fennel→Lua
#
# All pattern rules use stage-dirs (order-only) to guarantee the target
# directory exists.  No recipe creates directories itself.
#------------------------------------------------------------------------------#

# 1. Plain Lua copy
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua | stage-dirs
	cp "$<" "$@"

# 2. m4 templates → Lua
#    Static m4 files (build/m4/) are normal prerequisites.
#    config_env.m4 (stage/m4/) is order-only via ${config_env}: its .PHONY
#    nature triggers re-evaluation every run, but the cmp guard in project.mk
#    means its mtime only changes when the content changes.
#
#    Two -I flags: static macros in build/m4/, generated macros in stage/m4/.
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.lua.m4 ${m4_static_src} | stage-dirs ${config_env}
	"${M4}" -P -I "${m4_include_dir}" -I "${stage_m4_dir}" "$<" > "$@"

# 3. Fennel → Lua
${stage_nvim_dir}/lua/%.lua: ${nvim_src_dir}/lua/%.fnl | stage-dirs
	"${fennel}" --compile "$<" > "$@"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#
