extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Events = preload("res://scripts/city/figueiras_events.gd")
const Traffic = preload("res://scripts/city/figueiras_traffic.gd")
const Signals = preload("res://scripts/city/figueiras_signals.gd")
const Navigation = preload("res://scripts/city/figueiras_navigation.gd")
const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")
var _checks := 0
var _failures := 0
var _car: PlayerCar
var _rig: Node3D
var _weather: Node3D
var _timing: Node3D
var _traffic: Node3D
var _signals: Node3D
var _map: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_render_loop_enabled(false)
	root.get_node("WaveSettings").set_graphics_preset("economy")
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) != OK:
		quit(1)
		return
	await scene_changed
	FixtureInput.isolate()
	_car = current_scene.get_node("PlayerCar")
	_rig = current_scene.get_node("ChaseCamera")
	_weather = current_scene.get_node("Weather")
	_timing = current_scene.get_node("AlamedaSprint")
	_traffic = current_scene.get_node("Traffic")
	_signals = current_scene.get_node("Signals")
	_map = current_scene.get_node("HUD").city_map
	current_scene.get_node("DayNightCycle").running = false
	await _frames(35)
	await _check_traffic()
	await _check_impact()
	_traffic.set_active(false)
	await _check_wall_contacts()
	await _check_depot()
	await _check_views()
	await _check_map_and_activity()
	await _check_ridge_course()
	await _check_weather()
	print("Figueiras district: %d checks, %d failures" % [_checks, _failures])
	await FixtureAudio.drain(self)
	quit(int(_failures > 0))


func _check_traffic() -> void:
	_check(_traffic.drivers.size() == 24 and _car.collision_mask & Traffic.TRAFFIC_LAYER != 0, "normal startup places 24 collidable traffic vehicles")
	var active_bodies := 0
	for driver in _traffic.drivers:
		active_bodies += int(PhysicsServer3D.body_get_space(driver.body.get_rid()).is_valid())
	_check(active_bodies > 0 and active_bodies <= 8, "only nearby traffic bodies enter the physics space")
	var packed: Array = current_scene.get_node("City").get_meta("traffic_routes", [])
	var authored := Traffic.make_routes()
	var matches := packed.size() == authored.size()
	if matches:
		for index in authored.size():
			var route := authored[index]
			var saved := Traffic.TrafficRoute.from_bake(packed[index])
			matches = matches and saved.length == route.length
			for fraction: float in [-0.06, 0.0, 0.12, 0.28, 0.52, 0.83, 0.98, 1.07]:
				var station := route.length * fraction
				matches = matches and saved.point(station) == route.point(station) and saved.elevation(station) == route.elevation(station)
	_check(matches, "packed traffic circuits match authored positions and elevations, including the loop seam")
	var off_road := 0
	for driver in _traffic.drivers:
		for station in range(0, floori(driver.route.length), 9):
			off_road += int(Layout.road_distance(driver.route.point(station)) > -0.83)
	_check(off_road == 0, "all eight traffic lanes keep their car centers clear of the curbs")
	var heading := Vector2.DOWN
	var center := Signals.positions()[0]
	var stop_line := center + heading * (Signals.crossing(center, heading) + Signals.STOP_SETBACK) + heading.orthogonal() * 1.8
	var front_bumper := 2.05
	var stopped := float(_signals.speed_limit(stop_line + heading * (front_bumper + 0.15), -heading, 0.0, 12.0, front_bumper, 1.0))
	var approach := stop_line + heading * (front_bumper + 9.0)
	var dry_limit := float(_signals.speed_limit(approach, -heading, 8.0, 12.0, front_bumper, 1.0))
	var wet_limit := float(_signals.speed_limit(approach, -heading, 8.0, 12.0, front_bumper, 0.78))
	_check(stopped < 0.01 and dry_limit > wet_limit and wet_limit > 0.0, "traffic stops by the bumper at the painted line and brakes earlier on wet approaches")
	var stop_models := 0
	var seen_change := false
	var driven: Array[float] = []
	driven.resize(_traffic.drivers.size())
	driven.fill(0.0)
	var illegal_phases := 0
	var overlaps := 0
	var previous_clock: int = _signals.aspect(0, true)
	for tick in 5700:
		await physics_frame
		if tick % 6 != 0:
			continue
		for index in Signals.positions().size():
			illegal_phases += int(_signals.aspect(index, true) == 0 and _signals.aspect(index, false) == 0)
		var aspect: int = _signals.aspect(0, true)
		seen_change = seen_change or aspect != previous_clock
		var count: int = _traffic.drivers.size()
		for index in count:
			var driver = _traffic.drivers[index]
			driven[index] += driver.speed * 0.1
			if driver.speed < 0.33:
				stop_models |= 1 << index
			for other_index in range(index + 1, count):
				var other = _traffic.drivers[other_index]
				overlaps += int(Traffic.overlap(driver.site, driver.heading, driver.length - 0.02, other.site, other.heading, other.length - 0.02))
	_check(seen_change and illegal_phases == 0, "opposite axes never receive green at the same time")
	_check(overlaps == 0, "traffic car footprints stay separate over 95 seconds of urban circulation")
	_check(stop_models != 0 and driven.min() > 220.0, "cars stop for traffic or red lights and eventually resume each circuit")


