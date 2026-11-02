extends SceneTree

const MENU := preload("res://scripts/camp/cat_village_menu_replica.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var menu := MENU.new()
	root.add_child(menu)
	await process_frame
	_expect(menu.pages.size() == 5, "All five Unity tab pages should be reconstructed.")
	_expect(menu.tabs.size() == 5, "All five original tab images should be available.")
	_expect(menu.tabs[0].texture_normal != null, "The original character tab texture should load.")
	_expect(menu.find_children("*", "Label", true, false).size() > 0, "Extracted TMP strings should render as labels.")
	_expect(menu.find_children("*", "Button", true, false).size() > 0, "Extracted selectable controls should be interactive.")
	menu.open_menu()
	_expect(menu.visible and menu.pages[0].visible, "Opening should show the first page.")
	for index in range(5):
		menu._select_tab(index)
		_expect(menu.pages[index].visible, "Tab %d should show its matching page." % index)
		for other in range(5):
			if other != index:
				_expect(not menu.pages[other].visible, "Only one page should be visible.")
	_expect(menu.find_children("*", "TextureRect", true, false).size() > 40, "The extracted page art should be rendered.")
	menu.close_menu()
	_expect(not menu.visible, "Closing should hide the menu.")
	if failures.is_empty():
		print("CAT_VILLAGE_MENU_REPLICA_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
