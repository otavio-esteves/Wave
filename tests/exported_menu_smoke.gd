extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://project.godot"), "validation uses the exported resource package")
	_check(FileAccess.file_exists("res://scenes/world/cells/vale/manifest.json"), "world manifest is included in the exported package")
	var error := change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_check(error == OK, "export contains the main menu")
	await _frames(3)
	var menu := current_scene
	_check(root.gui_get_focus_owner() == menu.pilot_button, "pilot city is the default focused action")
	_check(menu.pilot_button.get_global_rect().intersects(root.get_visible_rect()), "pilot city is visible without scrolling")
	if not DisplayServer.get_name() == "headless":
		root.grab_focus()
		await _frames(3)
		root.get_texture().get_image().save_png("user://city-menu.png")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)
	_check(current_scene.scene_file_path == "res://scenes/city/drive_pilot_city.tscn", "Enter opens the exported pilot city")
	if current_scene.scene_file_path != "res://scenes/city/drive_pilot_city.tscn":
		_finish()
		return
	await create_timer(0.5).timeout
	var pilot_car := current_scene.get_node("PlayerCar")
	_check(current_scene.get_node("City").get_meta("block_count") == 72 and pilot_car.is_on_floor(), "export contains the connected seventy-two-block city with physical spawn support")
	var pilot_start: Vector3 = pilot_car.position
	Input.action_press("accelerate")
	await create_timer(2.0).timeout
	Input.action_release("accelerate")
	_check(pilot_car.position.distance_to(pilot_start) > 2 and pilot_car.is_on_floor(), "player drives on the exported pilot terrain")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "pilot city returns to the menu")
	current_scene.streaming_button.pressed.emit()
	await scene_changed
	if current_scene.scene_file_path != "res://scenes/world/drive_streamed_corridor.tscn":
		_check(false, "legacy streaming option opens the city walk")
		_finish()
		return
	_check(true, "legacy streaming option opens the city walk")
	var streamer := current_scene.get_node("WorldStreamer")
	var start := Time.get_ticks_msec()
	while streamer.blocked and Time.get_ticks_msec() - start < 15000:
		await process_frame
	_check(not streamer.blocked and streamer.failure_count == 0 and streamer.resident_count() > 0, "exported city loads cells and allows movement")
	if streamer.blocked:
		_finish()
		return
	await create_timer(1.0).timeout
	var car := current_scene.get_node("PlayerCar")
	var before: Vector3 = car.global_position
	Input.action_press("accelerate")
	await create_timer(2.0).timeout
	Input.action_release("accelerate")
	_check(car.global_position.distance_to(before) > 2.0 and car.is_on_floor(), "player drives on the exported city road")
	if not DisplayServer.get_name() == "headless":
		await _frames(3)
		root.get_texture().get_image().save_png("user://city-drive.png")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "city walk returns to the menu")
	_check(FileAccess.file_exists("res://scenes/world/cells/sol-serra/manifest.json"), "export contains the intercity manifest")
	current_scene.intercity_button.pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path == "res://scenes/world/drive_intercity.tscn", "export menu opens the continuous journey")
	streamer = current_scene.get_node("WorldStreamer")
	start = Time.get_ticks_msec()
	while streamer.blocked and Time.get_ticks_msec() - start < 15000:
		await process_frame
	_check(not streamer.blocked and streamer.records.size() == 4 and streamer.failure_count == 0, "exported journey loads its four-region manifest and urban support")
	current_scene.teleport_to(Vector3(3.5, 0.36, -1350))
	start = Time.get_ticks_msec()
	while streamer.blocked and Time.get_ticks_msec() - start < 15000:
		await process_frame
	await create_timer(0.3).timeout
	_check(not streamer.blocked and streamer.current_cell == "link-3" and streamer.failure_count == 0 and current_scene.get_node("PlayerCar").is_on_floor(), "exported remote town cell and shared resources provide real support")
	current_scene.queue_free()
	await _frames(3)
	await create_timer(0.3).timeout
	_finish()

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _finish() -> void:
	print("Exported access: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
