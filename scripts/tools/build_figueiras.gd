extends SceneTree

const Builder = preload("res://scripts/city/figueiras_builder.gd")
const OUTPUT := "res://scenes/city/figueiras/figueiras_map.scn"


func _initialize() -> void:
	# The city serializes its ambience bus after WaveSettings has registered it.
	_bake.call_deferred()


func _bake() -> void:
	var map: Node3D = Builder.new().build()
	var packed := PackedScene.new()
	var error := packed.pack(map)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		print("Vila das Figueiras: %d blocks, %d buildings, %d street and garden trees" % [map.get_meta("blocks"), map.get_meta("buildings"), map.get_meta("trees")])
	else:
		push_error("Could not save Vila das Figueiras: %s" % error_string(error))
	map.free()
	quit(0 if error == OK else 1)