func _check_impact() -> void:
	_traffic.set_physics_process(false)
	var driver = _traffic.drivers[0]
	var target: Vector2 = driver.site
	var axis: Vector2 = driver.heading
	var start := target - axis * 12.5
	var heading := atan2(-axis.x, -axis.y)
	_place(start, heading, 17.0)
	var impacts: Array[float] = []
	_car.impact.connect(func(strength: float) -> void: impacts.append(strength), Object.CONNECT_ONE_SHOT)
	var contacts: Array[bool] = []
	_car.body_impact.connect(func(_strength: float, _point: Vector3, bodywork: bool) -> void:
		contacts.append(bodywork), Object.CONNECT_ONE_SHOT)
	await _frames(58)
	var site := Vector2(_car.global_position.x, _car.global_position.z)
	_check(not impacts.is_empty() and impacts[0] > 0.25 and (target - site).dot(axis) > 2.7, "hitting a traffic body blocks the car and emits a speed-dependent impact")
	_check(is_equal_approx(_car.surface_friction, 1.05), "traffic collisions preserve asphalt sampling")
	_check(contacts == [true], "a traffic hit reports bodywork for the spatial sound")


func _check_wall_contacts() -> void:
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.14, 1.8, 4.0)
	collider.shape = box
	wall.add_child(collider)
	current_scene.add_child(wall)
	var site := Layout.SPAWN + Vector2(38.0, 0.0)
	wall.global_position = Layout.surface_point(site, 0.85)
	await _frames(3)
	var hits: Array[bool] = []
	var collect := func(_strength: float, _point: Vector3, bodywork: bool) -> void: hits.append(bodywork)
	_car.body_impact.connect(collect)
	_place(site - Vector2(12.0, 0.0), -PI * 0.5, 33.0)
	await _frames(58)
	_check(_car.global_position.x < site.x - 1.4 and hits == [false],
		"a thin wall stops the Gol at highway speed and plays one masonry contact")
	hits.clear()
	wall.global_position = Layout.surface_point(site + Vector2(0.0, -1.75), 0.70)
	box.size = Vector3(18.0, 2.1, 0.14)
	await _frames(3)
	var approach := Vector2(1.0, -0.19).normalized()
	_place(site - Vector2(8.0, 0.0), atan2(-approach.x, -approach.y), 12.5)
	var scrape := 0.0
	for tick in 60:
		await physics_frame
		scrape = maxf(scrape, _car.scrape_strength)
	_check(hits.is_empty() and scrape > 0.15 and _car.velocity.x > 7.0,
		"a shallow wall contact scrapes while the Gol carries momentum along the barrier")
	_car.body_impact.disconnect(collect)
	wall.queue_free()
	await process_frame


