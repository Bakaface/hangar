# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Hangar

Tmux session & project manager. Ruby gem (`hangar-cli`), binary is `hangar`.

## Tech Stack

- Ruby (>= 3.1.0), stdlib only — zero gem dependencies
- Bash for tmux session scripts (`lib.sh` bundled with gem + `.hangar.sh` per project)
- fzf as runtime dependency for interactive selection

## Project Layout

- `bin/hangar` — CLI entry point (`require_relative "../lib/hangar"; Hangar::CLI.run(ARGV)`)
- `lib/hangar.rb` — top-level requires
- `lib/hangar/` — Ruby modules: `cli`, `config`, `project`, `session`, `marks`, `bindings`, `template`, `hooks`, `version`
- `share/hangar/lib.sh` — Bash session library bundled with the gem
- `share/hangar/templates/` — Built-in templates (`basic.sh`, `dev.sh`)
- `.claude-plugin/plugin.json` + `skills/hangar-configurer/` — Claude Code plugin shipped from this repo

## Architecture

- CLI routing in `cli.rb` dispatches commands (and short aliases like `o`, `sw`, `mv`) to module methods. Everything is `module` + `self.` methods — no classes, no instances.
- **Session wrapper flow** (`Session.generate_wrapper`): hangar writes a temp bash script to `$TMPDIR` that exports `$session`, `$path`, `$repo`, sources `share/hangar/lib.sh`, optionally sources `~/.config/hangar/helpers.sh`, `cd`s into the project, then sources the project's `.hangar.sh`. `bash <script>` is invoked, and when already inside tmux, hangar follows up with `tmux switch-client -t <session>`.
- **`shortcut "xx"` is a runtime no-op** declared in `lib.sh`. Its real purpose is to be statically parsed by `Bindings.collect_shortcuts` (regex on `.hangar.sh` files) so tmux keybindings can be generated without executing user scripts.
- **Keybindings** use tmux key-tables for multi-key sequences: typing `g` → `goto`, `d` → `goto-d`, `o` → switches to session. Both shortcuts and marks bind under the same `goto` key-table; marks override shortcuts (rebound later in `build_keybindings`). After any mutation that affects shortcuts/marks (open, edit, mark set, rename, up), hangar calls `Bindings.generate(bind: true)` so the new bindings activate without manual reload.
- **Auto-registration**: `hangar open` (no args) treats cwd as a project if it has `.hangar.sh`, and auto-adds it to the registry on first open.
- **Storage** (XDG-aware via `Config`):
  - Registry: `$XDG_DATA_HOME/hangar/projects` — newline-delimited, each line is `path` or `path\talias` (tab-separated). Session name = alias or `File.basename(path)`, with `.` and `:` translated to `_`.
  - Marks: `$XDG_DATA_HOME/hangar/marks` — `keys=session` lines.
  - User templates: `$XDG_DATA_HOME/hangar/templates/<name>.sh` (override builtins).
  - Optional helpers: `$XDG_CONFIG_HOME/hangar/helpers.sh` (sourced into every session wrapper).
  - Settings: `$XDG_CONFIG_HOME/hangar/config.yml` — supports `default_template` and `startup` (list of project queries for `hangar up`).
  - Hooks: `$XDG_CONFIG_HOME/hangar/<hook>.sh` — `before-init`, `after-init`, `after-kill`, `after-up`. Each is run via `bash` (not sourced) with hook-specific env vars: `HANGAR_TEMPLATE` for init hooks, `HANGAR_SESSION` for `after-kill`, `HANGAR_STARTED` + `HANGAR_ALREADY_RUNNING` (space-separated) for `after-up`. A non-zero exit aborts the command and propagates the exit code, so `before-init` can veto. Missing hook files are silent no-ops.

## Commands

```
hangar open|kill|list|sessions|switch|add|remove|rename|init|bootstrap|edit|mark|generate-bindings|templates|template|up
```

Short aliases live in `CLI::ALIASES` (`o`, `k`, `l`/`ls`, `s`/`ss`, `sw`, `a`, `rm`, `mv`, `i`/`ip`, `b`, `e`, `m`, `gb`, `ts`, `t`, `u`). `bootstrap` chains `init` + `add` + `Session.start` (detached, no attach/switch) and refreshes bindings.

## Development

`mise.toml` defines the canonical tasks:

- `mise run` (`mise r`) — run `bin/hangar` from the checkout
- `mise console` (`mise c`) — `irb -Ilib -rhangar`
- `mise build` (`mise b`) — `gem build hangar-cli.gemspec`
- `mise install` (`mise i`) — build + `gem install` the resulting `.gem`
- `mise release` (`mise rel`) — build + `gem push` to RubyGems
- `mise clean` (`mise cl`) — delete built `.gem` files

## Verification

After making changes, run the smoke test to catch syntax/require errors:

```
ruby -e "require_relative 'lib/hangar'; puts 'OK'"
```

There is no test suite; rely on the smoke test and exercising commands via `mise r <command>`.

## Conventions

- `shortcut "xx"` in `.hangar.sh` replaces the old `switch_shortcut` from legacy `~/.ts/` scripts.
- Templates: user templates in `$XDG_DATA_HOME/hangar/templates/` override builtins of the same name.
- fzf is used whenever interactive selection is needed (project picker, session kill, switch).
- When adding a command, register it in both `CLI::COMMANDS` and the `print_usage` heredoc, and add an alias to `CLI::ALIASES` if appropriate.
