extends SceneTree
func _initialize() -> void:
	var valid := FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://project.godot")
	valid = valid and ResourceLoader.exists("res://assets/textures/neighborhood/leaf-cluster-v1.png") and not ResourceLoader.exists("res://references/realism/Pasted image.png")
	print("PASS: exported package has runtime foliage and excludes working reference images" if valid else "FAIL: exported resource identity or foliage/reference packaging")
	quit(0 if valid else 1)
