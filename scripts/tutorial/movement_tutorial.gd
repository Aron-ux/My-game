extends Node2D

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const TUTORIAL_DUMMY_SCRIPT := preload("res://scripts/tutorial/tutorial_training_dummy.gd")

enum TutorialStep {
	MOVE_TO_MARKER,
	ATTACK_DUMMY,
	SWITCH_ROLE,
	SWITCH_ENERGY,
	ULTIMATE,
	ROLE_INTRO,
	ENTER_PORTAL
}

enum SwitchTutorialStep {
	PREV_ROLE,
	NEXT_ROLE
}

enum SwitchEnergyTutorialStep {
	INTRO,
	PROMPT_SWITCH
}

const SWITCH_ROLE_ORDER := ["swordsman", "gunner", "mage"]
const ROLE_INTRO_ORDER := ["swordsman", "gunner", "mage"]
const ROLE_INTRO_CONTENT := {
	"swordsman": {
		"name": "剑士",
		"trait": "特性机制：攻击命中时有概率触发自愈，每次回复剑士最大生命值的一部分并追加已损失生命值回复，该效果每秒最多触发 1 次。若受到致命伤，会保留 1 点生命并进入 1.5 秒【战意】；战意触发后进入 80 秒冷却。",
		"buff": "Buff 机制：【战意】触发时机是剑士本该死亡的瞬间，效果是强制保命 1 次；【嗜血】主要在剑士压低血线或大招期间收益更高，剑士的吸血触发率会被放大，大招期间还会额外获得约 3 秒吸血强化；剑士普通攻击和无敌斩命中后还会附带流血。",
		"entry": "技能机制：登场技【突进破阵】会朝当前攻击方向或最近敌人突进，沿路径留下线性斩击判定，造成约 1.52 倍角色伤害，并获得 3 秒无敌。这个 3 秒内，剑士自己的回复收益会共享给另外两名队友。终极技能【无敌斩】会连续追斩目标，优先倾向锁定 Boss，整段期间无敌，结束后还会额外保留一段无敌时间。"
	},
	"gunner": {
		"name": "枪手",
		"trait": "特性机制：枪手基础自带额外闪避，同时角色特性等级会继续提高闪避率。只要持续不受伤，就会每 2 秒叠加 1 层【瞬杀】，最多 10 层；每层都会提高伤害与移速，一旦受伤则层数清空并进入 10 秒重置冷却。",
		"buff": "Buff 机制：【闪避】会对怪物碰撞、子弹和 Boss 技能都生效，触发时会直接免掉这次伤害；【瞬杀】的触发时机是枪手连续不掉血，层数越高，拉扯时的输出和机动性越强，属于越稳越强的持续增益。",
		"entry": "技能机制：登场技【快拔压制】会立刻打出 1 轮进场弹幕，并在极短间隔内补出后续波次，用来清近身怪。退场技【战术装填】会在原地触发一次退场攻击，并给下一次登场技做准备。终极技能【火箭弹幕】持续约 4 秒，枪手会向正前方锥形区域持续倾泻火力，范围大约 600，期间移速提高、闪避提高，并有短暂无敌保护。"
	},
	"mage": {
		"name": "术师",
		"trait": "特性机制：术师击杀敌人时有概率额外获得大招能量；当术师自己的大招能量已满后，这部分击杀回能会 100% 分享给另外两名队友，所以术师很适合作为团队回能核心。",
		"buff": "Buff 机制：术师登场后会进入 5 秒【奥法盈余】。这 5 秒内，术师自己获得的大招能量会 100% 分享给另外两名队友；状态自然结束后，还会额外获得 3 层奥术充能。术师的领域类技能同时兼顾减速、持续伤害与回血，属于持续控场型 Buff。",
		"entry": "技能机制：登场技【奥法盈余】会在术师周围生成 5 个落雷点，落点半径约 52，预警后爆炸，每道雷造成约 1.08 倍角色伤害。终极技能【奥数轰炸】持续约 4 秒，会以高频节奏在敌群或 Boss 周围连续落雷轰炸；它会明显倾向锁定 Boss 或小 Boss，但不会 100% 全程只打 Boss。"
	}
}

