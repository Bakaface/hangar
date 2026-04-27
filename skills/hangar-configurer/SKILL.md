---
name: hangar-configurer
description: "Use this skill whenever configuring, setting up, or modifying Hangar (the tmux session & project manager). Trigger when the user says 'set up hangar', 'configure hangar', 'add a hangar project', 'register a project with hangar', 'add a hangar shortcut', 'add a startup project', 'edit .hangar.sh', 'add a hangar helper', 'create a hangar template', 'change default hangar template', 'set a hangar mark', 'refresh hangar bindings', or asks about config.yml / helpers.sh / .hangar.sh / project registry / marks / templates / keybindings for hangar — even if they don't explicitly say 'hangar configurer'. Covers global config (`~/.config/hangar/config.yml`), helpers (`~/.config/hangar/helpers.sh`), per-project `.hangar.sh` files, project registry, marks, templates, and refreshing tmux keybindings after changes. Do NOT use for migrating from the legacy ts/tmux-mark setup — use migrate-from-ts instead. Do NOT use for hangar source-code development (Ruby modules in lib/hangar/) — only end-user configuration."
---

# Hangar Configurer

Configure Hangar — a tmux session & project manager (Ruby gem `hangar-cli`, binary `hangar`) — by editing its config files and using its CLI. Use this skill for end-user configuration, not for developing the gem itself.

## File Layout

| Path | Purpose |
|------|---------|
| `~/.config/hangar/config.yml` | Global settings: `default_template`, `startup` list |
| `~/.config/hangar/helpers.sh` | User bash helpers (e.g. `init_dev`); sourced before `.hangar.sh` |
| `~/.local/share/hangar/projects` | Project registry (one path per line, optional `\t<alias>`) |
| `~/.local/share/hangar/marks` | Saved marks (`<keys>=<session>` lines) |
| `~/.local/share/hangar/templates/` | User templates (override builtins of same name) |
| `<project>/.hangar.sh` | Per-project session script: declares `shortcut "xx"` and layout |

`.hangar.sh` is machine-specific — keep it in the user's **global** gitignore (`git config --global core.excludesFile`, fallback `~/.config/git/ignore`), not per-repo.

## CLI Reference

```
hangar open|kill|list|sessions|switch|add|remove|init|edit|mark|bindings|templates|template|up
```

Aliases: `o=open, u=up, k=kill, l/ls=list, s/ss=sessions, sw=switch, a=add, rm=remove, i/ip=init, e=edit, m=mark, b=bindings, ts=templates, t=template`. Users typically alias the binary itself: `alias hg=hangar`.

| Command | Effect |
|---------|--------|
| `hangar init [template]` | Create `.hangar.sh` in cwd from template (default from `config.yml`) |
| `hangar add [path] [--as <alias>]` | Register project (defaults to cwd); requires `.hangar.sh` to exist |
| `hangar remove [query]` | Unregister; query matches alias/basename/path, fzf if ambiguous |
| `hangar list` | Show registered projects + running status |
| `hangar edit [query]` | Open project's `.hangar.sh` in `$EDITOR`; auto-refreshes bindings |
| `hangar open [query]` | Open or attach session; auto-registers + auto-refreshes bindings |
| `hangar up` | Start every project listed in `config.yml`'s `startup:` |
| `hangar sessions` / `switch` | List / fzf-pick a running session |
| `hangar mark set/get/goto/list` | Manage marks (runtime tmux operations) |
| `hangar template new/edit <name>` | Create or edit a user template |
| `hangar templates` | List available template names |
| `hangar bindings [--bind]` | Print or apply tmux keybindings for shortcuts + marks |

## Common Tasks

### Set up Hangar from scratch

1. Install: `gem install hangar-cli` (or build locally: `cd <hangar-repo> && gem build hangar-cli.gemspec && gem install hangar-cli-*.gem`)
2. Add `alias hg=hangar` to the shell rc (`~/.zshrc` or `~/.bashrc`) near other aliases
3. Add `.hangar.sh` to global gitignore (see "File Layout")
4. Create `~/.config/hangar/config.yml`:
   ```yaml
   default_template: basic
   startup: []
   ```
5. (Optional) Create `~/.config/hangar/helpers.sh` for custom `init_*` helpers (see "Add or change a helper")
6. Wire tmux to refresh bindings on reload — add to `~/.tmux.conf`:
   ```tmux
   run-shell 'hangar bindings --bind'
   ```
7. (Optional) Add tmux bindings for marks and the switcher popup (see "Tmux integration" below)

If migrating from the legacy `ts`/`tmux-mark` setup, **use the `migrate-from-ts` skill instead** — it handles converting `~/.ts/*.sh` scripts and rewiring tmux.conf.

### Register a new project

```bash
cd <project>
hangar init [template]   # creates .hangar.sh; template defaults to config.yml's default_template
hangar add               # registers cwd; or `hangar add <path> --as <alias>`
```

Then edit `.hangar.sh` to set the shortcut and layout (next section).

### Edit `.hangar.sh`

Per-project file, sourced inside the session wrapper after `lib.sh` and `helpers.sh`. Available variables: `$session` (session name), `$path` and `$repo` (project dir).

Minimal example:

```bash
shortcut "hg"   # 2-char tmux goto sequence; parsed by `hangar bindings`

init_basic       # builtin: creates session, opens nvim in window 0, bash in window 9
```

Richer example using a user helper:

```bash
shortcut "s"

init_dev         # defined in ~/.config/hangar/helpers.sh

new 1 'bash'
new 2 'server'
send 'bin/dev'
```

**Layout helpers available** (from `share/hangar/lib.sh`):

