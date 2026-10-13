extends Node

# Entry point for a separate diagnostic export, never the game's main scene.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const Statistics = preload("res://scripts/tools/frame_statistics.gd")
const WORLD := "res://scenes/city/drive_pilot_city.tscn"
const DEFAULT_CASES := ["no-3d", "no-scripts", "no-physics", "no-sky", "no-foliage", "no-triplanar", "short-range", "half-resolution"]
const MONITORS := {
	"process_ms": Performance.TIME_PROCESS,
	"physics_ms": Performance.TIME_PHYSICS_PROCESS,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"static_memory_bytes": Performance.MEMORY_STATIC,
	"render_memory_bytes": Performance.RENDER_VIDEO_MEM_USED,
}
var world: Node3D
var geometry: Array[Dictionary] = []
var environment: Environment
var environment_defaults: Dictionary = {}
var plain_materials: Dictionary = {}
var base_size := Vector2i(854, 480)
var output := "user://pilot-profile"
var seconds := 6.0
var warmup := 2.0
var results: Array[Dictionary] = []
var events: FileAccess


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cases: Array = DEFAULT_CASES.duplicate()
	var views := [113]
	var preset := "economy"
	var expected_gpu := ""
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"--output": output = parts[1]
			"--seconds": seconds = maxf(0.1, float(parts[1]))
			"--warmup": warmup = maxf(0.0, float(parts[1]))
			"--preset": preset = parts[1]
			"--expected-gpu": expected_gpu = parts[1].to_lower()
			"--cases": cases.assign(parts[1].split(",", false))
			"--views":
				views.clear()
				for value in parts[1].split(","):
					views.append(int(value))
	if DisplayServer.get_name() == "headless" and "--validate-profile" not in OS.get_cmdline_user_args():
		push_error("Profiling requires a rendered window")
		get_tree().quit(1)
		return
	if not expected_gpu.is_empty() and not expected_gpu in RenderingServer.get_video_adapter_name().to_lower():
		push_error("GPU mismatch: expected %s, found %s" % [expected_gpu, RenderingServer.get_video_adapter_name()])
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		get_tree().quit(1)
		return
	events = FileAccess.open(output.path_join("events.jsonl"), FileAccess.WRITE)
	var settings := get_node("/root/WaveSettings")
	settings.set_graphics_preset(preset)
	settings.set_graphics("vsync", false)
	settings.set_graphics("fps_limit", 0)
	base_size = get_tree().root.size
	_event({"event": "loading", "debug_build": OS.is_debug_build(), "gpu": RenderingServer.get_video_adapter_name()})
	var started := Time.get_ticks_usec()
	world = load(WORLD).instantiate()
	add_child(world)
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
		Input.action_release(action)
	Input.action_press("handbrake")
	var camera := world.get_node("ChaseCamera")
	camera.set_process_unhandled_input(false)
	get_tree().root.focus_entered.disconnect(camera._capture_mouse)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(16.5)
	environment = world.get_node("WorldEnvironment").environment
	for property in ["background_mode", "ambient_light_source", "reflected_light_source"]:
		environment_defaults[property] = environment.get(property)
	for node in world.get_node("City").find_children("*", "GeometryInstance3D", true, false):
		geometry.append({"node": node, "visible": node.visible, "end": node.visibility_range_end, "margin": node.visibility_range_end_margin, "material": node.material_override})
	_event({"event": "loaded", "entry_ms": (Time.get_ticks_usec() - started) / 1000.0, "geometries": geometry.size()})
	for view in views:
		_place(view)
		await get_tree().create_timer(3.0).timeout
		await _capture(view, "baseline", "initial")
		for case in cases:
			_apply(case)
			await get_tree().create_timer(warmup).timeout
			await _capture(view, case, "ablation")
			_restore()
			await get_tree().create_timer(warmup).timeout
			await _capture(view, "baseline", "after-" + case)
	_restore()
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"scope": "static diagnostic ablations; shared machine, no exclusive-use or product certification; no GPU timestamp queries",
		"debug_build": OS.is_debug_build(), "engine": Engine.get_version_info(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"preset": preset, "base_window_size": str(base_size), "warmup_seconds": warmup,
		"capture_seconds_requested": seconds, "results": results,
	}, "\t") + "\n")
	file.close()
	_event({"event": "completed", "captures": results.size()})
	events.close()
	geometry.clear()
	plain_materials.clear()
	environment = null
	world.queue_free()
	world = null
	for index in 10:
		await get_tree().process_frame
	get_tree().quit()


