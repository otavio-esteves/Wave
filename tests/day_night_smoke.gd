extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
	await scene_changed
	for frame in 5:
		await process_frame
	var world := current_scene
	var cycle := world.get_node("DayNightCycle")
	var sun: DirectionalLight3D = world.get_node("Sun")
	var moon: DirectionalLight3D = world.get_node("Moon")
	var environment: Environment = world.get_node("WorldEnvironment").environment
	var sky := environment.sky.sky_material as ShaderMaterial
	var car := world.get_node("PlayerCar")
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "advance_time"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	cycle.running = false
	_check(sky != null and sky.shader.code.contains("moon_disc") and sky.shader.code.contains("star"), "playable world uses the celestial sky shader")
	_check(cycle._lamps.size() >= 300 and cycle._pool.size() == 8, "whole district has lamp anchors and a bounded pool of eight local lights")
	var maximum_sun := 0.0
	for hour in [0.0, 5.5, 6.0, 9.0, 12.0, 16.5, 18.0, 19.0, 23.0]:
		cycle.set_hour(hour)
		maximum_sun = maxf(maximum_sun, sun.light_energy)
		_check(sun.light_energy >= 0 and moon.light_energy >= 0 and is_finite(sun.rotation.x), "celestial light orientation is finite at hour %.1f" % hour)
		_check((sun.global_basis.z + moon.global_basis.z).length() < 0.0001, "moon and sun travel opposite each other at hour %.1f" % hour)
		_check(is_equal_approx(float(sky.get_shader_parameter("night_factor")), cycle.night_factor), "background and scene lighting share the same phase at hour %.1f" % hour)
	_check(maximum_sun > 1.0, "daytime retains direct sunlight")
	cycle.set_hour(12.0)
	_check(sun.light_energy > 1.0 and moon.light_energy == 0 and cycle.night_factor == 0, "noon turns off moonlight, stars and lamps")
	_check(cycle._pool.all(func(light: OmniLight3D) -> bool: return not light.visible), "street lighting is off in daylight")
	var day_ambient := environment.ambient_light_energy
	cycle.set_hour(0.0)
	_check(sun.light_energy == 0 and moon.light_energy > 0 and cycle.night_factor == 1, "midnight has moonlight and full star visibility")
	_check(environment.ambient_light_energy < day_ambient and environment.ambient_light_energy > 0.1, "night is darker while preserving street readability")
	_check(cycle._pool.any(func(light: OmniLight3D) -> bool: return light.visible and light.light_energy > 0), "nearby street lamps physically illuminate the playable night")
	_check(cycle._emissive.any(func(material: StandardMaterial3D) -> bool: return material.emission_energy_multiplier > 0), "window and lamp lenses gain nighttime emission")
	_check(cycle._emissive.any(func(material: StandardMaterial3D) -> bool: return material.resource_name == "downtown_window" and material.emission_energy_multiplier > 0), "occupied skyscraper windows join the nighttime lighting cycle")
	car.set_physics_process(false)
	var layout = preload("res://scripts/city/pilot_city_layout.gd")
	for id in [150, 113, 120]:
		car.position = layout.node(id) + Vector3.UP * 0.4
		cycle.set_hour(0)
		for frame in 2:
			await process_frame
		_check(cycle._pool.any(func(light: OmniLight3D) -> bool: return light.visible and light.position.distance_to(car.position) < 85), "local lamp pool follows the car into district at node %d" % id)
		_check(world.get_node("HUD/Overlay/Telemetry/Readout").text.contains(layout.district_at(car.position.x)), "HUD identifies the district at node %d" % id)
	car.set_physics_process(true)
	var dark_hour: float = cycle.hour
	car.reset_car()
	_check(cycle.hour == dark_hour and car.headlights_on, "car reset preserves world time and the available headlight beams")
	cycle.set_hour(25.0)
	_check(cycle.clock_text() == "01:00", "clock wraps after midnight")
	cycle.set_hour(-1.0)
	_check(cycle.clock_text() == "23:00", "clock safely wraps negative inspection times")
	for crossing in [6.0, 18.0]:
		cycle.set_hour(crossing - 0.01)
		var energy := sun.light_energy
		var ambient := environment.ambient_light_energy
		cycle.set_hour(crossing + 0.01)
		_check(absf(sun.light_energy - energy) < 0.02 and absf(environment.ambient_light_energy - ambient) < 0.01, "dawn/dusk light changes continuously across hour %.0f" % crossing)
	cycle.set_hour(23.999)
	cycle.running = true
	for frame in 15:
		await process_frame
	_check(cycle.hour < 0.1, "normal simulation advances smoothly through midnight")
	var before: float = cycle.hour
	paused = true
	for frame in 8:
		await process_frame
	_check(cycle.hour == before, "pause freezes time and cloud motion")
	paused = false
	cycle.running = false
	cycle.set_hour(16.5)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F6
	event.pressed = true
	InputSetup.configure()
	Input.parse_input_event(event)
	for frame in 2:
		await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	_check(is_equal_approx(cycle.hour, 19.5), "F6 advances three hours through the actual input path")
	_check(InputMap.action_get_events("advance_time").any(func(binding: InputEvent) -> bool: return binding is InputEventJoypadButton and binding.button_index == JOY_BUTTON_RIGHT_SHOULDER), "DualShock R1 provides the same time control")
	var duration: float = cycle.day_duration_seconds
	cycle.set_hour(10.0)
	cycle._process(60.0)
	_check(cycle.hour == 10.0, "inspection lock stops automatic time advancement")
	cycle.running = true
	cycle._process(60.0)
	_check(is_equal_approx(cycle.hour, 10.0 + 60.0 * 24.0 / duration), "one real minute advances one game hour at the default rate")
	current_scene.queue_free()
	for frame in 3:
		await process_frame
	print("Day/night: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
