extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Events = preload("res://scripts/city/figueiras_events.gd")
const TimingGate = preload("res://scripts/vehicle/timing_gate.gd")
const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")

var _car: PlayerCar
var _rig: Node3D
var _sprint: Node3D
var _effects: Node3D
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rendered := "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	RenderingServer.set_render_loop_enabled(false)
	root.get_node("WaveSettings").set_graphics_preset("medium" if rendered else "economy")
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) != OK:
		quit(1)
		return
	await scene_changed
	FixtureInput.isolate()
	_car = current_scene.get_node("PlayerCar")
	_rig = current_scene.get_node("ChaseCamera")
	_rig.set_process_unhandled_input(false)
	_sprint = current_scene.get_node("AlamedaSprint")
	_effects = current_scene.get_node("TireEffects")
	current_scene.get_node("Traffic").set_active(false)
	current_scene.get_node("DayNightCycle").running = false
	await _frames(30)
	_check(_car.surface_name == "asfalto" and is_equal_approx(_car.surface_friction, 1.05), "the start lane gives the original asphalt grip")
	_check(_effects._cloud.multimesh.visible_instance_count == 0, "idle tires do not create smoke")
	_reference_gate()
	await _surface_samples()
	await _check_weight_and_skid(rendered)
	await _run_sprint(rendered)
	print("Figueiras driving: %d checks, %d failures" % [_checks, _failures])
	await FixtureAudio.drain(self)
	quit(0 if _failures == 0 else 1)


func _reference_gate() -> void:
	var gate: Transform3D = _sprint.gates[0]
	var forward := -gate.basis.z
	var center := gate.origin + Vector3.UP * 0.4
	var half_width: float = _sprint.widths[0]
	_check(is_equal_approx(TimingGate.crossing_fraction(gate, center - forward, center + forward * 3.0, half_width, 2.8), 0.25),
		"the timer interpolates crossings within the physics tick")
	_check(is_inf(TimingGate.crossing_fraction(gate, center + forward, center - forward, half_width, 2.8))
		and is_inf(TimingGate.crossing_fraction(gate, center - forward + gate.basis.x * 6, center + forward + gate.basis.x * 6, half_width, 2.8)),
		"wrong-way crossings and the opposite lane do not count")


func _surface_samples() -> void:
	_place(Vector2(-125.0, Layout.ROWS[1] + Layout.LOCAL_HALF + 1.23), -PI * 0.5, 0.0)
	await _frames(18)
	_check(_car.is_on_floor() and _car.surface_name == "calçada" and absf(_car.surface_friction - 0.88) < 0.008, "wheel contacts recognize urban paving")
	_place(Vector2(22.0, -10.0), -PI * 0.5, 0.0)
	await _frames(18)
	_check(_car.is_on_floor() and _car.surface_name == "gramado" and absf(_car.surface_friction - 0.66) < 0.008, "grass is supported with lower grip")
	_place(Vector2(-125.0, Layout.ROWS[1] + Layout.LOCAL_HALF + 0.20), -PI * 0.5, 0.0)
	await _frames(18)
	_check(_car.is_on_floor() and _car.surface_friction > 0.89 and _car.surface_friction < 1.03, "mixed tire contacts blend grip across the curb")


func _check_weight_and_skid(rendered: bool) -> void:
	_place(Vector2(-174.0, Layout.SPAWN.y), -PI * 0.5, 17.0)
	# Seed the forward momentum, then compare the suspension before and after braking.
	Input.action_press("accelerate")
	await _frames(18)
	var body := _car.get_node("Visuals/Body") as Node3D
	var loaded_pitch := body.rotation.x
	Input.action_release("accelerate")
	Input.action_press("brake", 0.8)
	await _frames(13)
	_check(body.rotation.x < -0.017 and body.rotation.x < loaded_pitch - 0.023, "braking pitches the nose down from the accelerating attitude")
	_release()
	if rendered:
		RenderingServer.set_render_loop_enabled(true)
	_place(Vector2(-171.0, Layout.SPAWN.y), -PI * 0.5, 18.5)
	Input.action_press("handbrake")
	Input.action_press("steer_right", 0.7)
	await _frames(14)
	_check(_effects._cloud.multimesh.visible_instance_count > 0, "the locked rear tires emit smoke at their asphalt contacts")
	Input.action_release("handbrake")
	Input.action_press("accelerate", 0.65)
	await _frames(35 if rendered else 11)
	_check(_effects._marks.size() > 4 and _effects._map_mesh.get_surface_count() == 1, "slipping rear wheels leave one batched set of rubber marks")
	if rendered:
		_capture("derrapagem")
		RenderingServer.set_render_loop_enabled(false)
	_release()
	_car.reset_car()
	_check(_effects._marks.is_empty() and _effects._cloud.multimesh.visible_instance_count == 0, "reset removes the skid trail and smoke")


