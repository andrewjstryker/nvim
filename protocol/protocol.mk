# protocol.mk -- the shared home concern protocol
#
# src is the first-party declaration. Every unclaimed non-hidden path below it
# has the same relative path below stage, except that a final .m4 suffix is
# removed. Concerns claim inputs and publish outputs for other transformations.
# vendor is the third-party declaration: mapped namespace directories below it
# are installed directly and are never copied into stage. Dot-prefixed paths in
# either tree, and unmapped vendor directories such as vendor/build, are private.

PROTOCOL_MK  ?= ../protocol/protocol.mk
PROTOCOL_BIN ?= $(patsubst %/,%,$(dir ${PROTOCOL_MK}))/bin

SHELL         := /bin/sh
.SHELLFLAGS   := -eu -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SECONDEXPANSION:
.SILENT:

define nl


endef

# Environment -----------------------------------------------------------------

XDG_CONFIG_HOME ?= ${HOME}/.config
XDG_DATA_HOME   ?= ${HOME}/.local/share
XDG_STATE_HOME  ?= ${HOME}/.local/state
XDG_CACHE_HOME  ?= ${HOME}/.cache
BIN_DIR         ?= ${HOME}/.local/bin
required_inputs ?=

path_vars := \
  XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME BIN_DIR

require_nonempty = $(if $(strip $($1)),,$(error $1 must not be empty))
$(foreach v,HOME ${path_vars} ${required_inputs},$(call require_nonempty,$v))

export ${path_vars} ${required_inputs}

DESTDIR ?=

# Tools and caller inputs ------------------------------------------------------

M4    ?= $(shell command -v m4)
RSYNC ?= $(shell command -v rsync)
m4_vars ?=

# Tool lists contain variable names rather than commands. Wrappers extend the
# phase in which a tool is first required; the aggregate is diagnostic only.
stage_tools   = $(if $(strip ${SKIP}),,$(if $(strip ${m4_sources}),M4))
install_tools = $(if $(strip ${SKIP}),,RSYNC)
sync_tools    =
tools         = $(sort ${stage_tools} ${install_tools} ${sync_tools})

missing_tools = $(strip $(foreach v,$1,$(if $(strip $($v)),,$v)))

# Non-file inputs available to ordinary m4 templates. Required staging inputs
# participate automatically; wrappers extend the set with m4_vars. Every value
# is defined under its Make variable name and recorded in the renderer context.
m4_context_vars = \
  XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME BIN_DIR \
  ${required_inputs}
m4_render_vars = $(sort ${m4_context_vars} ${m4_vars})
m4_defines = $(foreach v,${m4_render_vars},--define=${v}='$(${v})')

# Renderer identity and behavior invalidate templates but are not themselves
# template variables. M4FLAGS is reserved for m4 options such as include paths.
m4_context_content = \
  M4=${M4}${nl} \
  M4FLAGS=${M4FLAGS}${nl} \
  HOME=${HOME}${nl} \
  $(foreach v,${m4_render_vars},$v=$($v)${nl})

export M4_CONTEXT = ${m4_context_content}

define check_tools
	$(if $(call missing_tools,$1),\
	  $(error Missing tools needed to $2: $(call missing_tools,$1)))
endef

.PHONY: check-stage-tools check-install-tools check-sync-tools
.PHONY: check-tools #> Check every declared tool requirement
check-stage-tools:
	$(call check_tools,${stage_tools},stage)

check-install-tools:
	$(call check_tools,${install_tools},install)

check-sync-tools:
	$(call check_tools,${sync_tools},sync)

check-tools: check-stage-tools check-install-tools check-sync-tools

# Source declaration and staged manifest --------------------------------------

src    ?= src
stage  ?= stage
vendor ?= vendor
claimed_sources ?=
claimed_outputs ?=

# GNU make's wildcard excludes dot entries. That is intentional: a dot-prefixed
# directory is private wherever it appears and cannot become installed payload.
rwildcard = \
  $(filter-out $(patsubst %/,%,$(wildcard $1*/)),$(wildcard $1$2)) \
  $(foreach d,$(wildcard $1*/),$(call rwildcard,$d,$2))

rdirectories = $(wildcard $1*/) \
  $(foreach d,$(wildcard $1*/),$(call rdirectories,$d))

source_excludes   := %~ %.orig %.rej
discovered_sources = $(filter-out ${source_excludes},$(call rwildcard,${src}/,*))
sources           = $(filter-out ${claimed_sources},${discovered_sources})
source_dirs      = $(patsubst %/,%,$(call rdirectories,${src}/))
m4_sources       = $(filter %.m4,${sources})
plain_sources    = $(filter-out ${m4_sources},${sources})

staged_files = \
  $(patsubst ${src}/%,${stage}/%,${plain_sources}) \
  $(patsubst ${src}/%.m4,${stage}/%,${m4_sources}) \
  ${claimed_outputs}
staged_dirs = $(patsubst ${src}/%,${stage}/%,${source_dirs})
staged      = ${staged_dirs} ${staged_files}

stage_files = $(patsubst ${stage}/%,%,${staged_files})

# The context reconciler runs before stage realizes its outputs. It replaces a
# real private file only when the renderer or its expanded flags change. That
# file is a normal prerequisite of every ordinary template, bridging values
# which Make cannot otherwise see into its timestamp graph.
m4_context := ${stage}/.build/m4-context

.PHONY: update-m4-context
update-m4-context: check-stage-tools
	$(if $(strip ${SKIP}),:,\
	  $(if $(strip ${m4_sources}),${PROTOCOL_BIN}/m4-context '${m4_context}',:))

${m4_context}: update-m4-context ;

${stage}/%: ${src}/%.m4 ${m4_context}
	M4='${M4}' ${PROTOCOL_BIN}/gen '$@' '$<' ${M4FLAGS} ${m4_defines}

${stage}/%: ${src}/%
	mkdir -p '$(@D)'
	cp -p '$<' '$@'

define stage_directory
$1:
	mkdir -p '$$@'
endef

$(foreach d,${staged_dirs},$(eval $(call stage_directory,$d)))

# Pruning precedes every public staged path. The order-only edge keeps prune's
# phony status from making otherwise-current outputs rebuild.
.PHONY: prune
prune: check-stage-tools
	${PROTOCOL_BIN}/prune '${stage}' ${staged}

stage_targets = $(if $(strip ${SKIP}),,${staged})

ifneq ($(strip ${staged}),)
${staged}: | prune
endif

.PHONY: stage #> Prune and incrementally realize the complete staged manifest
stage: prune $${stage_targets}

# Namespace mapping -----------------------------------------------------------

namespaces := config data state cache bin

# Vendored trees can be large. A single find per namespace avoids expanding a
# recursive Make wildcard expression for every directory. As elsewhere in the
# protocol, declaration paths containing whitespace are unsupported.
vendor_sources = $(filter-out ${source_excludes},\
  $(foreach n,${namespaces},$(shell \
    if [ -d '${vendor}/$n' ]; then \
      find '${vendor}/$n' -name '.*' -prune -o \
        \( -type f -o -type l \) -print; \
    fi)))
vendor_files = $(patsubst ${vendor}/%,%,${vendor_sources})

# The effective manifest is generated first-party output plus mapped vendored
# payload. vendor/build and all other unmapped vendor paths are build inputs.
files = ${stage_files} ${vendor_files}

config_root = ${XDG_CONFIG_HOME}
data_root   = ${XDG_DATA_HOME}
state_root  = ${XDG_STATE_HOME}
cache_root  = ${XDG_CACHE_HOME}
bin_root    = ${BIN_DIR}

namespace_of = $(firstword $(subst /, ,$1))
relative_of  = $(patsubst $(call namespace_of,$1)/%,%,$1)
root_of      = $($(call namespace_of,$1)_root)
installed_of = $(call root_of,$1)/$(call relative_of,$1)

claimed_files = $(patsubst ${stage}/%,%,${claimed_outputs})
source_of   = $(firstword $(wildcard ${src}/$1 ${src}/$1.m4))
manifest_of = $(if $(filter $1,${vendor_files}),${vendor}/$1,${stage}/$1)
declared_by = $(if $(filter $1,${vendor_files}),${vendor}/$1,$(if $(filter $1,${claimed_files}),${stage}/$1,$(call source_of,$1)))
mode_of     = $(if $(shell test -x '$(call declared_by,$1)' && echo x),0700,0600)

# A link names its manifest path. link_of adapts that path to the legacy place
# the application insists on; concerns override it when the default
# ~/.<basename> convention does not fit.
link_of = ${HOME}/.$(notdir $1)

# Transfer --------------------------------------------------------------------

# Content and permissions are authoritative; timestamps are not. This chmod
# removes group/world access without changing the source's owner-executable bit.
rsync_flags := \
  --recursive --checksum --perms --itemize-changes --mkpath \
  --chmod=u+rw,go-rwx

define transfer_stage
$(foreach n,${namespaces},\
  $(if $(wildcard ${stage}/$n/.),\
    "${RSYNC}" ${rsync_flags} $1 --exclude='.*' \
      '${stage}/$n/' '${DESTDIR}$(${n}_root)/';${nl}))
endef

# Vendored symlinks are dereferenced so the installed manifest remains a set of
# ordinary files with independently comparable content.
define transfer_vendor
$(foreach n,${namespaces},\
  $(if $(wildcard ${vendor}/$n/.),\
    "${RSYNC}" ${rsync_flags} --copy-links $1 --exclude='.*' \
      '${vendor}/$n/' '${DESTDIR}$(${n}_root)/';${nl}))
endef

transfer = $(call transfer_stage,$1) $(call transfer_vendor,$1)

.PHONY: preview #> Stage, then report files install would create or overwrite
preview: stage check-install-tools
	$(if ${SKIP},printf 'skipped: %s\n' '${SKIP}',\
	  $(call transfer,--dry-run))
	$(if ${SKIP},,\
	  $(foreach l,${links},\
	    DRY_RUN=1 ${PROTOCOL_BIN}/ensure-link.sh \
	      '$(call installed_of,$l)' '${DESTDIR}$(call link_of,$l)';${nl}))

.PHONY: install #> Stage and install every declared destination namespace
install: stage check-install-tools
	$(if ${SKIP},printf 'skipped: %s\n' '${SKIP}',\
	  $(call transfer,$(if ${DRY_RUN},--dry-run)))
	$(if ${SKIP},,\
	  $(foreach l,${links},\
	    DRY_RUN='${DRY_RUN}' ${PROTOCOL_BIN}/ensure-link.sh \
	      '$(call installed_of,$l)' '${DESTDIR}$(call link_of,$l)';${nl}))

# Uninstall is deliberately content-conservative. A path belongs to the current
# manifest, but it is removed only while its installed bytes and mode still
# match the corresponding stage or vendor declaration.
.PHONY: before-uninstall remove-installed after-uninstall
before-uninstall: stage

remove-installed: before-uninstall
	$(foreach l,${links},\
	  DRY_RUN='${DRY_RUN}' ${PROTOCOL_BIN}/remove-link.sh \
	    '$(call installed_of,$l)' '${DESTDIR}$(call link_of,$l)';${nl})
	$(foreach f,${files},\
	  source='$(call manifest_of,$f)'; target='${DESTDIR}$(call installed_of,$f)'; \
	  if [ ! -e "$$target" ]; then \
	    printf 'not installed  %s\n' "$$target"; \
	  elif [ -f "$$target" ] && [ ! -L "$$target" ] && \
	       cmp -s "$$source" "$$target" && \
	       { if [ -x "$$source" ]; then [ -x "$$target" ]; \
	         else [ ! -x "$$target" ]; fi; }; then \
	    $(if ${DRY_RUN},\
	      printf 'would remove %s\n' "$$target",\
	      rm -f "$$target" && printf 'removed %s\n' "$$target"); \
	  else \
	    printf 'left modified  %s\n' "$$target"; \
	  fi;${nl})

after-uninstall: remove-installed

.PHONY: uninstall #> Remove links still ours and files still identical to manifest
uninstall: after-uninstall

# Interface -------------------------------------------------------------------

.PHONY: help #> Show this help message
help:
	${PROTOCOL_BIN}/help ${MAKEFILE_LIST}

.PHONY: show #> Show resolved variables and manifest paths
show:
	printf 'Environment:\n'
	$(foreach v,HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR BIN_DIR,\
	  printf '  %-20s %s\n' '$v' '${$v}';${nl})
	printf '  %-20s %s\n' 'DESTDIR' '${DESTDIR}'
	$(foreach v,${show_vars},\
	  printf '  %-20s %s\n' '$v' '${$v}';${nl})
	$(foreach v,${tools},\
	  printf '  %-20s %s\n' '$v' '$(if ${$v},${$v},(MISSING))';${nl})
	$(foreach v,${required_inputs},\
	  printf '  %-20s %s\n' '$v' '${$v}';${nl})
	$(if ${SKIP},printf '\nSKIPPED: %s\n' '${SKIP}')
	printf '\nManifest:\n'
	$(foreach f,${files},\
	  printf '  file  %-6s %s\n' '$(call mode_of,$f)' '$(call installed_of,$f)';${nl})
	$(foreach l,${links},\
	  printf '  link         %s -> %s\n' '$(call link_of,$l)' \
	    '$(call installed_of,$l)';${nl})

.PHONY: check #> Stage and run concern-defined checks
check: stage
	$(if ${SKIP},printf 'skipped: %s\n' '${SKIP}')

.PHONY: sync #> Synchronize optional runtime or network state
sync: check-sync-tools

.PHONY: clean #> Remove the staging directory
clean:
	rm -rf '${stage}'