const ROLE_INTRO_CONTENT_OVERRIDE := {
	"swordsman": {
		"name": "剑士",
		"trait": "特性：攻击命中时有（5％+5％×等级）概率回复自身最大5％+已损失7.5％血量，每秒最多触发一次。剑士受到致命伤害时会进入[战意]状态。\n\n登场技：剑士朝指定距离突进释放斩击随后进入[嗜血]状态。",
		"buff": "[战意]：当剑士受到致命伤害时不会立即死亡，而是保留1点血量并进入1.5秒无敌时间。[战意]触发后进入80秒冷却时间。\n\n[嗜血]：持续3秒无敌时间，在此期间触发的吸血所回复的血量会翻倍，并同步回复到剩下的角色上。",
		"entry": ""
	},
	"gunner": {
		"name": "枪手",
		"trait": "特性：被攻击时有（15％+2％×等级）概率闪避此次伤害。如果枪手站场期间没有受到伤害则会获得[瞬杀]。\n\n登场技：枪手登场时会向周围打出2轮高伤害子弹。",
		"buff": "[瞬杀]：枪手每1.5秒没有受到伤害获得一层[瞬杀]，每一层提供枪手3％伤害与3％移速，受到伤害后全部层数移除并且进入10秒冷却时间。",
		"entry": ""
	},
	"mage": {
		"name": "术师",
		"trait": "特性：术师造成击杀时，有（10％ + 2％ × 等级）的概率触发3倍额外回能，每次触发3倍额外回能后获得一层[奥数充能]。术师大招能量积攒完毕后所造成的大招能量回复效果会施加到另外两名角色上。\n\n登场技：术师登场时会向周围释放雷击，同时进入[奥法盈余]状态。[奥法盈余]状态结束后为自身提供3层[奥数充能]。",
		"buff": "[奥法盈余]：术师在奥法盈余期间获得的大招能量会100％分享给另外两名角色。\n\n[奥数充能]：每一层为术师提供10％的回能效率增强、2.5％术师伤害加成以及10％分享给另外两名角色大招能量，最多10层。",
		"entry": ""
	}
}

@onready var tutorial_canvas: CanvasLayer = $CanvasLayer
@onready var tutorial_panel: PanelContainer = $CanvasLayer/TutorialPanel
@onready var tutorial_label: Label = $CanvasLayer/TutorialPanel/MarginContainer/TutorialLabel
@onready var continue_label: Label = $CanvasLayer/TutorialPanel/MarginContainer/ContinueLabel
@onready var switch_energy_arrow: Label = $CanvasLayer/SwitchEnergyArrow
@onready var role_intro_next_button: Button = $CanvasLayer/RoleIntroNextButton
@onready var role_intro_panel: PanelContainer = $CanvasLayer/RoleIntroPanel
@onready var role_intro_title: Label = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/Title
@onready var role_intro_trait: Label = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/TraitPanel/TraitLabel
@onready var role_intro_buff: Label = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/BuffPanel/BuffLabel
@onready var role_intro_entry: Label = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/EntryPanel/EntryLabel
@onready var role_intro_trait_panel: PanelContainer = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/TraitPanel
@onready var role_intro_buff_panel: PanelContainer = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/BuffPanel
@onready var role_intro_entry_panel: PanelContainer = $CanvasLayer/RoleIntroPanel/MarginContainer/Content/EntryPanel
@onready var tutorial_portal: Node2D = $TutorialPortal
@onready var tutorial_portal_interactable_shape: CollisionShape2D = $TutorialPortal/Interactable/CollisionShape2D
@onready var movement_target: Area2D = $MovementTarget
@onready var movement_target_shape: CollisionShape2D = $MovementTarget/CollisionShape2D
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var dummy_spawn: Marker2D = $DummySpawn

