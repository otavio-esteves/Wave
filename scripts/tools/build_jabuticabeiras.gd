extends SceneTree

const Builder = preload("res://scripts/tools/build_jabuticabeiras_street.gd")
const Lighting = preload("res://scripts/tools/build_jabuticabeiras_lighting.gd")
const OUTPUT := "res://scenes/city/jabuticabeiras/jabuticabeiras_map.scn"


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var map: Node3D = Builder.new().build()
	var illumination := Lighting.new()
	illumination.prepare(map)
	root.add_child(map)
	await physics_frame
	await physics_frame
	illumination.bake(map)
	root.remove_child(map)
	var scene := PackedScene.new()
	var error := scene.pack(map)
	if error == OK:
		error = ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		print("Rua das Jabuticabeiras: %d m, %d facades, saved at %s" % [map.get_meta("street_length"), map.get_meta("facade_count"), output])
	else:
		push_error("Could not save Rua das Jabuticabeiras: " + error_string(error))
	map.free()
	quit(0 if error == OK else 1)
