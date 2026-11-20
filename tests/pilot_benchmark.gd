extends "pilot_city_smoke.gd"

const TOUR := [88, 89, 90, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 142]


func _run() -> void:
	var route_check := "--route-check" in OS.get_cmdline_user_args()
	if not route_check and (DisplayServer.get_name() == "headless" or "--fixed-fps" in OS.get_cmdline_args()):
		push_error("Pilot benchmark requires a real window and wall-clock simulation")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var section_start := 0
	var section_limit := 0
	for argument in args:
		if argument.begins_with("--expected-gpu=") and not argument.trim_prefix("--expected-gpu=").to_lower() in RenderingServer.get_video_adapter_name().to_lower():
			push_error("Unexpected GPU: %s" % RenderingServer.get_video_adapter_name())
			quit(1)
			return
		if argument.begins_with("--section-limit="):
			var limit := argument.trim_prefix("--section-limit=")
			section_limit = int(limit) if limit.is_valid_int() and int(limit) > 0 else -1
		if argument.begins_with("--section-start="):
			var start := argument.trim_prefix("--section-start=")
			section_start = int(start) if start.is_valid_int() else -1
	var preset := "economy" if "--economy" in args else "medium"
	var long_session := "--long-session" in args
	var unbounded_proxies := "--unbounded-building-proxies" in args
	var section_end := TOUR.size() - 1 if section_limit == 0 else section_start + section_limit
	if section_start < 0 or section_limit < 0 or section_start >= section_end or section_end >= TOUR.size() or (long_session and (section_start != 0 or section_end != TOUR.size() - 1)):
		push_error("Invalid diagnostic section range")
		quit(1)
		return
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset(preset)
	settings.set_graphics("vsync", false)
	settings.set_graphics("fps_limit", 0)
	var started := Time.get_ticks_usec()
	change_scene_to_file(WORLD)
	await scene_changed
	FixtureInput.isolate()
	var entry_ms := (Time.get_ticks_usec() - started) / 1000.0
	var world := current_scene
	if unbounded_proxies:
		var lod := world.get_node("CityVisualLOD")
		if not lod.has_method("set_authored_ranges_enabled"):
			push_error("The packaged city does not support the building range experiment")
			quit(1)
			return
		lod.set_authored_ranges_enabled(false)
	var car: PlayerCar = world.get_node("PlayerCar")
	var camera := world.get_node("ChaseCamera")
	camera.set_process_unhandled_input(false)
	root.focus_entered.disconnect(camera._capture_mouse)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action in ACTIONS + ["reset_car", "pause", "camera_view", "camera_back", "headlights", "advance_time", "camera_look_left", "camera_look_right", "camera_look_up", "camera_look_down"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(16.5)
	var sections := _tour_sections()
	var path: PackedVector3Array = sections[section_start]
	_place(car, path[0], path[1] - path[0])
	Input.action_press("handbrake")
	if route_check:
		await _frames(20)
	else:
		await _wait_wall(10.0)
	var results: Array[Dictionary] = []
	var captures: Array[String] = []
	var capture := world.get_node("PerformanceCapture")
	var segmented := capture.has_method("start_segment")
	var transition_policy := "continuous rounded route split at shared frame boundaries; placement, settling and serialization outside measured tours" if segmented else "archived capture node; serialization between sections"
	var session_start := Time.get_ticks_usec()
	var measured_seconds := 0.0
	var leg := 0
	while leg == 0 or (long_session and measured_seconds < 600.0):
		if leg > 0:
			# Reset between tours is a declared transition outside measured legs.
			path = sections[0]
			_place(car, path[0], path[1] - path[0])
			Input.action_press("handbrake")
			cycle.set_hour(23.0 if leg % 2 else 16.5)
			await _wait_wall(1.0)
		await process_frame
		var boundary_usec := Time.get_ticks_usec()
		var boundary_unix := Time.get_unix_time_from_system()
		var tour_ok := true
		for section in range(section_start, section_end):
			path = sections[section]
			capture.benchmark_metadata = {"route_id": "pilot-three-districts-v4", "camera_policy": "automatic chase camera; physical mouse and gamepad events isolated", "section": section, "sections_per_tour": sections.size(), "target_kmh": 50.0, "warmup_seconds": 10.0, "entry_ms": entry_ms, "long_session": long_session, "leg": leg, "hour": cycle.hour, "unbounded_building_proxies": unbounded_proxies, "transition_policy": transition_policy, "scope": "rendered driving; exclusive-use status and memory target evaluated by runner context"}
			var section_started_usec := boundary_usec
			var section_started_unix := boundary_unix
			if not route_check:
				if segmented:
					capture.start_segment(section_started_usec, section_started_unix)
				else:
					capture.toggle()
			var result := await _drive(car, path, 50.0 / 3.6)
			await process_frame
			boundary_usec = Time.get_ticks_usec()
			var section_seconds := (boundary_usec - section_started_usec) / 1000000.0
			boundary_unix = section_started_unix + section_seconds
			if segmented:
				capture.finish_segment(boundary_usec)
				result["section_started_unix_seconds"] = section_started_unix
				result["section_finished_unix_seconds"] = boundary_unix
				result["section_duration_seconds"] = section_seconds
			elif not route_check:
				capture.finish()
				captures.append(capture.last_capture_path)
			results.append(result)
			measured_seconds += section_seconds
			print("Pilot benchmark tour %d section %d: %s" % [leg, section, result])
			if not result.arrived or result.ground_ratio < 0.99:
				tour_ok = false
				break
		if segmented:
			captures.append_array(capture.flush_segments())
		if not tour_ok:
			break
		leg += 1
	var file := FileAccess.open("user://pilot-benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"preset": preset, "route": TOUR, "sections_per_tour": sections.size(), "section_start": section_start, "results": results, "captures": captures, "entry_ms": entry_ms, "session_seconds": (Time.get_ticks_usec() - session_start) / 1000000.0, "measured_seconds": measured_seconds, "long_session": long_session, "gpu": RenderingServer.get_video_adapter_name(), "debug_build": OS.is_debug_build(), "package": FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://project.godot")}, "\t") + "\n")
	file.close()
	if not route_check:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://pilot-benchmark.png")
	world.queue_free()
	await process_frame
	quit.call_deferred(0 if results.all(func(result): return result.arrived and result.ground_ratio > 0.99) else 1)


# At low FPS, several physics ticks can occur between rendered frames. Apply
# steering on each tick so a slow GPU cannot change how the fixture drives.
func _drive_step() -> void:
	await physics_frame


func _wait_wall(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until:
		await process_frame


func _tour_sections() -> Array[PackedVector3Array]:
	# Split one rounded route, retaining the same waypoint on both sides of
	# each boundary. Independent two-node routes omit the connecting turns.
	var route := Layout.route(TOUR, 1.5)
	var sections: Array[PackedVector3Array] = []
	var start := 0
	for junction_index in range(1, TOUR.size() - 1):
		var junction := Layout.node(TOUR[junction_index])
		var boundary := start + 1
		var nearest := INF
		for index in range(start + 1, route.size() - 1):
			var distance := Vector2(route[index].x - junction.x, route[index].z - junction.z).length_squared()
			if distance < nearest:
				nearest = distance
				boundary = index
		sections.append(route.slice(start, boundary + 1))
		start = boundary
	sections.append(route.slice(start))
	return sections
