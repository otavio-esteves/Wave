extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "map_zoom_in", "map_zoom_out"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	for frame in 4:
		await physics_frame
		await process_frame
	var world := current_scene
	var map := world.get_node("HUD/Overlay/CityMap")
	var car := world.get_node("PlayerCar")
	var cycle := world.get_node("DayNightCycle")
	_check(not map.visible and map.roads.size() == 430 and not map.lots.is_empty(), "full map caches all roads and authored lots without opening at spawn")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_check(map.visible and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "M opens the full map, pauses driving and releases the cursor")
	var position: Vector3 = car.position
	var hour: float = cycle.hour
	for frame in 5:
		await process_frame
	_check(car.position == position and cycle.hour == hour, "map inspection freezes the car and world clock")
	var center := InputEventJoypadButton.new()
	center.button_index = JOY_BUTTON_RIGHT_STICK
	center.pressed = true
	Input.parse_input_event(center)
	await process_frame
	_check(map.project(Vector2(car.position.x, car.position.z)).distance_to(map.map_center()) < 0.01 and map.zoom == 2, "R3 centers the actual car at the map cursor")
	Input.action_press("map_zoom_in")
	for frame in 5:
		await process_frame
	Input.action_release("map_zoom_in")
	_check(map.zoom > 2, "analog map zoom works while the game is paused")
	map.set_marker(map.map_center())
	_check(map.marker.distance_to(Vector2(car.position.x, car.position.z)) < 0.01, "marker projection agrees with the car's world position")
	map.locate(preload("res://scripts/city/pilot_city_layout.gd").block_uv(145))
	_check(map.marker.is_finite() and map.project(map.marker).distance_to(map.map_center()) < 0.01, "square shortcut places and centers a marker")
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	_check(not map.visible and not paused, "Escape closes the map and resumes driving")
	car.position += Vector3(12, 0, 0)
	var before_cancel: Vector3 = car.position
	var share := InputEventJoypadButton.new()
	share.button_index = JOY_BUTTON_BACK
	share.pressed = true
	Input.parse_input_event(share)
	await process_frame
	_check(map.visible and paused, "Share opens the map through the actual gamepad input path")
	var reset_binding := InputEventJoypadButton.new()
	reset_binding.device = 99
	reset_binding.button_index = JOY_BUTTON_B
	InputMap.action_add_event("reset_car", reset_binding)
	var circle := InputEventJoypadButton.new()
	circle.device = 99
	circle.button_index = JOY_BUTTON_B
	circle.pressed = true
	Input.parse_input_event(circle)
	await process_frame
	_check(not map.visible and not paused and car.position.distance_to(before_cancel) < 0.5, "Circle returns to driving without resetting the car")
	circle.pressed = false
	share.pressed = false
	Input.parse_input_event(circle)
	Input.parse_input_event(share)
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var opened_again: bool = map.visible
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	_check(opened_again and not map.visible and not paused, "M toggles the map back to driving through focused GUI input")
	world.get_node("HUD").set_paused(true)
	map.open_map()
	map.close_map()
	_check(paused and world.get_node("HUD/Overlay/PauseMenu").visible, "map opened from pause returns to the existing pause menu")
	world.get_node("HUD").set_paused(false)
	_check(InputMap.action_get_events("city_map").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK), "DualShock Share opens the city map")
	world.queue_free()
	await process_frame
	print("City map: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
