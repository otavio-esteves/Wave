extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const WORLD := "res://scenes/city/figueiras/drive_figueiras.tscn"
const CONTROLS := ["accelerate", "brake", "steer_left", "steer_right"]
var _car: PlayerCar
var _rig: Node3D
var _route: RefCounted
var _scenario := "avenida"
var _station := 0.0
var _lane := 0.0
var _speed := 41.0
var _position_start := Vector3.ZERO
var _rain := false
var _vsync := false
var _min_scale := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This benchmark requires a rendered window.")
		quit(2)
		return
	var preset := _argument("--preset=", "medium")
	if preset not in ["economy", "medium", "high"]:
		push_error("Use economy, medium or high.")
		quit(2)
		return
	_scenario = _argument("--route=", "avenida")
	if _scenario not in ["avenida", "alameda", "mirante", "horto", "mercado", "cabine", "galeria", "estacao", "passo", "baixada", "usina"]:
		push_error("Unknown route: " + _scenario)
		quit(2)
		return
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset(preset)
	_vsync = "--vsync" in OS.get_cmdline_user_args()
	settings.set_graphics("vsync", _vsync)
	settings.set_graphics("fps_limit", 0)
	if "--fullscreen" in OS.get_cmdline_user_args():
		settings.set_graphics("fullscreen", true)
	if "--fixed-scale" in OS.get_cmdline_user_args():
		settings.set_graphics("adaptive_3d", false)
	if change_scene_to_file(WORLD) != OK:
		quit(2)
		return
	await scene_changed
	for action in CONTROLS + ["handbrake", "reset_car", "city_weather"]:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	if "--no-traffic" in OS.get_cmdline_user_args():
		current_scene.get_node("Traffic").set_active(false)
	root.grab_focus()
	_car = current_scene.get_node("PlayerCar")
	_rig = current_scene.get_node("ChaseCamera")
	_rig.set_process_unhandled_input(false)
	var cycle := current_scene.get_node("DayNightCycle")
	cycle.running = false
	cycle.set_hour(16.25)
	_rain = "--rain" in OS.get_cmdline_user_args()
	if _rain:
		current_scene.get_node("Weather").set_wet(true)
	if _scenario == "cabine":
		_rig.view = 2
	await create_timer(clampf(float(_argument("--warmup=", "3")), 2.0, 20.0)).timeout
	root.grab_focus()
	if not _place():
		quit(2)
		return
	var duration := clampf(float(_argument("--seconds=", "14")), 6.0, 60.0)
	var frames: Array[float] = []
	var draws := 0.0
	var primitives := 0.0
	var physics_time := 0.0
	var speed_sum := 0.0
	var focus_frames := 0
	var start := Time.get_ticks_usec()
	var previous := start
	var end := start + roundi(duration * 1000000.0)
	var physics_start := Engine.get_physics_frames()
	physics_frame.connect(_follow)
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		if now - start >= 500000:
			_min_scale = minf(_min_scale, root.scaling_3d_scale)
			frames.append((now - previous) * 0.001)
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			physics_time += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			speed_sum += _car.get_speed_kmh()
			focus_frames += int(root.has_focus())
		previous = now
	physics_frame.disconnect(_follow)
	for action in CONTROLS:
		Input.action_release(action)
	var ticks := Engine.get_physics_frames() - physics_start
	_report(preset, frames, draws, primitives, physics_time, speed_sum, focus_frames, ticks)
	await settings.quit_game()


