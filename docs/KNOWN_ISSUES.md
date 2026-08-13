# Known Issues

## Documentation

- `docs/13` and `docs/14` are historical three-stage/108-node specifications. Current player progression uses `LEVEL_TALENT_DEFINITIONS`; data or tests for old `TALENT_DEFINITIONS` do not prove player reachability.
- `graphify-out/` is the active generated code graph output when available.
- The checked-in graph report was built from an older commit; use current source for changed progression behavior until `graphify update .` is run after a code change.

## Assets

- Current BGM and some visual assets are development placeholders.
- Commercial/public release requires asset replacement or explicit license clearance.

## Gameplay/System Risks

- `scripts/player.gd` and `scripts/enemy.gd` remain large hub scripts; future work should avoid adding unrelated responsibilities there.
- Save/load and continue-game behavior should be treated as high-risk when changing player, enemy, blessings, equipment, hero traits, or mode state.
- Elite reward design is not final.
- Blessing text, blessing values, character panel display, and actual combat effects must stay synchronized.
- Common-prosperity applies a multiplicative switch-cooldown factor through player attribute data; changing switch cooldown formulas needs regression testing.
- Current talent definitions contain 42 player-facing options in 21 mutually exclusive `_1` / `_2` groups, while a choice is queued every three player levels. The all-groups-exhausted case has no finished product contract and can leave later pending choices without useful candidates.
- `_1` / `_2` talent names are alternatives, not sequential tiers; current I/II titles can mislead players.
- Current documentation uses the canonical player-facing role name `法师`, but two live Mage talent summaries in `LEVEL_TALENT_DEFINITIONS` and the camp's placeholder Mage interaction still say `术师`; synchronize that source copy before claiming player-facing labels are fully unified.
- Direct role-build skill unlock cards and blessing-recipe unlock/evolution coexist. Their intended precedence and long-term ownership are not settled.
- `EXIT_SKILLS_ENABLED=false` disables exit skills, but the movement tutorial still says a full-energy switch triggers both exit and entry skills.
- Old 108-node runtime helpers and tests remain beside the current system. `get_selected_talents()` / `has_talent()` are disabled and `skill_talents` is cleared, so restoring only a UI or developer entry would create a half-working second progression route.

## UI Risks

- Main-menu Settings must remain a full-screen `Control` hosting `SurvivorsModal`; using a plain `CenterContainer` can make the panel appear in a corner.
- Hover detail panels intentionally auto-size up to a max size. Very long future text can still require scrolling inside the detail panel.
- Only independent-cooldown skills should appear as separate bottom skill slots. Other passive/basic/ultimate changes should be folded into normal attack or ultimate hover descriptions.
- Character panel shows ordinary skill-build stacks but not the current `level_talents` ledger; its footer still says “查看天赋树” after the old tree was removed.
- `refresh_limit=0` disables the old whole-offer refresh, not the live per-card buttons. Ordinary four-card offers and level-talent detail cards track one refresh per card slot in `level_up_ui.gd`.

## Tooling

- Local graphify support for Godot/GDScript depends on local tooling availability.
- Godot MCP is development tooling only. Current handoff should not rely on MCP being available; CLI Godot checks are the safer baseline.

## Known Design Quirks

### Blessing Skill Unlock Lock Sharing
- `player_blessing_skill_state.gd` uses a global `role_recipe_locks` dictionary to track consumed blessings per skill unlock.
- These locks are NOT per-role — a blessing consumed to unlock a swordsman skill (e.g., `formation_break` for Blade Storm) is also subtracted when checking mage skill requirements (e.g., Surging Wave).
- Result: two roles that both meet the same blessing requirements may not both unlock their skills, because the first unlock's lock is subtracted from all roles.
- This may be intentional (shared resource pool) or a bug — confirmed with upstream before changing.
