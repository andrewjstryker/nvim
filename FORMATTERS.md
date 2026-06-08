# Installing formatters

Formatters are **optional dependencies**.  The build system detects whichever
are present on PATH (or, for `styler`, available via R) at `make sync` time,
and generates `plugins/formatting.lua` accordingly.  A filetype with no
available formatter falls through to LSP formatting via conform's
`lsp_fallback`.

After installing a new formatter, re-run `make sync` so the build re-probes
and re-stamps the resolved command paths into the generated config.

---

## Supported formatters

| Formatter       | Filetypes              | Discovery                             |
| --------------- | ---------------------- | ------------------------------------- |
| `prettier`      | markdown, json, yaml   | `command -v prettier`                 |
| `stylua`        | lua                    | `command -v stylua`                   |
| `ruff`          | python (+ LSP)         | `command -v ruff`                     |
| `black`         | python                 | `command -v black`                    |
| `sql_formatter` | sql                    | `command -v sql_formatter`            |
| `styler`        | r                      | `R` on PATH + styler package in R     |

For Python, `ruff` and `black` can both be installed; conform will use
`ruff_format` first and fall back to `black` (`stop_after_first = true`).

---

## Install recipes

### ruff (python) — also ships the Python LSP

Astral's standalone installer drops a single binary into `~/.local/bin/`:

```sh
curl -LsSf https://astral.sh/ruff/install.sh | sh
```

Alternatives: `pipx install ruff` or `uv tool install ruff`.

### black (python)

```sh
pipx install black
```

Or via pip: `pip install --user black`.

### prettier (markdown / json / yaml)

Requires Node + npm.  To keep the install user-local instead of writing to
a system-wide npm prefix:

```sh
npm config set prefix ~/.local
npm install -g prettier
```

`~/.local/bin` must be on PATH (the same location black lives at).

### stylua (lua)

Prebuilt binary from GitHub releases:

```sh
curl -L -o /tmp/stylua.zip \
  https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip
unzip -o /tmp/stylua.zip -d ~/.local/bin/
chmod +x ~/.local/bin/stylua
rm /tmp/stylua.zip
```

Or via cargo: `cargo install stylua`.

### sql_formatter (sql)

Via npm:

```sh
npm install -g sql-formatter
```

The package installs as `sql-formatter` but conform (and our discovery)
expects `sql_formatter`.  Symlink or rename:

```sh
ln -s ~/.local/bin/sql-formatter ~/.local/bin/sql_formatter
```

Adjust the source path if your npm prefix is different — `which sql-formatter`
to confirm.

### styler (r)

styler is an R package, not a standalone CLI.  conform invokes it through R.

1. Install R via your system package manager (apt, dnf, nix, pkg).
2. From R, install the styler package:

   ```sh
   Rscript -e 'install.packages("styler", repos="https://cloud.r-project.org")'
   ```

Our detection probes `R` on PATH and verifies the styler package is
available via `requireNamespace`.  Both must succeed.

---

## Verifying after install

Re-probe and check the rendered config:

```sh
make sync
grep command stage/nvim/lua/plugins/formatting.lua
```

You should see one line per installed formatter, with the absolute path
stamped in.  `make show` will also list all discovered formatter paths in
the toolset summary.

In Neovim, open a buffer of the relevant filetype and either save (formats
on save via conform) or run `<leader>cf` to format explicitly.
