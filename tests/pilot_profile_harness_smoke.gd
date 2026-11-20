extends SceneTree

var checks := 0
var failures := 0

class ProfileHarness:
	extends "res://scripts/tools/pilot_profile.gd"
	func _ready() -> void:
		pass

class FixtureCycle:
	extends Node
	var running := false
	var hour := 16.5
	var day_duration_seconds := 1440.0
	var _elapsed := 7.0
	var _lighting_timer := 0.1
	var _lamp_timer := 0.2
	var restored := 0
	func set_hour(value: float) -> void:
		hour = fposmod(value, 24.0)
		restored += 1
	func _process(delta: float) -> void:
		if running:
			hour = fposmod(hour + delta * 24.0 / day_duration_seconds, 24.0)
			_elapsed += delta
		_lighting_timer += delta
		_lamp_timer += delta

class FixtureLOD:
	extends Node
	var groups: Array[Dictionary] = []
	var proxies: Dictionary = {}
	var preparation_diagnostics: Dictionary = {}
	var _detail_scale := 1.6
	var economy_enabled := true
	var enabled := true
	var active_detail_batches := 1
	var refreshes := 0
	func refresh(_force: bool = false) -> void:
		refreshes += 1
		if _detail_scale < 1.0:
			for record in groups:
				record.active = false
	func set_render_profile(wanted: bool, extended: bool) -> void:
		economy_enabled = wanted
		enabled = wanted
		_detail_scale = 1.6 if extended else 1.0
		for record in groups:
			if record.has("base_detail_radius"):
				record.detail_radius = record.base_detail_radius * _detail_scale
				record.retain_radius = record.base_retain_radius * _detail_scale
	func set_canopy_visible(_value: bool) -> void:
		pass
	func snapshot() -> Dictionary:
		return {"enabled": enabled, "detail_radius": 200.0 * _detail_scale, "retain_radius": 260.0 * _detail_scale}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile := ProfileHarness.new()
	root.add_child(profile)
	_check(profile.hour == 16.5 and not "running-cycle" in profile.DEFAULT_CASES and not "incremental-sky" in profile.DEFAULT_CASES, "profile keeps its 16.5h default and live-clock/sky ablations remain opt-in")
	_check(profile._set_hour_argument("23.5") and profile.hour == 23.5, "hour argument accepts an explicit nighttime baseline")
	_check(profile._set_hour_argument("25.5") and profile.hour == 1.5 and profile._set_hour_argument("-1") and profile.hour == 23.0, "hour argument normalizes positive and negative clock wraps")
	_check(not profile._set_hour_argument("invalid") and not profile._set_hour_argument("nan") and profile.hour == 23.0, "invalid/nonfinite hour arguments cannot replace the chosen baseline")
	var world := Node3D.new()
	var city := Node3D.new()
	city.name = "City"
	world.add_child(city)
	var cycle := FixtureCycle.new()
	cycle.name = "DayNightCycle"
	world.add_child(cycle)
	profile.add_child(world)
	profile.world = world
	profile.environment = Environment.new()
	profile.environment.sky = Sky.new()
	profile.environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	profile.environment.sky.radiance_size = Sky.RADIANCE_SIZE_64
	profile._remember_environment_defaults()
	profile.base_size = root.size
	profile._cycle_defaults = {"elapsed": 7.0, "lighting_timer": 0.1, "lamp_timer": 0.2, "day_duration_seconds": 1440.0}
	profile.output = "user://profile-harness"
	DirAccess.make_dir_recursive_absolute(profile.output)
	profile.events = FileAccess.open(profile.output.path_join("events.jsonl"), FileAccess.WRITE)
	profile.seconds = 0.03
	profile._restore_cycle()
	profile._apply("frozen-cycle")
	_check(not cycle.is_processing(), "frozen-cycle ablation disables the actual cycle processing")
	profile._apply("running-cycle")
	_check(cycle.running and cycle.is_processing(), "running-cycle explicitly enables the real clock processing")
	var before := cycle.hour
	cycle._process(2.0)
	_check(cycle.hour > before and cycle._elapsed == 9.0, "running clock changes both celestial phase and cloud time")
	await profile._capture(113, "running-cycle", "ablation")
	var result: Dictionary = profile.results[-1]
	_check(result.clock.selected_hour == 23.0 and result.clock.running and result.clock.process_enabled and result.clock.end_hour > result.clock.start_hour and result.clock.end_cloud_seconds > result.clock.start_cloud_seconds, "capture JSON records the selected hour and actual moving-clock/cloud interval")
	cycle.day_duration_seconds = 100.0
	profile._restore()
	_check(not cycle.running and cycle.is_processing() and cycle.hour == 23.0 and cycle._elapsed == 7.0 and cycle._lighting_timer == 0.1 and cycle._lamp_timer == 0.2 and cycle.day_duration_seconds == 1440.0, "restoration resets clock, cloud phase, cadence and day length to the chosen baseline")
	await profile._capture(113, "baseline", "after-running-cycle")
	result = profile.results[-1]
	_check(not result.clock.running and result.clock.start_hour == result.clock.end_hour and result.clock.start_cloud_seconds == result.clock.end_cloud_seconds, "restored baseline capture keeps hour and cloud time static")
	profile._apply("incremental-sky")
	_check(cycle.running and cycle.is_processing() and profile.environment.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL and profile.environment.sky.radiance_size == Sky.RADIANCE_SIZE_64, "incremental-sky enables the real clock and only changes sky processing mode")
	await profile._capture(113, "incremental-sky", "ablation")
	result = profile.results[-1]
	_check(result.clock.end_hour > result.clock.start_hour and result.clock.end_cloud_seconds > result.clock.start_cloud_seconds and result.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL and result.sky.radiance_size_pixels == 64 and result.sky_end == result.sky, "incremental capture records its actual moving clock and stable sky mode/radiance size")
	profile.environment.sky.radiance_size = Sky.RADIANCE_SIZE_256
	profile._restore()
	_check(not cycle.running and profile.environment.sky.process_mode == Sky.PROCESS_MODE_QUALITY and profile.environment.sky.radiance_size == Sky.RADIANCE_SIZE_64, "restoration returns exact baseline quality and radiance size after incremental processing")
	await profile._capture(113, "baseline", "after-incremental-sky")
	result = profile.results[-1]
	_check(result.sky.process_mode_name == "quality" and result.sky.radiance_size_pixels == 64 and not result.clock.running and result.clock.end_hour == result.clock.start_hour, "next baseline records restored quality sky with a stationary clock")
	root.get_node("WaveSettings").set_graphics_preset("medium")
	var building := FixtureLOD.new()
	building.name = "CityVisualLOD"
	building.groups = [{"base_detail_radius": 340.0, "base_retain_radius": 420.0, "detail_radius": 544.0, "retain_radius": 672.0, "active": true}, {"base_detail_radius": 240.0, "base_retain_radius": 320.0, "detail_radius": 384.0, "retain_radius": 512.0, "active": false}]
	world.add_child(building)
	var foliage := FixtureLOD.new()
	foliage.name = "CityFoliageLOD"
	foliage.groups = [{"active": true}, {"active": false}]
	world.add_child(foliage)
	profile._apply("compact-near")
	_check(not "compact-near" in profile.DEFAULT_CASES and building._detail_scale == 0.8 and building.groups[0].detail_radius == 272.0 and building.groups[0].retain_radius == 336.0 and building.groups[1].detail_radius == 192.0 and building.groups[1].retain_radius == 256.0 and foliage._detail_scale == 0.8, "compact-near is opt-in and halves current extended tower, house and foliage distances")
	await profile._capture(113, "compact-near", "ablation")
	result = profile.results[-1]
	_check(result.structural_hlod.detail_scale == 0.8 and result.structural_hlod.radii_by_base_detail_metres[str(340.0)].detail == 272.0 and result.foliage_hlod.detail_radius == 160.0 and result.foliage_hlod.retain_radius == 208.0, "compact capture records actual structural and foliage radii")
	profile._restore()
	_check(building._detail_scale == 1.6 and foliage._detail_scale == 1.6 and building.groups[0].detail_radius == 544.0 and building.groups[1].retain_radius == 512.0 and building.groups[0].active and not building.groups[1].active and foliage.groups[0].active and not foliage.groups[1].active and profile._compact_near_defaults.is_empty(), "restoration returns exact normal radii and previous per-group hysteresis state")
	_check(not "occlusion" in profile.DEFAULT_CASES and not is_instance_valid(profile._diagnostic_occluder) and root.use_occlusion_culling == profile._occlusion_original, "occlusion remains opt-in with no default viewport or scene change")
	city.set_meta("generation_directory", "fixture-generation")
	city.position = Vector3(5, 2, 1)
	city.rotation.y = 0.4
	var occluder := ArrayOccluder3D.new()
	occluder.set_arrays(PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 2, 0)]), PackedInt32Array([0, 1, 2]))
	occluder.set_meta("source_generation", "fixture-generation")
	occluder.set_meta("box_count", 1)
	_check(profile._apply_occlusion(occluder) and root.use_occlusion_culling and profile._diagnostic_occluder.get_parent() == city and profile._diagnostic_occluder.transform == Transform3D.IDENTITY and profile._diagnostic_occluder.global_transform == city.global_transform, "diagnostic occluder uses City coordinates exactly once and enables viewport culling")
	await profile._capture(113, "occlusion", "ablation")
	result = profile.results[-1]
	_check(result.occlusion.viewport_enabled and result.occlusion.diagnostic_occluder_active and result.occlusion.boxes == 1 and result.occlusion.triangles == 1 and result.occlusion.source_generation == "fixture-generation", "occlusion capture records its actual active cache and geometry counts")
	profile._restore()
	_check(root.use_occlusion_culling == profile._occlusion_original and not is_instance_valid(profile._diagnostic_occluder) and not city.has_node("DiagnosticOccluder"), "restoration restores the original viewport flag and frees the diagnostic occluder")
	occluder.set_meta("source_generation", "different-generation")
	_check(not profile._apply_occlusion(occluder) and root.use_occlusion_culling == profile._occlusion_original and not city.has_node("DiagnosticOccluder"), "a different generation cannot activate stale occluders")
	occluder.set_meta("source_generation", "fixture-generation")
	root.get_node("WaveSettings").set_graphics_preset("high")
	_check(not profile._apply_occlusion(occluder) and not city.has_node("DiagnosticOccluder"), "full authored geometry opt-out cannot use the HLOD-dependent occlusion cache")
	root.get_node("WaveSettings").set_graphics_preset("medium")
	profile._requested_preset = "high"
	_check(not profile._apply_occlusion(occluder) and not city.has_node("DiagnosticOccluder"), "only the explicitly supported Economy and Medium diagnostic presets may enable the cache")
	profile._requested_preset = "economy"
	building.economy_enabled = false
	_check(not profile._apply_occlusion(occluder) and not city.has_node("DiagnosticOccluder"), "an inactive structural HLOD cannot use an occluder whose distant support would disappear")
	building.economy_enabled = true
	var empty_occluder := ArrayOccluder3D.new()
	empty_occluder.set_meta("source_generation", "fixture-generation")
	empty_occluder.set_meta("box_count", 0)
	_check(not profile._apply_occlusion(empty_occluder) and not city.has_node("DiagnosticOccluder") and root.use_occlusion_culling == profile._occlusion_original, "an empty bake cannot masquerade as a meaningful occlusion experiment")
	profile._occlusion_original = true
	profile._restore()
	_check(root.use_occlusion_culling, "restoration also preserves a previously enabled viewport flag")
	profile._occlusion_original = false
	profile._restore()
	profile._apply("no-far-buildings")
	_check(["no-far-buildings", "no-buildings", "far-mass-only", "far-flat-thin"].all(func(case): return not case in profile.DEFAULT_CASES) and profile._proxy_experiment.stats.applied and profile._proxy_experiment.stats["case"] == "no-far-buildings", "building proxy cases remain opt-in and the dispatcher applies the isolated experiment")
	var building_refreshes := building.refreshes
	var foliage_refreshes := foliage.refreshes
	profile._restore()
	_check(profile._proxy_experiment.stats.is_empty() and building.refreshes > building_refreshes and foliage.refreshes > foliage_refreshes, "normal restoration cleans up proxy experiments and forces both original controller selections")
	profile.events.close()
	profile.queue_free()
	await process_frame
	print("Pilot profile harness: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
