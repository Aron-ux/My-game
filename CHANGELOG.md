# Changelog

## Unreleased

### Changed
- Combat HUD bottom skill bar now uses a three-row team status stack anchored bottom-left: `Q` previous role, highlighted current role, and `E` next role each keep six fixed skill slots, HP, MP / ultimate energy, and hover details while preserving empty slots for locked skills.
- Character panel now uses a dark-gold build-archive layout inspired by the selected design reference, with a left role stack, existing player pixel run sprites as role portraits, ornamental frames, central role stats/equipment, right blessing list, and skill recipe details while preserving gift and blessing-composition interactions.
- Swordsman trait healing now triggers on attack hits instead of kills: base 5% proc chance plus 5% per trait level, each proc heals 5% of max health plus 7.5% of missing health, and the effect has its own 1-second trigger cooldown.
- `贪婪` now triggers on attack hits instead of kills, heals 1% of the attacker's max health on proc, uses tier-based proc chances of 1% / 5% / 10% / 20%, and has its own 1-second trigger cooldown.
- Mage `奥法盈余` now grants the caster 3 stacks of `奥术充能` when the 5-second surplus window expires naturally.

- Swordsman entry state now displays as `嗜血` instead of a generic `无敌`, shows a blue `嗜` buff icon in the combat buff bar, and shares entry lifesteal healing to the other two roles during its 3-second window.
- Reduced post-switch invulnerability from 0.2s to 0.1s to tighten role-swap safety windows.
- Cleaned Mac/archive metadata from imported asset folders and ignored future `.DS_Store`, `__MACOSX/`, and `._*` files.
- Normalized script encodings by removing UTF-8 BOM from local code/check scripts.
- Project display config now explicitly keeps resizable 16:9 `canvas_items + keep` settings required by project checks.
- Local project checks now include level-up scroll reopen, player targeting, player damage resolver, runtime registry, and player projectile pool smoke tests.
- Fixed consecutive reward/level-up panels so the second skill list keeps a valid scrollbar range.
- Runtime enemy, enemy projectile, projectile-pool, and pickup registries now use instance-id dictionaries behind the existing Array-returning API to avoid linear duplicate/removal scans in dense combat.
- Player projectile counts now use the runtime registry in performance checks/monitoring, and player bullet nodes can be recycled through a keyed runtime pool instead of always instantiating/freeing.
- Dense-combat CPU optimizations now throttle repeated HUD stat rebuilds, centralize global enemy feedback updates, reuse shared enemy sprite-frame resources, and keep visual feedback pools guarded without changing enemy counts, projectile counts, or damage rules.
- Dense-combat follow-up optimizations now cache reusable geometry/projectile visual data, pool turret bombard warning nodes, and remove duplicate vector math in enemy movement, separation, projectile, and damage checks without changing combat rules.
- Dense-combat enemy simulation now batch-updates simple normal chasers from the main scene and disables their per-node physics callbacks, preserving the same movement/damage rules while reducing late-wave scheduler overhead.
- Enemy projectile and pickup ticking now run through scene-level batch simulation where possible, keeping projectile motion, hit, attraction, despawn, and recycle rules unchanged while removing more high-density per-node physics callbacks.
- Dense-combat optimization now has an evidence-first benchmark/evaluator gate with frame-time p95/p99/max, gameplay-equivalence counters, CPU/core artifacts, and feature-flagged batch simulation wiring.
- Developer performance metrics now include rolling frame-time percentiles and the active performance feature-flag snapshot for dense-combat comparisons.
- Refactor verification docs now use the local Linux Godot CLI command paths instead of stale Windows examples.
- Combat HUD presentation now refreshes cooldown/energy/time/minimap feedback at 30 FPS, and project display settings explicitly avoid the 60 FPS render cap by disabling VSync with a 120 FPS project cap.
- Large telegraphed enemy waves now drain their spawn queue over smaller frame-budgeted chunks, reducing new-enemy instantiation spikes while preserving total wave size.
- Runtime performance metrics now include automatic-save peak timing/payload counters; automatic combat saves now run as a fixed background save about every 2 seconds and no longer expose a main-menu or pause-menu toggle.
- Enemy, enemy-projectile, and pickup batch simulation flags are now enabled by default, with the developer performance panel showing batch flag state and batch tick peaks.
- Added a default-off performance trace toggle in main-menu and pause settings that writes periodic and slow-frame JSONL samples to `user://performance_trace_latest.jsonl`.
- Reduced long-run main-thread HUD/spawn overhead by caching gameplay settings reads, caching combat HUD key labels, and using a lightweight spawn-growth score path.
- Combat HUD redraws now skip unchanged labels/cooldown widgets, and the ultimate-energy fill uses cheaper geometry so 30 FPS cooldown presentation creates less main-thread UI work.
- Per-frame HUD stats now use a lightweight payload that omits role-detail text not rendered by the live HUD, while full stat summaries remain available for explicit refreshes.
- Per-frame combat HUD cooldown payloads no longer rebuild blessing-skill evolution requirement text; hover/detail paths still use full descriptions when explicitly requested.
- Fixed 三命诡影 rebirth timing so target loss during revive no longer leaves it frozen/undamageable, and kept the authored 祸月星核 boss visual alive across repeated visual refreshes.
- Developer mode now includes a configurable normal-enemy batch spawner for each small enemy archetype, bypassing the normal active-enemy cap for dense-combat and enemy-specific reproduction.
- Runtime enemy caps no longer shrink based on low FPS, so endless-mode enemy density is controlled by spawn rules and difficulty profile rather than current frame rate.
- Level-up and skill-reward flow now avoids same-frame spikes by deferring level-up offer construction to the next frame, using lightweight immediate HUD stat notifications, deferring full HUD/save maintenance, and spacing chained pending level-up popups by a short delay.
- Added a performance optimization and validation record documenting dense-combat boundaries, root causes, trace workflow, and PR review checks.
- Reused player projectile nodes now restore their own scene-specific exported defaults, preventing pooled mage wave projectiles from inheriting generic bullet visual bounds.
- Batched damage queries now collect candidates from per-shape/per-radius grid bounds instead of one merged bounding box, and frame caches are isolated per current scene.
- Player per-frame timer and developer no-cooldown updates now route through `player_timer_flow.gd`, reducing `player.gd` responsibilities and covering temporary buff expiry with a smoke test.
- Player authored/primitive effect wrappers are thinner and route scene-specific setup into `player_authored_effects.gd` / `player_effect_primitives.gd`, with a bridge smoke covering common effect spawns.
- Runtime player save/load now restores role health after roles, equipment, attributes, and blessings are applied, preserving boosted health pools and standby-entry labels across roundtrips.
- Local project checks now include a player save roundtrip smoke covering health/mana, blessings, equipment, cooldowns, temporary buffs, and story style state.
- Blessing-driven skill unlock/evolution events now include consumed material details and show a battle UI popup when recipe materials are locked.
- Local project checks now run the player blessing system smoke so recipe-consumption notice payloads remain covered.
- Player blessing skill query, composition, binding-choice, and unlock notice bridge code moved from `player.gd` into `player_blessing_skill_bridge.gd`, keeping `player.gd` closer to a compatibility coordinator.
- Fixed developer blessing options for role-bound blessings so shared role counts display and disable correctly instead of always appearing as 0/6.
- Cleaned legacy progression runtime and documentation entry points.
- Level-up progression now uses the blessing system as the active progression model.
- Developer upgrade flow now points at blessing offers instead of old card pools.
- Player upgrade application was reduced to the current reward types: blessings, equipment, small boss training, final core rewards, and blank continuation options.
- Documentation was rewritten around current blessing, equipment, skill unlock, enemy spawning, HUD, and architecture boundaries.

### Added

- Blessing-driven skill unlock state.
- Role-shared role blessings and separate skill-bound blessings.
- Character panel blessing display and composition support.
- Map-bounded wave spawning with warnings.
- Runtime performance guard for dense combat scenarios.

### Notes

- BGM files under `assets/` are non-commercial placeholder materials for development testing only and will be replaced before commercial release or public distribution.
