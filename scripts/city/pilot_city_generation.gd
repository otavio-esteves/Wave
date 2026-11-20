extends RefCounted

const Storage = preload("res://scripts/city/pilot_city_storage.gd")

# Every dependency belongs to an immutable generation. Only the entry scene is
# replaced, by a same-directory rename after loading the complete staged scene.
static func save(city: Node3D, output: String, generation_family: String = "") -> Error:
	city.set_meta("resource_revision", "2026-11-19-prepacked-instance-upload")
	# An isolated entry may stage its dependencies in the final immutable family.
	# The verified entry can then be published without moving or rewriting files.
	var family := output.get_basename() + "_generations" if generation_family.is_empty() else generation_family
	var generation := family.path_join("%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var scene_path := generation.path_join("city.scn")
	var geometry_dir := generation.path_join("city_geometry")
	var error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if error != OK:
		return error
	error = DirAccess.make_dir_recursive_absolute(geometry_dir)
	if error != OK:
		return error
	var pool := preload("res://scripts/city/pilot_resource_pool.gd").new()
	pool.collect(city)
	error = pool.save_shared(generation.path_join("shared"))
	if error != OK:
		return error
	for child in city.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh: Mesh = child.mesh
		var path := geometry_dir.path_join(str(child.name) + ".res")
		error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			return error
		mesh.take_over_path(path)
	for body in city.get_children():
		if not body is StaticBody3D:
			continue
		for child in body.get_children():
			if not child is CollisionShape3D or not child.shape is ConcavePolygonShape3D:
				continue
			var path := geometry_dir.path_join(str(body.name) + "_" + str(child.name) + "Collision.res")
			error = ResourceSaver.save(child.shape, path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				return error
			child.shape.take_over_path(path)
	city.set_meta("generation_directory", generation)
	error = Storage.save(city, scene_path)
	if error != OK:
		return error
	return publish(scene_path, output)


static func publish(scene_path: String, output: String) -> Error:
	var physical_scene := _physical_resource_path(scene_path)
	if physical_scene.is_empty():
		return ERR_FILE_NOT_FOUND
	if not _dependencies_complete(scene_path, {}):
		return ERR_FILE_MISSING_DEPENDENCIES
	# Publication must validate the files a fresh game process will read. Ignoring
	# only the root scene still reuses cached dependencies, including stale data.
	var staged := ResourceLoader.load(physical_scene, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if staged == null or not staged.can_instantiate():
		return ERR_INVALID_DATA
	var temporary := output.get_basename() + ".pending-%d.scn" % Time.get_ticks_usec()
	var error := DirAccess.copy_absolute(physical_scene, temporary)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary, output)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func _dependencies_complete(path: String, checked: Dictionary) -> bool:
	# ResourceLoader.exists() also returns true for resources kept alive in its
	# cache after their files have disappeared. Check before reading dependencies
	# so a missing cached resource cannot become an apparently complete leaf.
	var physical := _physical_resource_path(path)
	if physical.is_empty():
		return false
	if checked.has(physical):
		return true
	checked[physical] = true
	for dependency in ResourceLoader.get_dependencies(physical):
		var resource_path := dependency.split("::")[-1]
		if resource_path.begins_with("uid://"):
			resource_path = ResourceUID.get_id_path(ResourceUID.text_to_id(resource_path))
		if resource_path.is_empty():
			return false
		if not _dependencies_complete(resource_path, checked):
			return false
	return true


static func _physical_resource_path(path: String) -> String:
	# Exported scripts/textures may only exist at their .remap destination.
	# Prefer that mapping even when a raw file or cached resource still exists;
	# only physical files can prove what a fresh process will actually read.
	var visited: Dictionary = {}
	var current := path.simplify_path()
	while not current.is_empty():
		if visited.has(current):
			return ""
		visited[current] = true
		var mapping_path := current + ".remap"
		if not FileAccess.file_exists(mapping_path):
			return current if FileAccess.file_exists(current) else ""
		var mapping := ConfigFile.new()
		if mapping.load(mapping_path) != OK:
			return ""
		var target: Variant = mapping.get_value("remap", "path", null)
		if not target is String or target.strip_edges().is_empty():
			return ""
		current = str(target).simplify_path()
	return ""