func _check_depot() -> void:
	_place(Vector2(-126.8, -169), PI, 7.0)
	var heights := Vector2(INF, -INF)
	var contacts := 0
	Input.action_press("accelerate", 0.38)
	for tick in 650:
		var position := _car.global_position
		if position.z > -56.0:
			break
		heights.x = minf(heights.x, position.y)
		heights.y = maxf(heights.y, position.y)
		contacts += int(_car.is_on_floor())
		await physics_frame
	Input.action_release("accelerate")
	_check(_car.global_position.z > -56.0 and contacts > 230 and heights.y - heights.x > 2.0, "the workshop passage is physically drivable on a varying ground grade")
	_place(Vector2(-137.0, -129.0), PI, 0.0)
	await _frames(35)
	_check(_car.surface_name == "paralelepípedo" and _car.surface_friction < 0.93, "the yard cobbles use their own tire grip")
	var clock := current_scene.get_node("City/CivicClock")
	var cycle := current_scene.get_node("DayNightCycle")
	cycle.set_hour(10.5)
	var hands := clock.get_children()
	_check(hands.size() == 2 and absf(absf(hands[1].rotation.z) - PI) < 0.001, "the gallery clock follows the district's simulation")


func _check_views() -> void:
	_car.reset_car()
	for index in range(1, 5):
		await _tap(KEY_V)
		_check(_rig.view == index, "camera input cycles to driving view %d" % index)
		if index == 2:
			_check(_rig.camera.near < 0.05 and _car.to_local(_rig.global_position).x < -0.26, "cockpit reaches the driver's seat rather than the centerline")
			Input.action_press("camera_back")
			await _frames(2)
			_check(not _rig.is_cockpit_view() and _car.to_local(_rig.global_position).z > 1.30,
				"rear look from the cockpit moves clear of the seats and pillars")
			Input.action_release("camera_back")
			await _frames(2)
			_check(_rig.is_cockpit_view() and _car.to_local(_rig.global_position).x < -0.26,
				"releasing rear look returns directly to the driver's seat")
		if index == 3:
			_check(_car.to_local(_rig.global_position).z < -1.9 and _rig.arm.spring_length < 0.01, "bumper view anchors ahead of the hood")
		if index == 4:
			_check(_rig.arm.spring_length > 9.0, "elevated chase frames the wider intersection")
	await _tap(KEY_V)
	_check(_rig.view == 0 and _rig.camera.near > 0.09, "the cycle returns to the default chase")


