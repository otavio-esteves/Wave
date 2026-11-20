extends RefCounted

# Diagnostic-only changes to the currently selected far building buffers.
# The controllers' immutable source/selection buffers are never edited.
var _originals: Array[Dictionary] = []
var _sources: Array[Dictionary] = []
var _temporary: Array[MultiMeshInstance3D] = []
var stats: Dictionary = {}


func apply(lod: Node, mode: String) -> Dictionary:
	cleanup()
	if lod == null or not lod.economy_enabled:
		return {"applied": false, "reason": "requires-active-structural-hlod"}
	stats = {"applied": true, "case": mode, "eligible_batches": 0, "input_instances": 0, "box_instances": 0, "plane_instances": 0, "removed_instances": 0, "temporary_batches": 0, "hidden_source_groups": 0, "hidden_source_instances": 0, "hidden_proxy_batches": 0, "hidden_proxy_instances": 0}
	if mode == "far-mass-only":
		stats["rule"] = {"wide_xz_min_metres": 5.0, "volume_height_min_metres": 2.0, "slab_height_max_metres": 0.6}
	elif mode == "far-flat-thin":
		stats["rule"] = {"thickness_max_metres": 0.4, "thin_to_broad_max_ratio": 0.2, "plane_triangles_per_instance": 4, "source_box_triangles_per_instance": 12}
	if mode == "no-buildings":
		for record in lod.groups:
			var node: GeometryInstance3D = record.node
			_sources.append({"node": node, "visible": node.visible})
			if node.visible:
				stats.hidden_source_groups += 1
				stats.hidden_source_instances += node.multimesh.instance_count
			node.hide()
	for entry in lod.proxies.values():
		var node: MultiMeshInstance3D = entry.node
		if mode in ["no-far-buildings", "no-buildings"]:
			_remember(node, entry.buffer)
			if node.visible:
				stats.hidden_proxy_batches += 1
				stats.hidden_proxy_instances += node.multimesh.instance_count
			node.hide()
			continue
		if not node.visible or not _eligible(node):
			continue
		_remember(node, entry.buffer)
		var data := partition(entry.buffer, mode)
		stats.eligible_batches += 1
		stats.input_instances += entry.buffer.size() / 16
		stats.box_instances += data.box.size() / 16
		stats.plane_instances += data.thin.size() / 16
		stats.removed_instances += data.removed
		node.multimesh.instance_count = data.box.size() / 16
		node.multimesh.buffer = data.box
		node.visible = not data.box.is_empty()
		if data.thin.is_empty():
			continue
		var copy := MultiMeshInstance3D.new()
		copy.name = "DiagnosticThinProxy_%d" % _temporary.size()
		copy.transform = node.transform
		copy.layers = node.layers
		copy.gi_mode = node.gi_mode
		copy.cast_shadow = node.cast_shadow
		copy.extra_cull_margin = node.extra_cull_margin
		copy.ignore_occlusion_culling = node.ignore_occlusion_culling
		copy.visibility_range_begin = node.visibility_range_begin
		copy.visibility_range_end = node.visibility_range_end
		copy.visibility_range_begin_margin = node.visibility_range_begin_margin
		copy.visibility_range_end_margin = node.visibility_range_end_margin
		copy.visibility_range_fade_mode = node.visibility_range_fade_mode
		copy.material_override = node.material_override
		copy.multimesh = MultiMesh.new()
		copy.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		copy.multimesh.use_colors = true
		# All three thin axes use this same Z-normal two-sided unit plane;
		# partition() rotates the instance basis, without changing world spans.
		copy.multimesh.mesh = load("res://scripts/city/pilot_proxy_planes.gd").mesh(2, node.material_override.cull_mode)
		copy.multimesh.instance_count = data.thin.size() / 16
		copy.multimesh.custom_aabb = node.multimesh.custom_aabb
		copy.multimesh.buffer = data.thin
		node.get_parent().add_child(copy)
		_temporary.append(copy)
	stats.temporary_batches = _temporary.size()
	return stats.duplicate(true)


func cleanup() -> void:
	for node in _temporary:
		if is_instance_valid(node):
			node.free()
	_temporary.clear()
	for original in _originals:
		var node: MultiMeshInstance3D = original.node
		if not is_instance_valid(node):
			continue
		node.multimesh.instance_count = original.count
		node.multimesh.custom_aabb = original.bounds
		node.multimesh.buffer = original.buffer
		node.multimesh.visible_instance_count = original.visible_count
		node.visible = original.visible
	_originals.clear()
	for original in _sources:
		if is_instance_valid(original.node):
			original.node.visible = original.visible
	_sources.clear()
	stats.clear()


func _remember(node: MultiMeshInstance3D, buffer: PackedFloat32Array) -> void:
	_originals.append({"node": node, "count": node.multimesh.instance_count, "visible_count": node.multimesh.visible_instance_count, "visible": node.visible, "bounds": node.multimesh.custom_aabb, "buffer": buffer})


static func _eligible(node: MultiMeshInstance3D) -> bool:
	var material := node.material_override as StandardMaterial3D
	return node.multimesh.mesh is BoxMesh and material != null and material.resource_name.begins_with("far_palette_") and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not material.emission_enabled


static func partition(buffer: PackedFloat32Array, mode: String) -> Dictionary:
	var boxes := PackedFloat32Array()
	var planes := PackedFloat32Array()
	var removed := 0
	for index in buffer.size() / 16:
		var offset := index * 16
		var placement := _transform(buffer, offset)
		var size := Vector3(placement.basis.x.length(), placement.basis.y.length(), placement.basis.z.length())
		if mode == "far-mass-only":
			var wide := size.x >= 5.0 and size.z >= 5.0
			if not wide or not (size.y >= 2.0 or size.y <= 0.6):
				removed += 1
				continue
		elif mode == "far-flat-thin":
			var axis := size.min_axis_index()
			var narrow := size[axis]
			var broad := size[size.max_axis_index()]
			if broad > 0.0 and narrow <= 0.4 and narrow / broad <= 0.2:
				if axis == 0:
					placement.basis *= Basis(Vector3.UP, PI * 0.5)
				elif axis == 1:
					placement.basis *= Basis(Vector3.RIGHT, -PI * 0.5)
				_append_transform(planes, placement)
				planes.append_array(buffer.slice(offset + 12, offset + 16))
				continue
		boxes.append_array(buffer.slice(offset, offset + 16))
	return {"box": boxes, "thin": planes, "removed": removed}


static func _transform(buffer: PackedFloat32Array, offset: int) -> Transform3D:
	return Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]), Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]), Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])), Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11]))


static func _append_transform(buffer: PackedFloat32Array, transform: Transform3D) -> void:
	for row in 3:
		buffer.append_array(PackedFloat32Array([transform.basis.x[row], transform.basis.y[row], transform.basis.z[row], transform.origin[row]]))
