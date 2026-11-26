extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Baixada = Layout.Baixada
const Navigation = preload("res://scripts/city/figueiras_navigation.gd")
const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")
const DELTA := 1.0 / 60.0
var _world: Node3D
var _city: Node3D
var _ground: StaticBody3D
var _car: PlayerCar
var _timing: Node3D
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_render_loop_enabled(false)
	root.get_node("WaveSettings").set_graphics_preset("economy")
	if change_scene_to_file("res://scenes/city/figueiras/drive_figueiras.tscn") != OK:
		quit(2)
		return
	await scene_changed
	FixtureInput.isolate()
	_world = current_scene
	_city = _world.get_node("City")
	_ground = _city.get_node("StreetAndTerrainSupport")
	_car = _world.get_node("PlayerCar")
	_timing = _world.get_node("AlamedaSprint")
	_world.get_node("Traffic").set_active(false)
	_world.get_node("DayNightCycle").running = false
	for tick in 8:
		await physics_frame
	var roads := Layout.district_routes()
	_check(roads.size() == 4 and _city.get_meta("baixada_road_length", 0.0) > 1300.0
		and _city.get_meta("baixada_buildings", 0) >= 30, "four added roads and the district are baked into the shipped scene")
	_check_support(roads)
	_check_bridges()
	_check_navigation(roads)
	await _drive_avenue(roads[Baixada.AVENIDA])
	await _drive_loading(roads[Baixada.TRAVESSA])
	_check_free_event()
	print("Baixada do Arroio: %d checks, %d failures" % [_checks, _failures])
	await FixtureAudio.drain(self)
	quit(int(_failures != 0))


func _check_support(roads: Array[Layout.Route]) -> void:
	var space := _car.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.68
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = sphere
	clearance.collision_mask = 1
	clearance.exclude = [_ground.get_rid()]
	for road in roads:
		var worst := 0.0
		var missing := 0
		var blocked := 0
		for station in range(4, floori(road.length) - 3, 4):
			for lane: float in [-2.45, 0.0, 2.45]:
				var site := Layout.surface_point(road.offset_at(station, lane))
				var query := PhysicsRayQueryParameters3D.create(site + Vector3.UP * 1.8, site - Vector3.UP * 1.2, 1)
				var hit := space.intersect_ray(query)
				if hit.is_empty() or hit.collider != _ground:
					missing += 1
					if missing <= 2:
						print("Missing road support ", road.title, " at ", station, " / ", lane, " ", site, " hit ", hit)
					continue
				worst = maxf(worst, absf(hit.position.y - site.y))
				clearance.transform.origin = hit.position + Vector3.UP * 0.94
				if not space.intersect_shape(clearance, 1).is_empty():
					blocked += 1
					if blocked <= 2:
						print("Obstruction ", road.title, " at ", station, " / ", lane, " ", site)
		_check(missing == 0 and blocked == 0 and worst < 0.28,
			"%s supports all three sampled driving lines (max %.2f m, %d gaps, %d obstacles)" % [road.title, worst, missing, blocked])


func _check_bridges() -> void:
	var space := _car.get_world_3d().direct_space_state
	var bridges := Layout.district_bridges()
	var separated := 0
	for road: Layout.Route in bridges:
		var center := Layout.surface_point(road.point_at(bridges[road]))
		var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(center + Vector3.UP, center - Vector3.UP, 1))
		var site := Vector3(Layout.creek_axis(center.z), Layout.CREEK_WATER_LEVEL + 0.18, center.z)
		var bed := space.intersect_ray(PhysicsRayQueryParameters3D.create(site, site - Vector3.UP * 2.5, 1))
		if not deck.is_empty() and not bed.is_empty() and deck.collider == _ground and bed.collider == _ground and deck.position.y - bed.position.y > 4.0:
			separated += 1
	_check(separated == 2, "the two new bridges carry the car over an independently colliding creek bed")


func _check_navigation(roads: Array[Layout.Route]) -> void:
	var nav := Navigation.new()
	var targets := [35.0, 100.0, 148.0, 72.0]
	var linked := 0
	for index in roads.size():
		var road := roads[index]
		var target: float = targets[index]
		var destination := road.point_at(target)
		var path := nav.route_to_start(Layout.SPAWN, Vector2.RIGHT, destination, road.direction_at(target))
		if path.size() < 4 or path[-1].distance_to(destination) > 0.65:
			continue
		var paved := true
		for segment in path.size() - 1:
			paved = paved and Layout.road_distance(path[segment].lerp(path[segment + 1], 0.5)) < 0.5
		linked += int(paved)
	_check(linked == roads.size(), "GPS connects the original spawn to all four roads along paved links")


