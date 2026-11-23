extends RefCounted

const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const SECTOR := 192.0
const MESH_ATTRIBUTES := [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
const PERMANENT_FINISHES := ["stone", "light", "signal_amber", "gallery_lamp"]


static func bake(city: Node3D) -> void:
	var instance_groups := {}
	var mesh_groups := {}
	for node in city.get_children():
		if not node is GeometryInstance3D or node.material_override == null or not node.visible:
			continue
		if node.visibility_range_end > 0.0 or node.visibility_range_begin > 0.0 or not node.visibility_parent.is_empty():
			continue
		if node.basis != Basis.IDENTITY or node.material_overlay != null:
			continue
		var material: Material = node.material_override
		var tile := Vector2i((Vector2(node.position.x, node.position.z) / SECTOR).floor())
		var key := [tile, material.get_instance_id(), node.cast_shadow, node.layers]
		if node is MultiMeshInstance3D and node.multimesh is BakedMultiMesh:
			if not (material.resource_name.begins_with("figueiras_wall_") or material.resource_name in PERMANENT_FINISHES):
				continue
			var batch: MultiMesh = node.multimesh
			if batch.visible_instance_count >= 0 or batch.use_custom_data:
				continue
			key.append(batch.mesh.get_instance_id())
			key.append(batch.use_colors)
			_append(instance_groups, key, node)
		elif node is MeshInstance3D and node.mesh is ArrayMesh:
			# Paint has few triangles. The architecture keeps its smaller
			# original cells so the renderer can cull complete buildings.
			if not node.name.begins_with("Ground_white_"):
				continue
			if node.mesh.get_surface_count() != 1 or node.mesh.surface_get_array_index_len(0) == 0:
				continue
			key.append(node.mesh.surface_get_format(0))
			_append(mesh_groups, key, node)
	var saved := Vector2i.ZERO
	for group: Array in instance_groups.values():
		if group.size() > 1:
			_join_instances(city, group, saved.x)
			saved.x += group.size() - 1
	for group: Array in mesh_groups.values():
		if group.size() > 1:
			_join_meshes(city, group, saved.y)
			saved.y += group.size() - 1
	city.set_meta("batched_draw_nodes_saved", saved)


static func _append(groups: Dictionary, key: Array, node: GeometryInstance3D) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(node)


static func _join_instances(city: Node3D, members: Array, sequence: int) -> void:
	var first: MultiMeshInstance3D = members[0]
	var frames: Array[Transform3D] = []
	var colors := PackedColorArray()
	for node: MultiMeshInstance3D in members:
		var batch: BakedMultiMesh = node.multimesh
		var offset := node.position - first.position
		for placement in batch.instance_transforms:
			placement.origin += offset
			frames.append(placement)
		if batch.use_colors:
			colors.append_array(batch.instance_tints)
	var output := BakedMultiMesh.new()
	output.mesh = first.multimesh.mesh
	output.set_instances(frames, colors)
	var joined := MultiMeshInstance3D.new()
	joined.name = "PermanentInstances_%d" % sequence
	joined.multimesh = output
	_install(city, joined, first, members)


static func _join_meshes(city: Node3D, members: Array, sequence: int) -> void:
	var first: MeshInstance3D = members[0]
	var output := first.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = output[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = output[Mesh.ARRAY_INDEX]
	for index in range(1, members.size()):
		var node: MeshInstance3D = members[index]
		var source := node.mesh.surface_get_arrays(0)
		var offset := node.position - first.position
		var first_vertex := positions.size()
		for point: Vector3 in source[Mesh.ARRAY_VERTEX]:
			positions.append(point + offset)
		for corner: int in source[Mesh.ARRAY_INDEX]:
			indices.append(corner + first_vertex)
		for channel: int in MESH_ATTRIBUTES:
			if source[channel] != null:
				var values: Variant = output[channel]
				values.append_array(source[channel])
				output[channel] = values
	output[Mesh.ARRAY_VERTEX] = positions
	output[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output)
	var joined := MeshInstance3D.new()
	joined.name = "Ground_white_joined_%d" % sequence
	joined.mesh = mesh
	_install(city, joined, first, members)


static func _install(city: Node3D, joined: GeometryInstance3D, first: GeometryInstance3D, members: Array) -> void:
	joined.position = first.position
	joined.material_override = first.material_override
	joined.cast_shadow = first.cast_shadow
	joined.layers = first.layers
	city.add_child(joined)
	joined.owner = city
	for node: GeometryInstance3D in members:
		node.free()
