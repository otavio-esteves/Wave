extends RefCounted

# Distant opaque thin boxes retain their two original broad faces. Near
# geometry remains authored; the source bounds and face depths are unchanged.
static var _cache: Dictionary = {}


static func mesh(axis: int, cull_mode: int) -> ArrayMesh:
	assert(axis >= 0 and axis <= 2)
	var key := Vector2i(axis, cull_mode)
	if _cache.has(key):
		return _cache[key]
	var source := BoxMesh.new()
	source.size = Vector3.ONE
	var original := source.surface_get_arrays(0)
	var positions: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = original[Mesh.ARRAY_TEX_UV]
	var source_indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
	var remap: Dictionary = {}
	var vertices := PackedVector3Array()
	var face_normals := PackedVector3Array()
	var face_uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for index in positions.size():
		if absf(normals[index][axis]) < 0.9:
			continue
		var point := positions[index]
		remap[index] = vertices.size()
		vertices.append(point)
		face_normals.append(normals[index])
		face_uvs.append(uvs[index])
	for index in range(0, source_indices.size(), 3):
		if remap.has(source_indices[index]) and remap.has(source_indices[index+1]) and remap.has(source_indices[index+2]):
			for corner in 3:
				indices.append(remap[source_indices[index+corner]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = face_normals
	arrays[Mesh.ARRAY_TEX_UV] = face_uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Keep the original box's conservative bounds including its thin-axis extent.
	# Instance/batch bounds must also retain their source bounds.
	result.custom_aabb = AABB(Vector3.ONE * -0.5, Vector3.ONE)
	result.set_meta("major_faces_proxy", true)
	result.set_meta("thin_axis", axis)
	result.set_meta("source_cull_mode", cull_mode)
	result.set_meta("strategy", "two original broad faces; positions, normals, winding and UVs unchanged")
	_cache[key] = result
	return result
