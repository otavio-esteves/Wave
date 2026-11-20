extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const Legacy = preload("res://tests/fixtures/legacy_baked_multimesh.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var instances := 4096
	var repetitions := 5
	var output := "user://prepacked-benchmark.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--instances="):
			instances = int(argument.trim_prefix("--instances="))
		elif argument.begins_with("--repetitions="):
			repetitions = int(argument.trim_prefix("--repetitions="))
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if instances < 1 or repetitions < 1:
		push_error("Instance and repetition counts must be positive")
		quit(2)
		return
	var placements: Array[Transform3D] = []
	var tints := PackedColorArray()
	for index in instances:
		var placement := Transform3D(Basis(Vector3.UP, index * 0.01).scaled(Vector3(2, 3, 4)), Vector3(index % 128 - 64, index % 7, index / 128 - 64))
		placements.append(placement)
		tints.append(Color(0.35 + index % 3 * 0.1, 0.55, 0.7, 0.5 + index % 2 * 0.5))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2, 3, 4)
	var legacy := Legacy.new()
	legacy.emulate_rendered_upload_in_headless = true
	legacy.mesh = mesh
	legacy.set_instances(placements, tints)
	legacy.billboard_radius = 4.0
	var modern := Baked.new()
	modern.mesh = mesh
	modern.set_instances(placements, tints)
	modern.billboard_radius = 4.0
	var files := {"legacy": "user://benchmark-legacy.res", "prepacked": "user://benchmark-prepacked.res"}
	if ResourceSaver.save(legacy, files.legacy, ResourceSaver.FLAG_COMPRESS) != OK or ResourceSaver.save(modern, files.prepacked, ResourceSaver.FLAG_COMPRESS) != OK:
		quit(1)
		return
	legacy = null
	modern = null
	# Warm filesystem/decoder/script caches symmetrically. Every timed root is
	# then loaded independently; alternate order to reduce warm-order bias.
	for path in files.values():
		var warm := ResourceLoader.load(path, "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE)
		warm = null
	var records: Dictionary = {"legacy": [], "prepacked": []}
	var parity := true
	for repetition in repetitions:
		var order := ["legacy", "prepacked"] if repetition % 2 == 0 else ["prepacked", "legacy"]
		for label: String in order:
			var started := Time.get_ticks_usec()
			var loaded := ResourceLoader.load(files[label], "MultiMesh", ResourceLoader.CACHE_MODE_IGNORE) as MultiMesh
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			if loaded == null:
				quit(1)
				return
			var equal: bool = loaded.instance_transforms == placements and loaded.instance_tints == tints
			parity = parity and equal
			records[label].append({"repetition": repetition, "load_ms": elapsed, "load_work": loaded.load_work(), "source_parity": equal, "bounds": str(loaded.custom_aabb)})
			loaded = null
	var medians: Dictionary = {}
	var bytes: Dictionary = {}
	for label: String in files:
		var times: Array[float] = []
		for row in records[label]:
			times.append(row.load_ms)
		times.sort()
		medians[label] = times[times.size() / 2]
		bytes[label] = FileAccess.open(files[label], FileAccess.READ).get_length()
	var report := {"scope": "Synthetic warm resource-load CPU microbenchmark on a shared machine. Legacy explicitly executes its rendered GDScript packing branch under headless; dummy uploads have no GPU cost. Not game startup, FPS or graphical performance certification.", "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "instances_per_resource": instances, "repetitions": repetitions, "legacy_rendered_branch_emulated": DisplayServer.get_name() == "headless", "source_parity": parity, "median_load_ms": medians, "median_speedup": medians.legacy / medians.prepacked, "serialized_bytes": bytes, "records": records}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("Prepacked CPU: %d instances; legacy %.3f ms, prepacked %.3f ms, %.2fx; parity=%s; %s" % [instances, medians.legacy, medians.prepacked, report.median_speedup, parity, output])
	quit(0 if parity else 1)
