extends SceneTree

# Fixed street viewpoints compare city revisions at identical authored locations.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists("res://project.binary") or FileAccess.file_exists("res://project.godot"):
		push_error("Visual review requires exclusively the exported resources")
		quit(1)
		return
	print("PASS: visual review uses exclusively the exported resource package")
	if DisplayServer.get_name() == "headless":
		push_error("Composition review needs a rendered window")
		quit(1)
		return
	var output := "res://builds/previews/composition"
	var preset := "medium"
	var city_override := ""
	var baseline_grade := false
	var selected := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--preset="):
			preset = argument.trim_prefix("--preset=")
		if argument.begins_with("--views="):
			selected = argument.trim_prefix("--views=").split(",")
		if argument.begins_with("--city="):
			city_override = argument.trim_prefix("--city=")
		if argument == "--baseline-grade":
			baseline_grade = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var settings := root.get_node("WaveSettings")
	var previous: Dictionary = settings.graphics.duplicate(true)
	settings.set_graphics_preset(preset)
	var packed := load("res://scenes/city/drive_pilot_city.tscn") as PackedScene
	var instance := packed.instantiate()
	if not city_override.is_empty():
		instance.get_node("City").free()
		var previous_city: Node3D = load(city_override).instantiate()
		previous_city.name = "City"
		instance.add_child(previous_city)
	root.add_child(instance)
	current_scene = instance
	await process_frame
	preload("fixture_input.gd").isolate()
	var world := current_scene
	var player: PlayerCar = world.get_node("PlayerCar")
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_process(false)
	_set_hour(world, cycle, 16.5, baseline_grade)
	for frame in 12:
		await physics_frame
		await process_frame
	player.set_physics_process(false)
	if selected.is_empty() or "driving" in selected:
		await _capture(output, "driving")
	world.get_node("HUD/Overlay").hide()
	player.get_node("Visuals").hide()
	var camera := Camera3D.new()
	camera.far = 5000
	world.add_child(camera)
	camera.current = true
	var views: Array[Dictionary] = []
	for view in [{"name": "gardens-street", "a": 110, "b": 111}, {"name": "aurora-street", "a": 116, "b": 117}, {"name": "downtown-street", "a": 120, "b": 121}, {"name": "hillside-street", "a": 88, "b": 89}, {"name": "perimeter-street", "a": 3, "b": 4}]:
		var points := Layout.edge_points(view.a, view.b)
		var start := points[12]
		var target := points[mini(48, points.size() - 1)]
		views.append({"name": view.name, "position": start + Vector3.UP * 2.1, "target": target + Vector3.UP * 1.5, "hour": 16.5, "fov": 65.0})
	var centre := Layout.block_uv(145)
	views.append({"name": "park", "position": Layout.position(centre.x + 52, centre.y - 80, 28), "target": Layout.position(centre.x, centre.y - 15, 1), "hour": 16.5, "fov": 64.0})
	var garden := Layout.block_uv(105)
	views.append({"name": "neighborhood-aerial", "position": Layout.position(garden.x + 95, garden.y + 120, 115), "target": Layout.position(garden.x, garden.y, 2), "hour": 16.5, "fov": 64.0})
	var night: Dictionary = views[1].duplicate()
	night.name = "aurora-night"
	night.hour = 23.0
	var night_points := Layout.edge_points(116, 117)
	night.position = night_points[roundi((night_points.size() - 1) * 0.60)] + Vector3.UP * 2.1
	night.target = night_points[roundi((night_points.size() - 1) * 0.90)] + Vector3.UP * 1.5
	views.append(night)
	var midday: Dictionary = views[0].duplicate()
	midday.name = "gardens-midday"
	midday.hour = 12.0
	views.append(midday)
	for view in views:
		if not selected.is_empty() and view.name not in selected:
			continue
		player.position = view.position - Vector3.UP * 1.7
		world.get_node("CityVisualLOD").refresh(true)
		_set_hour(world, cycle, view.hour, baseline_grade)
		camera.position = view.position
		camera.fov = view.fov
		camera.look_at(view.target)
		await _capture(output, view.name)
	var city := world.get_node("City")
	var inventory := {}
	for key in ["visual_revision", "generator_version", "block_count", "parcel_count", "volumetric_tree_count", "grass_tuft_count", "parked_vehicle_count", "skyscraper_count", "district_parcels", "composition_counts"]:
		inventory[key] = city.get_meta(key) if city.has_meta(key) else null
	var context := FileAccess.open(output.path_join("context.json"), FileAccess.WRITE)
	context.store_string(JSON.stringify({"gpu": RenderingServer.get_video_adapter_name(), "preset": preset, "resolution": str(root.size), "views": views, "inventory": inventory, "city_override": city_override, "baseline_grade": baseline_grade, "selected_views": selected, "scope": "Static appearance review with authored fog, shadows and visibility ranges. No performance measurement or human approval."}, "\t"))
	world.queue_free()
	for frame in 5:
		await process_frame
	settings.graphics = previous
	settings.save_settings()
	print("Composition review: " + output)
	quit()

func _capture(output: String, label: String) -> void:
	current_scene.get_node("VehicleReflection").refresh()
	for frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + error_string(error))
		quit(1)

func _set_hour(world: Node3D, cycle: Node, hour: float, baseline_grade: bool) -> void:
	cycle.set_hour(hour)
	if baseline_grade:
		world.get_node("WorldEnvironment").environment.ambient_light_energy = lerpf(0.13, 0.42, cycle.daylight)
		world.get_node("Sun").light_energy = 1.12 * smoothstep(-0.035, 0.22, cycle.sun_direction.y)
		world.get_node("Sun").directional_shadow_max_distance = 90.0
		world.get_node("Moon").light_energy = 0.13 * cycle.night_factor
		for light in cycle._pool:
			light.omni_range = 17.0
			light.light_energy = 1.6 * cycle.night_factor
