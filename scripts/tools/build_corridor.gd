extends SceneTree

const Builder = preload("res://scripts/corridor/corridor_builder.gd")


func _initialize() -> void:
	var output := "res://scenes/corridor/corridor_map.tscn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var map := Builder.new().build()
	var scene := PackedScene.new()
	var error := scene.pack(map)
	if error == OK:
		error = ResourceSaver.save(scene, output)
	print("Corridor: 600 m, seed %d, saved %s to %s" % [Builder.SEED, error_string(error), output])
	map.free()
	quit(0 if error == OK else 1)
