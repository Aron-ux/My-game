extends SceneTree

const CHARACTER_PANEL := preload("res://scripts/ui/hud/character_panel.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []
var shared_blessing_count_line_before_role_preview := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	_seed_character_build(player)

	var panel := CHARACTER_PANEL.new()
	root.add_child(panel)
	await process_frame
	panel.show_for_player(player)
	await process_frame
	await process_frame

	_check_stable_nodes(panel)
	await _check_skill_tree_content(panel)
	await _check_archive_ctrl_tab_focus(panel)
	await _check_blessing_content(panel)
	await _check_archive_pages_scroll(panel)
	await _check_role_preview_does_not_switch_active_role(panel, player)
	await _check_empty_states(panel, player)
	await _check_viewport_layout(panel)

	panel.queue_free()
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHARACTER_PANEL_UI_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _seed_character_build(player: Node) -> void:
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:basic_attack_damage")
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:basic_attack_damage")
	var offer := PLAYER_SKILL_TALENT_SYSTEM.build_choice_offer(player, {
		"role_id": "swordsman",
		"progress_id": "swordsman_basic"
	})
	PLAYER_SKILL_TALENT_SYSTEM.apply_option_with_result(
		player,
		"skill_talent:swordsman_basic_cross",
		offer
	)
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:basic_attack_damage")
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:basic_attack_cooldown")
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:entry_damage")
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:swordsman:entry_damage")
	PLAYER_BUILD_SYSTEM.apply_option(player, "role_build:gunner:entry_damage")

	for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
		PLAYER_BLESSING_SYSTEM.apply_blessing(player, "divine_grace", tier)
	PLAYER_BLESSING_SYSTEM.apply_blessing(player, "divine_grace", 2)
	for blessing_id in [
		"prayer",
		"formation_break",
		"benediction",
		"support",
		"greed",
		"tailwind",
		"burst",
		"unyielding"
	]:
		PLAYER_BLESSING_SYSTEM.apply_blessing(player, blessing_id, 1)
	player.set("skill_blessing_levels", {
		"kebiru_prayer": {1: 1, 2: 2, 3: 1, 4: 1},
		"kebiru_formation_break": {1: 1, 2: 1, 3: 1, 4: 1},
		"invoker_formation_break": {1: 1, 2: 1, 3: 1, 4: 1},
		"tide_rain": {1: 1},
		"reprise": {1: 1},
		"trick": {1: 1}
	})


func _check_stable_nodes(panel: Node) -> void:
	for node_name in [
		"BuildTabButton",
		"BlessingTabButton",
		"SkillTreeSelectorList",
		"SkillTreeDetailScroll",
		"SkillTreeDetail",
		"BlessingScroll",
		"BlessingList"
	]:
		_expect(
			panel.find_child(node_name, true, false) != null,
			"character panel should expose stable node %s" % node_name
		)


func _check_skill_tree_content(panel: Node) -> void:
	var selector_list := panel.find_child("SkillTreeSelectorList", true, false)
	var detail := panel.find_child("SkillTreeDetail", true, false)
	if selector_list == null or detail == null:
		return
	_expect(selector_list.get_child_count() == 6, "skill tree page should render exactly six selectors")
	for progress_id in PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER["swordsman"]:
		_expect(
			panel.find_child("SkillTreeSelector_%s" % progress_id, true, false) != null,
			"skill tree page should expose selector %s" % progress_id
		)

	await _check_skill_tree_selection_input(panel, "mouse_entered")
	await _check_skill_tree_selection_input(panel, "focus_entered")
	await _check_skill_tree_selection_input(panel, "pressed")

	detail = panel.find_child("SkillTreeDetail", true, false)
	var text := _collect_text(detail)
	for title in ["普通攻击", "十字剑势", "背身斩"]:
		_expect(text.contains(title), "basic attack tree should show %s" % title)
	_expect(text.contains("当前路径：1--"), "selected first talent should render path 1--")
	var stage_one_left := panel.find_child("SkillTreeStage1Left", true, false)
	var stage_one_right := panel.find_child("SkillTreeStage1Right", true, false)
	_expect(
		stage_one_left != null and _collect_text(stage_one_left).contains("已选择"),
		"selected left stage-I option should say 已选择"
	)
	_expect(
		stage_one_right != null and _collect_text(stage_one_right).contains("本局未选"),
		"unselected right stage-I option should say 本局未选"
	)
	for stage_number in [2, 3]:
		var stage := panel.find_child("SkillTreeStage%d" % stage_number, true, false)
		_expect(
			stage != null and _collect_text(stage).contains("尚未开放"),
			"stage %d should be explicit about being unavailable" % stage_number
		)
	_expect(
		not text.contains("Lv.6") and not text.contains("Lv.9"),
		"unimplemented stages should not expose invented Lv.6/Lv.9 thresholds"
	)
	_expect(
		_compact(text).contains("剑士普通攻击伤害倍率增加10％×3"),
		"basic attack tree should keep the concrete ordinary build ×3 count"
	)
	_expect(
		text.contains("主斩与第3击垂直追斩同步继承伤害"),
		"basic attack tree should explain how later upgrades affect the evolved skill"
	)
	var header_instance_id := panel.find_child("SkillTreeHeader", true, false).get_instance_id()
	var option_instance_id := stage_one_left.get_instance_id()
	var build_instance_id := panel.find_child("SkillTreeBuildDetails", true, false).get_instance_id()
	await _check_locked_skill_copy(panel)
	await _check_pretrigger_skill_copy(panel)
	await _check_pending_skill_copy(panel)
	_expect(
		panel.find_child("SkillTreeHeader", true, false).get_instance_id() == header_instance_id
		and panel.find_child("SkillTreeStage1Left", true, false).get_instance_id() == option_instance_id
		and panel.find_child("SkillTreeBuildDetails", true, false).get_instance_id() == build_instance_id,
		"switching skill trees should update persistent detail controls instead of rebuilding them"
	)


func _check_skill_tree_selection_input(panel: Node, signal_name: String) -> void:
	var other_selector := panel.find_child("SkillTreeSelector_swordsman_entry", true, false) as Button
	var basic_selector := panel.find_child("SkillTreeSelector_swordsman_basic", true, false) as Button
	if other_selector == null or basic_selector == null:
		failures.append("skill tree should expose swordsman entry and basic selectors")
		return
	other_selector.emit_signal("pressed")
	await process_frame
	if signal_name == "focus_entered":
		basic_selector.grab_focus()
	else:
		basic_selector.emit_signal(signal_name)
	await process_frame
	var detail := panel.find_child("SkillTreeDetail", true, false)
	_expect(
		detail != null and _collect_text(detail).contains("普通攻击"),
		"swordsman basic selector %s should show the basic attack tree" % signal_name
	)


func _check_locked_skill_copy(panel: Node) -> void:
	var selector := panel.find_child("SkillTreeSelector_swordsman_blade_storm", true, false) as Button
	if selector == null:
		failures.append("skill tree should expose the locked blade storm selector")
		return
	selector.emit_signal("pressed")
	await process_frame
	var text := _collect_text(panel.find_child("SkillTreeDetail", true, false))
	for expected in ["尚未解锁", "第一阶段不可用", "先解锁"]:
		_expect(text.contains(expected), "locked skill detail should say %s" % expected)
	_expect(
		not text.contains("第一阶段待选择") and not text.contains("继续获得该技能"),
		"locked skill detail should not describe unavailable progression as pending"
	)


func _check_pretrigger_skill_copy(panel: Node) -> void:
	var selector := panel.find_child("SkillTreeSelector_swordsman_trait", true, false) as Button
	if selector == null:
		failures.append("skill tree should expose the swordsman trait selector")
		return
	selector.emit_signal("pressed")
	await process_frame
	var text := _collect_text(panel.find_child("SkillTreeDetail", true, false))
	_expect(
		text.contains("阶段 I 于构筑 Lv.3 解锁"),
		"an unlocked level-1 skill should state its exact stage-I threshold"
	)
	_expect(
		not text.contains("第一阶段待选择"),
		"an unlocked skill below build Lv.3 should not say the choice is pending"
	)


func _check_pending_skill_copy(panel: Node) -> void:
	var selector := panel.find_child("SkillTreeSelector_swordsman_entry", true, false) as Button
	if selector == null:
		failures.append("skill tree should expose the swordsman entry selector")
		return
	selector.emit_signal("mouse_entered")
	await process_frame
	var text := _collect_text(panel.find_child("SkillTreeDetail", true, false))
	_expect(text.contains("冲锋"), "moving to another skill should update the tree header")
	_expect(
		text.contains("长驱冲阵") and text.contains("回马护阵"),
		"moving to another skill should update both stage-I options"
	)
	_expect(
		text.contains("第一阶段待选择"),
		"an unlocked build Lv.3 skill without a talent should say the choice is pending"
	)


func _check_archive_ctrl_tab_focus(panel: Node) -> void:
	var selector := panel.find_child("SkillTreeSelector_swordsman_entry", true, false) as Button
	var blessing_button := panel.find_child("BlessingTabButton", true, false) as Button
	var build_button := panel.find_child("BuildTabButton", true, false) as Button
	if selector == null or blessing_button == null or build_button == null:
		failures.append("archive Ctrl+Tab check requires selector and both tab buttons")
		return
	selector.grab_focus()
	await process_frame
	panel.call("_input", _ctrl_tab_event())
	await process_frame
	_expect(
		root.gui_get_focus_owner() == blessing_button,
		"first Ctrl+Tab from a skill selector should focus BlessingTabButton"
	)
	panel.call("_input", _ctrl_tab_event())
	await process_frame
	_expect(
		root.gui_get_focus_owner() == build_button,
		"second Ctrl+Tab should focus BuildTabButton"
	)


func _ctrl_tab_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.ctrl_pressed = true
	event.pressed = true
	return event


func _check_blessing_content(panel: Node) -> void:
	var blessing_button := panel.find_child("BlessingTabButton", true, false) as Button
	var blessing_list := panel.find_child("BlessingList", true, false)
	if blessing_button == null or blessing_list == null:
		return
	blessing_button.emit_signal("pressed")
	await process_frame
	var text := _collect_text(blessing_list)
	_expect(
		text.contains("团队共享 · 角色祝福（三角色生效）"),
		"blessing page should identify role blessings as shared by all three roles"
	)
	_expect(
		text.contains("技能绑定祝福 · 按技能类型生效"),
		"blessing page should group skill-bound blessings by skill type"
	)
	for scope_label in ["所有连段技能", "所有持续技能", "所有数量技能"]:
		_expect(text.contains(scope_label), "general skill blessing should show scope %s" % scope_label)
	for tier_count in ["I×1", "II×2", "III×1", "IV×1"]:
		_expect(
			_compact(text).contains(tier_count),
			"blessing page should show owned tier count %s" % tier_count
		)
	var divine_grace_row := panel.find_child("BlessingRow_divine_grace", true, false) as Button
	if divine_grace_row == null:
		failures.append("blessing page should render the shared divine grace row")
		return
	var row_instance_id := divine_grace_row.get_instance_id()
	shared_blessing_count_line_before_role_preview = divine_grace_row.text.get_slice("\n", 0)
	divine_grace_row.grab_focus()
	divine_grace_row.emit_signal("pressed")
	await process_frame
	await process_frame
	divine_grace_row = panel.find_child("BlessingRow_divine_grace", true, false) as Button
	if divine_grace_row == null:
		failures.append("expanded divine grace row should remain rendered")
		return
	_expect(
		divine_grace_row.get_instance_id() == row_instance_id and root.gui_get_focus_owner() == divine_grace_row,
		"expanded blessing row should update in place and preserve keyboard focus"
	)
	var expanded_text := divine_grace_row.text
	for effect_text in [
		"I级：最大血量增加8％",
		"II级：最大血量增加12％",
		"III级：最大血量增加16％，每5s回复1％点最大血量",
		"IV级：最大血量增加20％，每5s回复2％点最大血量"
	]:
		_expect(expanded_text.contains(effect_text), "expanded divine grace should show %s" % effect_text)
	_expect(expanded_text.contains("技能关联："), "expanded divine grace should show localized skill relations")
	_expect(
		not expanded_text.contains("divine_grace") and not expanded_text.contains("entry_rescue"),
		"expanded blessing detail should not expose internal blessing or skill IDs"
	)


func _check_archive_pages_scroll(panel: Node) -> void:
	var build_button := panel.find_child("BuildTabButton", true, false) as Button
	if build_button != null:
		build_button.emit_signal("pressed")
		await process_frame
	await _check_scroll_container(panel, "SkillTreeDetailScroll", "skill tree detail")
	var blessing_button := panel.find_child("BlessingTabButton", true, false) as Button
	if blessing_button != null:
		blessing_button.emit_signal("pressed")
		await process_frame
	await _check_scroll_container(
		panel,
		"BlessingScroll",
		"blessing page"
	)


func _check_scroll_container(
		panel: Node,
		scroll_name: String,
		page_label: String
) -> void:
	var scroll := panel.find_child(scroll_name, true, false) as ScrollContainer
	if scroll == null:
		return
	await process_frame
	var scroll_bar := scroll.get_v_scroll_bar()
	_expect(
		scroll_bar.max_value > scroll_bar.page,
		"%s should overflow vertically, max %.1f page %.1f" % [
			page_label,
			scroll_bar.max_value,
			scroll_bar.page
		]
	)
	if scroll_bar.max_value <= scroll_bar.page:
		return
	scroll.scroll_vertical = int(min(60.0, scroll_bar.max_value - scroll_bar.page))
	await process_frame
	_expect(scroll.scroll_vertical > 0, "%s should accept a positive vertical scroll offset" % page_label)


func _check_role_preview_does_not_switch_active_role(panel: Node, player: Node) -> void:
	var original_active_index := int(player.get("active_role_index"))
	var basic_selector := panel.find_child("SkillTreeSelector_swordsman_basic", true, false) as Button
	var role_nav_list := panel.get("role_nav_list") as VBoxContainer
	var first_role_card_id := 0
	if role_nav_list != null and role_nav_list.get_child_count() > 0:
		first_role_card_id = role_nav_list.get_child(0).get_instance_id()
	if basic_selector != null:
		basic_selector.emit_signal("pressed")
		await process_frame
	panel.call("_view_role", 1)
	await process_frame
	_expect(
		int(player.get("active_role_index")) == original_active_index,
		"previewing another role should not change active_role_index"
	)
	_expect(
		first_role_card_id != 0
		and role_nav_list.get_child(0).get_instance_id() == first_role_card_id,
		"role preview should update persistent role cards instead of rebuilding them"
	)
	var gunner_basic_selector := panel.find_child("SkillTreeSelector_gunner_basic", true, false) as Button
	_expect(
		basic_selector != null
		and gunner_basic_selector != null
		and gunner_basic_selector.get_instance_id() == basic_selector.get_instance_id(),
		"role preview should update the six persistent selector buttons in place"
	)
	var build_button := panel.find_child("BuildTabButton", true, false) as Button
	if build_button != null:
		build_button.emit_signal("pressed")
		await process_frame
	var selector_list := panel.find_child("SkillTreeSelectorList", true, false)
	var detail := panel.find_child("SkillTreeDetail", true, false)
	if selector_list != null and detail != null:
		var selector_text := _collect_text(selector_list)
		var detail_text := _collect_text(detail)
		_expect(selector_text.contains("枪火典礼"), "role preview should refresh gunner-bound skill content")
		_expect(selector_text.contains("火箭弹幕"), "role preview should refresh the gunner ultimate content")
		_expect(not selector_text.contains("冲锋"), "role preview should remove the previous role's skill content")
		_expect(
			detail_text.contains("破甲重弹") and detail_text.contains("三连点射"),
			"role preview should preserve slot index 2 and show the gunner basic tree"
		)
	var blessing_button := panel.find_child("BlessingTabButton", true, false) as Button
	if blessing_button != null:
		blessing_button.emit_signal("pressed")
		await process_frame
	var blessing_list := panel.find_child("BlessingList", true, false)
	if blessing_list != null:
		var blessing_text := _collect_text(blessing_list)
		_expect(
			blessing_text.contains("团队共享 · 角色祝福（三角色生效）"),
			"role preview should preserve the team-shared blessing group"
		)
		var divine_grace_row := panel.find_child("BlessingRow_divine_grace", true, false) as Button
		if divine_grace_row != null:
			_expect(
				divine_grace_row.text.get_slice("\n", 0) == shared_blessing_count_line_before_role_preview,
				"role preview should preserve shared blessing tier counts"
			)


func _check_empty_states(panel: Node, player: Node) -> void:
	player.set("role_special_states", {
		"swordsman": {},
		"gunner": {},
		"mage": {}
	})
	player.set("role_blessing_levels", PLAYER_BLESSING_SYSTEM.build_empty_role_state(player.get("roles")))
	player.set("skill_blessing_levels", {})
	panel.call("_view_role", 0)
	await process_frame

	var skill_detail := panel.find_child("SkillTreeDetail", true, false)
	if skill_detail != null:
		_expect(
			_contains_any(_collect_text(skill_detail), ["暂无普通构筑强化", "暂无构筑强化", "尚无构筑强化"]),
			"skill tree detail should show an empty ordinary-build state"
		)
	var blessing_button := panel.find_child("BlessingTabButton", true, false) as Button
	if blessing_button != null:
		blessing_button.emit_signal("pressed")
		await process_frame
	var blessing_list := panel.find_child("BlessingList", true, false)
	if blessing_list != null:
		_expect(
			_contains_any(_collect_text(blessing_list), ["暂无祝福", "尚未获得祝福", "本局暂无祝福"]),
			"blessing page should show an empty state"
		)
		var divine_grace_row := panel.find_child("BlessingRow_divine_grace", true, false) as Button
		_expect(
			divine_grace_row != null
			and not divine_grace_row.visible
			and divine_grace_row.text == ""
			and divine_grace_row.tooltip_text == ""
			and not divine_grace_row.button_pressed,
			"empty blessing state should clear hidden persistent rows"
		)


func _check_viewport_layout(panel: Node) -> void:
	var panel_control := panel.get("panel") as Control
	if panel_control == null:
		failures.append("character panel should expose its root panel control")
		return
	for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		panel.call("_layout_panel")
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var panel_rect := panel_control.get_global_rect()
		_expect(
			viewport_rect.encloses(panel_rect),
			"character panel should stay inside %dx%d viewport, got %s" % [
				viewport_size.x,
				viewport_size.y,
				str(panel_rect)
			]
		)


func _collect_text(node: Node) -> String:
	var parts: Array[String] = []
	if node is RichTextLabel:
		parts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)


func _compact(value: String) -> String:
	return value.replace(" ", "").replace("\n", "")


func _contains_any(value: String, candidates: Array[String]) -> bool:
	for candidate in candidates:
		if value.contains(candidate):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
