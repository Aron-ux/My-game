# Roadmap

This roadmap tracks project direction, not a promise of release dates.

## Now: stabilize prototype foundation

- Keep the current survivor-like combat loop playable.
- Stabilize save/load and continue-game behavior.
- Validate the current 36 single-tier skill talents, which are candidates for the first tier of the planned system, especially transformed follow-up upgrades, visual readability, and branch balance.
- Extend the character panel from total skill-build level to the exact acquired build cards and stack counts.
- Identify the Boss referenced by the meeting, then measure its difficulty and high-tier blessing timing before changing values.
- Keep dense-combat and autosave optimization evidence-driven through the existing benchmark, evaluator, trace, and feature-flag paths.

## Next: three-tier skill talents

- Replace the current per-skill single talent selection with three fixed binary tiers; paths such as `221` are composed from six independent options, not recursive branch-specific subtrees.
- Keep talent thresholds derived from the existing skill-build level and preserve the ordinary four-card/select-two reward.
- Migrate old saves from one stable `talent_id` to ordered tier selections without losing the current 36 talents.
- Update HUD, character panel, upgrade copy, developer tools, and continue-save restoration for tiered selections.
- Pilot one role first, then expand to all three roles after cadence, save, UI, and local path tests pass.
- Before designing the gunner's second- and third-tier talents, decide whether it stays without periodic background attacks or receives a role-specific off-field behavior.
- Detailed scope and acceptance criteria live in `docs/13_会议目标与三层技能天赋规划.md`.

## Next: rewards

- Rebuild elite and Boss reward identity through the existing reward modules.
- Define whether a Boss talent reward targets one role, lets several roles choose separately, or is a true team reward.
- Improve Boss pressure, readability, and phase identity after the current difficulty evidence is collected.

## Later: minimum meta loop and main story

- Build one complete meta loop before expanding the economy: one persistent resource, one repeatable Ruan Gou task, and one clear blacksmith sink.
- Keep the story on a fixed route with entry/Boss dialogue and replayable cleared maps; do not add room-selection structure.
- Add quest-style equipment or limited consumables only after equipment ownership and the first meta loop are stable.
- Defer complex camp gambling/buff facilities, large RPG equipment-slot trees, and dedicated crafting catalogs.
- Do not restore the retired three-in-one blessing, all-team role traits, pre-equipped skill loadouts, or the old seven-second switch cooldown.

## Continuous guardrails

- Keep the local achievement system independent from Steam APIs until platform integration.
- Maintain display settings: window/fullscreen and 16:9 window sizing.
- Keep docs synchronized with implemented systems.
- Protect UI modal/card/hover components and save serialization with automated checks.
- Keep automated checks for settings, achievements, save serialization, hero-trait persistence, and theme-unlock persistence.

## Later: release preparation

- Add clearer achievement categories once progression goals settle.
- Replace placeholder/non-commercial media.
- Finalize asset licensing and third-party notices.
- Add export presets and release checklist automation.
- Integrate GodotSteam behind `AchievementService` adapter.
- Add Steam achievement API names matching local achievement IDs.
