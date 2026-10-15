# Release Checklist

Use this before any public build, demo handoff, or store upload.

## Automated checks

- [ ] Run local project checks:

```bash
./scripts/check_project.sh
```

- [ ] GitHub `Project Checks` passes with its pinned Godot `4.6.2` binary.

## Package sanity

- [ ] Open the project in Godot `4.6.2`.
- [ ] Main scene is `res://scenes/main_menu.tscn`.
- [ ] Run headless parse:

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
```

- [ ] Manually launch main menu.
- [ ] Start story mode if enabled.
- [ ] Start endless mode.
- [ ] Test pause/resume/main-menu return.
- [ ] Test window/fullscreen switching and 16:9 window resize behavior.
- [ ] Test main-menu Settings opens centered after changing window size.
- [ ] Test level-up build offer shows three role cards plus one general blessing, accepts exactly two selections, and allows each card to refresh once.
- [ ] Reach skill Lv.5: verify the two-slot choice, one selected talent, correct owned/pending state and resume after save/load; at Lv.10 verify the other slot is granted.
- [ ] For mechanic, verify both effects of each skill line change their documented combat behavior; other roles must label unimplemented slots explicitly.
- [ ] Verify the live talent flow never opens the historical Lv.3/Lv.6/Lv.9 skill-build tree, writes old `skill_talents`, or queues every-three-player-level talent picks.
- [ ] Test hover details for role builds, blessings, rewards, bottom skill slots, normal attack, and ultimate energy.
- [ ] Open the character panel: verify all 11 overview stats and sources, skill levels/talents, blessing counts, shared carried items, equipment transfers, and the read-only saved `level_talents` list.
- [ ] Verify Q/E switching without full energy changes role but does not fire an entry skill; full **departing-role** energy is consumed and fires only the incoming entry skill. Exit-skill copy/tutorial must not claim an effect while `EXIT_SKILLS_ENABLED=false`.
- [ ] If Gunner has Infinite Reload I, verify the matching `1`–`6` slot key toggles it; do not assume other slots are manual abilities.
- [ ] In camp, verify all four roles including mechanic, avatar/team synchronization, role introductions, team replacement/reordering, and next-run semantics when a run already exists.
- [ ] At the dog and blacksmith, verify separate buy/refund actions, duplicate purchases, all 17 effect previews, capacity/poor/empty-owned states, and no inventory/bone changes after a failed save.
- [ ] Verify camp overview and departure loadout, nearest interact highlight, all-modal movement lock, focus restoration, and F not resetting an open tier selector. Check 1280×720 and 960×540 modal action bounds.
- [ ] Return after a clear, a defeat and an active end-run: keep permanent items/bones, clear only the run save, and show the latest clear summary without paying a duplicate reward.
- [ ] Defeat the endless final Boss that spawns at 12:00: verify fixed/first-clear bones, N+1 unlock, run-save removal, and return to camp with no same-run skill reward or “continue deeper” choice.


## Performance sanity

- [ ] Endless mode keeps intended enemy density; low FPS must not silently reduce normal enemy count.
- [ ] Developer normal-enemy batch spawner can reproduce dense-combat scenes.
- [ ] Level-up, blessing binding, and skill-reward confirmation do not create obvious click-frame stalls.
- [ ] If a stall is reported, enable performance trace briefly and inspect `user://performance_trace_latest.jsonl` for slow-frame, SavePeak, pending spawn, and batch counters.
- [ ] Combat save still overwrites `run_save.json` and `run_save_backup.json` only; save file count must not grow with play time.

## Save/settings sanity

- [ ] New story profile can be created.
- [ ] Endless profile can be created.
- [ ] Continue game works after leaving a run.
- [ ] Keybind changes persist.
- [ ] Music settings persist.
- [ ] Display settings persist.
- [ ] Keybind editing in main-menu Settings still works after closing/reopening the panel.
- [ ] Role-build levels and role special state persist across continue-game save/load.
- [ ] `role_special_states[role_id].skill_levels` and `.skill_talent_slots` persist across continue-game save/load, and a skill reaching level 5 still shows its pending two-slot talent pick after reloading.
- [ ] `pending_level_talent_choices`, active talent context, `level_talents`, and `level_talent_group_locks` still round-trip for legacy saves; the player-level talent entry no longer queues new picks, and legacy `skill_talents` remains empty after normalization.
- [ ] Blessing levels, retained attribute-training state, skill blessing levels, and equipment persist across continue-game save/load.
- [ ] Achievement unlock state persists.

## Content/legal

- [ ] Placeholder BGM replaced or license cleared.
- [ ] If the release requires combat/UI sound effects, add and verify an SFX system; the current project only provides menu/game BGM.
- [ ] Placeholder images/sketches replaced or license cleared.
- [ ] README, `docs/README_文档索引.md`, `docs/04`, `docs/06`, `docs/08`, `ROADMAP.md`, `KNOWN_ISSUES.md`, and this checklist describe the same shipped progression and settlement rules.
- [ ] `THIRD_PARTY_NOTICES.md` reviewed.
- [ ] `LICENSE.md` reviewed for intended distribution model.

## Steam-specific future checks

- [ ] GodotSteam installed only for Steam package lane.
- [ ] Steamworks Achievement API Names match local `data/achievements.json` IDs.
- [ ] Steamworks changes are published.
- [ ] `Steam.setAchievement()` and `Steam.storeStats()` verified in a Steam test app.
