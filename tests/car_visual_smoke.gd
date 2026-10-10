extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	InputSetup.configure()
	for action in ["accelerate", "brake", "headlights"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var car: PlayerCar = load("res://scenes/cars/player_car.tscn").instantiate()
	car.position.y = 10
	scene.add_child(car)
	var stationary: PlayerCar = load("res://scenes/cars/player_car.tscn").instantiate()
	stationary.position = Vector3(10, 10, 0)
	scene.add_child(stationary)
	stationary.set_physics_process(false)
	var body := car.get_node("Visuals/Body") as MeshInstance3D
	var lamps: Dictionary = {}
	var valid_normals := true
	for surface in body.mesh.get_surface_count():
		var material := body.get_active_material(surface) as StandardMaterial3D
		lamps[material.resource_name] = material
		var arrays := body.mesh.surface_get_arrays(surface)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			valid_normals = valid_normals and normal.is_finite() and absf(normal.length() - 1.0) < 0.02
	_check(valid_normals, "saved body normals remain finite and normalized for lighting")
	var tail: StandardMaterial3D = lamps.get("Hatch1000_tail_lamp")
	var reverse: StandardMaterial3D = lamps.get("Hatch1000_reverse_lamp")
	var front: StandardMaterial3D = lamps.get("Hatch1000_headlight_glass")
	var left := car.get_node("Visuals/Body/HeadlightLeft") as SpotLight3D
	var right := car.get_node("Visuals/Body/HeadlightRight") as SpotLight3D
	_check(front != null and front.emission_enabled and front.emission_energy_multiplier > 0 and left.visible and right.visible, "common vehicle starts with luminous lenses and two working headlights")
	Input.action_press("headlights")
	await _frames(2)
	_check(not left.visible and not right.visible and front.emission_energy_multiplier == 0, "headlight command disables both beams and lens emission")
	await _frames(3)
	_check(not car.headlights_on, "holding the headlight command never toggles repeatedly")
	_check(stationary.headlights_on and stationary.get_node("Visuals/Body/HeadlightLeft").visible, "headlight command leaves other cars' lights unchanged")
	car.reset_car()
	_check(not car.headlights_on, "vehicle reset preserves the chosen headlight state")
	Input.action_release("headlights")
	await _frames(2)
	Input.action_press("headlights")
	await _frames(2)
	Input.action_release("headlights")
	_check(left.visible and right.visible and front.emission_energy_multiplier > 0, "next headlight command restores beams and lens emission together")
	_check(tail != null and reverse != null, "saved car carries independent brake and reverse optics")
	if tail != null and reverse != null:
		await _frames(2)
		var resting := tail.emission_energy_multiplier
		Input.action_press("brake")
		await _frames(2)
		_check(tail.emission_energy_multiplier > resting * 5, "brake pedal illuminates both rear brake lenses")
		var other_body := stationary.get_node("Visuals/Body") as MeshInstance3D
		var isolated := true
		for surface in other_body.mesh.get_surface_count():
			var material := other_body.get_active_material(surface) as StandardMaterial3D
			if material.resource_name == "Hatch1000_tail_lamp":
				isolated = material != tail and material.emission_energy_multiplier == resting
		_check(isolated, "braking never changes another car's shared mesh material")
		Input.action_release("brake")
		car.velocity = Vector3.BACK * 3
		await _frames(2)
		_check(reverse.emission_energy_multiplier > 0 and tail.emission_energy_multiplier == resting, "backward motion enables reverse optics without holding brake lights")
		Input.action_press("accelerate")
		await _frames(2)
		_check(tail.emission_energy_multiplier > resting * 5, "braking backward with the forward pedal also lights the brake lenses")
		Input.action_release("accelerate")
		car.reset_car()
		_check(reverse.emission_energy_multiplier == 0, "reset immediately clears the reverse lights")
	for action in ["accelerate", "brake", "headlights"]:
		Input.action_release(action)
	scene.queue_free()
	await _frames(2)
	print("Car visuals: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

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
