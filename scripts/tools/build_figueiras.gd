extends SceneTree

const Builder = preload("res://scripts/city/figueiras_builder.gd")
const TerrainBake = preload("res://scripts/tools/build_figueiras_terrain.gd")
const Batches = preload("res://scripts/tools/build_figueiras_batches.gd")
const Shadows = preload("res://scripts/tools/build_figueiras_shadows.gd")
const RuntimeData = preload("res://scripts/tools/build_figueiras_runtime.gd")
const MeshDetail = preload("res://scripts/tools/build_figueiras_mesh_detail.gd")
const Pavement = preload("res://scripts/tools/build_figueiras_pavement.gd")
const OUTPUT := "res://scenes/city/figueiras/figueiras_map.scn"


func _initialize() -> void:
	# The city serializes its ambience bus after WaveSettings has registered it.
	_bake.call_deferred()


func _bake() -> void:
	if "--bake-pavement-textures" in OS.get_cmdline_user_args():
		var texture_error := Pavement.bake_textures()
		if texture_error != OK:
			push_error("Could not write pavement textures: %s" % error_string(texture_error))
		quit(0 if texture_error == OK else 1)
		return
	var refresh := ""
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--refresh-mesh-detail":
			refresh = OUTPUT
		elif argument.begins_with("--refresh-mesh-detail="):
			refresh = argument.trim_prefix("--refresh-mesh-detail=")
	var map: Node3D
	if not refresh.is_empty():
		var source := load(refresh) as PackedScene
		if source == null:
			push_error("Could not read the city to refresh: " + refresh)
			quit(1)
			return
		map = source.instantiate()
		map.scene_file_path = ""
	else:
		map = Builder.new().build()
		if map == null:
			push_error("Could not generate Vila das Figueiras")
			quit(1)
			return
		TerrainBake.optimize(map)
		Batches.bake(map)
		Shadows.bake(map)
		RuntimeData.bake(map)
	MeshDetail.bake(map)
	var packed := PackedScene.new()
	var error := Pavement.bake(map)
	if error == OK:
		error = packed.pack(map)
	if error == OK:
		error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		print("Vila das Figueiras: %d blocks, %d buildings, %d street and garden trees" % [map.get_meta("blocks"), map.get_meta("buildings"), map.get_meta("trees")])
		var terrain: Vector3i = map.get_meta("terrain_lod")
		print("Terrain LOD: %d chunks, %d detail triangles / %d lowest LOD triangles" % [terrain.x, terrain.y, terrain.z])
		var batches: Vector2i = map.get_meta("batched_draw_nodes_saved")
		print("Static batches: %d instanced and %d indexed mesh nodes consolidated" % [batches.x, batches.y])
		print("Pavement: %d additional draws consolidated" % map.get_meta("pavement_draws_saved", 0))
		var shadows: Vector2i = map.get_meta("shadow_batches")
		print("Shadow pass: %d static sources in %d sectors" % [shadows.x, shadows.y])
		var support: Vector2i = map.get_node("StreetAndTerrainSupport").get_meta("terrain_sectors")
		print("Physical support: %d sectors, %d original triangles" % [support.x, support.y])
		if map.has_meta("ground_contact"):
			print("Ground contact: ", map.get_meta("ground_contact"))
	else:
		push_error("Could not save Vila das Figueiras: %s" % error_string(error))
	map.free()
	quit(0 if error == OK else 1)
