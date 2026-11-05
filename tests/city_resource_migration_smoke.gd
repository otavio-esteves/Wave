extends SceneTree

const Pool = preload("res://scripts/city/pilot_resource_pool.gd")
var _resource_hashes: Dictionary = {}
var _pool := Pool.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Usage: city_resource_migration_smoke.gd -- SOURCE.scn CANDIDATE.scn")
		quit(2)
		return
	var snapshots: Array[Dictionary] = []
	for path in arguments:
		var packed := load(path) as PackedScene
		if packed == null:
			quit(1)
			return
		var city := packed.instantiate()
		var snapshot: Dictionary = {}
		_visit(city, city, snapshot)
		snapshots.append(snapshot)
		print("Migration snapshot: %d nodes; %s" % [snapshot.size(), path])
		city.free()
		packed = null
		_resource_hashes.clear()
	var failures := 0
	for path in snapshots[0]:
		if not snapshots[1].has(path) or snapshots[0][path] != snapshots[1][path]:
			failures += 1
			if failures <= 10:
				push_error("Migration changed authored data: %s" % path)
	if snapshots[0].size() != snapshots[1].size():
		failures += 1
	print("Migration integrity: %d node snapshots, %d differences (new shrub LOD indices excluded; full-detail geometry included)" % [snapshots[0].size(), failures])
	quit(0 if failures == 0 else 1)


func _visit(node: Node, city: Node, snapshot: Dictionary) -> void:
	var values: Array = [node.get_class()]
	if node is Node3D:
		values.append(node.transform)
	if node is GeometryInstance3D:
		for key in ["visible", "layers", "cast_shadow", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "lod_bias"]:
			values.append(node.get(key))
		values.append(_resource_hash(node.material_override))
	if node is MeshInstance3D:
		values.append(_resource_hash(node.mesh))
	elif node is MultiMeshInstance3D:
		values.append(node.multimesh.instance_transforms)
		values.append(node.multimesh.instance_tints)
		values.append(node.multimesh.billboard_radius)
		var mesh: Mesh = node.multimesh.mesh
		if str(node.name).begins_with("shrub_") and mesh is ArrayMesh:
			# LOD is the intended change. Compare the original encoded attributes,
			# normals, UVs, colours and full-resolution indices byte for byte.
			var surface: Dictionary = mesh.get("_surfaces")[0]
			surface.erase("lods")
			values.append(surface)
		else:
			values.append(_resource_hash(mesh))
	if node is CollisionObject3D:
		values.append([node.collision_layer, node.collision_mask])
	if node is CollisionShape3D:
		values.append(_resource_hash(node.shape))
	for key in node.get_meta_list():
		if key not in [&"generation_directory", &"resource_revision"]:
			values.append([key, node.get_meta(key)])
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(values))
	snapshot[str(city.get_path_to(node))] = context.finish()
	for child in node.get_children():
		_visit(child, city, snapshot)


func _resource_hash(resource: Resource) -> String:
	if resource == null:
		return ""
	if not _resource_hashes.has(resource):
		_resource_hashes[resource] = _pool.fingerprint(resource)
	return _resource_hashes[resource]
