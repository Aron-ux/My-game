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
- [ ] Reach player Lv.3: finish the ordinary reward, verify the talent menu first shows three role entries, then at most three eligible cards for the selected role, accepts exactly one, and allows each detail card to refresh once.
- [ ] Verify a selected `_1` / `_2` talent locks its sibling, locked-skill talents do not appear, and the selected effect changes actual combat behavior.
- [ ] Verify the live talent flow never opens the historical Lv.3/Lv.6/Lv.9 skill-build tree or writes `skill_talents`.
- [ ] Test hover details for role builds, blessings, rewards, bottom skill slots, normal attack, and ultimate energy.
- [ ] Open the character panel: verify six ordinary build records, stack counts, blessing ledger, stats, Ruan stone, and equipment; verify it does not claim to display the removed three-stage tree. Record the current known gap if the `level_talents` ledger is still absent.
- [ ] Verify Q/E switching without full energy changes role but does not fire an entry skill; full **departing-role** energy is consumed and fires only the incoming entry skill. Exit-skill copy/tutorial must not claim an effect while `EXIT_SKILLS_ENABLED=false`.
- [ ] If Gunner has Infinite Reload I, verify the matching `1`–`6` slot key toggles it; do not assume other slots are manual abilities.
- [ ] In endless camp, stand in front of `阮狗`, verify the interact prompt, advance every dialogue line, and close with `Esc`.
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
- [ ] `pending_level_talent_choices`, active talent context, `level_talents`, and `level_talent_group_locks` persist across continue-game save/load; legacy `skill_talents` remains empty after normalization.
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
