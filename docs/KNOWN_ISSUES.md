# Known Issues

## Documentation

- `docs/13` and `docs/14` are historical three-stage/108-node specifications. Current player progression uses acquisition/skill-level cards and level-5/10 talent slots; `LEVEL_TALENT_DEFINITIONS` acquisition is disabled, and data or tests for old `TALENT_DEFINITIONS` do not prove player reachability.
- `graphify-out/` is the active generated code graph output when available.
- Generated graph freshness must be checked against the working tree. Current source and the status entry take precedence over graph summaries and dated reviews.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/System Risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future work should avoid adding unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, blessings, equipment, hero traits, or mode state.
- Elite reward design is not final.
- Blessing text, blessing values, character panel display, and actual combat effects must stay synchronized.
- Camp return now preserves permanent purchases, and Rusted Dagger critical damage is included in combat and stat sources. Items already erased by an older return flow cannot be reconstructed automatically because profiles have no purchase history; this update preserves the remaining data and does not invent refunds.
- Common-prosperity applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs regression testing.
- The retained role-talent offer builder can produce empty choices when its groups are exhausted. Ordinary level-ups no longer increment `pending_level_talent_choices`, so this is a reactivation/developer-injection risk, not a current every-three-level progression blocker. Define exhaustion behavior before restoring that route.
- `_1` / `_2` talent names are alternatives, not sequential tiers; current I/II titles can mislead players.
- Direct role-build skill unlock cards are the only formal player-reachable active-skill unlock route. Blessing-recipe unlock/evolution, binding, and material-lock code remains, but required legacy materials are excluded from ordinary, Boss-choice, and random formal blessing generators.
- Old 108-node definitions are isolated in `scripts/player/data/legacy_skill_talent_catalog.gd`; compatibility helpers and tests remain. `get_selected_talents()` / `has_talent()` are disabled and `skill_talents` is cleared, so restoring only a UI or developer entry would create a half-working second progression route.

## UI Risks

- All four roles now consume `player_skill_level_effect_flow.gd`; mechanic has eight growth lines, independent entry/active turret sources and 16 implemented skill-slot talents. Other roles' skill slots remain placeholders. Mechanic balance tuning is explicitly outside the current task; full-run density/performance remains unverified.
- Most ability hover descriptions still contain authored base values. Turret/cannon stat rows read current deployment getters; a complete effective-value presentation for every ability remains separate content work.
- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future text can still require scrolling inside the detail panel.
- Only independent-cooldown skills should appear as separate bottom skill slots. Other passive/basic/ultimate changes should be folded into normal attack or ultimate hover descriptions.
- The character sheet now displays current stats/sources and saved `level_talents`. Some innate/ultimate parameters still come from authored descriptions. Mechanic current values read runtime getters, and its skill slots show real effects and ownership; other roles' slots still show placeholders.
- `refresh_limit=0` disables the old whole-offer refresh, not the live per-card buttons. Ordinary four-card offers and retained legacy level-talent detail cards track one refresh per card slot in `level_up_ui.gd`.

## Tooling

- Local graphify support for Godot/GDScript depends on local tooling availability.
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; CLI Godot checks are the safer baseline.

## Known Design Quirks

### Blessing Skill Unlock Lock Sharing
- `player_blessing_skill_state.gd` uses a global `role_recipe_locks` dictionary to track consumed blessings per skill unlock.
- These locks are NOT per-role — a blessing consumed to unlock a swordsman skill (e.g., `formation_break` for Blade Storm) is also subtracted when checking mage skill requirements (e.g., Surging Wave).
- Result when legacy materials are injected or restored: two roles that both meet the same blessing requirements may not both unlock their skills, because the first unlock's lock is subtracted from all roles.
- This is dormant in a clean formal run because the required materials are not generated. If recipes are restored, decide whether the shared resource pool is intentional before changing it.
