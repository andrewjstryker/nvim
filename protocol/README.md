# Home concern protocol

This directory is the reusable Make protocol and its private helpers:

```text
protocol.mk
bin/
├── gen
├── help
├── m4-context
├── prune
├── ensure-link.sh
└── remove-link.sh
```

A concern includes it with one overridable path:

```make
required_inputs := EMAIL

PROTOCOL_MK ?= ../protocol/protocol.mk
include ${PROTOCOL_MK}
```

Inputs which extend the protocol contract are declared before the include.
Every `required_inputs` value must be nonempty, is exported to recipes, and is
available to m4 under the same name. Consumers add optional render values with
`m4_vars += NAME` after the include.

Concern values rendered under the same macro name use `m4_vars`. The protocol
adds each value to the ordinary m4 arguments and to the context automatically:

```make
ENV_FILE ?= .env
-include ${ENV_FILE}

m4_vars += ACCOUNT HOST PORT
```

Changing a resolved value updates the context and invalidates ordinary m4
outputs. Changes to comments or formatting in `.env` do not. The protocol also
defines its persistent XDG variables and `BIN_DIR`; `M4FLAGS` is reserved for
renderer behavior such as include paths.

## Model

`src/` declares first-party files and `stage/` realizes them. Every non-hidden
source maps one-to-one to the same relative path under `stage/`; a final `.m4`
suffix is removed after rendering:

```text
src/config/git/config.m4  → stage/config/git/config
src/data/ssh/known_hosts  → stage/data/ssh/known_hosts
src/bin/home-backup.m4    → stage/bin/home-backup
```

Plain files are copied with their executable bit. Templates are rendered to a
temporary file, compared with the existing staged file, replaced only when the
bytes changed, and given the source template's executable bit.

A concern may claim sources which require another transformation and publish
their resulting staged files. Both lists are declared before the include; the
concern then owns the file rules, tools, and executable-bit preservation:

```make
claimed_sources = $(call rwildcard,${src}/config/example/,*.fnl)
claimed_outputs = $(patsubst ${src}/%.fnl,${stage}/%.lua,${claimed_sources})

include ${PROTOCOL_MK}

stage_tools += FENNEL

${stage}/config/example/%.lua: ${src}/config/example/%.fnl ${FENNEL}
	${FENNEL} --compile '$<' > '$@'
	chmod --reference='$<' '$@'
```

Claimed sources are removed from the identity/m4 partition. Claimed outputs
enter the same stage, prune, install, and uninstall manifest as ordinary
outputs. The protocol does not interpret the transformation.

`vendor/` declares pinned third-party files that are already installation
ready. Its mapped namespace directories participate directly in the manifest:

```text
vendor/data/zsh/oh-my-zsh → XDG_DATA_HOME/zsh/oh-my-zsh
vendor/state/tmux/plugins/tpm → XDG_STATE_HOME/tmux/plugins/tpm
```

They are not copied into `stage`. Unmapped paths such as `vendor/build/` are
build inputs, not installed payload. A concern must not declare the same
destination through both `stage` and `vendor`.

Any directory component beginning with `.` makes a staged path private. A
concern may put dependency stamps and intermediate files there, but those paths
are ignored by manifest discovery, pruning, installation, and uninstallation.
Every public output is derived either by the ordinary mapping or declared in
`claimed_outputs`.

The destination namespaces are:

| Manifest directory | Destination |
| --- | --- |
| `config/` | `XDG_CONFIG_HOME` |
| `data/` | `XDG_DATA_HOME` |
| `state/` | `XDG_STATE_HOME` |
| `cache/` | `XDG_CACHE_HOME` |
| `bin/` | `BIN_DIR` |

Each destination root uses the conventional `?=` default derived from `HOME`.
An explicitly supplied empty value is invalid rather than silently replaced;
the protocol reports the variable before evaluating lifecycle targets.

`stage` incrementally realizes the current declaration in one Make graph. Every
public staged path has an order-only dependency on pruning, so obsolete outputs
are removed before any transformation runs without making current outputs
rebuild. `clean` removes the complete staged tree.

Tools are declared by lifecycle phase. Lists contain the names of variables
which resolve to tool paths; wrappers extend `stage_tools`, `install_tools`, or
`sync_tools` according to when each tool is first required. `stage` checks its
tools before pruning, installation checks its tools before transfer, and
`sync` checks its tools before running concern-specific recipes. `check-tools`
checks all three lists without performing a lifecycle operation. The protocol
supplies `M4` for concerns with templates and `RSYNC` for installation.

Before realizing staged files, a phony reconciliation target records `M4`,
`M4FLAGS`, `HOME`, and every render variable in `stage/.build/m4-context`.
Render variables are the protocol context—the persistent XDG roots, `BIN_DIR`,
and every `required_inputs` value—plus the concern-level `m4_vars`. Each is
defined in m4 under the same name. The real context file is
replaced only when those values change and is a normal prerequisite of every
ordinary m4 output. Plain files and templates otherwise follow Make's timestamp
graph; concern-specific file inputs must be named as normal prerequisites.
Mode-only source changes are not visible to Make and require touching the source
or cleaning the stage.

The effective manifest is the union of `stage` and the mapped namespaces under
`vendor`. `preview` stages first and invokes the installation rsync commands with
`--dry-run`. `install` invokes the same commands without that flag. `uninstall`
removes only installed regular files whose bytes and executable status still
match the corresponding current manifest file; locally modified files are reported and
left in place.

`sync` depends only on its declared tools and any work a concern attaches to
that target. It assumes installation has already occurred. Install-then-sync
composition belongs to the collection driver, whose `apply` command installs
every selected concern before synchronizing any of them.

Environment fragments are ordinary configuration at
`src/config/env.d/*.sh[.m4]` or `vendor/config/env.d/*.sh`. The collection
driver reads them from the effective manifests for composition; staging and
installation give them no special treatment.

Run `tests/staging.sh` to exercise copying, rendering, mode propagation,
pruning, namespace transfers, preview, and conservative uninstall.
