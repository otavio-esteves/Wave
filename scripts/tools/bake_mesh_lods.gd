extends RefCounted


static func bake(mesh: ArrayMesh, exact_surfaces: PackedStringArray = PackedStringArray()) -> ArrayMesh:
	var imported := generate(mesh)
	var result := ArrayMesh.new()
	var levels := 0
	for index in mesh.get_surface_count():
		var material := mesh.surface_get_material(index)
		var exact := material != null and material.resource_name in exact_surfaces
		var arrays := mesh.surface_get_arrays(index) if exact else imported.get_surface_arrays(index)
		var lods := {} if exact else index_levels(imported, index)
		levels += lods.size()
		result.add_surface_from_arrays(mesh.surface_get_primitive_type(index), arrays, [], lods)
		result.surface_set_material(index, material)
		result.surface_set_name(index, mesh.surface_get_name(index))
	if levels == 0:
		return mesh
	result.resource_name = mesh.resource_name
	return result


static func generate(mesh: ArrayMesh) -> ImporterMesh:
	var imported := ImporterMesh.new()
	for index in mesh.get_surface_count():
		imported.add_surface(mesh.surface_get_primitive_type(index), mesh.surface_get_arrays(index), [], {},
			mesh.surface_get_material(index), mesh.surface_get_name(index))
	imported.generate_lods(32.0, 0.0, [])
	return imported


static func index_levels(mesh: ImporterMesh, surface: int) -> Dictionary:
	var lods := {}
	for level in mesh.get_surface_lod_count(surface):
		lods[mesh.get_surface_lod_size(surface, level)] = mesh.get_surface_lod_indices(surface, level)
	return lods
