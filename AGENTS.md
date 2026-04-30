# Project Agent Instructions

This Godot project uses the repository root as the working directory.

## Required checks before architecture/codebase answers

- Read `graphify-out/GRAPH_REPORT.md` when available.
- Prefer `docs/README_文档索引.md` as the documentation entry point.

## After modifying code

Run:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

Then run:

```bash
graphify update .
```

If graphify reports no Godot code files, check `docs/GRAPHIFY.md`; this project relies on local GDScript support for graphify.

## Documentation sync rule

When changing controls, settings, achievements, save data, UI modes, or release assumptions, update the relevant docs under `docs/` and `CHANGELOG.md`.
