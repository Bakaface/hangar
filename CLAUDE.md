# Hangar

Tmux session & project manager. Ruby gem (`hangar-cli`), binary is `hangar`.

## Tech Stack

- Ruby (>= 3.1.0), stdlib only — zero gem dependencies
- Bash for tmux session scripts (`_lib.sh` + `.hangar.sh` per project)
- fzf as runtime dependency for interactive selection

## Project Layout

- `bin/hangar` — CLI entry point
- `lib/hangar/` — Ruby modules: cli, config, project, session, marks, bindings, template
- `share/hangar/lib.sh` — Bash session library bundled with the gem
- `share/hangar/templates/` — Built-in templates (basic, dev)

## Architecture

- CLI routing in `cli.rb` dispatches to module methods (no classes, all `module` + `self.` methods)
- Session scripts are bash: hangar generates a wrapper that sets vars, sources `_lib.sh`, then sources `.hangar.sh`
- Keybindings use tmux key-tables for multi-key sequences (e.g., `goto` → `goto-d` → `goto-do`)
- Both shortcuts and marks bind under the same `goto` key-table; marks override shortcuts
- Project registry at `~/.local/share/hangar/projects`, marks at `~/.local/share/hangar/marks`

## Commands

```
hangar open|kill|list|sessions|add|remove|init|edit|mark|bindings|templates|template
```

## Conventions

- `shortcut "xx"` in `.hangar.sh` replaces old `switch_shortcut` from `~/.ts/` scripts
- Templates: user templates in `~/.local/share/hangar/templates/` override builtins
- fzf used whenever interactive selection is needed (project picker, session kill)
