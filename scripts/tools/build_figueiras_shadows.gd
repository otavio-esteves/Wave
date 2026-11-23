extends RefCounted

const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const SECTOR_SIZE := 72.0
const OPT_OUT := ["bark", "canopy", "ipe", "bush"]


class Sector:
	var origin: Vector3
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	func _init(tile: Vector2i) -> void:
		origin = Vector3(tile.x + 0.5, 0.0, tile.y + 0.5) * SECTOR_SIZE

	func append(points: PackedVector3Array, triangles: PackedInt32Array, pose: Transform3D) -> void:
		var first := vertices.size()
		pose.origin -= origin
		for point in points:
			vertices.append(pose * point)
		if triangles.is_empty():
			for index in points.size():
				indices.append(first + index)
		else:
			for index in triangles:
				indices.append(first + index)


static func bake(city: Node3D) -> void:
	var sectors: Dictionary[Vector2i, Sector] = {}
	var source_count := 0
	for child in city.get_children():
		var node := child as GeometryInstance3D
		if node == null or not _eligible(node):
			continue
		var mesh: Mesh
		if node is MeshInstance3D:
			mesh = node.get_meta("shadow_proxy_mesh", node.mesh)
			node.remove_meta("shadow_proxy_mesh")
		elif node is MultiMeshInstance3D and node.multimesh is BakedMultiMesh:
			mesh = node.multimesh.mesh
		if mesh == null or mesh.get_surface_count() != 1:
			continue
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if points.is_empty():
			continue
		var center := mesh.get_aabb().get_center()
		if node is MultiMeshInstance3D:
			for placement: Transform3D in node.multimesh.instance_transforms:
				var pose := node.transform * placement
				_sector(sectors, pose * center).append(points, indices, pose)
		else:
			_sector(sectors, node.transform * center).append(points, indices, node.transform)
		node.set_meta("shadow_batched", true)
		source_count += 1
	for tile in sectors:
		var sector := sectors[tile]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = sector.vertices
		arrays[Mesh.ARRAY_INDEX] = sector.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var caster := MeshInstance3D.new()
		caster.name = "ShadowSector_%d_%d" % [tile.x, tile.y]
		caster.position = sector.origin
		caster.mesh = mesh
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		caster.set_meta("shadow_sector", true)
		caster.hide()
		city.add_child(caster)
		caster.owner = city
	city.set_meta("shadow_batches", Vector2i(source_count, sectors.size()))


static func _eligible(node: GeometryInstance3D) -> bool:
	if not node.visible or node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		return false
	if (node.visibility_range_begin != 0.0 or node.visibility_range_end != 0.0
		or (not node.visibility_parent.is_empty() and not node.has_meta("shadow_proxy_mesh"))):
		return false
	if node.has_meta("foliage_cell") or node.material_overlay != null or node.layers != 1:
		return false
	var material := node.material_override
	if material is StandardMaterial3D:
		return material.resource_name not in OPT_OUT and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and material.cull_mode == BaseMaterial3D.CULL_BACK and material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED
	return material is ShaderMaterial and material.resource_name.begins_with("figueiras_wall_")


static func _sector(sectors: Dictionary[Vector2i, Sector], center: Vector3) -> Sector:
	var tile := Vector2i((Vector2(center.x, center.z) / SECTOR_SIZE).floor())
	if not sectors.has(tile):
		sectors[tile] = Sector.new(tile)
	return sectors[tile]
