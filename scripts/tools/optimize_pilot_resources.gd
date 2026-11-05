extends SceneTree

# Offline migration of the saved city: preserve placements, collision and full
# detail, add the missing shrub LODs and publish shared immutable resources.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := "res://scenes/city/pilot/pilot_city.scn"
	var output := "user://pilot_city.scn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var packed := load(source) as PackedScene
	if packed == null:
		quit(1)
		return
	var city := packed.instantiate() as Node3D
	packed = null
	# Restore the generator's flat layout before the storage service repartitions it.
	for sector in city.get_children():
		if not str(sector.name).begins_with("Geometry_"):
			continue
		for geometry in sector.get_children():
			var placement: Transform3D = sector.transform * geometry.transform
			geometry.owner = null
			geometry.reparent(city, false)
			geometry.transform = placement
			geometry.owner = city
		sector.free()
	var converted: Dictionary = {}
	var shrubs := 0
	for geometry in city.get_children():
		if not geometry is MultiMeshInstance3D or not str(geometry.name).begins_with("shrub_"):
			continue
		var mesh: ArrayMesh = geometry.multimesh.mesh
		if not converted.has(mesh):
			converted[mesh] = preload("res://scripts/city/foliage_mesh_lod.gd").apply(mesh)
		geometry.multimesh.mesh = converted[mesh]
		shrubs += geometry.multimesh.instance_count
	converted.clear()
	var error: Error = preload("res://scripts/city/pilot_city_generation.gd").save(city, output)
	city.free()
	print("Pilot resource optimization: %s; %d shrubs; %s" % [error_string(error), shrubs, output])
	quit(0 if error == OK else 1)
