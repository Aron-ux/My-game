extends RefCounted

static func toggle_menu(main: Node) -> void:
	if main.cat_village_menu == null:
		return
	if main.cat_village_menu.visible:
		hide_menu(main)
		return
	if main.character_panel != null and main.character_panel.visible:
		return
	main.get_tree().paused = true
	main.cat_village_menu.open_menu()


static func hide_menu(main: Node) -> void:
	if main.cat_village_menu == null:
		return
	main.cat_village_menu.hide_panel()
	if main.character_panel == null or not main.character_panel.visible:
		main.get_tree().paused = false
