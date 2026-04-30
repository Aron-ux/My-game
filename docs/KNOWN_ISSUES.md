# Known Issues

## Documentation and governance

- Some older design docs still use “当前” heavily; verify against code before relying on them as specs.
- `docs/graphify/` is a legacy documentation-only graph snapshot; the active code graph is `graphify-out/`.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/system risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future feature work should avoid adding more unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, build, or mode state.
- Elite reward design is not final.

## Tooling

- Local graphify support for Godot/GDScript currently depends on a local patch to installed `graphifyy`; reinstalling/upgrading graphify may remove that support.
