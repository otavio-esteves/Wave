extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const Pool = preload("res://scripts/city/pilot_resource_pool.gd")
const Generation = preload("res://scripts/city/pilot_city_generation.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pool := Pool.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "ivory"
	material.uv1_world_triplanar = true
	material.normal_scale = 0.3
	_check(pool.intern(material) == pool.intern(material.duplicate()), "equivalent sector materials share one resource")
	var different: StandardMaterial3D = material.duplicate()
	different.uv1_scale = Vector3(0.5, 0.75, 1)
	_check(pool.intern(material) != pool.intern(different), "different UV scales cannot merge into the same material")
	different = material.duplicate()
	different.normal_scale = 0.8
	_check(pool.intern(material) != pool.intern(different), "different normal strengths cannot merge into the same material")
	var cube := BoxMesh.new()
	cube.size = Vector3(2, 3, 4)
	_check(pool.intern(cube) == pool.intern(cube.duplicate()), "equivalent primitive meshes share one resource")
	var other_cube: BoxMesh = cube.duplicate()
	other_cube.size.y = 5
	_check(pool.intern(cube) != pool.intern(other_cube), "different primitive dimensions remain distinct")
	var placement := Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.1)).scaled(Vector3(2, 3, 4)), Vector3(-17, 9, 201))
	var placements: Array[Transform3D] = [placement, Transform3D.IDENTITY]
	var tints := PackedColorArray([Color(0.2, 0.4, 0.6, 0.8)])
	var buffer := Baked.make_buffer(placements, tints)
	var restored := Transform3D(Basis(Vector3(buffer[0], buffer[4], buffer[8]), Vector3(buffer[1], buffer[5], buffer[9]), Vector3(buffer[2], buffer[6], buffer[10])), Vector3(buffer[3], buffer[7], buffer[11]))
	_check(buffer.size() == 32 and restored.is_equal_approx(placement), "bulk upload preserves rotated scaled row-major transforms and negative positions")
	_check(Color(buffer[12], buffer[13], buffer[14], buffer[15]).is_equal_approx(tints[0]) and buffer.slice(28, 32) == PackedFloat32Array([1, 1, 1, 1]), "bulk colours retain alpha and use white for missing tints")
	_check(Baked.make_buffer(placements, PackedColorArray()).size() == 24, "uncoloured batches use the twelve-float transform stride")
	var baked := Baked.new()
	baked.mesh = cube
	baked.set_instances(placements, tints)
	var expected := (placement * cube.get_aabb()).merge(cube.get_aabb())
	_check(baked.custom_aabb.is_equal_approx(expected) and baked.instance_count == 2 and baked.use_colors, "atomic updates retain correct visibility bounds and instance counts")
	baked.billboard_radius = 6
	_check(baked.custom_aabb.encloses(expected) and baked.custom_aabb.size.x > expected.size.x + 11.9, "billboard padding expands bounds without changing transforms")
	baked.set_instances([])
	_check(baked.instance_count == 0 and baked.custom_aabb == AABB() and not baked.use_colors, "empty updates release visible instances and stale bounds")
	var city := Node3D.new()
	city.name = "PilotCity"
	var colliders := StaticBody3D.new()
	colliders.name = "Colliders"
	city.add_child(colliders)
	colliders.owner = city
	for x in [0.0, 1024.0]:
		var node := MultiMeshInstance3D.new()
		node.name = "Batch%d" % int(x)
		node.position.x = x
		node.multimesh = Baked.new()
		node.multimesh.mesh = cube.duplicate()
		node.multimesh.set_instances(placements, tints)
		node.material_override = material.duplicate()
		city.add_child(node)
		node.owner = city
	var output := "user://shared-city.scn"
	_check(Generation.save(city, output) == OK, "shared city generation publishes across independent sectors")
	city.free()
	var packed := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var loaded := packed.instantiate()
	var batches := loaded.find_children("*", "MultiMeshInstance3D", true, false)
	_check(batches.size() == 2 and batches[0].multimesh.mesh == batches[1].multimesh.mesh and batches[0].material_override == batches[1].material_override, "cold reloading separate sectors keeps their mesh and material shared")
	_check(batches[0].multimesh.instance_transforms == placements and batches[1].multimesh.instance_tints == tints, "cold reloading preserves every authored transform and tint")
	loaded.free()
	var tree: Dictionary = preload("res://scripts/city/neighborhood_tree_mesh.gd").new().build(0)
	var arrays: Array = tree.leaves.surface_get_arrays(0)
	var foliage := preload("res://scripts/city/foliage_mesh_lod.gd").apply(tree.leaves)
	_check(foliage.surface_get_arrays(0) == arrays, "foliage LOD retains the exact full-detail vertices, normals, UVs, colours and indices")
	var lods: Array = foliage.get("_surfaces")[0].lods
	var full_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(lods.size() == 4 and lods[3].size() == full_indices.size() * 2 / 3, "distant foliage draws one third of the original patch triangles")
	var settings := root.get_node("WaveSettings")
	DirAccess.remove_absolute(settings.SETTINGS_PATH)
	settings.reload_settings()
	_check(settings.get_graphics_preset() == "economy", "a clean installation starts with the supported integrated-GPU profile")
	var config := ConfigFile.new()
	config.set_value("audio", "Motor", 0.25)
	config.save(settings.SETTINGS_PATH)
	settings.reload_settings()
	_check(settings.get_graphics_preset() == "legacy" and settings.volumes.Motor == 0.25, "existing audio-only preferences retain their previous graphics and volume")
	print("City resources: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