var player: CharacterBody2D
var hud: CanvasLayer
var training_dummy: Node2D
var current_step: TutorialStep = TutorialStep.MOVE_TO_MARKER
var switch_step: SwitchTutorialStep = SwitchTutorialStep.PREV_ROLE
var switch_energy_step: SwitchEnergyTutorialStep = SwitchEnergyTutorialStep.INTRO
var player_in_portal_range: bool = false
var hud_revealed: bool = false
var initial_role_id: String = "swordsman"
var expected_prev_role_id: String = ""
var expected_next_role_id: String = ""
var energy_switch_source_role_id: String = ""
var switch_energy_intro_token: int = 0
var ultimate_tutorial_role_id: String = ""
var attack_mode_hint_tutorial_tween: Tween
var role_intro_index: int = 0
var role_intro_tween: Tween
var pending_role_intro_token: int = 0
var ultimate_intro_scheduled: bool = false
var role_intro_completed: bool = false
var ultimate_cast_started: bool = false


func _ready() -> void:
	get_tree().paused = false
	tutorial_canvas.layer = 10
	_spawn_player()
	_spawn_hud()
	_spawn_training_dummy()
	tutorial_portal.visible = false
	switch_energy_arrow.visible = false
	role_intro_panel.visible = false
	role_intro_next_button.visible = false
	role_intro_completed = false
	role_intro_next_button.pressed.connect(_advance_role_intro)
	role_intro_trait_panel.mouse_entered.connect(_on_role_intro_panel_hovered.bind(role_intro_trait_panel))
	role_intro_buff_panel.mouse_entered.connect(_on_role_intro_panel_hovered.bind(role_intro_buff_panel))
	role_intro_entry_panel.mouse_entered.connect(_on_role_intro_panel_hovered.bind(role_intro_entry_panel))
	_update_player_hud_visibility(false)
	_set_player_attack_enabled(false)
	_update_step_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if current_step == TutorialStep.ROLE_INTRO:
			if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_INTERACT) or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_advance_role_intro()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE or GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
				_complete_role_intro_and_enter_endless()
				get_viewport().set_input_as_handled()
				return
		if current_step == TutorialStep.ENTER_PORTAL and player_in_portal_range and GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_INTERACT):
			_show_role_intro_panel()
			get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if current_step == TutorialStep.MOVE_TO_MARKER:
		_update_player_hud_visibility(false)
		_set_player_attack_enabled(false)
		_check_movement_target_reached()
	elif current_step == TutorialStep.ENTER_PORTAL:
		_update_portal_interaction_state()
	elif not hud_revealed:
		_reveal_combat_ui()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody2D
	player.name = "TutorialPlayer"
	player.global_position = player_spawn.global_position
	add_child(player)
	player.active_role_index = 0
	player._update_active_role_state()
	_set_player_attack_enabled(false)
	player.stats_changed.connect(_on_player_stats_changed)
	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.active_role_changed.connect(_on_player_active_role_changed)
	initial_role_id = str(player._get_active_role_id()) if player.has_method("_get_active_role_id") else "swordsman"


func _spawn_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	hud.visible = false
	add_child(hud)
	_refresh_hud()


func _spawn_training_dummy() -> void:
	training_dummy = TUTORIAL_DUMMY_SCRIPT.new()
	training_dummy.name = "TrainingDummy"
	training_dummy.global_position = dummy_spawn.global_position
	add_child(training_dummy)
	training_dummy.hit_registered.connect(_on_training_dummy_hit_registered)


func _refresh_hud() -> void:
	if hud == null or player == null:
		return
	if hud.has_method("update_stats"):
		hud.update_stats(player.get_stat_summary())
	if hud.has_method("update_health"):
		hud.update_health(player.current_health, player.max_health)
	if hud.has_method("update_mana"):
		hud.update_mana(player.current_mana, player.max_mana)
	if hud.has_method("update_experience"):
		hud.update_experience(player.experience, player.experience_to_next_level, player.level)
	if hud.has_method("update_time"):
		hud.update_time(0.0)


func _set_player_attack_enabled(enabled: bool) -> void:
	if player == null:
		return
	player.auto_attack_enabled = enabled
	if player.fire_timer == null:
		return
	if enabled:
		player._update_fire_timer()
	else:
		player.fire_timer.stop()


