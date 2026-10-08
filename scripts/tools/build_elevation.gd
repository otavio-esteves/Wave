extends SceneTree


func _initialize() -> void:
	var output := "res://scenes/world/cells/elevation"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var error: Error = preload("res://scripts/world/elevation_builder.gd").new().build(output)
	print("Elevation lab: %s, output %s" % [error_string(error), output])
	quit(0 if error == OK else 1)
