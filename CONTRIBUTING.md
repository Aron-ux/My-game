# Contributing

This project is currently a private/early prototype. Contributions should prioritize small, reviewable, reversible changes.

## Development baseline

- Engine: Godot `4.6.2`
- Main scene: `res://scenes/main_menu.tscn`
- Project file: `project.godot`

## Local checks

Run the one-command project check before reporting completion or opening a pull request:

```bash
./scripts/check_project.sh
```

This runs Markdown link checks, achievement JSON checks, project config checks, Godot headless parse, achievement smoke, and graphify update when available.

## Change rules

1. Keep gameplay behavior stable unless the task explicitly changes it.
2. Update docs when changing player-facing systems, save data, settings, achievements, or controls.
3. Do not add new dependencies without a clear reason.
4. Keep generated/cache files out of commits unless the repository already tracks them intentionally.
5. Before reporting completion, run at least:

```bash
godot --headless --path . --quit
```

Use the local binary when needed:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

## Commit style

Use intent-first commit messages. Include useful trailers where appropriate:

```text
Clarify why the change exists

Short context and tradeoffs.

Tested: Godot headless parse
Not-tested: Manual gameplay pass
```