func _update_player_hud_visibility(visible_value: bool) -> void:
	if hud != null:
		hud.visible = visible_value
		var combat_skill_bar: Control = hud.get("combat_skill_bar") as Control
		if combat_skill_bar != null and combat_skill_bar.has_method("set_switch_widget_visible"):
			var should_show_switch_widget: bool = visible_value and (
				current_step == TutorialStep.SWITCH_ROLE
				or current_step == TutorialStep.SWITCH_ENERGY
				or current_step == TutorialStep.ULTIMATE
				or current_step == TutorialStep.ROLE_INTRO
				or current_step == TutorialStep.ENTER_PORTAL
			)
			combat_skill_bar.set_switch_widget_visible(should_show_switch_widget)
		_update_attack_mode_hint_tutorial_highlight()
	if player == null:
		return
	var health_bar: Node2D = player.get_node_or_null("PlayerHealthBar") as Node2D
	if health_bar != null:
		health_bar.visible = visible_value
	var duration_bar: Node2D = player.get_node_or_null("PlayerDurationStatusBar") as Node2D
	if duration_bar != null and not visible_value:
		duration_bar.visible = false


func _reveal_combat_ui() -> void:
	hud_revealed = true
	_update_player_hud_visibility(true)
	_set_player_attack_enabled(true)
	_refresh_hud()


func _check_movement_target_reached() -> void:
	if current_step != TutorialStep.MOVE_TO_MARKER:
		return
	if player == null or not is_instance_valid(player):
		return
	var circle_shape: CircleShape2D = movement_target_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	if player.global_position.distance_to(movement_target.global_position) <= circle_shape.radius:
		movement_target.visible = false
		current_step = TutorialStep.ATTACK_DUMMY
		_update_step_text()


func _update_portal_interaction_state() -> void:
	if player == null or not is_instance_valid(player):
		return
	var circle_shape: CircleShape2D = tutorial_portal_interactable_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	var in_range: bool = player.global_position.distance_to(tutorial_portal.global_position) <= circle_shape.radius
	if in_range == player_in_portal_range:
		return
	player_in_portal_range = in_range
	continue_label.text = "按 F 查看角色介绍" if player_in_portal_range else "前往传送门"


func _update_step_text() -> void:
	_update_tutorial_panel_layout()
	match current_step:
		TutorialStep.MOVE_TO_MARKER:
			tutorial_label.text = "使用 WASD 移动到发光标记点"
			continue_label.visible = false
		TutorialStep.ATTACK_DUMMY:
			tutorial_label.text = "现在去对幽影树人木桩造成伤害"
			continue_label.visible = false
		TutorialStep.SWITCH_ROLE:
			tutorial_label.text = "按 Q 切换上一名队友" if switch_step == SwitchTutorialStep.PREV_ROLE else "按 E 切换下一名队友"
			continue_label.visible = false
		TutorialStep.SWITCH_ENERGY:
			tutorial_label.text = "切人能量满后切换角色，会触发退场技和登场技" if switch_energy_step == SwitchEnergyTutorialStep.INTRO else "按 Q/E 切换角色释放登场技"
			continue_label.visible = false
		TutorialStep.ULTIMATE:
			tutorial_label.text = "终极技能能量收集完毕，按 R 释放你的终极技能"
			continue_label.visible = false
		TutorialStep.ROLE_INTRO:
			tutorial_label.text = ""
			continue_label.visible = false
		TutorialStep.ENTER_PORTAL:
			tutorial_label.text = "已完成切换教学。前往传送门进入无尽模式"
			continue_label.visible = true
			continue_label.text = "前往传送门"
			tutorial_portal.visible = true
	_update_switch_energy_arrow()
	_update_attack_mode_hint_tutorial_highlight()