func _place() -> bool:
	var point := Layout.SPAWN
	var forward := Vector2.RIGHT
	_lane = point.y
	match _scenario:
		"alameda":
			_route = Layout.urban_routes()[1]
			_station = 24.0
			_lane = -2.26
			_speed = 31.0
		"mirante":
			_route = Layout.scenic_routes()[0]
			_station = 28.0
			_lane = -2.4
			_speed = 48.0
		"galeria", "estacao":
			_route = Layout.urban_routes()[Layout.GALERIA_ROUTE if _scenario == "galeria" else Layout.ESTACAO_ROUTE]
			_station = 7.5
			_lane = -1.6
			_speed = 30.0
		"passo":
			_route = Layout.scenic_routes()[Layout.PASSO_ROUTE]
			_station = 142.0
			_lane = -1.75
			_speed = 42.0
		"baixada":
			_route = Layout.district_routes()[Layout.Baixada.AVENIDA]
			_station = 375.0
			_lane = -2.40
			_speed = 63.0
		"usina":
			_route = Layout.district_routes()[Layout.Baixada.TRAVESSA]
			_station = 15.0
			_lane = -1.85
			_speed = 34.0
		"horto":
			if Layout.urban_routes().size() < 3:
				push_error("This build has no Horto road.")
				return false
			_route = Layout.urban_routes()[2]
			_station = 21.0
			_lane = -2.05
			_speed = 38.0
		"mercado":
			if Layout.urban_routes().size() < 4:
				push_error("This build has no Mercado road.")
				return false
			_route = Layout.urban_routes()[3]
			_station = 21.0
			_lane = -2.02
			_speed = 32.0
	if _route != null:
		point = _route.offset_at(_station, _lane)
		forward = _route.direction_at(_station)
	_car.reset_car()
	var yaw := atan2(-forward.x, -forward.y)
	_car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Layout.surface_point(point, 0.39))
	_car.velocity = Vector3(forward.x, 0.0, forward.y) * (_speed / 3.6)
	_rig.snap_to_target()
	if _scenario == "cabine":
		_rig.view = 2
	_position_start = _car.global_position
	return true


func _follow() -> void:
	var point := Vector2(_car.global_position.x, _car.global_position.z)
	var forward := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
	var aim := Vector2(point.x + 8.0, _lane)
	var target_speed := _speed
	if _route != null:
		var station: float = _route.project(point).x
		var first: Vector2 = _route.direction_at(station)
		var next: Vector2 = _route.direction_at(station + 14.0)
		aim = _route.offset_at(station + 7.5, _lane)
		target_speed = maxf(24.0, target_speed - absf(first.angle_to(next)) * 60.0)
		if station + 12.0 >= _route.length:
			target_speed = minf(target_speed, 14.0)
	var turn := clampf(forward.angle_to(aim - point) * 2.8, -1.0, 1.0)
	var pedal := clampf((target_speed - _car.get_speed_kmh()) * 0.19, -1.0, 1.0)
	Input.action_press("steer_right", maxf(turn, 0.0))
	Input.action_press("steer_left", maxf(-turn, 0.0))
	Input.action_press("accelerate", maxf(pedal, 0.0))
	Input.action_press("brake", maxf(-pedal, 0.0))


func _report(preset: String, frames: Array[float], draws: float, primitives: float, physics_ms: float, speed: float, focus: int, ticks: int) -> void:
	if frames.is_empty():
		push_error("No frame measurements were collected.")
		return
	frames.sort()
	var count := frames.size()
	var total := 0.0
	var slower_than_30 := 0
	for duration in frames:
		total += duration
		slower_than_30 += int(duration > 1000.0 / 30.0)
	var tail_count := maxi(1, ceili(count * 0.01))
	var tail_time := 0.0
	for index in range(count - tail_count, count):
		tail_time += frames[index]
	var viewport := root.get_visible_rect().size * root.get_stretch_transform().get_scale()
	var result := {
		"preset": preset, "route": _scenario, "driver": DisplayServer.get_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "window": str(root.size),
		"viewport": str(Vector2i(viewport.round())), "min_3d_resolution": str(Vector2i((viewport * _min_scale).round())),
		"vsync": _vsync, "rain": _rain,
		"scale_3d_min": _min_scale, "scale_3d_final": root.scaling_3d_scale,
		"frames": count, "focused": focus, "fps": 1000.0 * count / total,
		"p95_ms": frames[mini(count - 1, floori(count * 0.95))],
		"p99_ms": frames[mini(count - 1, floori(count * 0.99))],
		"one_percent_low_fps": 1000.0 * tail_count / tail_time,
		"frame_share_over_33ms": float(slower_than_30) / count,
		"draws": draws / count, "primitives": primitives / count, "physics_ms": physics_ms / count, "physics_ticks": ticks,
		"speed_kmh": speed / count, "distance_m": _position_start.distance_to(_car.global_position),
	}
	var record := JSON.stringify(result)
	print("FIGUEIRAS_BENCH " + record)
	var output := _argument("--output=", "")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_line(record)
		else:
			push_error("Cannot open benchmark output: " + output)


func _argument(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback
