# Hangar

A tmux session & project manager. Declare each project's layout in a single file and switch between them with mnemonic shortcuts you define yourself.

[![RubyGems](https://img.shields.io/badge/gem-hangar--cli-red.svg)](https://rubygems.org/gems/hangar-cli)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1-blue.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](#license)

---

## Overview

Hangar treats every project on your machine as a named tmux session with a declarative layout. You drop a tiny `.hangar.sh` in the project root, register it once, and from then on:

- `hangar open <name>` — attach the session, or build it from scratch if it isn't running yet.
- A mnemonic shortcut you pick yourself — `ap` for `api`, `we` for `web`, `hg` for hangar itself, or a single `s` if you want — lives in the project's `.hangar.sh` and jumps you straight to that session from anywhere in tmux. No fzf picker, no hunting through a session list — you type the keystrokes that *mean* the project to you.
- `hangar mark set <keys>` — pin a running session under a key chord that overrides shortcuts. Marks are runtime; shortcuts are declarative.
- `hangar up` — fire up everything in your `startup:` list in one go.

Zero gem dependencies (Ruby stdlib only). Bash + tmux + fzf at runtime.

---

## Why

Tmux sessions are the right unit of "project I'm working on" — they remember panes, scroll buffers, REPLs, server processes — but tmux itself has no opinion about which sessions you keep around or how they're laid out. You end up either babying `tmux new-session` invocations by hand, or growing a folder of bespoke shell scripts that drift apart.

Hangar is what fell out of years of doing the latter. It's a thin layer:

- The session script lives **next to the project**, not in a central `~/scripts/` graveyard.
- The CLI is small and stateless — registry on disk, no daemon.
- Shortcuts are tmux key-tables, so jumping between sessions is one chord, not a fuzzy picker.

If you already love tmux and just want a way to declare "this project is called `api`, lives at `~/code/api`, and opens nvim plus a server window," you'll feel at home.

---

## Installation

```bash
gem install hangar-cli
```

Or build from a local checkout:

```bash
git clone https://github.com/Bakaface/hangar
cd hangar
mise install   # alias: mise i — builds the gem and installs it
```

Runtime requirements:

- **Ruby** ≥ 3.1
- **tmux** (any modern version)
- **bash** (the per-project scripts are bash, not POSIX sh)
- **fzf** for the interactive pickers

Most people add a short alias:

```bash
alias hg=hangar
```

And add `.hangar.sh` to their **global** gitignore so per-machine session scripts don't leak into project repos:

```bash
echo '.hangar.sh' >> ~/.config/git/ignore
```

---

## Quick start

A five-minute tour. Assume you have a project at `~/code/api`.

**1. Drop a `.hangar.sh` in the project:**

```bash
cd ~/code/api
hangar init       # creates .hangar.sh from the 'basic' template
```

It looks like this:

```bash
# shortcut "xx"

init_basic
```

**2. Pick a shortcut and (optionally) tweak the layout:**

```bash
shortcut "ap"     # press `ap` inside the goto key-table to jump here

init_basic         # window 0 → nvim, window 9 → bash
new 2 'server'     # add a third window named 'server'
send 'bin/dev'     # type `bin/dev` + Enter into it
```

**3. Register the project and open it:**

```bash
hangar add        # registers $(pwd); session name = basename, here "api"
hangar open api   # builds the session and attaches
```

Inside tmux, your shortcut is live: enter the goto key-table (see [Tmux integration](#tmux-integration)) and type `ap`.

**4. Add more projects.** Repeat steps 1–3, give each a unique shortcut (any length — 1, 2, or more characters), and you have a switchable workspace per project.

---

## Concept model

Three things are worth understanding up front.

### The session wrapper

`hangar open` doesn't run your `.hangar.sh` directly. It writes a small bash wrapper to `$TMPDIR`, sources hangar's library, sources your optional helpers, `cd`s into the project, and *then* sources `.hangar.sh`. Because of this:

- `$session`, `$path`, and `$repo` are available inside `.hangar.sh`.
- Helpers like `init`, `new`, `send`, `vsplit`, `init_basic`, `init_vim`, `init_gitui` come from `share/hangar/lib.sh` and are already in scope.
- You can define cross-project helpers in `~/.config/hangar/helpers.sh` and call them from any `.hangar.sh`.

### Shortcuts vs marks

Both live under the same tmux key-table (`goto`). The difference is who writes them:

| | Shortcuts | Marks |
|---|---|---|
| Declared in | `.hangar.sh` (`shortcut "xx"`) | Runtime, via `hangar mark set` |
| Persisted in | The project repo (well, your machine's copy) | `~/.local/share/hangar/marks` |
| Best for | "This is `api`'s key, forever" | "Pin this scratch session under `q`" |
| Wins on conflict | Loses to marks | Overrides shortcuts |

After any mutation (`open`, `edit`, `mark set`, `rename`, `up`) hangar calls `tmux bind-key …` for you so new bindings activate without a reload.

The `shortcut "xx"` line is a runtime no-op — `lib.sh` defines it as an empty function. Its real purpose is to be parsed by hangar's bindings generator (a regex over your registered `.hangar.sh` files). That's why you can change the shortcut without re-running the script.

### Where state lives

Hangar follows the XDG base directory spec.

| Path | What |
|---|---|
| `$XDG_DATA_HOME/hangar/projects` | Registry: one line per project, optional `\t<alias>` |
| `$XDG_DATA_HOME/hangar/marks` | `<keys>=<session>` lines |
| `$XDG_DATA_HOME/hangar/templates/` | User templates (override builtins of same name) |
| `$XDG_CONFIG_HOME/hangar/config.yml` | `default_template`, `startup` list |
| `$XDG_CONFIG_HOME/hangar/helpers.sh` | Cross-project bash helpers |
| `$XDG_CONFIG_HOME/hangar/<hook>.sh` | Lifecycle hooks (`before-init`, `after-init`, `after-kill`, `after-up`) |
| `<project>/.hangar.sh` | Per-project session script |

Defaults: `$XDG_DATA_HOME` is `~/.local/share`, `$XDG_CONFIG_HOME` is `~/.config`.

---

## Commands

```
hangar <command> [args]
```

Aliases are listed in parentheses. `hg=hangar` is the usual shell alias.

| Command | Effect |
|---|---|
| `open` (`o`) `[query]` | Open or attach a session. Auto-registers cwd if it has `.hangar.sh`. |
| `kill` (`k`) `[query]` | Kill a running session. No query → fzf picker. |
| `list` (`l`, `ls`) | List registered projects with running status. |
| `sessions` (`s`, `ss`) | List running tmux sessions. |
| `switch` (`sw`) | Fuzzy-pick a running session to switch to. |
| `add` (`a`) `[path] [--as name]` | Register a project. Defaults to cwd. |
| `remove` (`rm`) `[query]` | Unregister a project. |
| `rename` (`mv`) `<query> <name>` | Change a project's alias. Empty name clears it. |
| `init` (`i`, `ip`) `[template]` | Create `.hangar.sh` from a template. |
| `bootstrap` (`b`) `[template]` | `init` + `add` + start session detached (no attach/switch). |
| `edit` (`e`) `[query]` | `$EDITOR` on a project's `.hangar.sh`; refreshes bindings. |
| `mark` (`m`) `set/get/goto/list` | Manage marks (see [Marks](#marks)). |
| `generate-bindings` (`gb`) `[--bind]` | Print or apply tmux keybindings for shortcuts + marks. |
| `templates` (`ts`) | List available templates. |
| `template` (`t`) `new/edit <name>` | Create or edit a user template. |
| `up` (`u`) | Start every project in `config.yml`'s `startup:`. |

`query` is resolved as alias → exact session name → substring match. If multiple match, fzf picks; if zero match, hangar exits with an error. With no query at all, `open` treats the current directory as a project if it has `.hangar.sh`, otherwise opens fzf over the registry.

Run `hangar help` for the inline reference.

---

## `.hangar.sh` recipes

Everything below assumes you're inside `.hangar.sh`, sourced by hangar's wrapper, with `$session`, `$path`, `$repo` already exported.

### Minimal

```bash
shortcut "ap"

init_basic
```

`init_basic` = `init` + `init_vim` + a `bash` window. Opens nvim on the project root and a shell.

### Multi-window dev layout

```bash
shortcut "we"

init_basic
new 1 'claude'
send 'claude'
new 2 'server'
send 'bin/dev'
new 8 'gitui'
send 'gitui'
select_window 1
```

### Use a shared helper

In `~/.config/hangar/helpers.sh`:

```bash
init_dev() {
  init_basic
  new 1 'claude'  ; send 'claude'
  new 2 'server'  ; send 'bin/dev'
  new 8 'gitui'   ; send 'gitui'
  select_window 1
}
```

In any `.hangar.sh`:

```bash
shortcut "we"

init_dev
```

### A `before` hook

Define a function called `before` in `.hangar.sh` and `init_vim` will run it just before `nvim` launches — handy for setting env vars or warming caches:

```bash
shortcut "we"

before() {
  export RAILS_ENV=development
}

init_basic
```

### Layout helpers available

All defined in `share/hangar/lib.sh`:

| Function | Effect |
|---|---|
| `init` | Create the tmux session detached at `$path`. Errors if already running. |
| `init_vim` | Rename window 0 → `vim`, run `nvim $(pwd)`. Calls `before` if defined. |
| `init_gitui` | Window 8 named `gitui`, runs `gitui`. |
| `init_basic` | `init` + `init_vim` + window 9 named `bash`. |
| `init_project` | `init_vim` + `init_gitui` only (call `init` yourself first). |
| `new <idx> <name>` | New window at index, named, in `$path`. Calls `before` if defined. |
| `rename <idx> <name>` | Rename window. |
| `send '<cmd>'` | Send keys + Enter to the current window. |
| `select_window <idx>` | Focus a window. |
| `vsplit` / `hsplit` | Split current pane vertically / horizontally in `$path`. |

---

## Tmux integration

Hangar generates `tmux bind-key …` invocations from your shortcuts and marks, but it doesn't touch your `~/.tmux.conf`. You wire up the bindings yourself. A typical block:

```tmux
# Apply hangar shortcuts + marks on tmux start/reload
run-shell 'hangar generate-bindings --bind'

# Enter the goto key-table — chord then type the shortcut
bind G switch-client -T goto

# Set a mark on the current session
bind m command-prompt -p "mark:" "run-shell 'hangar mark set %%'"

# Goto-mark popup (live as you type)
bind "'" display-popup -E -w 30 -h 12 "hangar mark goto"

# Fuzzy session switcher
bind g display-popup -E "hangar switch"

# Show the current session's mark in status-right
set -g status-right '#(m=$(hangar mark get 2>/dev/null); [ -n "$m" ] && echo "#[fg=#665c54][$m] ")'
```

With this, the typical flow inside tmux is:

- `<prefix> G ap` — jump to project `ap` (declared in `.hangar.sh`).
- `<prefix> '` — open the goto-mark popup, type your mark chord.
- `<prefix> g` — fuzzy session picker.
- `<prefix> m` — bind a mark to the current session.

---

## Configuration

### `~/.config/hangar/config.yml`

```yaml
default_template: basic   # used by `hangar init` with no arg
startup:                  # used by `hangar up`
  - dotfiles
  - api
  - <alias-or-basename>
```

Each `startup:` entry is passed to the same resolver as `hangar open`.

### `~/.config/hangar/helpers.sh`

Sourced into every session wrapper before `.hangar.sh`. Use it for shared `init_*` recipes so individual `.hangar.sh` files stay one-liners. Helpers can call anything in `lib.sh` and read `$session`, `$path`, `$repo`.

### Hooks

Drop an executable-free `<hook>.sh` in `~/.config/hangar/` and hangar runs it (via `bash`, not sourced) at the matching point in a command's lifecycle. Missing hook files are silent no-ops.

| Hook | Fires | Env passed |
|---|---|---|
| `before-init` | Before `init`/`bootstrap` writes `.hangar.sh` | `HANGAR_TEMPLATE` |
| `after-init` | After `.hangar.sh` is created | `HANGAR_TEMPLATE` |
| `after-kill` | After a session is killed | `HANGAR_SESSION` |
| `after-up` | After `up` finishes | `HANGAR_STARTED`, `HANGAR_ALREADY_RUNNING` (space-separated session lists) |

A non-zero exit aborts the command and propagates the exit code, so `before-init` can **veto** an init. Example `~/.config/hangar/after-up.sh`:

```bash
#!/usr/bin/env bash
[ -n "$HANGAR_STARTED" ] && notify-send "hangar: started $HANGAR_STARTED"
```

### Refresh checklist

After changing things, what to re-run:

| Change | Refresh |
|---|---|
| `.hangar.sh` shortcut line | `hangar generate-bindings --bind` (or use `hangar edit`/`open` inside tmux) |
| `.hangar.sh` layout (windows/sends) | `hangar kill <q> && hangar open <q>` |
| `helpers.sh` | Same — kill + reopen affected sessions |
| `config.yml: default_template` | Takes effect on next `hangar init` |
| `config.yml: startup` | Takes effect on next `hangar up` |
| Marks file edited directly | `hangar generate-bindings --bind` |
| New or edited template | Takes effect on next `hangar init <name>` |

---

## Templates

Templates are bash files copied verbatim by `hangar init`. Two ship in the box:

- `basic` — `init_basic` only.
- `dev` — `init_basic` + a couple of pre-created windows.

User templates live in `$XDG_DATA_HOME/hangar/templates/<name>.sh` and override builtins of the same name.

```bash
hangar templates                 # list builtins + user templates
hangar template new my-stack     # create + open in $EDITOR
hangar template edit basic       # edit user copy (copies builtin if missing)
```

A template should have the same shape as a `.hangar.sh`: a commented `shortcut` placeholder and an `init_*` call.

---

## Marks

Marks are runtime — they bind a multi-key sequence to a *currently running* session and live in `~/.local/share/hangar/marks`. They're ideal for "I'm going to be flipping between these three sessions for the next hour."

```bash
hangar mark set qq        # bind 'qq' → current session
hangar mark get [session] # print mark for a session
hangar mark goto          # interactive picker (intended for a tmux popup)
hangar mark list          # list all
```

Editing the marks file by hand is fine; the format is `<keys>=<session>` per line. After hand-editing, run `hangar generate-bindings --bind` to apply.

Marks override shortcuts inside the same `goto` key-table — useful if you want to temporarily redirect a familiar chord.

---

## Development

This repo is pure stdlib Ruby + bash. The canonical tasks are in `mise.toml`:

```bash
mise run        # mise r  — run bin/hangar from the checkout
mise console    # mise c  — irb -Ilib -rhangar
mise build      # mise b  — gem build hangar-cli.gemspec
mise install    # mise i  — build + gem install the resulting .gem
mise release    # mise rel — build + gem push to RubyGems
mise clean      # mise cl — delete built .gem files
```

There's no test suite. The smoke check is:

```bash
ruby -e "require_relative 'lib/hangar'; puts 'OK'"
```

…plus exercising the affected commands via `mise r <command>`.

### Project layout

```
bin/hangar                       # 4-line entry point
lib/hangar.rb                    # top-level requires
lib/hangar/cli.rb                # command dispatch + usage
lib/hangar/{session,project,marks,bindings,template,config,hooks}.rb
share/hangar/lib.sh              # bash helpers sourced into every session
share/hangar/templates/*.sh      # builtin templates
.claude-plugin/                  # Claude Code plugin manifest
skills/hangar-configurer/        # Claude Code skill shipped with the gem
```

Everything is `module X; def self.…` — no classes, no instances. The CLI is a flat lookup table from command name to a `cmd_*` method.

---

## Claude Code plugin

This repo also ships a Claude Code skill at `skills/hangar-configurer/` plus a `.claude-plugin/plugin.json` manifest. If you use Claude Code, the skill knows the file layout, the refresh rules, and the common configuration tasks — handy when wiring hangar into a new machine.

---

## License

MIT. See the `LICENSE` file if present, or [`hangar-cli.gemspec`](./hangar-cli.gemspec).
