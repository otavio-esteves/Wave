extends SceneTree

# Rebuild this small visual cache after publishing a different immutable city.
# Production geometry and collision resources are read without being rewritten.
const Baker = preload("res://scripts/city/pilot_road_seam_baker.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var generation := "res://scenes/city/pilot/pilot_city_generations/1795138135-45180082"
	var output := "res://assets/geometry/pilot-road-seams.scn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--generation="):
			generation = argument.trim_prefix("--generation=")
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var directory := generation.path_join("city_geometry")
	var names := DirAccess.get_files_at(directory)
	var baker := Baker.new()
	var sources: Dictionary = {}
	var started := Time.get_ticks_msec()
	for name in names:
		if not name.begins_with("Streets_") or not name.ends_with(".res"):
			continue
		var path := directory.path_join(name)
		var mesh := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null:
			quit(1)
			return
		baker.add_road(mesh)
		sources[path] = {"sha256": FileAccess.get_sha256(path), "vertices": mesh.surface_get_array_len(0)}
	print("Road seam bake: indexed ", baker.triangles.size(), " road triangles")
	var scene := Node3D.new()
	scene.name = "RoadSeams"
	var triangle_count := 0
	for name in names:
		if not name.begins_with("Sidewalks_") or not name.ends_with(".res"):
			continue
		var path := directory.path_join(name)
		var mesh := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null:
			quit(1)
			return
		sources[path] = {"sha256": FileAccess.get_sha256(path), "vertices": mesh.surface_get_array_len(0)}
		var faces := baker.seal(mesh)
		if faces.is_empty():
			continue
		var node := MeshInstance3D.new()
		node.name = name.replace("Sidewalks_", "RoadSeam_")
		node.mesh = Baker.mesh_from_faces(faces)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 220.0
		node.set_meta("surface_kind", "RoadSeam")
		scene.add_child(node)
		node.owner = scene
		triangle_count += faces.size() / 3
	scene.set_meta("source_generation", generation)
	scene.set_meta("source_geometry", sources)
	scene.set_meta("triangles", triangle_count)
	scene.set_meta("seams", baker.seam_count)
	scene.set_meta("maximum_gap", baker.maximum_gap)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS)
	print("Road seam bake: ", scene.get_child_count(), " tiles, ", triangle_count, " triangles, ", baker.seam_count, " seams, maximum gap ", baker.maximum_gap, " m, elapsed ", Time.get_ticks_msec() - started, " ms; result ", error)
	scene.free()
	quit(0 if error == OK else 1)
