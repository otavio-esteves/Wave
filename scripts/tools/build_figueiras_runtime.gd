extends RefCounted

const Traffic = preload("res://scripts/city/figueiras_traffic.gd")
const TrafficVisuals = preload("res://scripts/city/figueiras_traffic_visuals.gd")
const StaticShapes = preload("res://scripts/city/pilot_city_physics.gd")
const SUPPORT_SECTOR_SIZE := 64.0


static func bake(city: Node3D) -> void:
	var routes: Array[Dictionary] = []
	for route in Traffic.make_routes():
		routes.append(route.baked_data())
	city.set_meta("traffic_routes", routes)
	city.set_meta("traffic_meshes", TrafficVisuals.make_meshes())
	StaticShapes.bake_shapes(city.get_node("SolidObjects"))
	_partition_support(city.get_node("StreetAndTerrainSupport"))


static func _partition_support(support: StaticBody3D) -> void:
	var original := support.get_child(0) as CollisionShape3D
	var source := original.shape as ConcavePolygonShape3D
	var faces := source.get_faces()
	var sectors: Dictionary[Vector2i, PackedVector3Array] = {}
	for first in range(0, faces.size(), 3):
		var center := (faces[first] + faces[first + 1] + faces[first + 2]) / 3.0
		var tile := Vector2i(floori(center.x / SUPPORT_SECTOR_SIZE), floori(center.z / SUPPORT_SECTOR_SIZE))
		if not sectors.has(tile):
			sectors[tile] = PackedVector3Array()
		# Assign whole triangles. This preserves the curb seams and layered
		# bridges, including triangles that reach beyond the nominal sector.
		sectors[tile].append(faces[first])
		sectors[tile].append(faces[first + 1])
		sectors[tile].append(faces[first + 2])
	for part in sectors.values():
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = source.backface_collision
		shape.set_faces(part)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = original.transform
		support.add_child(collider)
	original.free()
	StaticShapes.bake_shapes(support)
	support.set_meta("terrain_sectors", Vector2i(sectors.size(), faces.size() / 3))
