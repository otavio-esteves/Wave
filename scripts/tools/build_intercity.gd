extends SceneTree


func _initialize() -> void:
	var output := "res://scenes/world/cells/sol-serra"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var error: Error = preload("res://scripts/world/intercity_builder.gd").new().build_route(output)
	print("Intercity proof: %s, output %s" % [error_string(error), output])
	quit(0 if error == OK else 1)