func _run_sprint(rendered: bool) -> void:
	const RADIUS := 14.0
	var lane := Layout.SPAWN.y + Layout.AVENUE_LANE
	var alameda := Layout.urban_routes()[1]
	var exit_lane := alameda.offset_at(21.0, -2.25)
	var pivot := Vector2(exit_lane.x - RADIUS, lane + RADIUS)
	_place(Vector2(-162.0, lane), -PI * 0.5, 10.0)
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_T
	toggle.pressed = true
	FixtureInput.inject(toggle)
	await _frames(1)
	toggle.pressed = false
	FixtureInput.inject(toggle)
	_check(_sprint.next_gate == 0, "T arms the district activity without moving the car")
	if rendered:
		_capture("largada")
	var brakes := 0
	var frames := 0
	var unsupported := 0
	var margin := INF
	var focus_yaw := 0.0
	var farthest_gate := 0
	for frame in 1600:
		var site := Vector2(_car.global_position.x, _car.global_position.z)
		farthest_gate = maxi(farthest_gate, _sprint.next_gate)
		if _sprint.last_time > 0.0:
			break
		var target := Vector2(site.x + 6, lane)
		var speed := lerpf(31.0, 65.0, smoothstep(10.0, 45.0, pivot.x - site.x))
		if site.y >= pivot.y:
			var station := alameda.project(site).x
			target = alameda.offset_at(station + 6.0, -2.25)
			speed = lerpf(33.0, 54.0, smoothstep(28.0, 74.0, station))
		elif site.x >= pivot.x - 6.0:
			var angle := clampf((site - pivot).angle(), -PI * 0.5, 0.0) + 6.0 / RADIUS
			target = pivot + Vector2.from_angle(minf(angle, 0.0)) * RADIUS + Vector2.DOWN * maxf(angle, 0.0) * RADIUS
			focus_yaw = maxf(focus_yaw, absf(_rig.camera.rotation.y))
		_drive(target, speed)
		brakes += int(Input.is_action_pressed("brake"))
		frames += 1
		margin = minf(margin, -Layout.road_distance(site))
		unsupported += int(not _car.is_on_floor() and frame > 6)
		await _frames(1)
	_release()
	print("Alameda sprint %.3f s, peak preview %.1f°, asphalt margin %.2f m, %d/%d brake frames, %d unsupported" %
		[_sprint.last_time, rad_to_deg(focus_yaw), margin, brakes, frames, unsupported])
	_check(_sprint.last_time > 12.0 and _sprint.last_time < 40.0 and farthest_gate == 4, "normal throttle, braking and steering complete every gate in order")
	_check(brakes > 12 and margin > 0.80 and unsupported == 0, "the sprint demands braking and stays supported within the pavement")
	_check(focus_yaw > deg_to_rad(3.0) and focus_yaw < deg_to_rad(9.0), "the camera previews the turn with a bounded angle")
	var times := ConfigFile.new()
	var loaded := times.load(Events.BEST_TIME_PATH)
	_check(loaded == OK and is_equal_approx(float(times.get_value("alameda", "best_seconds", 0.0)), float(_sprint.best_time)), "the best time is saved for the next session")
	if rendered:
		_capture("resultado")
		current_scene.get_node("DayNightCycle").set_hour(18.6)
		await _frames(8)
		_capture("anoitecer")
	var best: float = _sprint.best_time
	toggle.pressed = true
	FixtureInput.inject(toggle)
	await _frames(1)
	toggle.pressed = false
	FixtureInput.inject(toggle)
	_check(_sprint.next_gate == 0, "T can immediately stage another attempt")
	_car.reset_car()
	_check(_sprint.next_gate < 0 and is_equal_approx(_sprint.best_time, best), "reset ends any active run and keeps the record")


func _place(site: Vector2, heading: float, speed: float) -> void:
	_release()
	_car.reset_car()
	_car.global_transform = Transform3D(Basis(Vector3.UP, heading), Layout.surface_point(site, 0.39))
	_car.velocity = -_car.global_basis.z * speed
	_rig.snap_to_target()


func _drive(target: Vector2, speed: float) -> void:
	var site := Vector2(_car.global_position.x, _car.global_position.z)
	var forward := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
	var steering := clampf(forward.angle_to(target - site) * 2.7, -1.0, 1.0)
	_release()
	Input.action_press("steer_right" if steering >= 0.0 else "steer_left", absf(steering))
	var error := speed - _car.get_speed_kmh()
	if absf(error) >= 0.9:
		Input.action_press("accelerate" if error > 0.0 else "brake", clampf(absf(error) * 0.19, 0.08, 1.0))


func _release() -> void:
	for action in ["accelerate", "brake", "handbrake", "steer_left", "steer_right"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _capture(name: String) -> void:
	RenderingServer.force_draw(false)
	var status := root.get_texture().get_image().save_jpg("user://wave-%s.jpg" % name, 0.91)
	_check(status == OK, "captured %s in the game renderer" % name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
