extends SceneTree

const FixtureInput = preload("fixture_input.gd")

const Chunks = preload("res://scripts/city/pilot_surface_chunks.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var faces := PackedVector3Array([Vector3(127, 0, 127), Vector3(129, 1, 127), Vector3(127, 0, 129), Vector3(-129, 0, -129), Vector3(-127, 0, -129), Vector3(-129, 0, -127)])
	var chunks := Chunks.split(faces)
	var rebuilt := PackedVector3Array()
	for chunk in chunks.values():
		rebuilt.append_array(chunk.vertices)
	_check(chunks.size() == 2 and rebuilt == faces, "sector seams and negative coordinates preserve exact authored triangles")
	root.get_node("WaveSettings").set_graphics_preset("medium")
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	FixtureInput.isolate()
	await process_frame
	await process_frame
	var city := current_scene.get_node("City")
	var geometry: Array = city.find_children("*", "MeshInstance3D", true, false)
	var surfaces := {"Terrain": 0, "Streets": 0, "Sidewalks": 0}
	var bounded := true
	var matching := true
	var lod_levels := 0
	var detailed_floor_ranges := true
	for node in geometry:
		var kind: String = node.get_meta("surface_kind", "")
		if not surfaces.has(kind):
			continue
		surfaces[kind] += 1
		for surface in node.mesh.get("_surfaces"):
			lod_levels += surface.get("lods", []).size()
		detailed_floor_ranges = detailed_floor_ranges and is_equal_approx(node.visibility_range_end, 220.0)
		var bounds: AABB = node.mesh.get_aabb()
		bounded = bounded and bounds.size.x <= 160.0 and bounds.size.z <= 160.0
		var tile := str(node.name).trim_prefix(kind + "_")
		var collider := city.get_node_or_null("Support_" + tile + "/" + kind) as CollisionShape3D
		matching = matching and collider != null
		if collider != null:
			var visual: PackedVector3Array = node.mesh.get_faces()
			var physical: PackedVector3Array = collider.shape.get_faces()
			matching = matching and visual.size() == physical.size()
			for index in mini(visual.size(), physical.size()):
				# Saved ArrayMesh attributes are quantized; physics remains full precision.
				matching = matching and visual[index].distance_squared_to(physical[index]) < 0.001 * 0.001
	_check(surfaces.values().all(func(count: int) -> bool: return count > 100), "terrain, streets and sidewalks each have independently culled local meshes")
	_check(bounded, "all playable surface bounds stay within a local tile plus the original crossing triangles")
	_check(matching, "every saved playable mesh matches local collision within one millimetre of render quantization")
	_check(lod_levels > 1000, "playable surfaces retain original geometry and include offline index-only visual LODs")
	var far_floor := city.find_children("FloorFar_*", "MeshInstance3D", true, false)
	var far_triangles := 0
	var far_kinds := {}
	for proxy in far_floor:
		far_triangles += proxy.mesh.get_faces().size() / 3
		far_kinds[proxy.get_meta("floor_kind", "")] = true
	_check(detailed_floor_ranges and far_floor.size() > 30 and far_floor.size() < 200 and far_kinds.has("Terrain") and far_kinds.has("Streets") and far_kinds.has("SidewalksFar") and far_triangles < 300000, "distant floor backing stays resident with all surface kinds and a bounded geometry budget")
	_check(city.find_children("*", "CollisionShape3D", true, false).size() < 30000, "convex wall envelopes reduce physical shape residency below thirty thousand")
	var parked_instances := 0
	var cheap_parked := true
	var outward_parked := true
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		if node.material_override.resource_name == "parked_car":
			parked_instances += node.multimesh.instance_count
			cheap_parked = cheap_parked and node.multimesh.mesh.get_faces().size() / 3 < 400
			var arrays: Array = node.multimesh.mesh.surface_get_arrays(0)
			for index in 36:
				var vertex: int = arrays[Mesh.ARRAY_INDEX][index]
				outward_parked = outward_parked and arrays[Mesh.ARRAY_NORMAL][vertex].dot(arrays[Mesh.ARRAY_VERTEX][vertex] - Vector3(0, 0.34, 0)) > 0.0
	_check(parked_instances == city.get_meta("parked_vehicle_count") and cheap_parked, "every parked vehicle retains its placement with fewer than four hundred triangles")
	_check(outward_parked, "parked vehicle body faces and normals point outwards")
	var address_instances := 0
	var cheap_addresses := true
	var outward_addresses := true
	for node in city.find_children("*", "MultiMeshInstance3D", true, false):
		if node.material_override.resource_name != "address_plate":
			continue
		address_instances += node.multimesh.instance_count
		var address_faces: PackedVector3Array = node.multimesh.mesh.get_faces()
		cheap_addresses = cheap_addresses and address_faces.size() == 6 and node.visibility_range_end <= 55
		outward_addresses = outward_addresses and (address_faces[1] - address_faces[0]).cross(address_faces[2] - address_faces[0]).z < 0.0
	_check(outward_addresses, "address plaques face the street with clockwise front faces")
	_check(address_instances > 4000 and cheap_addresses, "addresses use two-triangle digit instances with a short visibility range")
	_check(city.find_children("HouseNumbers*", "MeshInstance3D", true, false).is_empty(), "global extruded house-number geometry is removed")
	var settings := root.get_node("WaveSettings")
	var material: StandardMaterial3D
	for node in city.find_children("*", "GeometryInstance3D", true, false):
		if node.material_override != null and node.material_override.resource_name == "ivory":
			material = node.material_override
			break
	_check(material != null and material.normal_enabled, "balanced preset enables material detail")
	settings.set_graphics("antialiasing", false)
	_check(material.normal_enabled and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "disabling MSAA preserves the chosen material appearance")
	settings.set_graphics("material_detail", false)
	_check(not material.normal_enabled and not settings.graphics.antialiasing, "material detail can be disabled independently of MSAA")
	settings.set_graphics("antialiasing", true)
	_check(not material.normal_enabled, "enabling MSAA does not re-enable material detail")
	settings.save_settings()
	settings.graphics.material_detail = true
	settings.reload_settings()
	_check(not settings.graphics.material_detail and settings.graphics.antialiasing, "independent graphics choices survive saving and reloading")
	current_scene.queue_free()
	await process_frame
	print("Pilot optimization: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
