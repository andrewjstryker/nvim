PROTOCOL_MK ?= ../../../protocol/protocol.mk

CONTEXT_INPUT ?= required-context
required_inputs := CONTEXT_INPUT
claimed_sources = ${src}/config/claimed.upper
claimed_outputs = ${stage}/config/claimed

include ${PROTOCOL_MK}

FIXTURE_VALUE ?= rendered
m4_vars += FIXTURE_VALUE
links := config/static.conf

OPTIONAL_CONTEXT ?= optional-context
m4_vars += OPTIONAL_CONTEXT

STAGE_TOOL   ?= /bin/true
INSTALL_TOOL ?= /bin/true
SYNC_TOOL    ?= /bin/true
TRANSFORM_TOOL ?= $(shell command -v tr)

stage_tools   += STAGE_TOOL TRANSFORM_TOOL
install_tools += INSTALL_TOOL
sync_tools    += SYNC_TOOL

${stage}/config/claimed: ${src}/config/claimed.upper
	mkdir -p '$(@D)'
	'${TRANSFORM_TOOL}' '[:lower:]' '[:upper:]' < '$<' > '$@'
	chmod --reference='$<' '$@'

.PHONY: check-required-export
check-required-export:
	test "$$CONTEXT_INPUT" = '${CONTEXT_INPUT}'
