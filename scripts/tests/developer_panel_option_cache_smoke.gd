extends SceneTree

const DEVELOPER_PANEL := preload("res://scripts/developer/developer_panel.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := DEVELOPER_PANEL.new()
	root.add_child(panel)
	await process_frame

	var options: Array = []
	for index in range(300):
		options.append({
			"id": "skill_%03d" % index,
			"title": "技能 %03d" % index,
			"description": "测试技能"
		})
	panel.set_skill_options(options)
	var skill_list: VBoxContainer = panel.get("skill_list")
	assert(skill_list.get_child_count() == 300)
	var first_button_id := skill_list.get_child(0).get_instance_id()

	panel.set_skill_options(options.duplicate(true))
	assert(skill_list.get_child(0).get_instance_id() == first_button_id)

	options[0]["title"] = "已变化"
	panel.set_skill_options(options)
	assert(skill_list.get_child(0).get_instance_id() != first_button_id)
	assert((skill_list.get_child(0) as Button).text.begins_with("已变化"))

	print("DEVELOPER_PANEL_OPTION_CACHE_SMOKE_OK")
	panel.queue_free()
	await process_frame
	quit(0)
