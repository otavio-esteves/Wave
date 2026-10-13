extends SceneTree

const FixtureInput = preload("fixture_input.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("medium")
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	FixtureInput.isolate()
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	car.set_physics_process(false)
	var probe: ReflectionProbe = world.get_node("VehicleReflection")
	var cycle := world.get_node("DayNightCycle")
	cycle.running = false
	_check(probe.visible and probe.update_mode == ReflectionProbe.UPDATE_ONCE, "detailed graphics enable one local one-shot environment capture")
	_check(probe.cull_mask == 1 and probe.reflection_mask == 2, "capture excludes the hero car and affects only its visual layer")
	var volume := AABB(probe.global_position - probe.size / 2, probe.size)
	_check(volume.has_point(car.global_position + Vector3(62, 0, 0)) and volume.has_point(car.global_position - Vector3(62, 0, 0)), "capture volume covers a full update interval at the vehicle speed cap")
	_check(car.find_children("*", "GeometryInstance3D", true, false).all(func(node): return node.layers == 2), "body, wheels and contact shadow remain visible on the dedicated vehicle layer")
	var camera: Camera3D = world.get_node("ChaseCamera/Camera3D") if world.has_node("ChaseCamera/Camera3D") else world.get_node("ChaseCamera").find_children("*", "Camera3D", true, false)[0]
	_check(camera.cull_mask & 2 != 0, "playable camera still includes the vehicle layer")
	var start := probe.position
	car.position += Vector3.RIGHT * 5
	probe._process(1.1)
	_check(probe.position == start, "small movements reuse the local capture")
	car.position += Vector3.RIGHT * 30
	probe._process(1.1)
	_check(probe.global_position.distance_to(car.global_position + Vector3.UP * 1.4) < 0.01, "local environment recentres after travelling to another street")
	start = probe.position
	cycle.set_hour(23)
	probe._process(1.1)
	_check(probe.position != start and probe._last_hour == 23, "stationary clock changes refresh the environment without stale daytime reflections")
	car.reset_car()
	_check(probe.global_position.distance_to(car.global_position + Vector3.UP * 1.4) < 0.01, "vehicle reset immediately restores the local reflection origin")
	settings.set_graphics_preset("economy")
	_check(not probe.visible and not probe.is_processing(), "economy disables the capture and its update loop")
	start = probe.position
	car.position += Vector3.RIGHT * 50
	probe.refresh()
	_check(probe.position == start, "disabled capture stays dormant during resets or movement")
	settings.set_graphics_preset("medium")
	_check(probe.visible and probe.global_position.distance_to(car.global_position + Vector3.UP * 1.4) < 0.01, "restoring detail recaptures the current street")
	world.queue_free()
	for frame in 4:
		await process_frame
	print("Vehicle reflections: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)
