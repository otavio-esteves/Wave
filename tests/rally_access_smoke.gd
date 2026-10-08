extends SceneTree

const Layout = preload("res://scripts/rally/rally_layout.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := load("res://scenes/rally/drive_rally.tscn").instantiate() as Node3D
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rally-map="):
			var previous := world.get_node("RallyMap")
			world.remove_child(previous)
			previous.free()
			var replacement := load(argument.trim_prefix("--rally-map=")).instantiate() as Node3D
			replacement.name = "RallyMap"
			world.add_child(replacement)
	if "--box-collider" in OS.get_cmdline_user_args():
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 0.7, 3.65)
		world.get_node("PlayerCar/Collision").shape = shape
	root.add_child(world)
	current_scene = world
	await _frames(1)
	var car: PlayerCar = current_scene.get_node("PlayerCar")
	var points := Layout.route()
	# Sample clear shoulders; nearby trunks, rocks and posts remain obstacles.
	for index in [80, 115, 195, 245, 315, 405, 475, 555, 635, 695]:
		var right := Layout.tangent(points, index).cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			car.reset_car()
			var start: Vector3 = points[index] + right * side * 7.5
			car.global_position = Layout.ground(start.x, start.z) + Vector3.UP * 0.5
			var direction: Vector3 = -right * side
			var heading := atan2(-direction.x, -direction.z)
			car.rotation = Vector3(0, heading, 0)
			car.forward_speed = 220.0 / 3.6
			await _frames(25)
			var arrived := false
			for frame in 900:
				Input.action_release("accelerate")
				Input.action_release("brake")
				Input.action_press("accelerate" if car.drive_speed < 3 else "brake", 0.5)
				var error := wrapf(heading - car.get_heading(), -PI, PI)
				Input.action_release("steer_left")
				Input.action_release("steer_right")
				Input.action_press("steer_left" if error > 0 else "steer_right", minf(absf(error) * 2.4, 1.0))
				await _frames(1)
				if (car.global_position - points[index]).dot(right * side) < 0.5:
					arrived = true
					break
			Input.action_release("accelerate")
			Input.action_release("brake")
			Input.action_release("steer_left")
			Input.action_release("steer_right")
			if not arrived:
				for hit_index in car.get_slide_collision_count():
					var hit := car.get_slide_collision(hit_index)
					print("CONTACT: ", hit.get_collider(), " normal=", hit.get_normal(), " point=", hit.get_position())
			_check(arrived and car.is_on_floor() and car.surface_name == ("asfalto" if index < 180 else "cascalho"), "rally grass to road at sample %d side %.0f; end=%s" % [index, side, car.global_position])
			if arrived:
				car.reset_car()
				car.global_position = points[index] + Vector3.UP * 0.64
				car.rotation = Vector3(0, heading + PI, 0)
				await _frames(25)
				var exited := false
				for frame in 900:
					Input.action_release("accelerate")
					Input.action_release("brake")
					Input.action_press("accelerate" if car.drive_speed < 3 else "brake", 0.5)
					var error := wrapf(heading + PI - car.get_heading(), -PI, PI)
					Input.action_release("steer_left")
					Input.action_release("steer_right")
					Input.action_press("steer_left" if error > 0 else "steer_right", minf(absf(error) * 2.4, 1.0))
					await _frames(1)
					if (car.global_position - points[index]).dot(right * side) > 7.5:
						exited = true
						break
				for action in ["accelerate", "brake", "steer_left", "steer_right"]:
					Input.action_release(action)
				if not exited or not car.is_on_floor() or car.surface_name != "grama":
					print("EXIT STATE: arrived=", exited, " floor=", car.is_on_floor(), " surface=", car.surface_name, " velocity=", car.velocity)
					for hit_index in car.get_slide_collision_count():
						var hit := car.get_slide_collision(hit_index)
						print("EXIT CONTACT: ", hit.get_collider(), " normal=", hit.get_normal(), " point=", hit.get_position())
				_check(exited and car.is_on_floor() and car.surface_name == "grama", "rally road to grass at sample %d side %.0f; end=%s" % [index, side, car.global_position])
	current_scene.queue_free()
	await _frames(5)
	OS.delay_msec(150)
	print("Rally access: %d checks, %d failures" % [checks, failures])
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