func _update_tutorial_panel_layout() -> void:
	if tutorial_panel == null:
		return
	if current_step == TutorialStep.SWITCH_ROLE:
		tutorial_panel.anchor_left = 0.0
		tutorial_panel.anchor_right = 0.0
		tutorial_panel.anchor_top = 1.0
		tutorial_panel.anchor_bottom = 1.0
		tutorial_panel.offset_left = 18.0
		tutorial_panel.offset_top = -116.0
		tutorial_panel.offset_right = 222.0
		tutorial_panel.offset_bottom = -62.0
		return
	if current_step == TutorialStep.SWITCH_ENERGY:
		tutorial_panel.anchor_left = 0.0
		tutorial_panel.anchor_right = 0.0
		tutorial_panel.anchor_top = 1.0
		tutorial_panel.anchor_bottom = 1.0
		tutorial_panel.offset_left = 18.0
		tutorial_panel.offset_top = -178.0
		tutorial_panel.offset_right = 338.0
		tutorial_panel.offset_bottom = -108.0
		return
	if current_step == TutorialStep.ULTIMATE:
		tutorial_panel.anchor_left = 0.0
		tutorial_panel.anchor_right = 0.0
		tutorial_panel.anchor_top = 1.0
		tutorial_panel.anchor_bottom = 1.0
		tutorial_panel.offset_left = 364.0
		tutorial_panel.offset_top = -216.0
		tutorial_panel.offset_right = 704.0
		tutorial_panel.offset_bottom = -150.0
		return
	if current_step == TutorialStep.ROLE_INTRO:
		tutorial_panel.visible = false
		return
	tutorial_panel.visible = true
	tutorial_panel.anchor_left = 0.5
	tutorial_panel.anchor_top = 0.0
	tutorial_panel.anchor_right = 0.5
	tutorial_panel.anchor_bottom = 0.0
	tutorial_panel.offset_left = -250.0
	tutorial_panel.offset_top = 24.0
	tutorial_panel.offset_right = 250.0
	tutorial_panel.offset_bottom = 128.0


func _prepare_switch_tutorial_targets() -> void:
	var active_role_id: String = initial_role_id
	if player != null and player.has_method("_get_active_role_id"):
		active_role_id = str(player._get_active_role_id())
	var active_index: int = SWITCH_ROLE_ORDER.find(active_role_id)
	if active_index < 0:
		active_index = 0
	expected_prev_role_id = SWITCH_ROLE_ORDER[(active_index + SWITCH_ROLE_ORDER.size() - 1) % SWITCH_ROLE_ORDER.size()]
	expected_next_role_id = active_role_id


func _prepare_switch_energy_tutorial() -> void:
	if player == null:
		return
	energy_switch_source_role_id = str(player._get_active_role_id()) if player.has_method("_get_active_role_id") else ""
	if energy_switch_source_role_id == "":
		return
	switch_energy_step = SwitchEnergyTutorialStep.INTRO
	if player.has_method("_set_role_switch_energy"):
		player._set_role_switch_energy(energy_switch_source_role_id, float(player.SWITCH_ENTRY_ENERGY_REQUIRED))
	_start_switch_energy_intro_timer()


func _prepare_ultimate_tutorial() -> void:
	if player == null:
		return
	ultimate_tutorial_role_id = str(player._get_active_role_id()) if player.has_method("_get_active_role_id") else ""
	if ultimate_tutorial_role_id == "":
		return
	ultimate_intro_scheduled = false
	ultimate_cast_started = false
	if player.has_method("_set_role_mana"):
		player._set_role_mana(ultimate_tutorial_role_id, float(player.max_mana), false)
	if player.has_method("_emit_active_mana_changed"):
		player._emit_active_mana_changed()

func _schedule_portal_step_after_ultimate() -> void:
	if ultimate_intro_scheduled:
		return
	ultimate_intro_scheduled = true
	pending_role_intro_token += 1
	var intro_token: int = pending_role_intro_token
	call_deferred("_run_delayed_portal_step", intro_token)


func _run_delayed_portal_step(intro_token: int) -> void:
	var tree := get_tree()
	if tree == null:
		ultimate_intro_scheduled = false
		return
	await tree.create_timer(4.0).timeout
	if intro_token != pending_role_intro_token:
		return
	if current_step != TutorialStep.ULTIMATE:
		ultimate_intro_scheduled = false
		return
	ultimate_tutorial_role_id = ""
	ultimate_intro_scheduled = false
	ultimate_cast_started = false
	_enter_portal_step()


