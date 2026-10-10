extends SceneTree
func _initialize() -> void:
 var scene: PackedScene = load("res://scenes/cars/player_car.tscn")
 var car := scene.instantiate()
 var body: ArrayMesh = car.get_node("Visuals/Body").mesh
 var wheel: ArrayMesh = load("res://assets/models/hatch_1000/wheel.tres")
 print(JSON.stringify({"package": FileAccess.file_exists("res://project.binary"), "model": car.get_meta("model_name"), "body_triangles": body.get_faces().size() / 3, "wheel_triangles": wheel.get_faces().size() / 3}))
 car.free()
 quit()
