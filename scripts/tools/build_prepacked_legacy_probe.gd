extends SceneTree

const Legacy = preload("res://tests/fixtures/legacy_baked_multimesh.gd")
const WORK_KEYS := ["rebuilds", "bounds_scans", "buffer_packs", "prepacked_loads", "fallback_loads", "uploads", "payload_gets", "payload_get_instances"]
var _ticks_per_second := 0.0


class LegacyScriptLoader extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["gd"])
	func _handles_type(type: StringName) -> bool:
		return type in [&"Script", &"GDScript"]
	func _recognize_path(path: String, _type: StringName) -> bool:
		return path == "res://scripts/city/baked_multimesh.gd"
	func _load(_path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		return Legacy


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := ""
	var output := "user://legacy-sector-probe.json"
	var use_legacy := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--legacy-implementation":
			use_legacy = true
	if source.is_empty():
		push_error("Provide --source=SECTOR.scn; this probe never selects the full city implicitly")
		quit(2)
		return
	if OS.get_name() == "Linux":
		var tick_output: Array = []
		if OS.execute("getconf", ["CLK_TCK"], tick_output) == 0 and not tick_output.is_empty():
			_ticks_per_second = float(str(tick_output[0]).strip_edges())
	var loader: ResourceFormatLoader
	if use_legacy:
		loader = LegacyScriptLoader.new()
		ResourceLoader.add_resource_format_loader(loader, true)
	var started := Time.get_ticks_usec()
	var cpu_start := _cpu_seconds()
	var packed := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var loaded := Time.get_ticks_usec()
	var cpu_loaded := _cpu_seconds()
	if packed == null:
		quit(1)
		return
	var before := _packed_inventory(packed)
	var node := packed.instantiate()
	var instantiated := Time.get_ticks_usec()
	var cpu_instantiated := _cpu_seconds()
	var after := _node_inventory(node)
	var report := {"scope": "Read-only isolated PackedScene load/instantiate CPU and wall diagnostic; no scene attachment, world generation, FPS or GPU measurement", "source": source, "implementation": "frozen-legacy" if use_legacy else "current", "display": DisplayServer.get_name(), "engine": Engine.get_version_info().string, "timing_ms": {"load_wall": (loaded - started) / 1000.0, "instantiate_wall": (instantiated - loaded) / 1000.0, "load_cpu": (cpu_loaded - cpu_start) * 1000 if cpu_start >= 0 else null, "instantiate_cpu": (cpu_instantiated - cpu_loaded) * 1000 if cpu_loaded >= 0 else null}, "after_load": before, "after_instantiate": after, "static_memory_bytes": OS.get_static_memory_usage(), "peak_static_memory_bytes": OS.get_static_memory_peak_usage()}
	node.free()
	packed = null
	if loader != null:
		ResourceLoader.remove_resource_format_loader(loader)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("Legacy sector probe: %s; load wall %.2f ms, CPU %s ms; instantiate wall %.2f ms; %s" % [report.implementation, report.timing_ms.load_wall, report.timing_ms.load_cpu, report.timing_ms.instantiate_wall, output])
	quit()


func _cpu_seconds() -> float:
	if _ticks_per_second <= 0.0:
		return -1.0
	var file := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return -1.0
	# procfs reports a zero file length; read the line rather than using the
	# convenience get_file_as_string helper, which relies on that length.
	var document := file.get_line()
	var fields := document.substr(document.rfind(")") + 2).split(" ", false)
	if fields.size() < 13:
		return -1.0
	return (float(fields[11]) + float(fields[12])) / _ticks_per_second


func _packed_inventory(packed: PackedScene) -> Dictionary:
	var resources: Dictionary = {}
	var state := packed.get_state()
	for node in state.get_node_count():
		for property in state.get_node_property_count(node):
			var value: Variant = state.get_node_property_value(node, property)
			if value is MultiMesh and value.has_method("load_work"):
				resources[value] = true
	return _inventory(resources)


func _node_inventory(node: Node) -> Dictionary:
	var resources: Dictionary = {}
	for geometry in node.find_children("*", "MultiMeshInstance3D", true, false):
		if geometry.multimesh != null and geometry.multimesh.has_method("load_work"):
			resources[geometry.multimesh] = true
	return _inventory(resources)


func _inventory(resources: Dictionary) -> Dictionary:
	var work: Dictionary = {}
	for key in WORK_KEYS:
		work[key] = 0
	var instances := 0
	var local_resources := 0
	var scripts: Dictionary = {}
	for multimesh: MultiMesh in resources:
		instances += multimesh.instance_transforms.size()
		local_resources += 1 if multimesh.resource_local_to_scene else 0
		var counters: Dictionary = multimesh.load_work()
		for key in work:
			work[key] += counters.get(key, 0)
		scripts[multimesh.get_script().resource_path] = true
	return {"unique_multimeshes": resources.size(), "instances": instances, "local_to_scene_resources": local_resources, "load_work": work, "scripts": scripts.keys()}
