extends RefCounted

# Static opaque fittings share a finish inside the same spatial sector. The
# material and geometry conversions happen during the offline scene bake.
const SECTOR := 96.0
const RUNTIME_MATERIALS := ["light", "signal_amber", "water", "bark"]
const TEXTURED_FINISHES := ["roof", "roof_gray", "door", "bench", "stone", "glass", "residential_glass_lit"]


func bake(city: Node3D) -> void:
	var groups := {}
	for node: MultiMeshInstance3D in city.find_children("*", "MultiMeshInstance3D", false, false):
		if not _mergeable(node):
			continue
		var tile := Vector2i((Vector2(node.position.x, node.position.z) / SECTOR).floor())
		var finish: StandardMaterial3D = node.material_override
		var texture_key := finish.get_instance_id() if finish.resource_name in TEXTURED_FINISHES else 0
		var key := [tile, node.cast_shadow, node.visibility_range_end, node.visibility_range_end_margin, texture_key]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(node)
	var material := StandardMaterial3D.new()
	material.resource_name = "figueiras_architecture"
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.86
	var removed := 0
	var textured_removed := 0
	for key: Array in groups:
		var members: Array = groups[key]
		if members.size() < 2:
			continue
		var textured: bool = key[4] != 0
		var finish: StandardMaterial3D = members[0].material_override if textured else material
		_make_batch(city, members, finish, textured, removed)
		removed += members.size() - 1
		if textured:
			textured_removed += members.size() - 1
	city.set_meta("fused_architecture_batches", removed)
	city.set_meta("fused_textured_architecture_batches", textured_removed)


func _mergeable(node: MultiMeshInstance3D) -> bool:
	var mesh := node.multimesh.mesh
	var name := str(node.name)
	var material := node.material_override as StandardMaterial3D
	if material == null:
		return false
	var kit := mesh.resource_name.begins_with("figueiras_kit_")
	if material.resource_name in TEXTURED_FINISHES:
		return mesh is BoxMesh or mesh is QuadMesh or mesh is PrismMesh or kit or name.begins_with("hip_roof_") or name.begins_with("pane_arch_")
	if material.resource_name in RUNTIME_MATERIALS:
		return false
	if not (mesh is BoxMesh or mesh is CylinderMesh or mesh is PrismMesh
		or kit or name.begins_with("shutter_grooves_") or name.begins_with("facade_frame_") or name.begins_with("facade_ironwork_")):
		return false
	return (material.albedo_texture == null and material.normal_texture == null
		and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not material.emission_enabled
		and material.cull_mode == BaseMaterial3D.CULL_BACK and material.roughness > 0.67)


func _make_batch(city: Node3D, members: Array, material: StandardMaterial3D, textured: bool, index: int) -> void:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	var first: MultiMeshInstance3D = members[0]
	var origin := first.position
	var needs_tangents := textured and material.normal_texture != null
	for member: MultiMeshInstance3D in members:
		var multi := member.multimesh
		var arrays := multi.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var directions: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var triangles := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			triangles = arrays[Mesh.ARRAY_INDEX]
		var surface_colors := PackedColorArray()
		if arrays[Mesh.ARRAY_COLOR] != null:
			surface_colors = arrays[Mesh.ARRAY_COLOR]
		var source_uv := PackedVector2Array()
		if textured:
			source_uv = arrays[Mesh.ARRAY_TEX_UV]
		var source_tangents := PackedFloat32Array()
		if needs_tangents:
			source_tangents = arrays[Mesh.ARRAY_TANGENT]
		var matte := member.material_override as StandardMaterial3D
		var instance_colors: PackedColorArray = multi.instance_tints
		var instance := 0
		var offset := member.position - origin
		for transform: Transform3D in multi.instance_transforms:
			var tint := matte.albedo_color
			if instance < instance_colors.size() and matte.vertex_color_use_as_albedo:
				tint *= instance_colors[instance]
			var normals_basis := transform.basis.inverse().transposed()
			var start := positions.size()
			for vertex in points.size():
				positions.append(transform * points[vertex] + offset)
				normals.append((normals_basis * directions[vertex]).normalized())
				if textured:
					uv.append(source_uv[vertex])
					if needs_tangents:
						var k := vertex * 4
						var tangent := (transform.basis * Vector3(source_tangents[k], source_tangents[k + 1], source_tangents[k + 2])).normalized()
						tangents.append(tangent.x)
						tangents.append(tangent.y)
						tangents.append(tangent.z)
						tangents.append(source_tangents[k + 3])
				if not textured or material.vertex_color_use_as_albedo:
					var color := Color.WHITE if textured else tint
					colors.append(color if surface_colors.is_empty() else color * surface_colors[vertex])
			if triangles.is_empty():
				for vertex in points.size():
					indices.append(start + vertex)
			else:
				for vertex in triangles:
					indices.append(start + vertex)
			instance += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	if textured:
		arrays[Mesh.ARRAY_TEX_UV] = uv
		if needs_tangents:
			arrays[Mesh.ARRAY_TANGENT] = tangents
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Architecture_%d" % index
	node.position = origin
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = first.cast_shadow
	node.visibility_range_end = first.visibility_range_end
	node.visibility_range_end_margin = first.visibility_range_end_margin
	city.add_child(node)
	node.owner = city
	for member: MultiMeshInstance3D in members:
		member.free()
