extends Node

# Entry point for a separate diagnostic export, never the game's main scene.
const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const Statistics = preload("res://scripts/tools/frame_statistics.gd")
const ProxyExperiment = preload("res://scripts/tools/pilot_proxy_experiment.gd")
const FoliageLOD = preload("res://scripts/city/pilot_foliage_lod.gd")
const WORLD := "res://scenes/city/drive_pilot_city.tscn"
const OCCLUSION_CACHE := "res://assets/geometry/pilot-occlusion-experiment.res"
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
var hour := 16.5
var results: Array[Dictionary] = []
var events: FileAccess
var _cycle_defaults: Dictionary = {}
var _sky_defaults: Dictionary = {}
var _compact_near_defaults: Array[Dictionary] = []
var _occlusion_original := false
var _diagnostic_occluder: OccluderInstance3D
var _requested_preset := "economy"
var _proxy_experiment := ProxyExperiment.new()
var _diagnostic_blossoms: Node3D


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
			"--hour":
				if not _set_hour_argument(parts[1]):
					push_error("Profile hour must be a finite number")
					get_tree().quit(1)
					return
			"--preset": preset = parts[1]
			"--expected-gpu": expected_gpu = parts[1].to_lower()
			"--cases": cases.assign(parts[1].split(",", false))
			"--views":
				views.clear()
				for value in parts[1].split(","):
					views.append(int(value))
	_requested_preset = preset
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
	cycle.set_hour(hour)
	_cycle_defaults = {"elapsed": cycle._elapsed, "lighting_timer": cycle._lighting_timer, "lamp_timer": cycle._lamp_timer, "day_duration_seconds": cycle.day_duration_seconds}
	environment = world.get_node("WorldEnvironment").environment
	_remember_environment_defaults()
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
		"scope": "fixed-view diagnostic ablations; clock baseline locked, running-cycle and incremental-sky opt-in; shared machine, no exclusive-use or product certification; no GPU timestamp queries",
		"debug_build": OS.is_debug_build(), "engine": Engine.get_version_info(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"preset": preset, "base_window_size": str(base_size), "warmup_seconds": warmup,
		"capture_seconds_requested": seconds, "hour": hour, "results": results,
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
	var started := Time.get_ticks_usec()
	car.reset_car()
	var reset := Time.get_ticks_usec()
	car.position = path[path.size() / 2] + Vector3.UP * 0.05
	var forward := path[-1] - path[0]
	car.rotation = Vector3(0, atan2(-forward.x, -forward.z), 0)
	car.velocity = Vector3.ZERO
	world.get_node("CityPhysics").refresh()
	var physical := Time.get_ticks_usec()
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		visual_lod.refresh(true)
	var structural := Time.get_ticks_usec()
	var foliage_lod := world.get_node_or_null("CityFoliageLOD")
	if foliage_lod != null:
		foliage_lod.refresh(true)
	var foliage := Time.get_ticks_usec()
	world.get_node("ChaseCamera").snap_to_target()
	_event({"event": "placed", "view": view, "reset_wall_ms": (reset - started) / 1000.0, "physics_and_placement_wall_ms": (physical - reset) / 1000.0, "structural_refresh_wall_ms": (structural - physical) / 1000.0, "foliage_refresh_wall_ms": (foliage - structural) / 1000.0, "total_wall_ms": (Time.get_ticks_usec() - started) / 1000.0})


func _apply(case: String) -> void:
	match case:
		"blossom-hlod":
			if not _apply_blossom_hlod():
				push_error("Blossom experiment requires active city LOD and the nonempty layer13 atlas")
				get_tree().quit(1)
		"no-blossoms":
			if is_instance_valid(_diagnostic_blossoms):
				_diagnostic_blossoms.set_canopy_visible(false)
			for record in geometry:
				if record.material is StandardMaterial3D and record.material.resource_name in ["blossom_gold", "blossom_violet"]:
					record.node.hide()
		"no-far-buildings", "no-buildings", "far-mass-only", "far-flat-thin":
			var diagnostic := _proxy_experiment.apply(world.get_node_or_null("CityVisualLOD"), case)
			if not diagnostic.get("applied", false):
				push_error("Building proxy experiment requires an active structural HLOD")
				get_tree().quit(1)
		"compact-near": _apply_compact_near()
		"occlusion":
			if not _apply_occlusion():
				push_error("Occlusion diagnostic requires a valid cache from the active immutable city")
				get_tree().quit(1)
		"authored-detail":
			world.get_node("CityVisualLOD").set_economy_enabled(false)
			var foliage_lod := world.get_node_or_null("CityFoliageLOD")
			if foliage_lod != null:
				foliage_lod.set_render_profile(false, false)
		"no-3d": get_tree().root.disable_3d = true
		"no-scripts": world.process_mode = Node.PROCESS_MODE_DISABLED
		"no-physics": PhysicsServer3D.space_set_active(world.get_world_3d().space, false)
		"frozen-cycle": world.get_node("DayNightCycle").set_process(false)
		"running-cycle", "incremental-sky":
			var cycle := world.get_node("DayNightCycle")
			cycle.set_process(true)
			cycle.running = true
			if case == "incremental-sky":
				if environment.sky == null:
					push_error("incremental-sky requires the world's actual Sky")
					get_tree().quit(1)
					return
				environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		"no-sky":
			environment.background_mode = Environment.BG_COLOR
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		"half-resolution": get_tree().root.size = Vector2i(maxi(1, base_size.x / 2), maxi(1, base_size.y / 2))
		"no-foliage", "short-range", "no-triplanar", "no-floor-far":
			if case == "no-foliage":
				var foliage_lod := world.get_node_or_null("CityFoliageLOD")
				if foliage_lod != null:
					foliage_lod.set_canopy_visible(false)
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
	_restore_blossom_hlod()
	_proxy_experiment.cleanup()
	_restore_occlusion()
	get_tree().root.disable_3d = false
	get_tree().root.size = base_size
	world.process_mode = Node.PROCESS_MODE_INHERIT
	PhysicsServer3D.space_set_active(world.get_world_3d().space, true)
	for property in environment_defaults:
		environment.set(property, environment_defaults[property])
	if environment.sky != null and not _sky_defaults.is_empty():
		environment.sky.process_mode = _sky_defaults.process_mode
		environment.sky.radiance_size = _sky_defaults.radiance_size
	_restore_cycle()
	for record in geometry:
		record.node.visible = record.visible
		record.node.visibility_range_end = record.end
		record.node.visibility_range_end_margin = record.margin
		record.node.material_override = record.material
	_restore_compact_near()
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		var settings: Dictionary = get_node("/root/WaveSettings").graphics
		visual_lod.set_render_profile(bool(settings["city_lod"]), bool(settings.get("city_detail_extended", false)))
		visual_lod.refresh(true)
	var foliage_lod := world.get_node_or_null("CityFoliageLOD")
	if foliage_lod != null:
		var settings: Dictionary = get_node("/root/WaveSettings").graphics
		foliage_lod.set_render_profile(bool(settings["city_lod"]), bool(settings.get("city_detail_extended", false)))
		foliage_lod.set_canopy_visible(true)
		foliage_lod.refresh(true)


func _capture(view: int, case: String, phase: String) -> void:
	_event({"event": "capture", "view": view, "case": case, "phase": phase})
	var frames: Array[float] = []
	var samples: Array[Dictionary] = []
	var focus: Array[bool] = []
	var cycle := world.get_node("DayNightCycle")
	var clock := {"selected_hour": hour, "running": cycle.running, "process_enabled": cycle.is_processing(), "start_hour": cycle.hour, "start_cloud_seconds": cycle._elapsed, "day_duration_seconds": cycle.day_duration_seconds}
	var sky := _sky_snapshot()
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
	clock["end_hour"] = cycle.hour
	clock["end_cloud_seconds"] = cycle._elapsed
	result["clock"] = clock
	result["sky"] = sky
	result["sky_end"] = _sky_snapshot()
	var foliage_lod := world.get_node_or_null("CityFoliageLOD")
	if foliage_lod != null:
		result["foliage_hlod"] = foliage_lod.snapshot()
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod != null:
		result["structural_hlod_preparation"] = visual_lod.preparation_diagnostics.duplicate(true)
	result["runtime_batch_compaction"] = world.get_node("City").get_meta("runtime_batch_compaction", {})
	result["runtime_road_seams"] = world.get_node("City").get_meta("runtime_road_seams", {})
	result["structural_hlod"] = _structural_snapshot()
	result["occlusion"] = _occlusion_snapshot()
	result["building_proxy_experiment"] = _proxy_experiment.stats.duplicate(true)
	result["blossom_hlod"] = _diagnostic_blossoms.snapshot() if is_instance_valid(_diagnostic_blossoms) else {}
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


func _apply_compact_near() -> void:
	# Diagnostic only: preserve the actual baseline radii and hysteresis state.
	# No game preference or controller default is changed by this experiment.
	_restore_compact_near()
	for name in ["CityVisualLOD", "CityFoliageLOD"]:
		var lod := world.get_node_or_null(name)
		if lod == null:
			continue
		var records: Array[Dictionary] = []
		for record in lod.groups:
			var saved := {"active": record.active}
			if record.has("detail_radius"):
				saved["detail_radius"] = record.detail_radius
				saved["retain_radius"] = record.retain_radius
				record.detail_radius *= 0.5
				record.retain_radius *= 0.5
			records.append(saved)
		_compact_near_defaults.append({"node": lod, "scale": lod._detail_scale, "records": records})
		lod._detail_scale *= 0.5
		lod.refresh(true)


func _restore_compact_near() -> void:
	for saved in _compact_near_defaults:
		var lod: Node = saved.node
		lod._detail_scale = saved.scale
		for index in saved.records.size():
			var record: Dictionary = lod.groups[index]
			var original: Dictionary = saved.records[index]
			record.active = original.active
			if original.has("detail_radius"):
				record.detail_radius = original.detail_radius
				record.retain_radius = original.retain_radius
	_compact_near_defaults.clear()


func _structural_snapshot() -> Dictionary:
	var lod := world.get_node_or_null("CityVisualLOD")
	if lod == null:
		return {}
	var radii: Dictionary = {}
	var near_instances := 0
	var visible_detail_batches := 0
	for record in lod.groups:
		var key := str(record.base_detail_radius)
		radii[key] = {"detail": record.detail_radius, "retain": record.retain_radius}
		var node: MultiMeshInstance3D = record.get("node")
		if record.active and node != null and node.visible:
			visible_detail_batches += 1
			near_instances += node.multimesh.instance_count
	var far_instances := 0
	var far_batches := 0
	for entry in lod.proxies.values():
		if entry.node.visible:
			far_batches += 1
			far_instances += entry.node.multimesh.instance_count
	var plane_instances := int(_proxy_experiment.stats.get("plane_instances", 0))
	var plane_batches := int(_proxy_experiment.stats.get("temporary_batches", 0))
	return {"enabled": lod.economy_enabled, "detail_scale": lod._detail_scale, "radii_by_base_detail_metres": radii, "source_groups": lod.groups.size(), "active_detail_batches": lod.active_detail_batches, "visible_detail_batches": visible_detail_batches, "active_detail_instances": near_instances, "proxy_batches": far_batches + plane_batches, "proxy_instances": far_instances + plane_instances, "original_proxy_batches": far_batches, "original_proxy_instances": far_instances, "diagnostic_plane_instances": plane_instances}


func _apply_occlusion(occluder: ArrayOccluder3D = null) -> bool:
	_restore_occlusion()
	# Cache eligibility relies on opaque volumes retained by the active HLODs,
	# rather than arbitrary objects with a shorter authored visibility range.
	if _requested_preset not in ["economy", "medium"] or not bool(get_node("/root/WaveSettings").graphics.city_lod):
		return false
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if visual_lod == null or not visual_lod.economy_enabled:
		return false
	if occluder == null:
		if not ResourceLoader.exists(OCCLUSION_CACHE):
			return false
		occluder = load(OCCLUSION_CACHE) as ArrayOccluder3D
	var city := world.get_node("City") as Node3D
	if occluder == null or occluder.get_meta("source_generation", "") != city.get_meta("generation_directory", ""):
		return false
	if int(occluder.get_meta("box_count", 0)) <= 0 or occluder.vertices.size() < 3 or occluder.indices.size() < 3:
		return false
	_diagnostic_occluder = OccluderInstance3D.new()
	_diagnostic_occluder.name = "DiagnosticOccluder"
	_diagnostic_occluder.occluder = occluder
	# Cache vertices use City coordinates, including all authored parent/instance
	# transforms. This node must not also receive the City's transform twice.
	city.add_child(_diagnostic_occluder)
	get_tree().root.use_occlusion_culling = true
	return true


func _apply_blossom_hlod(source_atlas: Texture2D = null) -> bool:
	_restore_blossom_hlod()
	var visual_lod := world.get_node_or_null("CityVisualLOD")
	if not bool(get_node("/root/WaveSettings").graphics.city_lod) or visual_lod == null or not visual_lod.economy_enabled:
		return false
	var lod := FoliageLOD.new()
	lod.domain = "blossoms"
	lod.detail_radius = 40.0
	lod.retain_radius = 70.0
	lod.alpha_cutoff = 0.15
	lod.atlas = source_atlas if source_atlas != null else load(FoliageLOD.ATLAS_PATH) as Texture2D
	if not lod.atlas_supports_domain():
		lod.free()
		return false
	lod.name = "DiagnosticBlossomLOD"
	world.add_child(lod)
	if lod.total_instances <= 0:
		lod.free()
		return false
	_diagnostic_blossoms = lod
	return true


func _restore_blossom_hlod() -> void:
	if is_instance_valid(_diagnostic_blossoms):
		_diagnostic_blossoms.restore_original_sources()
		_diagnostic_blossoms.free()
	_diagnostic_blossoms = null


func _restore_occlusion() -> void:
	get_tree().root.use_occlusion_culling = _occlusion_original
	if is_instance_valid(_diagnostic_occluder):
		_diagnostic_occluder.free()
	_diagnostic_occluder = null


func _occlusion_snapshot() -> Dictionary:
	var result := {"viewport_enabled": get_tree().root.use_occlusion_culling, "diagnostic_occluder_active": is_instance_valid(_diagnostic_occluder)}
	if is_instance_valid(_diagnostic_occluder):
		var resource := _diagnostic_occluder.occluder as ArrayOccluder3D
		result.merge({"boxes": resource.get_meta("box_count", 0), "vertices": resource.vertices.size(), "triangles": resource.indices.size() / 3, "source_generation": resource.get_meta("source_generation", ""), "resource_path": resource.resource_path})
	return result


func _event(data: Dictionary) -> void:
	data["monotonic_usec"] = Time.get_ticks_usec()
	events.store_line(JSON.stringify(data))
	events.flush()


func _set_hour_argument(value: String) -> bool:
	if not value.is_valid_float():
		return false
	var parsed := float(value)
	if not is_finite(parsed):
		return false
	hour = fposmod(parsed, 24.0)
	return true


func _restore_cycle() -> void:
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_process(true)
	cycle._elapsed = _cycle_defaults.get("elapsed", 0.0)
	cycle._lighting_timer = _cycle_defaults.get("lighting_timer", 0.0)
	cycle._lamp_timer = _cycle_defaults.get("lamp_timer", 0.0)
	cycle.day_duration_seconds = _cycle_defaults.get("day_duration_seconds", cycle.day_duration_seconds)
	cycle.set_hour(hour)


func _remember_environment_defaults() -> void:
	_occlusion_original = get_tree().root.use_occlusion_culling
	for property in ["background_mode", "ambient_light_source", "reflected_light_source"]:
		environment_defaults[property] = environment.get(property)
	_sky_defaults.clear()
	if environment.sky != null:
		_sky_defaults = {"process_mode": environment.sky.process_mode, "radiance_size": environment.sky.radiance_size}


func _sky_snapshot() -> Dictionary:
	if environment == null or environment.sky == null:
		return {"available": false}
	var sky := environment.sky
	return {"available": true, "process_mode": sky.process_mode, "process_mode_name": ["automatic", "quality", "incremental", "realtime"][sky.process_mode], "radiance_size": sky.radiance_size, "radiance_size_pixels": 32 << int(sky.radiance_size)}
