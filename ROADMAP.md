# Roadmap

This roadmap tracks project direction, not a promise of release dates.

## Now: stabilize prototype foundation

- Keep the current survivor-like combat loop playable.
- Stabilize save/load and continue-game behavior.
- Validate the current every-three-player-level talent loop: role choice, up-to-three eligible role-detail cards, one-refresh-per-card behavior, skill prerequisites, pair locks, save restoration, and exhaustion at high levels.
- Add a read-only player-level talent ledger to the character panel; the existing skill-build page already shows exact ordinary build cards and stack counts.
- Identify the Boss referenced by the meeting, then measure its difficulty and high-tier blessing timing before changing values.
- Keep dense-combat and autosave optimization evidence-driven through the existing benchmark, evaluator, trace, and feature-flag paths.

## Now: close the progression migration

- Decide explicitly whether the residual 18-tree/108-node definitions, projections, developer options, and old smokes are deleted, archived as test fixtures, or restored through a new approved design. Do not leave them half-authoritative.
- Keep formal player progression on one route: ordinary four-card/select-two rewards, followed by queued player-level talents at level multiples of three.
- Verify `level_talents`, pair locks, pending choices, and active talent context survive continue-save roundtrips while legacy `skill_talents` remain empty.
- Resolve naming that makes `_1`/`_2` alternatives look like sequential ranks, and define behavior once all 21 current talent groups are exhausted.
- Keep direct role-build cards as the only formal active-skill unlock route unless a separate review explicitly restores legacy blessing materials, binding, recipe locks, and evolution balance as one complete feature.
- Align the character-panel hint, tutorial copy, current docs, and tests with the chosen source of truth.
- Treat `docs/13_会议目标与三层技能天赋规划.md` and `docs/14_三角色完整三层技能天赋设计.md` as historical input until a new review explicitly reactivates that design.

## Next: rewards

- Rebuild elite and Boss reward identity through the existing reward modules.
- Define whether a Boss talent reward targets one role, lets several roles choose separately, or is a true team reward.
- Improve Boss pressure, readability, and phase identity after the current difficulty evidence is collected.
- Balance the implemented endless meta loop: normal/elite/Boss bone income, linear Ruan-stone costs, five-stone pick rates, and long-session proc performance.

## Later: minimum meta loop and main story

- The first complete meta loop is implemented: persistent bones feed Ruan Gou's five infinitely upgradable stones and one team-wide active slot.
- Give the blacksmith one clear sink only after bone income and Ruan-stone balance are stable.
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