func _start_switch_energy_intro_timer() -> void:
	switch_energy_intro_token += 1
	var intro_token: int = switch_energy_intro_token
	call_deferred("_run_switch_energy_intro_timer", intro_token)


func _run_switch_energy_intro_timer(intro_token: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(2.0).timeout
	if intro_token != switch_energy_intro_token:
		return
	if current_step != TutorialStep.SWITCH_ENERGY:
		return
	switch_energy_step = SwitchEnergyTutorialStep.PROMPT_SWITCH
	_update_step_text()


func _update_switch_energy_arrow() -> void:
	if switch_energy_arrow == null:
		return
	switch_energy_arrow.visible = current_step == TutorialStep.SWITCH_ENERGY
	if not switch_energy_arrow.visible:
		return
	switch_energy_arrow.text = "↙"
	switch_energy_arrow.modulate = Color(1.0, 0.18, 0.18, 1.0)
	switch_energy_arrow.position = Vector2(192.0, get_viewport_rect().size.y - 162.0)


func _update_attack_mode_hint_tutorial_highlight() -> void:
	if hud == null:
		return
	var hint_panel: Control = hud.get("attack_mode_hint_panel") as Control
	if hint_panel == null:
		return
	if attack_mode_hint_tutorial_tween != null and attack_mode_hint_tutorial_tween.is_valid():
		attack_mode_hint_tutorial_tween.kill()
		attack_mode_hint_tutorial_tween = null
	hint_panel.scale = Vector2.ONE
	hint_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if current_step != TutorialStep.ATTACK_DUMMY:
		return
	attack_mode_hint_tutorial_tween = create_tween()
	attack_mode_hint_tutorial_tween.set_loops()
	attack_mode_hint_tutorial_tween.tween_property(hint_panel, "modulate", Color(1.0, 0.92, 0.52, 1.0), 0.28)
	attack_mode_hint_tutorial_tween.parallel().tween_property(hint_panel, "scale", Vector2(1.04, 1.04), 0.28)
	attack_mode_hint_tutorial_tween.tween_property(hint_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.28)
	attack_mode_hint_tutorial_tween.parallel().tween_property(hint_panel, "scale", Vector2.ONE, 0.28)


func _show_role_intro_panel() -> void:
	if role_intro_completed:
		_enter_endless_battle()
		return
	pending_role_intro_token += 1
	ultimate_intro_scheduled = false
	current_step = TutorialStep.ROLE_INTRO
	role_intro_index = 0
	role_intro_panel.visible = true
	role_intro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	role_intro_next_button.visible = true
	role_intro_next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_role_intro_next_button()
	tutorial_panel.visible = false
	switch_energy_arrow.visible = false
	_update_role_intro_card()
	_update_player_hud_visibility(true)

func _layout_role_intro_next_button() -> void:
	if role_intro_next_button == null:
		return
	role_intro_next_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	role_intro_next_button.anchor_left = 0.5
	role_intro_next_button.anchor_top = 1.0
	role_intro_next_button.anchor_right = 0.5
	role_intro_next_button.anchor_bottom = 1.0
	role_intro_next_button.offset_left = -82.0
	role_intro_next_button.offset_top = -164.0
	role_intro_next_button.offset_right = 82.0
	role_intro_next_button.offset_bottom = -120.0

func _update_role_intro_card() -> void:
	var role_id: String = ROLE_INTRO_ORDER[clamp(role_intro_index, 0, ROLE_INTRO_ORDER.size() - 1)]
	var content: Dictionary = ROLE_INTRO_CONTENT_OVERRIDE.get(role_id, ROLE_INTRO_CONTENT.get(role_id, {}))
	role_intro_title.text = str(content.get("name", role_id))
	role_intro_trait.text = str(content.get("trait", ""))
	role_intro_buff.text = str(content.get("buff", ""))
	role_intro_entry.text = str(content.get("entry", ""))
	role_intro_next_button.text = "下一页" if role_intro_index < ROLE_INTRO_ORDER.size() - 1 else "完成"
	_reset_role_intro_panels()


func _reset_role_intro_panels() -> void:
	if role_intro_tween != null and role_intro_tween.is_valid():
		role_intro_tween.kill()
	for panel in [role_intro_trait_panel, role_intro_buff_panel, role_intro_entry_panel]:
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
			panel.scale = Vector2.ONE


func _on_role_intro_panel_hovered(target_panel: PanelContainer) -> void:
	if target_panel == null:
		return
	_reset_role_intro_panels()
	role_intro_tween = create_tween()
	role_intro_tween.tween_property(target_panel, "modulate", Color(1.0, 0.92, 0.58, 1.0), 0.18)
	role_intro_tween.parallel().tween_property(target_panel, "scale", Vector2(1.01, 1.01), 0.18)
	role_intro_tween.tween_property(target_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
	role_intro_tween.parallel().tween_property(target_panel, "scale", Vector2.ONE, 0.18)


func _enter_portal_step() -> void:
	pending_role_intro_token += 1
	if role_intro_tween != null and role_intro_tween.is_valid():
		role_intro_tween.kill()
	role_intro_panel.visible = false
	role_intro_next_button.visible = false
	current_step = TutorialStep.ENTER_PORTAL
	_update_step_text()
	_update_player_hud_visibility(true)
	_refresh_hud()


func _complete_role_intro_and_enter_endless() -> void:
	pending_role_intro_token += 1
	role_intro_completed = true
	if role_intro_tween != null and role_intro_tween.is_valid():
		role_intro_tween.kill()
	role_intro_panel.visible = false
	role_intro_next_button.visible = false
	_enter_endless_battle()


func _enter_endless_battle() -> void:
	if SAVE_MANAGER.has_save(-1, SAVE_MANAGER.MODE_ENDLESS):
		SAVE_MANAGER.request_continue()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_training_dummy_hit_registered() -> void:
	if current_step != TutorialStep.ATTACK_DUMMY:
		return
	current_step = TutorialStep.SWITCH_ROLE
	switch_step = SwitchTutorialStep.PREV_ROLE
	_prepare_switch_tutorial_targets()
	_update_step_text()
	_update_player_hud_visibility(true)
	_refresh_hud()


func _on_player_active_role_changed(role_id: String, _role_name: String) -> void:
	if role_id == "":
		return
	if current_step == TutorialStep.SWITCH_ROLE:
		if switch_step == SwitchTutorialStep.PREV_ROLE:
			if role_id != expected_prev_role_id:
				return
			switch_step = SwitchTutorialStep.NEXT_ROLE
			_update_step_text()
			return
		if role_id != expected_next_role_id:
			return
		current_step = TutorialStep.SWITCH_ENERGY
		_prepare_switch_energy_tutorial()
		_update_step_text()
		_update_player_hud_visibility(true)
		_refresh_hud()
		return
	if current_step != TutorialStep.SWITCH_ENERGY:
		return
	if energy_switch_source_role_id == "" or role_id == energy_switch_source_role_id:
		return
	switch_energy_intro_token += 1
	current_step = TutorialStep.ULTIMATE
	energy_switch_source_role_id = ""
	_prepare_ultimate_tutorial()
	_update_step_text()
	_update_player_hud_visibility(true)
	_refresh_hud()


func _on_player_stats_changed(_summary: Dictionary) -> void:
	_refresh_hud()


func _on_player_health_changed(_current_health: float, _max_health: float) -> void:
	_refresh_hud()


func _on_player_mana_changed(_current_mana: float, _max_mana: float) -> void:
	if current_step == TutorialStep.ULTIMATE and not ultimate_cast_started and _current_mana < _max_mana:
		ultimate_cast_started = true
		_schedule_portal_step_after_ultimate()
	_refresh_hud()


func _on_player_experience_changed(_current_experience: int, _required_experience: int, _level: int) -> void:
	_refresh_hud()


func _advance_role_intro() -> void:
	if role_intro_index >= ROLE_INTRO_ORDER.size() - 1:
		_complete_role_intro_and_enter_endless()
		return
	role_intro_index += 1
	_update_role_intro_card()
