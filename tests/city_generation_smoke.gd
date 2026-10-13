extends SceneTree

const Generation = preload("res://scripts/city/pilot_city_generation.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://atomic-city.scn"
	var city := _city(1.0)
	_check(Generation.save(city, output) == OK, "first generation publishes a complete entry scene")
	city.free()
	var first: Node3D = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	var first_directory: String = first.get_meta("generation_directory")
	_check(first.get_node("Geometry_0_0/Paving").position.x == 1.0, "published scene loads its staged geometry")
	var before := FileAccess.get_sha256(output)
	_check(Generation.publish("user://missing-generation.scn", output) != OK and FileAccess.get_sha256(output) == before, "failed generation leaves the previous entry byte-for-byte intact")
	var broken := FileAccess.open("user://broken-city.tscn", FileAccess.WRITE)
	broken.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="Mesh" path="user://missing-mesh.tres" id="1"]\n[node name="City" type="MeshInstance3D"]\nmesh = ExtResource("1")\n')
	broken.close()
	_check(Generation.publish("user://broken-city.tscn", output) == ERR_FILE_MISSING_DEPENDENCIES and FileAccess.get_sha256(output) == before, "missing staged dependency cannot replace the working city")
	city = _city(2.0)
	_check(Generation.save(city, output) == OK, "second generation commits successfully")
	city.free()
	var second: Node3D = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	_check(second.get_meta("generation_directory") != first_directory and second.get_node("Geometry_0_0/Paving").position.x == 2.0, "replacement references only its own immutable dependencies")
	_check(FileAccess.file_exists(first_directory.path_join("city.scn")) and first.get_node("Geometry_0_0/Paving").position.x == 1.0, "previous generation remains loadable after replacement")
	first.free()
	second.free()
	var builder := preload("res://scripts/city/pilot_city_builder.gd").new()
	builder.begin("SurfaceNames", "Colliders")
	builder._palette()
	builder._premium_palette()
	builder._projected_patch("Stripe", Vector3(10, 0, 10), Vector2.ONE, "white", 0.045)
	builder._projected_patch("Paving", Vector3(10, 0, 10), Vector2.ONE, "paving", 0.035)
	builder._flush_surfaces()
	_check(builder.scene_root.has_node("Paving_0_0") and builder.scene_root.has_node("Paving_paving_0_0"), "different paving materials in one tile receive deterministic unique names")
	builder.scene_root.free()
	print("City generation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _city(x: float) -> Node3D:
	var city := Node3D.new()
	city.name = "PilotCity"
	var body := StaticBody3D.new()
	body.name = "Colliders"
	city.add_child(body)
	body.owner = city
	var mesh := MeshInstance3D.new()
	mesh.name = "Paving"
	mesh.position.x = x
	mesh.mesh = BoxMesh.new()
	city.add_child(mesh)
	mesh.owner = city
	return city


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)
