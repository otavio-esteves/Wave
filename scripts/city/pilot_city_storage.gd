extends RefCounted

# Separate static geometry by world sector without changing its transforms or colliders.
static func save(city: Node3D, output: String) -> Error:
	partition_colliders(city)
	var directory := output.get_basename() + "_sectors"
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var sectors: Dictionary = {}
	for child in city.get_children():
		if not (child is MeshInstance3D or child is MultiMeshInstance3D):
			continue
		var bounds: AABB = child.multimesh.custom_aabb if child is MultiMeshInstance3D else child.mesh.get_aabb()
		var centre: Vector3 = child.transform * bounds.get_center()
		var key := Vector2i(floori(centre.x / 512), floori(centre.z / 512))
		if not sectors.has(key):
			var sector := Node3D.new()
			sector.name = "Geometry_%d_%d" % [key.x, key.y]
			city.add_child(sector)
			sector.owner = city
			sectors[key] = sector
		child.owner = null
		city.remove_child(child)
		sectors[key].add_child(child)
		child.owner = sectors[key]
	for key in sectors:
		var sector: Node3D = sectors[key]
		var packed := PackedScene.new()
		error = packed.pack(sector)
		if error != OK:
			return error
		var path := directory.path_join(str(sector.name) + ".scn")
		error = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH)
		if error != OK:
			return error
		packed.take_over_path(path)
		var instance := packed.instantiate()
		city.remove_child(sector)
		sector.free()
		city.add_child(instance)
		instance.owner = city
	var scene := PackedScene.new()
	error = scene.pack(city)
	if error == OK:
		error = ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS)
	return error


static func partition_colliders(city: Node3D) -> void:
	# Small static bodies avoid updating one enormous shape list when leaving the city.
	# Road/terrain shapes keep their original body and names for support queries.
	var original := city.get_node("Colliders") as StaticBody3D
	var tiles: Dictionary = {}
	var shapes := original.get_children()
	shapes.reverse()
	for shape in shapes:
		if not shape is CollisionShape3D or not shape.name.begins_with("Solid_"):
			continue
		var key := Vector2i(floori(shape.position.x / 128), floori(shape.position.z / 128))
		if not tiles.has(key):
			var body := StaticBody3D.new()
			body.name = "Solids_%d_%d" % [key.x, key.y]
			body.collision_layer = original.collision_layer
			body.collision_mask = original.collision_mask
			city.add_child(body)
			body.owner = city
			tiles[key] = body
		shape.owner = null
		original.remove_child(shape)
		tiles[key].add_child(shape)
		shape.owner = city
