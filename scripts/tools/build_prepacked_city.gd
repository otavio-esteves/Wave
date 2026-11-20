extends SceneTree

# Offline migration only: runtime meshes, transforms, colours and visibility
# remain authoritative. Generation.save writes a new immutable family, and this
# tool compares every instanced batch after a fresh resource roundtrip.
const Generation = preload("res://scripts/city/pilot_city_generation.gd")
const Pool = preload("res://scripts/city/pilot_resource_pool.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := "res://scenes/city/pilot/pilot_city.scn"
	var output := "user://pilot-city-prepacked.scn"
	var report_path := "user://prepacked-city-migration.json"
	var generation_family := ""
	var replace_output := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--generation-family="):
			generation_family = argument.trim_prefix("--generation-family=")
		elif argument == "--replace-output":
			replace_output = true
	if output == source and not replace_output or FileAccess.file_exists(output) and not replace_output:
		push_error("Migration requires a new output path; --replace-output explicitly keeps a rollback entry for replacement")
		quit(2)
		return
	var backup := ""
	if FileAccess.file_exists(output):
		backup = output.get_basename() + ".before-prepacked-%d.scn" % Time.get_ticks_usec()
		if DirAccess.copy_absolute(output, backup) != OK:
			push_error("Cannot retain the previous entry scene before migration")
			quit(1)
			return
	var started := Time.get_ticks_usec()
	var packed := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null:
		quit(1)
		return
	var city := packed.instantiate() as Node3D
	packed = null
	if city == null or city.get_node_or_null("Colliders") == null:
		if city != null:
			city.free()
		push_error("Prepacked migration expects a saved city with Colliders")
		quit(1)
		return
	var loaded := Time.get_ticks_usec()
	var before := _inventory(city)
	# Standalone external MultiMesh files must not remain legacy dependencies of
	# the new generation. Built-in sector resources already serialize into their
	# replacement sectors; only external resources need a path-free shallow copy.
	var external_copies: Dictionary = {}
	for geometry in city.find_children("*", "MultiMeshInstance3D", true, false):
		var resource: MultiMesh = geometry.multimesh
		if resource == null or not resource.has_method("load_work") or resource.resource_path.is_empty() or resource.resource_path.contains("::"):
			continue
		if not external_copies.has(resource):
			external_copies[resource] = resource.duplicate()
		geometry.multimesh = external_copies[resource]
	external_copies.clear()
	# Restore the generator's flat authoring layout before storage repartitions
	# it. Folding the sector transform preserves every world-space placement.
	for sector in city.get_children():
		if not str(sector.name).begins_with("Geometry_"):
			continue
		for geometry in sector.get_children():
			var placement: Transform3D = sector.transform * geometry.transform
			geometry.owner = null
			geometry.reparent(city, false)
			geometry.transform = placement
			_set_owner(geometry, city)
		sector.free()
	var save_started := Time.get_ticks_usec()
	var error := Generation.save(city, output, generation_family)
	city.free()
	var saved := Time.get_ticks_usec()
	if error != OK:
		_restore_entry(backup, output)
		push_error("Prepacked migration save failed: " + error_string(error))
		quit(1)
		return
	packed = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null:
		_restore_entry(backup, output)
		quit(1)
		return
	city = packed.instantiate() as Node3D
	packed = null
	var reloaded := Time.get_ticks_usec()
	var after := _inventory(city)
	city.free()
	var parity: bool = before.authored_sha256 == after.authored_sha256 and before.batches == after.batches and before.instances == after.instances
	var fast_path: bool = after.load_work.prepacked_loads == after.unique_multimeshes and after.load_work.buffer_packs == 0 and after.load_work.bounds_scans == 0
	if not parity or not fast_path:
		_restore_entry(backup, output)
	var report := {"scope": "Offline instanced-source parity and resource-load CPU timings. Does not measure FPS, GPU time or certify complete city performance. Full mesh/collision parity is validated by city_resource_migration_smoke.gd.", "source": source, "output": output, "generation_family": generation_family, "rollback_entry": backup, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "authored_instance_parity": parity, "all_batches_use_prepacked_load": fast_path, "before": before, "after": after, "timing_ms": {"source_load_instantiate": (loaded - started) / 1000.0, "save": (saved - save_started) / 1000.0, "new_load_instantiate": (reloaded - saved) / 1000.0}}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("Prepacked city migration: %d batches, %d instances; parity=%s; fast_path=%s; %s" % [after.batches, after.instances, parity, fast_path, report_path])
	quit(0 if parity and fast_path else 1)


func _set_owner(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for child in node.get_children():
		_set_owner(child, owner_root)


func _restore_entry(backup: String, output: String) -> void:
	if not backup.is_empty():
		if DirAccess.rename_absolute(backup, output) != OK:
			push_error("Migration failed parity; restore the retained rollback entry: " + backup)
	else:
		DirAccess.remove_absolute(output)


func _inventory(city: Node3D) -> Dictionary:
	var rows: Array[String] = []
	var seen: Dictionary = {}
	var resource_hashes: Dictionary = {}
	var pool := Pool.new()
	var counts := {"batches": 0, "instances": 0}
	var work := {"rebuilds": 0, "bounds_scans": 0, "buffer_packs": 0, "prepacked_loads": 0, "fallback_loads": 0, "uploads": 0}
	_visit(city, Transform3D.IDENTITY, rows, counts, seen, work, resource_hashes, pool)
	rows.sort()
	return {"authored_sha256": _hash(rows), "batches": counts.batches, "instances": counts.instances, "unique_multimeshes": seen.size(), "load_work": work}


func _visit(node: Node, parent_transform: Transform3D, rows: Array[String], counts: Dictionary, seen: Dictionary, work: Dictionary, resource_hashes: Dictionary, pool: RefCounted) -> void:
	var placement: Transform3D = parent_transform * node.transform if node is Node3D else parent_transform
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.has_method("load_work"):
		var multimesh: MultiMesh = node.multimesh
		var values: Array = [str(node.name), placement, multimesh.instance_transforms, multimesh.instance_tints, multimesh.billboard_radius, multimesh.custom_aabb, multimesh.instance_count, multimesh.visible_instance_count, multimesh.use_colors, multimesh.transform_format]
		for resource in [multimesh.mesh, node.material_override]:
			if resource == null:
				values.append("")
			else:
				if not resource_hashes.has(resource):
					resource_hashes[resource] = pool.fingerprint(resource)
				values.append(resource_hashes[resource])
		for key in ["visible", "layers", "cast_shadow", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "lod_bias"]:
			values.append(node.get(key))
		rows.append(_hash(values))
		counts.batches += 1
		counts.instances += multimesh.instance_transforms.size()
		if not seen.has(multimesh):
			seen[multimesh] = true
			var counters: Dictionary = multimesh.load_work()
			for key in work:
				work[key] += counters[key]
	for child in node.get_children():
		_visit(child, placement, rows, counts, seen, work, resource_hashes, pool)


func _hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()
