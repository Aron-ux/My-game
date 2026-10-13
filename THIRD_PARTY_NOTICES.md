# Third-Party Notices and Asset Status

This file tracks bundled assets/plugins and their release readiness.

## Godot MCP addon

- Path: `addons/godot_mcp/`
- Purpose: editor/MCP tooling for local development.
- Release note: verify whether this addon should be included in exported builds. If not needed at runtime, disable/remove it for release builds.

## Placeholder audio

Current files:

- `assets/game_bgm.mp3`
- `assets/game_bgm.ogg`
- `assets/menu_bgm.mp3`
- `assets/menu_bgm.ogg`

Status: development placeholder / non-commercial testing material unless explicit license evidence is added later.

Release requirement: replace or document license before public/commercial distribution.

## Prototype images/sketches

Current paths include:

- `assets/demo2.png`
- `assets/sketch/`
- `effects/`
- `enemies/`

Status: prototype material. Verify source and usage rights before public/commercial distribution.

## Mechanic artwork (2026-10-13)

- Runtime paths: `assets/players/mechanic/`, the two mechanic portraits in `assets/UI/facility/`, and the eight active sequences listed in `docs/07_资源_美术_特效规范.md` under `effects/mechanic/`.
- Source: newly generated with the built-in `image_gen` tool, then registered and exported through Aseprite. Original outputs, prompts and the reproducible import instructions are in `design/mechanic-rework-20261013/`.
- Character reference requested by the user: Maria Custard from Rance, using [AliceSoft's official Rance IX character page](https://www.alicesoft.com/rance9/character/outlaw.html). The official reference image itself is not bundled in the runtime assets; the generated design remains visibly reference-derived and is not recorded as an independently cleared character design.

## Ruan Dog pixel sprite

- Path: `assets/camp/ruan_dog_husky.png`
- Source: [Husky Sprites](https://opengameart.org/content/husky-sprites) by Hellkipz, based on work by Shepardskin.
- License: CC0 1.0 Universal.
- Usage: the original PNG is bundled unchanged; `scenes/endless_camp.tscn` selects one sitting-idle frame with `AtlasTexture` for the camp sprite and dialogue portrait.
