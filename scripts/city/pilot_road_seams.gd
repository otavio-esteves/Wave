extends RefCounted

# A small offline cache fills only measured road/sidewalk boundary intervals.
# Its immutable generation and every participating resource path/vertex count
# must match. SHA256 provenance is recorded by the baker for offline review;
# gameplay performs no triangle search, texture readback or file hashing.
const CACHE_PATH := "res://assets/geometry/pilot-road-seams.scn"


static func prepare(city: Node3D, cache: PackedScene = null) -> Dictionary:
	if city.has_meta("runtime_road_seams"):
		return city.get_meta("runtime_road_seams")
	if cache == null:
		cache = load(CACHE_PATH) as PackedScene
	if cache == null:
		return {"applied": false, "reason": "cache-unavailable"}
	var seams := cache.instantiate() as Node3D
	if seams == null:
		return {"applied": false, "reason": "invalid-cache"}
	if city.get_meta("generation_directory", "") != seams.get_meta("source_generation", ""):
		seams.free()
		return {"applied": false, "reason": "different-generation"}
	var sources: Dictionary = seams.get_meta("source_geometry", {})
	var found: Dictionary = {}
	var asphalt: Material
	var reference: MeshInstance3D
	for node in city.find_children("*", "MeshInstance3D", true, false):
		var kind: String = node.get_meta("surface_kind", "")
		if kind not in ["Streets", "Sidewalks"]:
			continue
		if node.mesh == null or not sources.has(node.mesh.resource_path):
			seams.free()
			return {"applied": false, "reason": "different-geometry"}
		var expected: Dictionary = sources[node.mesh.resource_path]
		if node.mesh.get_surface_count() != 1 or node.mesh.surface_get_array_len(0) != int(expected.vertices):
			seams.free()
			return {"applied": false, "reason": "different-geometry"}
		found[node.mesh.resource_path] = true
		if kind == "Streets" and asphalt == null:
			asphalt = node.material_override
			reference = node
	if found.size() != sources.size() or asphalt == null:
		seams.free()
		return {"applied": false, "reason": "incomplete-geometry"}
	for node: MeshInstance3D in seams.get_children():
		node.material_override = asphalt
		node.layers = reference.layers
		node.gi_mode = reference.gi_mode
		# Keep RoadSeam: this visual-only weld has no physical support shape.
		# Art direction resolves the shared asphalt by its material resource name.
	city.add_child(seams)
	var result := {"applied": true, "tiles": seams.get_child_count(), "triangles": seams.get_meta("triangles", 0), "seams": seams.get_meta("seams", 0), "maximum_gap": seams.get_meta("maximum_gap", 0.0)}
	city.set_meta("runtime_road_seams", result)
	return result
