extends SceneTree

const Assembly = preload("res://scripts/city/offline_scene_builder.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var builder := Assembly.new()
	var first := builder.begin("FirstCell", "Colliders")
	builder.add_box(Vector3(-2, 1, 3), Vector3(2, 2, 2), "cream", true, 0.4)
	builder.add_box(Vector3(90, 1, 3), Vector3(2, 2, 2), "cream")
	builder.finish()
	_check(first.get_child_count() == 3, "placements in separate spatial sectors produce separate batches")
	builder.finish()
	_check(first.get_child_count() == 3, "finishing twice cannot duplicate saved placements")
	var first_material: StandardMaterial3D = builder.materials["cream"]
	var second := builder.begin("SecondCell", "Colliders")
	builder.add_box(Vector3.ZERO, Vector3.ONE, "cream", true)
	builder.finish()
	_check(second.get_child_count() == 2 and second.get_node("Colliders").get_child_count() == 1, "new cell does not inherit old batches or colliders")
	_check(builder.materials["cream"] != first_material, "new build does not mutate the previous cell palette")
	_check(_owners(first, first) and _owners(second, second), "each cell assigns ownership to its own packed root")
	first.free()
	second.free()
	for entry in [["city/neighborhood", "neighborhood"], ["race/race", "race"], ["rally/rally", "rally"]]:
		var original := load("res://scenes/%s_map.tscn" % entry[0]) as PackedScene
		var generated := load("user://%s-generated.tscn" % entry[1]) as PackedScene
		_check(original != null and generated != null, "offline %s artifacts are available" % entry[1])
		if original == null or generated == null:
			continue
		var reference := original.instantiate()
		var candidate := generated.instantiate()
		var problems: Array[String] = []
		_compare(reference, candidate, problems)
		_check(problems.is_empty(), "regenerated %s preserves nodes, placements, collision shapes, materials and visibility: %s" % [entry[1], str(problems.slice(0, 5))])
		reference.free()
		candidate.free()
	print("Offline assembly smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _owners(node: Node, scene: Node) -> bool:
	for child in node.get_children():
		if child.owner != scene or not _owners(child, scene):
			return false
	return true


func _compare(reference: Node, candidate: Node, problems: Array[String]) -> void:
	var path := str(reference.name)
	if reference.get_class() != candidate.get_class() or reference.name != candidate.name or reference.get_child_count() != candidate.get_child_count():
		problems.append(path + ": hierarchy differs")
		return
	if reference is Node3D and not reference.transform.is_equal_approx(candidate.transform):
		problems.append(path + ": transform differs")
	if reference is Label3D and (reference.text != candidate.text or not is_equal_approx(reference.pixel_size, candidate.pixel_size)):
		problems.append(path + ": sign differs")
	if reference is CollisionShape3D:
		if reference.shape.get_class() != candidate.shape.get_class():
			problems.append(path + ": collider class differs")
		elif reference.shape is BoxShape3D and not reference.shape.size.is_equal_approx(candidate.shape.size):
			problems.append(path + ": box collider differs")
		elif reference.shape is ConcavePolygonShape3D and not _vertices_equal(reference.shape.get_faces(), candidate.shape.get_faces()):
			problems.append(path + ": terrain/road collider differs")
	if reference is GeometryInstance3D:
		if not is_equal_approx(reference.visibility_range_begin, candidate.visibility_range_begin) or not is_equal_approx(reference.visibility_range_end, candidate.visibility_range_end) or reference.cast_shadow != candidate.cast_shadow or reference.visibility_parent != candidate.visibility_parent:
			problems.append(path + ": visibility or shadows differ")
	if reference is MultiMeshInstance3D:
		if not reference.multimesh.custom_aabb.position.is_equal_approx(candidate.multimesh.custom_aabb.position) or not reference.multimesh.custom_aabb.size.is_equal_approx(candidate.multimesh.custom_aabb.size):
			problems.append(path + ": culling bounds differ")
		if reference.multimesh.instance_count != candidate.multimesh.instance_count:
			problems.append(path + ": placement count differs")
		else:
			for index in reference.multimesh.instance_count:
				if not reference.multimesh.get_instance_transform(index).is_equal_approx(candidate.multimesh.get_instance_transform(index)):
					problems.append(path + ": saved placement differs")
					break
		if not _vertices_equal(reference.multimesh.mesh.get_faces(), candidate.multimesh.mesh.get_faces()):
			problems.append(path + ": batch mesh differs")
		if reference.material_override.resource_name != candidate.material_override.resource_name or not reference.material_override.albedo_color.is_equal_approx(candidate.material_override.albedo_color):
			problems.append(path + ": material differs")
	if reference is MeshInstance3D and not _vertices_equal(reference.mesh.get_faces(), candidate.mesh.get_faces()):
		problems.append(path + ": mesh differs")
	for index in reference.get_child_count():
		_compare(reference.get_child(index), candidate.get_child(index), problems)


func _vertices_equal(first: PackedVector3Array, second: PackedVector3Array) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if not first[index].is_equal_approx(second[index]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
