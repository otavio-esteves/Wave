extends RefCounted

# A foliage patch is two folded quads (12 indices). Keep patches on every
# authored branch at each level; only overlapping patches are removed.
static func bake(arrays: Array, material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return apply(mesh)


static func apply(source: ArrayMesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var middle := PackedInt32Array()
	var distant := PackedInt32Array()
	for patch in indices.size() / 12:
		if patch % 3 != 1:
			middle.append_array(indices.slice(patch * 12, (patch + 1) * 12))
		if patch % 3 == 0:
			distant.append_array(indices.slice(patch * 12, (patch + 1) * 12))
	# Retain the encoded attributes verbatim. Refeeding decoded normals and UVs
	# through add_surface_from_arrays would quantize them a second time.
	var surfaces: Array = source.get("_surfaces")
	var stride := 2 if arrays[Mesh.ARRAY_VERTEX].size() < 65536 else 4
	surfaces[0]["lods"] = [0.006, _encode(middle, stride), 0.020, _encode(distant, stride)]
	var mesh := ArrayMesh.new()
	mesh.set("_surfaces", surfaces)
	mesh.resource_name = source.resource_name
	return mesh


static func _encode(indices: PackedInt32Array, stride: int) -> PackedByteArray:
	if stride == 4:
		return indices.to_byte_array()
	var bytes := PackedByteArray()
	bytes.resize(indices.size() * 2)
	for index in indices.size():
		bytes.encode_u16(index * 2, indices[index])
	return bytes
