extends "res://tests/pilot_city_smoke.gd"

const Navigation = preload("res://scripts/city/pilot_city_navigation.gd")


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file(WORLD)
	await scene_changed
	FixtureInput.isolate()
	for action in ACTIONS + ["reset_car"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	await _frames(12)
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var trip := world.get_node("CityTrip")
	_check(trip.state == "idle" and not trip.panel.visible, "exploration starts freely without forcing an activity")
	var hud := world.get_node("HUD")
	_check(hud.get_node("Overlay/Controls").text.length() < 160 and not hud.help_panel.visible, "pilot HUD has concise hints and optional full controls")
	_check(not hud.buttons.get_node("Race").visible and not hud.buttons.get_node("Rally").visible, "city pause menu prioritizes the pilot activity")
	hud.set_paused(true)
	hud.graphics_options.open()
	hud._toggle_help()
	_check(hud.help_panel.visible and not hud.graphics_options.visible and not hud.buttons.visible, "paused help closes settings and avoids overlapping menus")
	var back := InputEventAction.new()
	back.action = "pause"
	back.pressed = true
	hud._unhandled_input(back)
	_check(paused and not hud.help_panel.visible and hud.buttons.visible, "closing help returns to the existing pause menu")
	hud.set_paused(false)
	hud.city_map.open_map()
	var help := InputEventAction.new()
	help.action = "driving_help"
	help.pressed = true
	hud._unhandled_input(help)
	_check(not hud.help_panel.visible, "full map cannot activate a hidden help overlay")
	hud.city_map.close_map()
	var navigation := Navigation.new()
	var path := navigation.shortest_path(150, 69)
	var connected: bool = not path.is_empty() and path.front() == 150 and path.back() == 69
	for index in path.size() - 1:
		connected = connected and navigation.adjacency[path[index]].any(func(edge): return edge.node == path[index + 1])
	_check(connected, "navigation uses connected streets between the residential and workshop districts")
	var start_key := InputEventKey.new()
	start_key.physical_keycode = KEY_T
	start_key.pressed = true
	FixtureInput.inject(start_key)
	await _frames(2)
	start_key.pressed = false
	FixtureInput.inject(start_key)
	await _frames(2)
	_check(trip.state == "to_square" and trip.route.size() > 100 and trip.panel.visible, "starting the activity creates road guidance to the square")
	_check(root.get_visible_rect().encloses(trip.panel.get_global_rect()) and not trip.panel.get_global_rect().intersects(hud.get_node("Overlay/Telemetry").get_global_rect()), "activity remains on screen without obscuring telemetry")
	var toggle := InputEventJoypadButton.new()
	toggle.button_index = JOY_BUTTON_DPAD_UP
	toggle.pressed = true
	FixtureInput.inject(toggle)
	await _frames(2)
	_check(trip.state == "idle", "actual gamepad activity input cancels guidance")
	toggle.pressed = false
	FixtureInput.inject(toggle)
	await _frames(2)
	toggle.pressed = true
	FixtureInput.inject(toggle)
	await _frames(2)
	_check(trip.state == "to_square", "actual gamepad activity input restarts the optional trip")
	toggle.pressed = false
	FixtureInput.inject(toggle)
	await _frames(2)
	var route: PackedVector3Array = trip.route.duplicate()
	# Remove consecutive coincident points at graph joins before the driver.
	var clean := PackedVector3Array([route[0]])
	for point in route:
		if Vector2(point.x - clean[-1].x, point.z - clean[-1].z).length() > 0.01:
			clean.append(point)
	var result := await _drive(car, clean, 10.0, _access_junctions())
	_check(result.arrived and result.ground_ratio > 0.99 and trip.state == "to_square", "real inputs reach the square without prematurely awarding arrival")
	Input.action_press("handbrake")
	# Wait for an actual supported stop, rather than assuming a one-second brake.
	for frame in 180:
		await _frames(1)
		if trip.parked_seconds > 0.0:
			break
	_check(trip.parked_seconds > 0 and trip.state == "to_square", "grounded parking starts the square arrival dwell")
	var dwell: float = trip.parked_seconds
	hud.set_paused(true)
	await _frames(120)
	_check(trip.parked_seconds == dwell and trip.state == "to_square", "pause freezes activity progress")
	hud.set_paused(false)
	await _frames(130)
	_check(trip.state == "to_workshop" and trip.route.size() > 100, "square arrival advances to a road route into the workshop yard")
	Input.action_release("handbrake")
	var access := Layout.square_access()
	var nearest := INF
	var start := 0
	var projection := car.position
	for index in access.size() - 1:
		var point := Geometry3D.get_closest_point_to_segment(car.position, access[index], access[index + 1])
		if point.distance_squared_to(car.position) < nearest:
			nearest = point.distance_squared_to(car.position)
			start = index
			projection = point
	var departure := PackedVector3Array([car.position, projection])
	for index in range(start, -1, -1):
		departure.append(access[index])
	# Back into the near lane before turning forward, using a real three-point manoeuvre.
	var exit := access[0] + (access[0] - access[1]).normalized() * 4.0
	exit.y = Layout.height_at(exit.x, exit.z) + Layout.CAR_LIFT
	departure.append(exit)
	result = await _drive(car, departure, 3.0, _access_junctions(), true)
	_check(result.arrived and result.ground_ratio > 0.99, "real reverse inputs leave the square through its paved access")
	Input.action_press("handbrake")
	await _frames(90)
	Input.action_release("handbrake")
	route = trip.route.slice(trip.route_cursor + 1)
	clean = PackedVector3Array([car.position])
	for point in route:
		if Vector2(point.x - clean[-1].x, point.z - clean[-1].z).length() > 0.01:
			clean.append(point)
	result = await _drive(car, clean, 10.0, _access_junctions())
	_check(result.arrived and result.ground_ratio > 0.99, "real inputs follow the second route and enter the workshop yard")
	Input.action_press("handbrake")
	await _frames(190)
	_check(trip.state == "complete" and trip.route.is_empty(), "two legitimate parked arrivals complete the optional activity")
	car.reset_car()
	await _frames(10)
	_check(trip.state == "to_square" and trip.parked_seconds == 0, "car reset restarts the current activity without preserving arrival credit")
	car.position = trip.destination
	await _frames(180)
	_check(trip.state == "interrupted" and trip.parked_seconds == 0, "teleporting to the destination cannot complete an activity")
	trip.cancel()
	_check(trip.state == "idle" and not trip.panel.visible and trip.route.is_empty(), "cancelling removes guidance and restores free exploration")
	_release()
	world.queue_free()
	await _frames(3)
	print("Pilot trip: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _access_junctions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for access in [Layout.square_access(), Layout.workshop_access()]:
		result.append(Vector2(access[0].x, access[0].z))
	return result