func _check_map_and_activity() -> void:
	_check(_timing.events.size() == 12 and _timing.selected == 0, "map offers twelve events with the original sprint selected")
	var depot_route: PackedVector2Array = _timing.route_for(4)
	_check(depot_route.size() > _timing.events[4].fixed.size() and Layout.DEPOT.has_point(depot_route[4]), "workshop preview follows its real turns and paved shortcut")
	var old_record: float = _timing.record_for(0)
	await _tap(KEY_M)
	_check(paused and _map.visible, "M opens the interactive atlas and pauses driving")
	_map._rows[2].pressed.emit()
	_check(_map._enter.has_focus(), "confirming an activity gives the controller a direct path to mark its start")
	_map._enter.pressed.emit()
	_check(not paused and not _map.visible and _timing.selected == 2 and _timing.next_gate == 0, "the atlas stages the selected radar challenge without teleporting")
	_check(_timing.approach.size() > 1, "arming from the map draws an approach through the district")
	_check_navigation()
	var lane := Layout.AVENUE + 4.6
	_place(Vector2(-183, lane), -PI * 0.5, 21.0)
	_timing.start_attempt()
	var room := INF
	for frame in 1250:
		if _timing.last_time > 0.0:
			break
		var site := Vector2(_car.global_position.x, _car.global_position.z)
		var heading := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
		var steering := clampf(heading.angle_to(Vector2(12.0, lane - site.y)) * 2.8, -1.0, 1.0)
		Input.action_press("steer_left", maxf(-steering, 0.0))
		Input.action_press("steer_right", maxf(steering, 0.0))
		var error := 79.0 - _car.get_speed_kmh()
		Input.action_press("accelerate", clampf(error * 0.22, 0.0, 1.0))
		room = minf(room, -Layout.road_distance(site))
		await physics_frame
	for action in ["accelerate", "steer_left", "steer_right"]:
		Input.action_release(action)
	_check(_timing.last_time > 10.0 and _timing.score > 190.0 and _timing.score < 280.0 and room > 1.0,
		"steering through three supported lane crossings measures and sums the radar speeds")
	var radar_score: float = _timing.record_for(2)
	_check(radar_score >= _timing.score and is_equal_approx(old_record, float(_timing.record_for(0))), "the radar score persists alongside the existing Alameda record")
	_timing.select_event(3)
	_timing._finish_attempt(59.4)
	_check(absf(_timing.score - 2.4) < 0.001, "regularity scores the distance from 57 seconds")
	_timing._finish_attempt(54.6)
	_check(absf(_timing.score - 2.4) < 0.001, "regularity penalizes early arrivals equally")


func _check_navigation() -> void:
	var navigation := Navigation.new()
	var routed := 0
	for index in _timing.events.size():
		_timing.select_event(index)
		var gate: Transform3D = _timing.gates[0]
		var target := Vector2(gate.origin.x, gate.origin.z)
		var direction := Vector2(-gate.basis.z.x, -gate.basis.z.z)
		var guide := navigation.route_to_start(Layout.SPAWN, Vector2.RIGHT, target, direction)
		if guide.size() < 2 or guide[-1].distance_to(target) > 5.0:
			continue
		var on_road := true
		for segment in guide.size() - 1:
			var steps := maxi(1, ceili(guide[segment].distance_to(guide[segment + 1]) / 3.0))
			for step in steps + 1:
				var site := guide[segment].lerp(guide[segment + 1], float(step) / steps)
				on_road = on_road and Layout.road_distance(site) < 0.3
		var final_direction := guide[-2].direction_to(guide[-1])
		routed += int(on_road and final_direction.dot(direction) > 0.82)
	_check(routed == _timing.events.size(), "every start is reachable on paved roads and in the timing gate's direction")
	var gate := Vector2(-144.0, Layout.AVENUE)
	var origin := gate + Vector2(20.0, 0.0)
	var wrong_side := navigation.route_to_start(origin, Vector2.RIGHT, gate, Vector2.RIGHT)
	_check(wrong_side.size() > 4 and wrong_side[-2].x < gate.x, "passing a start on the avenue routes around the block to approach it forward")
	var turn := PackedVector2Array([Vector2.ZERO, Vector2(30.0, 0.0), Vector2(30.0, 40.0)])
	_check(Navigation.instruction(turn) == "Vire à direita em 30 m", "the next connected turn has a distance and direction")
	_check(Navigation.advance(turn, Vector2(13.0, 0.0))[0].is_equal_approx(Vector2(13.0, 0.0))
		and Navigation.advance(turn, Vector2(12.0, 20.0)).is_empty(), "the approach follows motion and detects leaving its route")
	_timing.select_event(2, true)


