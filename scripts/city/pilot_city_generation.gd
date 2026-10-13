extends RefCounted

const Storage = preload("res://scripts/city/pilot_city_storage.gd")

# Every dependency belongs to an immutable generation. Only the entry scene is
# replaced, by a same-directory rename after loading the complete staged scene.
static func save(city: Node3D, output: String) -> Error:
	var generation := output.get_basename() + "_generations/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var scene_path := generation.path_join("city.scn")
	var geometry_dir := generation.path_join("city_geometry")
	var error := DirAccess.make_dir_recursive_absolute(geometry_dir)
	if error != OK:
		return error
	var saved_shared: Dictionary = {}
	for child in city.get_children():
		var mesh: Mesh
		var name := str(child.name)
		if child is MeshInstance3D:
			mesh = child.mesh
		elif child is MultiMeshInstance3D and child.material_override.resource_name in ["parked_car", "address_plate"]:
			mesh = child.multimesh.mesh
			name = mesh.resource_name
			if saved_shared.has(name):
				continue
		else:
			continue
		var path := geometry_dir.path_join(name + ".res")
		error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			return error
		mesh.take_over_path(path)
		saved_shared[name] = true
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
	if not FileAccess.file_exists(scene_path):
		return ERR_FILE_NOT_FOUND
	if not _dependencies_complete(scene_path):
		return ERR_FILE_MISSING_DEPENDENCIES
	var staged := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if staged == null or not staged.can_instantiate():
		return ERR_INVALID_DATA
	var temporary := output.get_basename() + ".pending-%d.scn" % Time.get_ticks_usec()
	var error := DirAccess.copy_absolute(scene_path, temporary)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary, output)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func _dependencies_complete(path: String, checked: Dictionary = {}) -> bool:
	if checked.has(path):
		return true
	checked[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var resource_path := dependency.split("::")[-1]
		if resource_path.begins_with("uid://"):
			resource_path = ResourceUID.get_id_path(ResourceUID.text_to_id(resource_path))
		if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
			return false
		if not _dependencies_complete(resource_path, checked):
			return false
	return true
