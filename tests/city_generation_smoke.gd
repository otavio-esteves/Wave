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
	var cached_mesh := BoxMesh.new()
	cached_mesh.size = Vector3(3, 4, 5)
	var cached_path := "user://cached-staged-mesh.res"
	ResourceSaver.save(cached_mesh, cached_path)
	cached_mesh.take_over_path(cached_path)
	var cached_node := MeshInstance3D.new()
	cached_node.mesh = cached_mesh
	var cached_scene := PackedScene.new()
	cached_scene.pack(cached_node)
	ResourceSaver.save(cached_scene, "user://cached-staged-city.scn")
	DirAccess.remove_absolute(cached_path)
	_check(ResourceLoader.exists(cached_path) and not FileAccess.file_exists(cached_path), "deleted staged dependency remains cached in the regression fixture")
	_check(Generation.publish("user://cached-staged-city.scn", output) == ERR_FILE_MISSING_DEPENDENCIES and FileAccess.get_sha256(output) == before, "cached missing dependency cannot replace the working entry scene")
	ResourceSaver.save(cached_mesh, cached_path)
	_check(Generation.publish("user://cached-staged-city.scn", "user://restored-city.scn") == OK, "restoring a dependency allows a new complete publication")
	cached_node.free()
	cached_scene = null
	cached_mesh = null
	_remap_regression(output, before)
	city = _city(2.0)
	_check(Generation.save(city, output) == OK, "second generation commits successfully")
	city.free()
	var second: Node3D = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	_check(second.get_meta("generation_directory") != first_directory and second.get_node("Geometry_0_0/Paving").position.x == 2.0, "replacement references only its own immutable dependencies")
	_check(FileAccess.file_exists(first_directory.path_join("city.scn")) and first.get_node("Geometry_0_0/Paving").position.x == 1.0, "previous generation remains loadable after replacement")
	first.free()
	second.free()
	var staged_output := "user://review/staged-city.scn"
	var published_hash := FileAccess.get_sha256(output)
	city = _city(3.0)
	_check(Generation.save(city, staged_output, "user://final-city-generations") == OK and FileAccess.get_sha256(output) == published_hash, "isolated staging can use the final resource family without changing the working entry")
	city.free()
	var reviewed: Node3D = ResourceLoader.load(staged_output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP).instantiate()
	_check(str(reviewed.get_meta("generation_directory")).begins_with("user://final-city-generations/") and reviewed.get_node("Geometry_0_0/Paving").position.x == 3.0, "reviewed entry references its final immutable dependencies")
	reviewed.free()
	_check(Generation.publish(staged_output, output) == OK and FileAccess.get_sha256(output) == FileAccess.get_sha256(staged_output), "reviewed entry publishes byte-for-byte without rewriting its dependencies")
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


func _remap_regression(output: String, before: String) -> void:
	var logical := "user://cached-logical.gd"
	var physical := "user://compiled-target.gd"
	var code := "extends Node3D\nconst MARKER := 42\n"
	_write(logical, code)
	_write(physical, code)
	var cached_logical := ResourceLoader.load(logical) as GDScript
	var cached_physical := ResourceLoader.load(physical) as GDScript
	var node := Node3D.new()
	node.set_script(cached_logical)
	var scene := PackedScene.new()
	scene.pack(node)
	var staged := "user://remapped-staged.scn"
	ResourceSaver.save(scene, staged)
	var mapping := ConfigFile.new()
	mapping.set_value("remap", "path", physical)
	mapping.save(logical + ".remap")
	_check(Generation.publish(staged, "user://remap-verified.scn") == OK, "valid remapped script dependency publishes with its physical target")
	DirAccess.remove_absolute(physical)
	_check(ResourceLoader.exists(logical) and ResourceLoader.exists(physical) and FileAccess.file_exists(logical) and not FileAccess.file_exists(physical), "logical and physical scripts remain cached after only the remap target disappears")
	_check(Generation.publish(staged, output) == ERR_FILE_MISSING_DEPENDENCIES and FileAccess.get_sha256(output) == before, "cached logical script and existing raw source cannot hide a missing remap target")
	_write(physical, code)
	_check(Generation.publish(staged, "user://remap-restored.scn") == OK, "restoring the physical remap target permits complete publication")
	mapping.set_value("remap", "path", 42)
	mapping.save(logical + ".remap")
	_check(Generation.publish(staged, output) == ERR_FILE_MISSING_DEPENDENCIES and FileAccess.get_sha256(output) == before, "malformed remap destination cannot fall back to an existing raw script")
	mapping.set_value("remap", "path", physical)
	mapping.save(logical + ".remap")
	var cycle := ConfigFile.new()
	cycle.set_value("remap", "path", logical)
	cycle.save(physical + ".remap")
	_check(Generation.publish(staged, output) == ERR_FILE_MISSING_DEPENDENCIES and FileAccess.get_sha256(output) == before, "remap cycles terminate safely without replacing the working entry")
	DirAccess.remove_absolute(physical + ".remap")
	_check(Generation.publish(staged, "user://remap-after-cycle.scn") == OK, "removing the remap cycle restores publication without stale validation state")
	node.free()
	scene = null
	cached_logical = null
	cached_physical = null


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


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
