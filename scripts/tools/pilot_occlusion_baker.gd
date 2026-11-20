extends RefCounted

# Diagnostic only. Each cuboid is inscribed independently in a real, opaque,
# closed BoxMesh; a building's overall AABB must never fill courtyards or gaps.
const LOD = preload("res://scripts/city/pilot_city_visual_lod.gd")
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const INSET := 0.995
const BUILDING_MATERIALS := ["ivory", "sage", "cream", "rose", "stone", "charcoal", "aged_plaster", "downtown_stone", "downtown_brick"]
const CORNERS := [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(-1,1,-1), Vector3(-1,-1,1), Vector3(1,-1,1), Vector3(1,1,1), Vector3(-1,1,1)]
const TRIANGLES := [0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]


static func build(city: Node3D) -> Dictionary:
	var result := {"vertices": PackedVector3Array(), "indices": PackedInt32Array(), "boxes": [], "rejected": {}}
	_walk(city, Transform3D.IDENTITY, true, city, result)
	return result


static func _walk(node: Node, parent_transform: Transform3D, parent_visible: bool, city: Node3D, result: Dictionary) -> void:
	var transform := parent_transform
	var visible := parent_visible
	if node is Node3D:
		visible = visible and node.visible
		if node != city:
			transform *= node.transform
	if node is GeometryInstance3D:
		if not visible or node.transparency > 0.0 or node.material_overlay != null or node.get_script() != null or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			_reject(result, "hidden-or-custom-geometry")
		elif node is MultiMeshInstance3D and node.multimesh != null:
			var mm: MultiMesh = node.multimesh
			if mm.transform_format != MultiMesh.TRANSFORM_3D or mm.use_custom_data:
				_reject(result, "custom-multimesh")
			else:
				var count := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.instance_count, mm.visible_instance_count)
				for index in count:
					# The headless dummy server discards native buffer uploads.
					# BakedMultiMesh's authored arrays remain authoritative offline.
					var placement: Transform3D = mm.instance_transforms[index] if mm is BakedMultiMesh else mm.get_instance_transform(index)
					_add(node, mm.mesh, transform * placement, index, city, result)
		elif node is MeshInstance3D:
			_add(node, node.mesh, transform, -1, city, result)
	for child in node.get_children():
		_walk(child, transform, visible, city, result)


static func _add(node: GeometryInstance3D, mesh: Mesh, transform: Transform3D, instance: int, city: Node3D, result: Dictionary) -> void:
	if not mesh is BoxMesh or mesh.get_script() != null or mesh.get_surface_count() != 1:
		_reject(result, "not-closed-box")
		return
	var material: Material = node.material_override
	if material == null:
		material = mesh.surface_get_material(0)
	if not material is StandardMaterial3D or material.get_script() != null or material.next_pass != null:
		_reject(result, "nonstandard-or-multipass-material")
		return
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a < 1.0 or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		_reject(result, "transparent-or-deformed-material")
		return
	if material.resource_name not in BUILDING_MATERIALS:
		_reject(result, "not-building-material")
		return
	var size: Vector3 = mesh.size
	var dimensions := size * Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length())
	if dimensions.x < 6.0 or dimensions.z < 6.0 or dimensions.y < 2.0 or absf(transform.basis.determinant()) < 0.000001 or not transform.is_finite():
		_reject(result, "thin-small-or-invalid-box")
		return
	var tower := material.resource_name.begins_with("downtown")
	var house := material.resource_name in LOD.HOUSE_MATERIALS
	if not node is MultiMeshInstance3D or not ((tower and LOD._structural(dimensions, material.resource_name)) or (house and LOD._house_structural(dimensions, false))):
		_reject(result, "outside-hlod-structural-classification")
		return
	var vertices: PackedVector3Array = result.vertices
	var indices: PackedInt32Array = result.indices
	var first := vertices.size()
	for corner in CORNERS:
		vertices.append(transform * (corner * size * 0.5 * INSET))
	for triangle in range(0, TRIANGLES.size(), 3):
		indices.append(first + TRIANGLES[triangle])
		indices.append(first + TRIANGLES[triangle + (2 if transform.basis.determinant() < 0.0 else 1)])
		indices.append(first + TRIANGLES[triangle + (1 if transform.basis.determinant() < 0.0 else 2)])
	result.vertices = vertices
	result.indices = indices
	result.boxes.append({"node": str(city.get_path_to(node)), "instance": instance, "material": material.resource_name, "mesh_path": mesh.resource_path, "size": [size.x,size.y,size.z], "transform": [transform.basis.x.x,transform.basis.x.y,transform.basis.x.z,transform.basis.y.x,transform.basis.y.y,transform.basis.y.z,transform.basis.z.x,transform.basis.z.y,transform.basis.z.z,transform.origin.x,transform.origin.y,transform.origin.z], "dimensions": [dimensions.x,dimensions.y,dimensions.z], "visibility_range_end": node.visibility_range_end, "visibility_range_begin": node.visibility_range_begin, "hlod_class": "tower" if tower else "house"})


static func _reject(result: Dictionary, reason: String) -> void:
	result.rejected[reason] = int(result.rejected.get(reason, 0)) + 1
