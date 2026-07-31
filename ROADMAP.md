# Roadmap

This roadmap tracks project direction, not a promise of release dates.

## Now: stabilize prototype foundation

- Keep the current survivor-like combat loop playable.
- Stabilize save/load and continue-game behavior.
- Validate the implemented 108 three-stage skill-talent nodes, especially ordinary-build inheritance, visual readability, branch balance, and long-session behavior.
- Extend the character panel from total skill-build level to the exact acquired build cards and stack counts.
- Identify the Boss referenced by the meeting, then measure its difficulty and high-tier blessing timing before changing values.
- Keep dense-combat and autosave optimization evidence-driven through the existing benchmark, evaluator, trace, and feature-flag paths.

## Now: three-tier skill-talent verification

- Validate the implemented Lv.3/Lv.6/Lv.9, naming, upgrade-inheritance, and 108-node specification in `docs/14_三角色完整三层技能天赋设计.md`; complete 144-path behavior regression and balance passes.
- Exercise the implemented three fixed binary tiers; paths such as `221` are composed from six independent options, not recursive branch-specific subtrees.
- Keep talent thresholds derived from the existing skill-build level and preserve the ordinary four-card/select-two reward.
- Regression-test old-save migration from one stable `talent_id` to ordered tier selections without losing the original stage-I talent.
- Verify HUD, character panel, upgrade copy, developer tools, and continue-save restoration stay consistent for tiered selections.
- Complete 144 single-skill-path regression and cross-role high-risk smoke coverage for the already implemented three roles.
- Keep the gunner without periodic background attacks; its later talents reinforce entry and on-field damage instead.
- Planning and acceptance criteria live in `docs/13_会议目标与三层技能天赋规划.md`; the complete content specification lives in `docs/14_三角色完整三层技能天赋设计.md`.

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