func _drive_avenue(road: Layout.Route) -> void:
	_place(road, 26.0, -2.45, 10.0)
	var event := _event_index("baixada")
	_timing.select_event(event, true)
	var unsupported := 0
	var brake_frames := 0
	var last_station := 0.0
	var top_speed := 0.0
	for tick in 6500:
		var station := road.project(_site()).x
		last_station = station
		if _timing.last_time > 0.0:
			break
		var bending := absf(road.direction_at(station).angle_to(road.direction_at(station + 18.0)))
		brake_frames += int(_drive(road.offset_at(station + 8.0, -2.45), maxf(47.0, 76.0 - bending * 68.0)))
		top_speed = maxf(top_speed, _car.get_speed_kmh())
		unsupported += int(tick > 18 and not _car.is_on_floor())
		await physics_frame
	_release()
	print("Avenida da Baixada %.2f s, %.1f km/h maximum, %.1f m, %d brake ticks, %d unsupported" %
		[_timing.last_time, top_speed, last_station, brake_frames, unsupported])
	_check(_timing.last_time > 32.0 and _timing.last_time < 115.0 and _timing._fault.is_empty()
		and unsupported <= 3 and brake_frames > 25 and top_speed > 65.0, "the new sprint is completed with continuous pedal and steering input")


func _drive_loading(road: Layout.Route) -> void:
	_world.get_node("Weather").set_wet(true)
	_place(road, 16.0, -1.92, 7.5)
	var sheltered := 0.0
	var exposed := 0.0
	var concrete_samples := 0
	var last_station := 0.0
	for tick in 1000:
		var station := road.project(_site()).x
		last_station = station
		if station >= 106.0:
			break
		_drive(road.offset_at(station + 6.5, -1.92), 33.0)
		if station > 21.0 and station < 44.0:
			concrete_samples += int(_car.surface_name == "concreto")
			sheltered = maxf(sheltered, _car.surface_water)
		if station > 62.0 and station < 101.0:
			exposed = maxf(exposed, _car.surface_water)
		await physics_frame
	_release()
	_check(last_station >= 105.0 and concrete_samples > 40 and sheltered < 0.42 and exposed > 0.80,
		"the wet approach drives through sheltered concrete and back into rain across the Usina bridge")


func _check_free_event() -> void:
	_car.set_physics_process(false)
	_timing.set_physics_process(false)
	var event := _event_index("arroio")
	_timing.select_event(event, true)
	_cross(0, -1.0)
	_check(_timing.next_gate == 0, "an open-route start remains directional")
	_cross(0, 1.0)
	_cross(4, 1.0)
	_cross(3, -1.0)
	_cross(3, 1.0)
	_check(_timing.next_gate == 2 and _timing.checkpoint_pending(1) and not _timing.checkpoint_pending(3)
		and _timing.last_time == 0.0, "the finish starts locked and a reverse checkpoint only counts once")
	_cross(1, 1.0)
	_cross(2, -1.0)
	_cross(4, 1.0)
	_check(_timing.next_gate == -1 and _timing.last_time > 0.0 and _timing.best_clean_score > 0.0,
		"checkpoints can be collected in the order 3–1–2 and finish a timed run")


func _cross(index: int, direction: float) -> void:
	var gate: Transform3D = _timing.gates[index]
	var axis := -gate.basis.z * direction
	var center := gate.origin + Vector3.UP * 0.43
	_timing._previous = center - axis * 0.18
	_car.global_position = center + axis * 0.18
	_timing._physics_process(DELTA)


func _event_index(id: String) -> int:
	for index in _timing.events.size():
		if _timing.events[index].id == id:
			return index
	return -1


func _place(road: Layout.Route, station: float, lane: float, speed: float) -> void:
	_car.reset_car()
	var forward := road.direction_at(station)
	var yaw := atan2(-forward.x, -forward.y)
	_car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Layout.surface_point(road.offset_at(station, lane), 0.39))
	_car.velocity = Vector3(forward.x, 0.0, forward.y) * speed
	_world.get_node("ChaseCamera").snap_to_target()


func _site() -> Vector2:
	return Vector2(_car.global_position.x, _car.global_position.z)


func _drive(target: Vector2, speed: float) -> bool:
	var heading := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
	var steer := clampf(heading.angle_to(target - _site()) * 3.1, -1.0, 1.0)
	var pedal := clampf((speed - _car.get_speed_kmh()) * 0.17, -1.0, 1.0)
	Input.action_press("steer_left", maxf(-steer, 0.0))
	Input.action_press("steer_right", maxf(steer, 0.0))
	Input.action_press("accelerate", maxf(pedal, 0.0))
	Input.action_press("brake", maxf(-pedal, 0.0))
	return pedal < -0.02


func _release() -> void:
	for action in [&"accelerate", &"brake", &"steer_left", &"steer_right"]:
		Input.action_release(action)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("OK ", description)
	else:
		_failures += 1
		print("FAIL ", description)
