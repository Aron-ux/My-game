extends Control

signal closed
signal prepare_requested

const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ROLES := preload("res://scripts/player/roles/role_database.gd")
const PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")

var modal: Control
var body: VBoxContainer
var role_id := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modal = MODAL.new()
	add_child(modal)
	modal.configure(Vector2(820, 570), 0.70, 0.83, Vector2(480, 360))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.set_body(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	scroll.add_child(body)
	modal.add_footer_button("关闭", close_panel)
	modal.add_footer_button("整备队伍", _prepare, "primary")
	hide()


func open(id: String, team: Array) -> void:
	role_id = id
	modal.set_title(PRESENTER.get_role_name(id) + " · 驻营")
	var slot := team.find(id)
	modal.set_hint("当前阵容第 %d 位，1 号位为下一局首发。" % (slot + 1) if slot >= 0 else "候补成员，可在队伍整备中加入下一局阵容。")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_add_text(str(PRESENTER.ROLE_DESCRIPTIONS.get(id, "")), 18)
	for role in ROLES.ROLE_DATA:
		if str(role["id"]) == id:
			_add_text("基础生命 %.0f    攻击 %.0f    攻速 %.2f 次/秒\n移动速度 %.0f    护甲 %.0f" % [role["base_health"], role["damage"], role["base_attack_speed"], role["move_speed"], role["armor"]], 17)
	var actives: PackedStringArray = []
	for progress in LEVELS.get_role_progress_ids(id):
		if LEVELS.UNLOCKABLE_PROGRESS.has(progress):
			actives.append(LEVELS.get_progress_title(progress))
	_add_text("可解锁主动技能\n" + "、".join(actives), 17)
	_add_text("终结技\n" + LEVELS.get_progress_title(id + "_ultimate"), 17)
	_add_text("基础属性未计携带物品与局内成长。主动技能在战斗升级时通过「获得技能」卡解锁，技能达到 5 / 10 级获得对应天赋位。", 15, UI.COLOR_TEXT_MUTED)
	show()
	modal.apply_layout()
	modal.footer.get_child(1).grab_focus()


func _add_text(value: String, font_size: int, color: Color = UI.COLOR_TEXT) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	body.add_child(label)


func close_panel() -> void:
	if visible:
		hide()
		closed.emit()


func _prepare() -> void:
	close_panel()
	prepare_requested.emit()