func _check_ridge_course() -> void:
	var road := Layout.scenic_routes()[0]
	var start := 18.0
	var direction: Vector2 = road.direction_at(start)
	_place(road.offset_at(start, -2.16), atan2(-direction.x, -direction.y), 8.0)
	_timing.select_event(1, true)
	var min_margin := INF
	var highest_gate := 0
	var unsupported := 0
	for frame in 4400:
		if _timing.last_time > 0.0:
			break
		var site := Vector2(_car.global_position.x, _car.global_position.z)
		var station := road.project(site).x
		var target := road.offset_at(station + 8.0, -2.16)
		var forward := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
		var correction := clampf(forward.angle_to(target - site) * 3.25, -1.0, 1.0)
		var speed := 52.0 - absf(road.direction_at(station + 13.0).angle_to(road.direction_at(station))) * 65.0
		var demand := (maxf(27.0, speed) - _car.get_speed_kmh()) * 0.20
		Input.action_press("steer_right", maxf(0.0, correction))
		Input.action_press("steer_left", maxf(0.0, -correction))
		Input.action_press("accelerate", clampf(demand, 0.0, 1.0))
		Input.action_press("brake", clampf(-demand, 0.0, 1.0))
		highest_gate = maxi(highest_gate, _timing.next_gate)
		min_margin = minf(min_margin, -Layout.road_distance(site))
		unsupported += int(frame > 10 and not _car.is_on_floor())
		await physics_frame
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	print("Mirante %.3f s, minimum asphalt margin %.2f m, %d unsupported frames" % [_timing.last_time, min_margin, unsupported])
	_check(_timing.last_time > 15.0 and _timing.last_time < 70.0 and highest_gate == 5, "a continuous drive clears the six Mirante gates through the gallery")
	_check(min_margin > 0.7 and unsupported <= 5, "the complete climb and descent stay on supported scenic asphalt")
	var finish: float = _timing.last_time
	_timing.select_event(1, true)
	var stored: PackedFloat32Array = _timing._best_splits
	_check(stored.size() == 5 and absf(stored[-1] - finish) < 0.001, "timed courses keep checkpoint splits with the best finish")
	if not stored.is_empty():
		_timing._capture_split(stored[0] - 0.30)
		_check(absf(_timing._split_delta + 0.30) < 0.001, "the next attempt compares each checkpoint to its own best-run split")
	_timing.set_wet(true)
	_check(_timing._best_splits.is_empty(), "wet attempts compare to their own best-run splits")
	_timing.set_wet(false)


func _check_weather() -> void:
	_car.reset_car()
	_timing.select_event(2)
	_timing.start_attempt()
	await _tap(KEY_G)
	await _frames(155)
	_check(_weather.wet and _weather.intensity > 0.99 and _timing.next_gate < 0, "rain changes conditions and ends an attempt already in progress")
	_check(_car.is_on_floor() and absf(_car.surface_friction - 1.05 * 0.79) < 0.002, "rain reduces asphalt grip by 21 percent at the tires")
	_check(_timing.wet and _timing.record_for(2) == -1.0, "the wet radar leaderboard uses its own record")
	var finish: ShaderMaterial = _weather.finishes[0]
	_check(float(finish.get_shader_parameter("wetness")) > 0.99 and _weather._rain.emitting, "wet conditions run the rain simulation and wet surface shader")
	Input.action_press("accelerate")
	_car.velocity = -_car.global_basis.z * 14.0
	await _frames(18)
	Input.action_release("accelerate")
	var effects := current_scene.get_node("TireEffects")
	var spray := 0
	for puff in effects._puffs:
		spray += int(puff.spray)
	_check(spray > 0 and effects._marks.is_empty(), "rolling tires spray water without drawing dry rubber")
	await _tap(KEY_G)
	await _frames(290)
	_check(not _weather.wet and _weather.intensity == 0.0 and not _weather._rain.emitting, "dry conditions restore the road finish and stop the rain stream")


func _place(site: Vector2, yaw: float, speed: float) -> void:
	_car.reset_car()
	_car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Layout.surface_point(site, 0.42))
	_car.velocity = -_car.global_basis.z * speed
	_rig.snap_to_target()


func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	FixtureInput.inject(event)
	await _frames(3)
	event.pressed = false
	FixtureInput.inject(event)
	await _frames(3)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", what)
	else:
		_failures += 1
		push_error("FAIL: " + what)