func _place(view: int) -> void:
	var path := Layout.route([view, view + 1], 1.5)
	var car: PlayerCar = world.get_node("PlayerCar")
	car.reset_car()
	car.position = path[path.size() / 2] + Vector3.UP * 0.05
	var forward := path[-1] - path[0]
	car.rotation = Vector3(0, atan2(-forward.x, -forward.z), 0)
	car.velocity = Vector3.ZERO
	world.get_node("CityPhysics").refresh()
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		visual_lod.refresh(true)
	world.get_node("ChaseCamera").snap_to_target()


func _apply(case: String) -> void:
	match case:
		"authored-detail": world.get_node("CityVisualLOD").set_economy_enabled(false)
		"no-3d": get_tree().root.disable_3d = true
		"no-scripts": world.process_mode = Node.PROCESS_MODE_DISABLED
		"no-physics": PhysicsServer3D.space_set_active(world.get_world_3d().space, false)
		"no-sky":
			environment.background_mode = Environment.BG_COLOR
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"half-resolution": get_tree().root.size = Vector2i(640, 360)
		"no-foliage", "short-range", "no-triplanar", "no-floor-far":
			for record in geometry:
				var node: GeometryInstance3D = record.node
				var material := record.material as StandardMaterial3D
				if case == "no-floor-far" and node.get_meta("surface_kind", "") == "FloorFar":
					node.hide()
				elif case == "no-foliage" and material != null and material.resource_name == "tree_leaves":
					node.hide()
				elif case == "short-range" and node.get_meta("surface_kind", "") not in ["FloorFar", "Terrain", "Streets", "Sidewalks", "BackgroundLandscape"]:
					node.visibility_range_end = minf(record.end, 240.0) if record.end > 0 else 240.0
					node.visibility_range_end_margin = 0.0
				elif case == "no-triplanar" and material != null and material.uv1_triplanar:
					if not plain_materials.has(material):
						var copy := material.duplicate() as StandardMaterial3D
						copy.uv1_triplanar = false
						copy.uv1_world_triplanar = false
						plain_materials[material] = copy
					node.material_override = plain_materials[material]
		_:
			push_error("Unknown diagnostic case: " + case)
			get_tree().quit(1)


func _restore() -> void:
	get_tree().root.disable_3d = false
	get_tree().root.size = base_size
	world.process_mode = Node.PROCESS_MODE_INHERIT
	PhysicsServer3D.space_set_active(world.get_world_3d().space, true)
	for property in environment_defaults:
		environment.set(property, environment_defaults[property])
	for record in geometry:
		record.node.visible = record.visible
		record.node.visibility_range_end = record.end
		record.node.visibility_range_end_margin = record.margin
		record.node.material_override = record.material
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		visual_lod.set_economy_enabled(bool(get_node("/root/WaveSettings").graphics["city_lod"]))


func _capture(view: int, case: String, phase: String) -> void:
	_event({"event": "capture", "view": view, "case": case, "phase": phase})
	var frames: Array[float] = []
	var samples: Array[Dictionary] = []
	var focus: Array[bool] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var last_sample := start
	while Time.get_ticks_usec() - start < seconds * 1000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - previous) / 1000.0)
		focus.append(get_tree().root.has_focus())
		previous = now
		if now - last_sample >= 500000:
			var sample := {"elapsed_seconds": (now - start) / 1000000.0}
			for key in MONITORS:
				var value := Performance.get_monitor(MONITORS[key])
				sample[key] = value * 1000.0 if key.ends_with("_ms") else value
			sample["active_solid_shapes"] = world.get_node("CityPhysics").active_shapes
			samples.append(sample)
			last_sample = now
	var result := Statistics.summarize(frames)
	result.merge({"view": view, "case": case, "phase": phase, "frames": frames.size(), "duration_seconds": (previous - start) / 1000000.0, "focused_frames": focus.count(true), "unfocused_frames": focus.count(false), "window_size": str(get_tree().root.size), "samples": samples})
	results.append(result)
	var basename := "%02d-view%d-%s" % [results.size(), view, case]
	var csv := FileAccess.open(output.path_join(basename + ".csv"), FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["frame", "frame_ms", "focused"]))
	for index in frames.size():
		csv.store_csv_line(PackedStringArray([str(index), str(frames[index]), str(focus[index])]))
	csv.close()
	var json := FileAccess.open(output.path_join(basename + ".json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(result, "\t") + "\n")
	json.close()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output.path_join(basename + ".png"))
	_event({"event": "captured", "file": basename, "fps": result.average_fps, "p99_ms": result.p99_frame_ms})


func _event(data: Dictionary) -> void:
	data["monotonic_usec"] = Time.get_ticks_usec()
	events.store_line(JSON.stringify(data))
	events.flush()
