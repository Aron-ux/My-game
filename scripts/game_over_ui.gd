extends CanvasLayer

signal restart_requested

var dimmer: ColorRect
var panel: PanelContainer
var title_label: Label
var message_label: Label
var restart_button: Button

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.8)
	root.add_child(dimmer)

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_container)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 220)
	center_container.add_child(panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "战斗结束"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	message_label = Label.new()
	message_label.text = "你坚持了 00:00"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message_label)

	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(180, 44)
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)

	hide_ui()

func show_game_over(survival_time: float, level: int) -> void:
	var total_seconds := int(floor(survival_time))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	title_label.text = "战斗失败"
	message_label.text = "你坚持了 %02d:%02d\n到达等级 %d" % [minutes, seconds, level]
	visible = true

func show_victory(survival_time: float, level: int) -> void:
	var total_seconds := int(floor(survival_time))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	title_label.text = "胜利"
	message_label.text = "你完成了本轮关卡\n用时 %02d:%02d  等级 %d" % [minutes, seconds, level]
	visible = true

func hide_ui() -> void:
	visible = false

func _on_restart_pressed() -> void:
	restart_requested.emit()