| Function | Effect |
|---|---|
| `init` | Create the tmux session detached at `$path` (errors if already running) |
| `init_vim` | Rename window 0 → `vim`, run `nvim $(pwd)`. Calls user-defined `before` if present |
| `init_gitui` | Window 8 named `gitui`, runs `gitui` |
| `init_basic` | `init` + `init_vim` + window 9 (`bash`) |
| `init_project` | `init_vim` + `init_gitui` (no `init` — call `init` yourself first) |
| `new <idx> <name>` | New window at index, named, in `$path` |
| `rename <idx> <name>` | Rename window |
| `send '<cmd>'` | Send keys + Enter to current window |
| `select_window <idx>` | Focus a window |
| `vsplit` / `hsplit` | Split current pane vertically / horizontally in `$path` |
| `attach $1` | Attach if arg is `a` (handled automatically by wrapper) |

Define a `before` function in `.hangar.sh` to run code right before `init_vim` opens nvim (e.g., warm caches, set env).

### Add or change a shortcut

Edit the project's `.hangar.sh` and change the `shortcut "xx"` line. Keys can be any length (2 chars typical) and form a tmux key-table chain under the `goto` table — e.g., `shortcut "do"` becomes `goto → goto-d → o`.

After editing, refresh bindings:

```bash
hangar bindings --bind
```

`hangar edit <query>` and `hangar open <query>` auto-refresh when run inside tmux, so manual refresh is only needed if neither was used.

**Conflicts:** marks override shortcuts in the same `goto` table. If a shortcut isn't firing, check `hangar mark list` for a colliding key sequence.

### Edit global `config.yml`

`~/.config/hangar/config.yml`:

```yaml
default_template: dev          # used by `hangar init` when no template arg given
startup:                       # used by `hangar up`
  - dotfiles
  - hangar
  - <alias-or-basename>        # must match a registered project
```

Each `startup` entry is a query passed to the same resolver as `hangar open` (alias > exact session name > substring match).

### Add or change a helper

Helpers live in `~/.config/hangar/helpers.sh` and are sourced before every `.hangar.sh`. Use them to define reusable `init_*` functions referenced from multiple projects.

```bash
init_dev() {
  init_basic
  new 1 'claude'
  send 'claude'
  new 8 'tools'
  send 'lazygit'
  select_window 1
}
```

Helpers can call any function from `lib.sh` (`init`, `new`, `send`, etc.) and read the wrapper variables (`$session`, `$path`, `$repo`).

### Templates

Templates are files copied verbatim by `hangar init`. User templates at `~/.local/share/hangar/templates/<name>.sh` override builtins of the same name.

```bash
hangar template new <name>     # creates and opens in $EDITOR
hangar template edit <name>    # edits user copy (creating from builtin if needed)
hangar templates               # lists builtins + user templates
```

A template should have the same shape as a `.hangar.sh`: a `shortcut` placeholder line (commented) and an `init_*` call.

### Marks (runtime)

Marks bind a multi-key sequence to a running session, persisted at `~/.local/share/hangar/marks`. They're managed via tmux keybindings, not config files:

- `hangar mark set <keys>` — bind keys → current session
- `hangar mark get [session]` — print mark for a session
- `hangar mark goto` — interactive picker (intended for a tmux popup)
- `hangar mark list` — list all

Editing the marks file directly is supported (format `<keys>=<session>`); afterward run `hangar bindings --bind` to apply.

### Tmux integration

A typical `~/.tmux.conf` block for hangar:

```tmux
# Apply hangar shortcuts + marks on tmux start/reload
run-shell 'hangar bindings --bind'

# Set a mark on the current session
bind m command-prompt -p "mark#(m=$(hangar mark get 2>/dev/null); [ -n \"$m\" ] && echo \" [$m]\"):" "run-shell 'hangar mark set %%'"

# Goto-mark popup
bind "'" display-popup -E -w 30 -h 12 "hangar mark goto"

# Fuzzy session switcher
bind g display-popup -E "hangar switch"

# Show current mark in status-right
set -g status-right '#(m=$(hangar mark get 2>/dev/null); [ -n "$m" ] && echo "#[fg=#665c54][$m] ")'
```

The `goto` key-table that holds shortcuts/marks needs a way in. Common pattern (separate from the popup binding above):

```tmux
bind G switch-client -T goto    # prefix G enters the goto table; then type the shortcut keys
```

## Refresh Checklist

After any change, the right refresh action depends on what changed:

| Change | Refresh |
|---|---|
| `.hangar.sh` shortcut | `hangar bindings --bind` (or use `hangar edit`/`open` inside tmux) |
| `.hangar.sh` layout (windows/sends) | Kill + reopen the session: `hangar kill <q> && hangar open <q>` |
| `helpers.sh` | Kill + reopen any session that uses the changed helper |
| `config.yml` `default_template` | Takes effect on next `hangar init` |
| `config.yml` `startup` | Takes effect on next `hangar up` |
| Marks file edited directly | `hangar bindings --bind` |
| New/edited template | Takes effect on next `hangar init <name>` |

## Verification

After non-trivial changes:

```bash
hangar list                  # registry intact, expected aliases shown
hangar bindings              # prints expected tmux commands (no --bind = dry run)
ruby -e "require 'yaml'; YAML.safe_load_file(File.expand_path('~/.config/hangar/config.yml'))"
bash -n ~/.config/hangar/helpers.sh           # syntax-check helpers
bash -n <project>/.hangar.sh                  # syntax-check a project script
```

Inside tmux, test a shortcut by entering the goto key-table and pressing the keys; if nothing happens, `tmux list-keys -T goto` should show the binding.
