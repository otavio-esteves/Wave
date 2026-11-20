extends RefCounted

# Keep the exact source meshes, materials, instance colours and transforms.
# Address digits and parked cars were split into thousands of tiny authored
# batches. Coalesce only equivalent static batches before they enter the tree.
const Baked = preload("res://scripts/city/baked_multimesh.gd")
const TILE := {"address_plate": 192.0, "parked_car": 256.0}


static func prepare(city: Node3D) -> void:
	if city.has_meta("runtime_batch_compaction"):
		return
	var groups: Dictionary = {}
	var candidates := 0
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		var material := node.material_override as StandardMaterial3D
		if material == null or not TILE.has(material.resource_name) or node.get_script() != null or node.get_child_count() != 0 or node.material_overlay != null or node.visibility_parent != NodePath() or node.transparency != 0.0 or node.extra_cull_margin != 0.0 or node.visibility_range_begin > 0.0:
			continue
		var multimesh: MultiMesh = node.multimesh
		if not multimesh is Baked or multimesh.use_custom_data or multimesh.visible_instance_count >= 0:
			continue
		var transform := _relative_transform(node, city)
		var bounds: AABB = transform * multimesh.custom_aabb
		var centre := bounds.get_center()
		var tile: float = TILE[material.resource_name]
		var key := "%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [floori(centre.x / tile), floori(centre.z / tile), multimesh.mesh.get_instance_id(), material.get_instance_id(), node.cast_shadow, node.layers, node.visible, multimesh.use_colors, node.visibility_range_begin, node.visibility_range_begin_margin, node.visibility_range_fade_mode, node.gi_mode, node.get_parent().get_instance_id()]
		if not groups.has(key):
			groups[key] = {"members": [], "bounds": bounds, "material": material, "mesh": multimesh.mesh}
		groups[key].members.append({"node": node, "transform": transform, "centre": centre})
		groups[key].bounds = groups[key].bounds.merge(bounds)
		candidates += 1
	var removed := 0
	var created := 0
	var instances := 0
	for entry in groups.values():
		if entry.members.size() < 2:
			continue
		var first: MultiMeshInstance3D = entry.members[0].node
		var centre: Vector3 = entry.bounds.get_center()
		var placements: Array[Transform3D] = []
		var tints := PackedColorArray()
		var margin := 0.0
		for record in entry.members:
			var source: MultiMeshInstance3D = record.node
			var source_placements: Array[Transform3D] = source.multimesh.instance_transforms
			var source_tints: PackedColorArray = source.multimesh.instance_tints
			for index in source_placements.size():
				var placement: Transform3D = record.transform * source_placements[index]
				placement.origin -= centre
				placements.append(placement)
				if source.multimesh.use_colors:
					tints.append(source_tints[index] if index < source_tints.size() else Color.WHITE)
			margin = maxf(margin, source.visibility_range_end_margin)
		var merged := MultiMeshInstance3D.new()
		merged.name = "RuntimeBatch_%s_%d" % [entry.material.resource_name, created]
		var parent := first.get_parent() as Node3D
		merged.transform = _relative_transform(parent, city).affine_inverse() * Transform3D(Basis.IDENTITY, centre)
		merged.multimesh = Baked.new()
		merged.multimesh.mesh = entry.mesh
		merged.multimesh.set_instances(placements, tints)
		# Repacked instance bounds can be tighter than a rotated source AABB.
		# Use their actual centre, not the conservative authored union's centre.
		var actual_centre: Vector3 = centre + merged.multimesh.custom_aabb.get_center()
		var end := 0.0
		for record in entry.members:
			var source: MultiMeshInstance3D = record.node
			end = INF if source.visibility_range_end == 0.0 else maxf(end, source.visibility_range_end + actual_centre.distance_to(record.centre))
		merged.material_override = entry.material
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		merged.gi_mode = first.gi_mode
		merged.visible = first.visible
		merged.visibility_range_begin = first.visibility_range_begin
		merged.visibility_range_begin_margin = first.visibility_range_begin_margin
		merged.visibility_range_end = 0.0 if is_inf(end) else end
		merged.visibility_range_end_margin = margin
		merged.visibility_range_fade_mode = first.visibility_range_fade_mode
		merged.set_meta("source_batch_count", entry.members.size())
		parent.add_child(merged)
		for record in entry.members:
			record.node.free()
		removed += entry.members.size()
		created += 1
		instances += placements.size()
	city.set_meta("runtime_batch_compaction", {"candidate_batches": candidates, "removed_batches": removed, "created_batches": created, "saved_batches": removed - created, "preserved_instances": instances})


static func _relative_transform(node: Node3D, city: Node3D) -> Transform3D:
	# Global transforms are unavailable before children enter the scene tree.
	if node == city:
		return Transform3D.IDENTITY
	var transform := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != city:
		transform = parent.transform * transform
		parent = parent.get_parent() as Node3D
	return transform
