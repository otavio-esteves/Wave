extends RefCounted

# A foliage patch is two folded quads (12 indices). Keep patches on every
# authored branch at each level; only overlapping patches are removed.
static func bake(arrays: Array, material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return apply(mesh)


static func flatten_patches(source: ArrayMesh) -> ArrayMesh:
	# Replace each folded patch with the quad connecting its outer corners.
	var arrays := source.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var flat := PackedInt32Array()
	for first in range(0, indices.size(), 12):
		var left := indices[first]
		var right := indices[first + 7]
		var far_right := indices[first + 8]
		var far_left := indices[first + 5]
		flat.append_array(PackedInt32Array([left, right, far_right, left, far_right, far_left]))
	arrays[Mesh.ARRAY_INDEX] = flat
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return apply(mesh, 6)


static func apply(source: ArrayMesh, indices_per_patch := 12) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var middle := PackedInt32Array()
	var distant := PackedInt32Array()
	for patch in indices.size() / indices_per_patch:
		var first := patch * indices_per_patch
		if patch % 3 != 1:
			middle.append_array(indices.slice(first, first + indices_per_patch))
		if patch % 3 == 0:
			distant.append_array(indices.slice(first, first + indices_per_patch))
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
