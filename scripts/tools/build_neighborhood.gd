extends SceneTree

const Builder = preload("res://scripts/city/neighborhood_builder.gd")
const Validation = preload("res://scripts/city/neighborhood_validation.gd")
const OUTPUT := "res://scenes/city/neighborhood_map.tscn"


func _initialize() -> void:
	var map: Node3D = Builder.new().build()
	var scene := PackedScene.new()
	var error := scene.pack(map)
	if error == OK:
		error = ResourceSaver.save(scene, OUTPUT)
	if error != OK:
		push_error("Could not build neighborhood: %s" % error_string(error))
		map.free()
		quit(1)
		return
	# Re-read the file, not the in-memory builder, to catch lost render data.
	var saved := ResourceLoader.load(OUTPUT, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if saved == null:
		push_error("Could not reload the generated neighborhood.")
		map.free()
		quit(1)
		return
	var reloaded := saved.instantiate() as Node3D
	var problems: PackedStringArray = Validation.validate(reloaded)
	reloaded.free()
	if not problems.is_empty():
		for problem in problems:
			push_error(problem)
		map.free()
		quit(1)
		return
	print("Neighborhood saved to " + OUTPUT)
	print("Serialized render transforms, visibility bounds and floor/buildings validated.")
	map.free()
	quit()
