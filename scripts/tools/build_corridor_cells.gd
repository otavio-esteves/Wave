extends SceneTree

func _initialize() -> void:
	var output := "res://scenes/world/cells/vale"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var builder := preload("res://scripts/world/corridor_cells_builder.gd").new()
	var error: Error = builder.build(output)
	print("Corridor cells: %s, output %s" % [error_string(error), output])
	quit(0 if error == OK else 1)
