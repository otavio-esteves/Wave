extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	var menu := current_scene
	menu._load_world("res://missing-map.tscn")
	_check(menu.load_error.visible and menu.buttons_scroll.visible and menu.loading_path.is_empty(), "missing map presents a recoverable error without leaving the menu")
	menu.drive_button.pressed.emit()
	_check(menu.loading_panel.visible and not menu.buttons_scroll.visible and not menu.load_error.visible, "loading displays progress immediately and clears the previous error")
	menu.pilot_button.pressed.emit()
	_check(menu.loading_path == "res://scenes/city/drive_neighborhood.tscn", "repeated selection cannot start a second concurrent map request")
	await scene_changed
	_check(current_scene.scene_file_path == "res://scenes/city/drive_neighborhood.tscn", "background loading eventually opens the selected world")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await scene_changed
	menu = current_scene
	menu.pilot_button.pressed.emit()
	var frames := 0
	while is_instance_valid(menu) and current_scene == menu:
		await process_frame
		frames += 1
	_check(frames >= 2 and current_scene.has_node("PlayerCar"), "city loading gives the UI frames to render before attaching the prepared world")
	current_scene.queue_free()
	await process_frame
	print("City loading: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)
