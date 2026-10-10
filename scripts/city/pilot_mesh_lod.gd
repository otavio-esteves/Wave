extends RefCounted

# Bake index-only visual LODs offline. The full-resolution surface and collision
# faces remain available; runtime selection follows projected geometric error.
static func bake(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		importer.add_surface(mesh.surface_get_primitive_type(surface), mesh.surface_get_arrays(surface), [], {}, mesh.surface_get_material(surface))
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()
