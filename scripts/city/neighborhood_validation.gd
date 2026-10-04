extends RefCounted


static func validate(map: Node3D) -> PackedStringArray:
	var errors := PackedStringArray()
	var batches := map.find_children("*", "MultiMeshInstance3D", true, false)
	if batches.is_empty():
		errors.append("The map has no render geometry.")
		return errors
	var box_bounds: Array[AABB] = []
	for batch: MultiMeshInstance3D in batches:
		var multimesh := batch.multimesh
		if multimesh == null or multimesh.mesh == null:
			errors.append("%s has no mesh." % batch.name)
			continue
		var stored: Variant = multimesh.get("instance_transforms")
		if not stored is Array or stored.is_empty() or stored.size() != multimesh.instance_count:
			errors.append("%s has missing serialized instance transforms." % batch.name)
			continue
		if not multimesh.custom_aabb.has_volume():
			errors.append("%s has empty visibility bounds." % batch.name)
		var primitive_bounds := multimesh.mesh.get_aabb()
		for placement: Transform3D in stored:
			if not placement.origin.is_finite() or absf(placement.basis.determinant()) < 0.00000001:
				errors.append("%s contains an invalid or collapsed instance." % batch.name)
				break
			var bounds := placement * primitive_bounds
			if not multimesh.custom_aabb.grow(0.001).encloses(bounds):
				errors.append("%s has geometry outside its visibility bounds." % batch.name)
				break
			if multimesh.mesh is BoxMesh:
				box_bounds.append(_map_transform(batch, map) * bounds)

	# Compare visible volumes with the real floor/building collision volumes.
	# This catches a playable collision-only map without needing a GPU readback.
	for collider: CollisionShape3D in map.find_children("*", "CollisionShape3D", true, false):
		if not collider.shape is BoxShape3D:
			continue
		var size: Vector3 = collider.shape.size
		var is_building := size.x >= 5.0 and size.z >= 5.0 and size.y >= 4.0
		var is_ground := size.x >= 200.0 and size.z >= 200.0
		if not is_building and not is_ground:
			continue
		var physical_bounds: AABB = _map_transform(collider, map) * AABB(-size * 0.5, size)
		var found: bool = false
		for visible_bounds in box_bounds:
			if visible_bounds.is_equal_approx(physical_bounds):
				found = true
				break
		if not found:
			errors.append("%s has floor/building collision without matching visible geometry." % collider.name)
	return errors


static func _map_transform(node: Node3D, map: Node3D) -> Transform3D:
	var placement := Transform3D.IDENTITY
	var ancestor: Node = node
	while ancestor != map and ancestor != null:
		if ancestor is Node3D:
			placement = ancestor.transform * placement
		ancestor = ancestor.get_parent()
	return placement
