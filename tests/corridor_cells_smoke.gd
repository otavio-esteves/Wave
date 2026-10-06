extends SceneTree

const Builder = preload("res://scripts/world/corridor_cells_builder.gd")
const Original = preload("res://scripts/corridor/corridor_builder.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	var error: Error = Builder.new().build("user://cells-regenerated")
	_check(error == OK, "offline cell pipeline writes independent cells and shared resources into an isolated directory")
	var source := Original.new().build()
	var saved := _load_cells("res://scenes/world/cells/vale/manifest.json")
	var regenerated := _load_cells("user://cells-regenerated/manifest.json")
	_check(_placements([source]) == _placements(saved), "cell ownership preserves every original batched prop, collider and landmark in world coordinates")
	_check(_placements(saved) == _placements(regenerated), "offline regeneration reproduces all cell placements/collisions")
	var before := _surface_areas([source])
	var after := _surface_areas(saved)
	var clipping_ok := before.size() == after.size()
	for name in before:
		clipping_ok = clipping_ok and after.has(name) and absf(before[name] - after.get(name, 0.0)) <= maxf(0.001, before[name] * 0.00002)
	_check(clipping_ok, "clipping preserves the area of ground, road, patches, wires and vertex-occlusion surfaces without duplicating geometry")
	var regenerated_areas := _surface_areas(regenerated)
	_check(after == regenerated_areas, "serialized generated surfaces preserve deterministic geometry areas")
	var bounded := true
	for map in saved:
		for child in map.get_children():
			if child is MeshInstance3D:
				var box: AABB = child.mesh.get_aabb()
				var zmin: float = map.position.z + child.position.z + box.position.z
				var zmax: float = map.position.z + child.position.z + box.end.z
				if not map.name.begins_with("ValeHorizon"):
					var floor: CollisionShape3D = map.get_node("Colliders/Floor")
					bounded = bounded and zmin >= map.position.z + floor.position.z - floor.shape.size.z / 2 - 0.001 and zmax <= map.position.z + floor.position.z + floor.shape.size.z / 2 + 0.001
	_check(bounded, "all standalone surfaces are clipped to their owning cell boundaries")
	source.free()
	for map in saved + regenerated:
		map.free()
	print("Corridor cells smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _load_cells(path: String) -> Array[Node3D]:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Array[Node3D] = []
	for entry in document.cells:
		var map: Node3D = load(entry.scene).instantiate()
		map.position = Vector3(entry.origin[0], entry.origin[1], entry.origin[2])
		result.append(map)
	var horizon: Node3D = load(path.get_base_dir() + "/horizon.tscn").instantiate()
	result.append(horizon)
	return result


func _placements(maps: Array) -> String:
	var rows: Array[String] = []
	for map: Node3D in maps:
		for node in map.find_children("*", "", true, false):
			if node is MultiMeshInstance3D:
				for transform: Transform3D in node.multimesh.instance_transforms:
					transform.origin += map.position + node.position
					rows.append("prop:%s:%s" % [node.name, _transform(transform)])
			elif node is CollisionShape3D and node.name != "Floor" and node.shape.size != Vector3(260, 0.6, 820):
				var transform: Transform3D = node.transform
				transform.origin += map.position
				rows.append("solid:%s:%s:%s" % [node.name, _transform(transform), node.shape.size])
			elif node is Marker3D:
				rows.append("marker:%s:%s" % [node.name, (map.position + node.position).snapped(Vector3.ONE * 0.001)])
	rows.sort()
	return "\n".join(rows).sha256_text()


func _transform(transform: Transform3D) -> String:
	return str(transform.basis.x.snapped(Vector3.ONE * 0.001)) + str(transform.basis.y.snapped(Vector3.ONE * 0.001)) + str(transform.basis.z.snapped(Vector3.ONE * 0.001)) + str(transform.origin.snapped(Vector3.ONE * 0.001))


func _surface_areas(maps: Array) -> Dictionary:
	var areas: Dictionary = {}
	for map: Node3D in maps:
		for node in map.get_children():
			if not node is MeshInstance3D:
				continue
			var area := 0.0
			for surface in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var total := indices.size() if not indices.is_empty() else points.size()
				for offset in range(0, total, 3):
					var a := points[indices[offset] if not indices.is_empty() else offset]
					var b := points[indices[offset + 1] if not indices.is_empty() else offset + 1]
					var c := points[indices[offset + 2] if not indices.is_empty() else offset + 2]
					area += (b - a).cross(c - a).length() / 2
			areas[node.name] = float(areas.get(node.name, 0.0)) + area
	return areas


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
