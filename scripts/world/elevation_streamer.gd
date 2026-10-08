extends "res://scripts/world/world_streamer.gd"

const Layout = preload("res://scripts/world/elevation_layout.gd")


func _valid_floor(instance: Node3D, record: Dictionary) -> bool:
	# Opt in only to the exact continuous surface built by this lab. Flat-world
	# validation stays intact; a metadata claim cannot authorize missing triangles.
	var floor := instance.get_node_or_null("Colliders/Support") as CollisionShape3D
	var bounds: AABB = record.bounds
	var origin: Vector3 = record.origin
	if floor == null or floor.disabled or not floor.shape is ConcavePolygonShape3D:
		return false
	var body := floor.get_parent() as StaticBody3D
	if body == null or body.collision_layer != 1 or body.transform != Transform3D.IDENTITY or floor.transform != Transform3D.IDENTITY or instance.basis != Basis.IDENTITY:
		return false
	if origin.x != 0 or origin.y != 0 or origin.z > 0 or origin.z < -600 or fmod(origin.z, Layout.CELL_LENGTH) != 0:
		return false
	if bounds != AABB(Vector3(-40, -1, origin.z - 200), Vector3(80, 22, 200)):
		return false
	return floor.shape.get_faces() == Layout.faces(origin.z)


func has_support(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 2.0, 1, [_target.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	for record in records:
		if record.node != null and Engine.get_physics_frames() >= record.support_tick and _distance(point, record.bounds) == 0:
			if hit.collider == record.node.get_node("Colliders"):
				return true
	return false
