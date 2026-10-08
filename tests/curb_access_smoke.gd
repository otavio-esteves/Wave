extends "res://tests/elevation_smoke.gd"


func _run() -> void:
	change_scene_to_file("res://scenes/world/drive_streamed_corridor.tscn")
	await scene_changed
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var streamer: WorldStreamer = world.get_node("WorldStreamer")
	car.forward_speed = 1.2
	# Keep the nose clear of the building facade beyond the narrow sidewalk.
	var routes := [[3.5, 7.9], [7.9, 3.5], [-3.5, -7.9], [-7.9, -3.5]]
	for route in routes:
		var rightward: bool = route[1] > route[0]
		world.teleport_to(Vector3(route[0], 0.36, -62), -PI / 2 if rightward else PI / 2)
		await _support(streamer)
		await _frames(8)
		var holds := streamer.blocking_events
		var arrived := false
		var peak := 0.0
		Input.action_press("accelerate", 0.6)
		for frame in 600:
			await _frames(1)
			peak = maxf(peak, car.position.y)
			if (rightward and car.position.x >= route[1]) or (not rightward and car.position.x <= route[1]):
				arrived = true
				break
		Input.action_release("accelerate")
		_check(arrived and car.is_on_floor() and streamer.blocking_events == holds, "actual avenue sidewalk from x=%s to x=%s traverses its 28 cm lip without stopping or a guard hold; end=%s" % [route[0], route[1], car.position])
		_check(peak < 0.95 and absf(car.position.z + 62) < 0.2, "sidewalk crossing remains grounded and aligned")
	world.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	await _frames(5)
	await create_timer(0.2).timeout
	print("Curb access: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
