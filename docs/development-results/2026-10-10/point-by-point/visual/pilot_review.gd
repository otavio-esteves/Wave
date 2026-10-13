extends SceneTree

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const FixtureInput = preload("fixture_input.gd")
var output := "user://pilot-review"
var contexts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual review requires a rendered window")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var preset := "medium" if "--medium" in OS.get_cmdline_user_args() else "economy"
	root.get_node("WaveSettings").set_graphics_preset(preset)
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	FixtureInput.isolate()
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var trip := world.get_node("CityTrip")
	trip.set_physics_process(false)
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause", "camera_view", "camera_back", "headlights", "advance_time"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	Input.action_press("handbrake")
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(16.5)
	trip.start()
	await _capture("spawn")
	for definition in [{"name": "square", "path": Layout.square_access()}, {"name": "workshop", "path": Layout.workshop_access()}]:
		var path: PackedVector3Array = definition.path
		car.reset_car()
		car.position = path[-1]
		var forward := path[-1] - path[-2]
		car.rotation = Vector3(0, atan2(-forward.x, -forward.z), 0)
		var physics := world.get_node_or_null("CityPhysics")
		if physics != null:
			physics.refresh()
		trip.state = "to_square" if definition.name == "square" else "to_workshop"
		trip._set_destination()
		trip._update_readout()
		world.get_node("ChaseCamera").snap_to_target()
		await _capture(definition.name)
	car.reset_car()
	trip.start()
	cycle.set_hour(23.0)
	await _capture("night")
	world.get_node("HUD").city_map.open_map()
	await _capture("map")
	var file := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "static views with the actual driving camera, presets, fog and visibility ranges; not FPS, route completion or human approval", "views": contexts}, "\t") + "\n")
	world.queue_free()
	await process_frame
	quit()


func _capture(name: String) -> void:
	for index in 30:
		await physics_frame
		await process_frame
	# State is frozen for a stable view; refresh the usual timed readout once.
	current_scene.get_node("CityTrip")._update_route_progress()
	current_scene.get_node("CityTrip")._update_readout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	var world := current_scene
	contexts.append({"name": name, "preset": root.get_node("WaveSettings").get_graphics_preset(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "viewport": str(root.size), "hour": world.get_node("DayNightCycle").hour, "position": str(world.get_node("PlayerCar").position), "generator": world.get_node("City").get_meta("generator_version"), "active_solid_shapes": world.get_node("CityPhysics").active_shapes if world.has_node("CityPhysics") else null})
