# Graphify Workflow

Active graph location:

- `graphify-out/GRAPH_REPORT.md`
- `graphify-out/graph.json`

Legacy documentation-only snapshot:

- `docs/graphify/` was an older graph generated from design docs only. Do not treat it as the active code graph.

## Update command

After code changes, run:

```bash
graphify update .
```

This should rebuild the AST/code graph without API cost.

## Godot/GDScript note

The installed `graphifyy 0.4.18` did not originally recognize Godot files (`.gd`, `.tscn`, `.tres`, `.godot`). The local environment was patched so `graphify update .` can classify and lightly extract GDScript/Godot text assets.

If a future reinstall or upgrade makes graphify print:

```text
No code files found - nothing to rebuild.
```

check whether `.gd` is present in `graphify.detect.CODE_EXTENSIONS` and whether `graphify.extract` has a GDScript extractor/dispatch.

## Noise control

The project root maintains `.graphifyignore` to keep the graph focused on gameplay/runtime code:

- `.godot/`
- `graphify-out/`
- `addons/godot_mcp/`

Without this ignore file, editor MCP tooling can dominate the graph with utility nodes such as `_success()`, `_error()`, and `_find_node_by_path()`, making architecture review less useful.
