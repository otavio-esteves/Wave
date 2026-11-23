extends SceneTree

const Builder = preload("res://scripts/city/figueiras_builder.gd")
const TerrainBake = preload("res://scripts/tools/build_figueiras_terrain.gd")
const Batches = preload("res://scripts/tools/build_figueiras_batches.gd")
const Shadows = preload("res://scripts/tools/build_figueiras_shadows.gd")
const RuntimeData = preload("res://scripts/tools/build_figueiras_runtime.gd")
const OUTPUT := "res://scenes/city/figueiras/figueiras_map.scn"


func _initialize() -> void:
	# The city serializes its ambience bus after WaveSettings has registered it.
	_bake.call_deferred()


func _bake() -> void:
	var map: Node3D = Builder.new().build()
	if map == null:
		push_error("Could not generate Vila das Figueiras")
		quit(1)
		return
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	TerrainBake.optimize(map)
	Batches.bake(map)
	Shadows.bake(map)
	RuntimeData.bake(map)
	var packed := PackedScene.new()
	var error := packed.pack(map)
	if error == OK:
		error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		print("Vila das Figueiras: %d blocks, %d buildings, %d street and garden trees" % [map.get_meta("blocks"), map.get_meta("buildings"), map.get_meta("trees")])
		var terrain: Vector3i = map.get_meta("terrain_lod")
		print("Terrain LOD: %d chunks, %d detail triangles / %d lowest LOD triangles" % [terrain.x, terrain.y, terrain.z])
		var batches: Vector2i = map.get_meta("batched_draw_nodes_saved")
		print("Static batches: %d instanced and %d indexed mesh nodes consolidated" % [batches.x, batches.y])
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
