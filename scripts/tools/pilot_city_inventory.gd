extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var city_path := "res://scenes/city/pilot/pilot_city.scn"
	var output := "user://pilot-inventory.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--city="):
			city_path = argument.trim_prefix("--city=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var started := Time.get_ticks_usec()
	var packed := load(city_path) as PackedScene
	if packed == null:
		quit(1)
		return
	var loaded := Time.get_ticks_usec()
	var city := packed.instantiate()
	var instantiated := Time.get_ticks_usec()
	root.add_child(city)
	var attached := Time.get_ticks_usec()
	var totals: Dictionary = {}
	var nodes := city.find_children("*", "", true, false)
	var multimesh_instances := 0
	var collision_shapes := 0
	for node in nodes:
		if node is MultiMeshInstance3D:
			multimesh_instances += node.multimesh.instance_count
		if node is CollisionShape3D:
			collision_shapes += 1
		if not node is MeshInstance3D:
			continue
		var kind: String = node.get_meta("surface_kind", str(node.name))
		if not totals.has(kind):
			totals[kind] = {"objects": 0, "triangles": 0, "max_bound_x": 0.0, "max_bound_z": 0.0}
		var item: Dictionary = totals[kind]
		item.objects += 1
		item.triangles += node.mesh.get_faces().size() / 3
		var bounds: AABB = node.mesh.get_aabb()
		item.max_bound_x = maxf(item.max_bound_x, bounds.size.x)
		item.max_bound_z = maxf(item.max_bound_z, bounds.size.z)
	var report := {"city": city_path, "generator_version": city.get_meta("generator_version"), "nodes": nodes.size(), "collision_shapes": collision_shapes, "multimesh_instances": multimesh_instances, "surfaces": totals,
		"resource_load_ms": (loaded - started) / 1000.0, "instantiate_ms": (instantiated - loaded) / 1000.0, "attach_ms": (attached - instantiated) / 1000.0, "timing_scope": "headless structural diagnostic; not graphical FPS or controlled startup benchmark", "engine_static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Pilot inventory: %d nodes, %d colliders, %d instances; %s" % [nodes.size(), collision_shapes, multimesh_instances, output])
	city.queue_free()
	await process_frame
	quit()
