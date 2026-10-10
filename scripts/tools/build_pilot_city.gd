extends SceneTree


func _initialize() -> void:
	var output := "res://scenes/city/pilot/pilot_city.scn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var error: Error = preload("res://scripts/city/pilot_city_builder.gd").new().save_city(output)
	print("Pilot city: %s, output %s" % [error_string(error), output])
	quit(0 if error == OK else 1)
