extends SceneTree

const Builder = preload("res://scripts/corridor/corridor_builder.gd")
const MAP := "res://scenes/corridor/corridor_map.tscn"
const WORLD := "res://scenes/corridor/drive_corridor.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var builder := Builder.new()
	var generated := builder.build()
	var saved: Node3D = load(MAP).instantiate()
	_check(_signature(generated) == _signature(saved), "offline corridor preserves deterministic placements and colliders after saving")
	var second := Builder.new().build()
	_check(_signature(generated) == _signature(second), "same seed and authored layout reproduce the corridor")
	_check(saved.get_meta("length_m") == 600.0 and saved.get_meta("seed") == 5547, "corridor records 600 metres and seed")
	_check(saved.has_node("Workshop") and saved.has_node("Market"), "both authored landmarks persist in the generated scene")
	_check(saved.find_children("*", "Label3D", true, false).is_empty(), "static corridor signs avoid the measured first-use cost of runtime 3D fonts")
	var cards_safe := true
	var instances := 0
	for batch: Node in saved.get_children():
		if batch is MultiMeshInstance3D:
			instances += batch.multimesh.instance_count
			if batch.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
				cards_safe = cards_safe and batch.multimesh.billboard_radius >= 6.0
	_check(cards_safe, "billboards keep conservative rotating visibility bounds")
	print("Corridor inventory: %d nodes, %d batched instances, %d box colliders" % [saved.get_child_count(), instances, saved.get_node("CorridorColliders").get_child_count()])
	generated.free()
	saved.free()
	second.free()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	current_scene.corridor_button.pressed.emit()
	await scene_changed
	print("Corridor input isolation: joypads=", Input.get_connected_joypads(), " accelerator=", Input.get_action_strength("accelerate"), " brake=", Input.get_action_strength("brake"), " left=", Input.get_action_strength("steer_left"), " right=", Input.get_action_strength("steer_right"))
	# Scripted routes own their commands even when a physical controller is attached.
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "pause", "camera_view", "camera_back", "headlights"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	await _frames(10)
	_check(current_scene.scene_file_path == WORLD, "main menu opens the visual corridor")
	var car: PlayerCar = current_scene.get_node("PlayerCar")
	_check(car.is_on_floor() and car.get_speed_kmh() < 0.1, "corridor spawn is clear and grounded")
	car.forward_speed = 24.0
	Input.action_press("accelerate")
	# Route completion should allow the slower launch without overshooting
	# the authored corridor while waiting for a fixed duration.
	for frame in 1900:
		await _frames(1)
		if car.position.z < -570.0:
			break
	_check(car.position.z < -550 and absf(car.position.x - 3.5) < 0.1 and car.is_on_floor(), "avenue is continuously driveable through both intersections")
	_check(current_scene.get_node("CarContactShadow").position.distance_to(Vector3(car.position.x, 0.045, car.position.z)) < 0.1, "cheap Legacy contact shadow follows the car without altering physics")
	Input.action_release("accelerate")
	car.reset_car()
	car.global_position = Vector3(-65, 0.36, -160)
	car.rotation.y = -PI / 2
	car.forward_speed = 8.0
	current_scene.get_node("ChaseCamera").snap_to_target()
	await _frames(3)
	Input.action_press("accelerate")
	await _frames(1000)
	_check(car.position.x > 58 and car.is_on_floor(), "side street connects across the avenue without blocking curbs")
	Input.action_release("accelerate")
	car.reset_car()
	car.global_position = Vector3(3.5, 0.36, -115)
	car.rotation.y = PI / 2
	current_scene.get_node("ChaseCamera").snap_to_target()
	await _frames(3)
	Input.action_press("accelerate")
	await _frames(430)
	_check(car.position.x < -20 and car.position.x > -27 and car.get_speed_kmh() < 1.0, "workshop forecourt is accessible and the closed facade stops the car")
	Input.action_release("accelerate")
	car.reset_car()
	await _frames(3)
	_check(car.position.distance_to(car.spawn_transform.origin) < 0.1, "reset retains the corridor spawn and camera contract")
	current_scene.get_node("HUD").set_paused(true)
	current_scene.get_node("HUD/Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(not paused and get_nodes_in_group("wave_audio").is_empty(), "return to menu releases corridor audio and pause")
	current_scene.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	await process_frame
	print("Corridor smoke test: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _signature(map: Node3D) -> String:
	var placements: Array[String] = []
	for node in map.find_children("*", "", true, false):
		if node is MultiMeshInstance3D:
			placements.append(str(node.name) + str(node.position) + str(node.multimesh.instance_transforms))
		elif node is CollisionShape3D:
			placements.append(str(node.transform) + str(node.shape.size))
	return "\n".join(placements).sha256_text()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
