extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const FixtureInput = preload("fixture_input.gd")
const RoadChassis = preload("res://scripts/vehicle/road_chassis.gd")
const StaticShapes = preload("res://scripts/city/pilot_city_physics.gd")
var _car: PlayerCar
var _camera: Node3D
var _checks := 0
var _failures := 0


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
	_camera = current_scene.get_node("ChaseCamera")
	current_scene.get_node("Traffic").set_active(false)
	current_scene.get_node("DayNightCycle").running = false
	await _frames(22)
	_check_bake()
	await _check_vehicle()
	_check_chassis_transients()
	await _check_pedal_braking()
	await _check_road_audio()
	await _check_radio()
	await _check_camera_clearance()
	await _check_horto()
	await _check_market()
	print("Figueiras quality: %d checks, %d failures" % [_checks, _failures])
	call_group("wave_audio", "stop_audio")
	await process_frame
	quit(int(_failures != 0))


func _check_bake() -> void:
	var city := current_scene.get_node("City")
	var draws: Vector2i = city.get_meta("batched_draw_nodes_saved", Vector2i.ZERO)
	_check(draws.x > 100 and draws.y > 20, "the shipped city consolidates permanent instances and road paint")
	var solids := city.get_node("SolidObjects") as StaticBody3D
	_check(solids.get_child_count() == 0 and StaticShapes.shape_count(solids) >= 2943,
		"authoring colliders become native shape owners before the city enters physics")
	var support := city.get_node("StreetAndTerrainSupport") as StaticBody3D
	var partition: Vector2i = support.get_meta("terrain_sectors", Vector2i.ZERO)
	var triangles := 0
	for owner in support.get_shape_owners():
		var shape := support.shape_owner_get_shape(owner, 0) as ConcavePolygonShape3D
		if shape != null:
			triangles += shape.get_faces().size() / 3
	_check(partition.x > 100 and StaticShapes.shape_count(support) == partition.x and triangles == partition.y,
		"the terrain sectors retain every baked triangle in the same support body")
	var cover: MeshInstance3D = city.find_children("Ground_utility_cover_*", "MeshInstance3D", false, false)[0]
	var asphalt: MeshInstance3D = city.find_children("Ground_asphalt_*", "MeshInstance3D", false, false)[0]
	_check(cover.material_override.shader == preload("res://assets/shaders/figueiras/utility_cover_economy.gdshader")
		and asphalt.material_override.shader == preload("res://assets/shaders/figueiras/street_economy.gdshader"),
		"circular covers and opaque streets use separate shader variants")
	var grass: MeshInstance3D = city.find_children("Ground_grass_*", "MeshInstance3D", false, false)[0]
	var meadow := grass.material_override as ShaderMaterial
	var sky: Sky = current_scene.get_node("WorldEnvironment").environment.sky
	var settings := root.get_node("WaveSettings")
	_check(meadow.shader == preload("res://assets/shaders/figueiras/meadow_economy.gdshader")
		and int(meadow.get_shader_parameter("surface_kind")) == 5 and sky.radiance_size == Sky.RADIANCE_SIZE_32,
		"the economy profile uses the grass-specific shader and the smallest sky cubemap")
	meadow.set_shader_parameter("wetness", 0.65)
	settings.set_graphics_preset("medium")
	_check(meadow.shader == preload("res://assets/shaders/figueiras/meadow_finish.gdshader")
		and is_equal_approx(float(meadow.get_shader_parameter("wetness")), 0.65) and meadow.get_shader_parameter("has_ground_contact"),
		"switching to balanced keeps the wet grass and the ground contact mask")
	var casters := city.find_children("ShadowSector_*", "MeshInstance3D", false, false)
	var shadow_only := casters.all(func(node: MeshInstance3D) -> bool:
		return node.visible and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_check(casters.size() > 12 and shadow_only, "balanced submits the baked sectors only to the shadow pass")
	settings.set_graphics_preset("high")
	_check(sky.radiance_size == Sky.RADIANCE_SIZE_64, "quality uses the larger sky cubemap for reflections")
	_check(casters.all(func(node): return not node.visible), "quality restores the original shadow casters")
	settings.set_graphics_preset("economy")
	meadow.set_shader_parameter("wetness", 0.0)
	var near := 0
	var far := 0
	for node in city.get_children():
		if node.has_meta("foliage_cell") and node.visible:
			if node.has_meta("foliage_proxy"):
				far += 1
			else:
				near += 1
	_check(near > 0 and far > 0 and city.get_meta("foliage_cells", 0) > 30 and city.get_meta("forest_impostors", 0) > 350,
		"near tree geometry, distance batches and the outer woodland atlas coexist at startup")
	var coarse := 0
	var mapped := 0
	for node in city.get_children():
		if node.has_meta("foliage_distant"):
			coarse += 1
		if node.has_meta("foliage_proxy") and not node.visibility_parent.is_empty():
			var parent := node.get_node_or_null(node.visibility_parent)
			mapped += int(parent != null and parent.has_meta("foliage_distant"))
	_check(coarse == city.get_meta("foliage_distant_batches", 0) and coarse > 20 and mapped >= coarse * 2,
		"the packed distant woodland groups have their original foliage cells as visibility dependents")
	_check(city.get_meta("fused_architecture_batches", 0) > 110 and city.get_meta("terrace_houses", 0) >= 14, "offline batching covers the added terrace architecture")
	_check(city.get_node_or_null("CasaDasSementes") is Marker3D and float(city.get_meta("horto_length", 0.0)) > 335.0, "the Horto pavilion and its connecting grade are present in the baked scene")


func _check_vehicle() -> void:
	Input.action_press("accelerate")
	var shifted := false
	var rpm_before := 0.0
	var rpm_after := 0.0
	var lowest_torque := INF
	var last_gear := 1
	var speed_at_shift := 0.0
	for step in 325:
		if _car.gearbox.gear > last_gear:
			shifted = true
			speed_at_shift = _car.get_speed_kmh()
			rpm_before = _car.gearbox.rpm
			last_gear = _car.gearbox.gear
		if shifted:
			rpm_after = _car.gearbox.rpm
			lowest_torque = minf(lowest_torque, _car.gearbox.torque)
			if rpm_after < rpm_before - 180.0:
				break
		await physics_frame
	Input.action_release("accelerate")
	_check(shifted and speed_at_shift > 38.0 and speed_at_shift < 68.0 and rpm_after < rpm_before - 150.0 and lowest_torque < 0.80,
		"the Gol upshifts during real acceleration, with a torque interruption and RPM drop")
	_car.reset_car()
	await _frames(32)
	_check(_car.gearbox.gear == 1 and _car.gearbox.rpm < 1020.0, "reset restores first gear and idle speed")
	var site := Vector2(-118.0, Layout.ROWS[1] - Layout.LOCAL_HALF + 0.11)
	_place(site, Vector2.UP, 0.0)
	await _frames(24)
	_check(_car.axle_grip.x < _car.axle_grip.y and _car.surface_friction > _car.axle_grip.x, "the front axle loses authority before the rear on a mixed surface")
	_car.reset_car()
	Input.action_press("steer_left", 1.0)
	await _frames(15)
	Input.action_release("steer_left")
	var inner: Node3D = _car.get_node("Visuals/FrontLeft")
	var outer: Node3D = _car.get_node("Visuals/FrontRight")
	_check(absf(inner.rotation.y) > absf(outer.rotation.y) + 0.032, "the inner front wheel steers farther during a low-speed turn")
	var edge := Vector2(-113.0, Layout.ROWS[1] + Layout.LOCAL_HALF + 0.08)
	_place(edge, Vector2.RIGHT, 0.0)
	await _frames(24)
	_car.velocity = -_car.global_basis.z * 10.5
	await _frames(5)
	Input.action_press("brake", 0.72)
	await _frames(14)
	Input.action_release("brake")
	var front_load := _car.wheel_loads.x + _car.wheel_loads.y
	print("Split braking front load %.3f, yaw rate %.3f rad/s" % [front_load, _car.get_turn_rate()])
	_check(_car.is_on_floor() and front_load > 0.63 and _car.get_turn_rate() > 0.022,
		"braking shifts load onto the front axle and pulls towards the higher-grip side")


func _check_camera_clearance() -> void:
	_car.reset_car()
	await _frames(4)
	var free := _camera.arm.get_hit_length() as float
	var free_fov: float = _camera.camera.fov
	var free_framing := _car_screen_height()
	_check(absf(_camera._arm_distance - free) < 0.05 and free > 5.5,
		"the first chase sweep establishes clearance without starting at a retracted distance")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.43, 3.8, 5.1)
	collider.shape = box
	wall.add_child(collider)
	wall.position = _car.global_position + Vector3(-2.6, 1.0, 0.0)
	current_scene.add_child(wall)
	await _frames(6)
	var obstructed := _camera._arm_distance as float
	var obstructed_fov: float = _camera.camera.fov
	_check(free > 5.5 and obstructed < 3.4 and obstructed <= _camera.arm.get_hit_length() + 0.01,
		"the chase camera shortens its arm to clear a real obstruction")
	var obstructed_framing := _car_screen_height()
	print("Chase framing %.3f clear and %.3f behind a wall" % [free_framing, obstructed_framing])
	_check(free_framing > 0.70 and free_framing < 0.76 and absf(obstructed_framing - free_framing) < 0.04,
		"the camera keeps the car in the lower third as the arm retracts")
	wall.queue_free()
	await _frames(4)
	var first_recovery := _camera._arm_distance as float
	await _frames(55)
	_check(first_recovery > obstructed and first_recovery < free - 1.0 and absf(_camera._arm_distance - free) < 0.5,
		"the chase camera opens gradually after the obstruction clears")
	_check(obstructed_fov > free_fov + 2.0 and absf(_camera.camera.fov - free_fov) < 0.6,
		"chase view widens to preserve visibility at a wall and recovers its original field of view")
	var close_wall := StaticBody3D.new()
	var close_collider := CollisionShape3D.new()
	close_collider.shape = box
	close_wall.add_child(close_collider)
	close_wall.position = _car.global_position + Vector3(-1.65, 1.0, 0.0)
	_car.set_physics_process(false)
	current_scene.add_child(close_wall)
	await _frames(3)
	_check(_camera.camera.cull_mask & _camera.PLAYER_MESH_LAYER == 0 and _camera._arm_distance < 1.75,
		"an extreme retraction clears the view through the Gol's own shell")
	close_wall.queue_free()
	await _frames(15)
	_car.set_physics_process(true)
	_check(_camera.camera.cull_mask & _camera.PLAYER_MESH_LAYER != 0,
		"the Gol shell returns after the chase lens has cleared the bumper")
	var road := Layout.urban_routes()[Layout.HORTO_ROUTE]
	var site := road.point_at(102.0)
	var preview: Vector3 = _camera.terrain_preview.call(site, road.direction_at(102.0), 10.0)
	_check(preview.x > 0.07 and preview.y > 0.55 and _camera.camera.keep_aspect == Camera3D.KEEP_WIDTH,
		"the camera reads an approaching grade and frames it using a horizontal FOV")
	var across: Vector3 = _camera.terrain_preview.call(site, road.direction_at(102.0).orthogonal(), 10.0)
	_check(across.y < 0.16 and absf(across.z) < 0.001,
		"road preview rejects a route when the car is pointed across it")


func _check_chassis_transients() -> void:
	const DELTA := 1.0 / 60.0
	const ASPHALT := Vector4.ONE * 1.05
	var chassis := RoadChassis.new()
	var motion := Vector2(16.0, 0.0)
	var first_turn := chassis.step(motion, 0.10, 0.0, 0.0, false, 0.0, 8.0, Vector2.ZERO, DELTA).y
	var settled_turn := first_turn
	for tick in 12:
		settled_turn = chassis.step(motion, 0.10, 0.0, 0.0, false, 0.0, 8.0, Vector2.ZERO, DELTA).y
	_check(first_turn > 0.05 and settled_turn > first_turn * 1.6,
		"lateral force builds over distance after the steering changes")
	for tick in 12:
		var approach_grade := 0.10 - float(tick) * 0.012
		chassis.sample(ASPHALT, Vector4.ZERO, Vector4.ONE, Vector2.ZERO, approach_grade, 1.0, motion.x, DELTA)
	var crest_load := chassis.normal_load_scale
	for tick in 29:
		chassis.sample(ASPHALT, Vector4.ZERO, Vector4.ONE, Vector2.ZERO, -0.032, 1.0, motion.x, DELTA)
	print("Crest load %.3f, recovered %.3f, initial lateral force %.2f, settled %.2f" %
		[crest_load, chassis.normal_load_scale, first_turn, settled_turn])
	_check(crest_load < 0.68 and chassis.normal_load_scale > 0.94,
		"suspension unloads over a moving crest and regains weight on the grade")
	var support := Vector4(1.0, 1.0, 0.0, 1.0)
	chassis.sample(ASPHALT, Vector4(0.02, 0.03, -0.16, 0.04), support, Vector2(-7.0, 2.0), -0.032, 1.0, motion.x, DELTA)
	chassis.step(motion, 0.0, -7.0, 0.7, false, 0.0, 8.0, Vector2.ZERO, DELTA)
	_check(chassis.wheel_loads.z == 0.0 and chassis.wheel_usage.z == 0.0 and chassis.wheel_usage.w > 0.1 and
		is_equal_approx(chassis.wheel_loads.dot(Vector4.ONE), 1.0),
		"an unsupported rear wheel generates no grip and the remaining wheels keep the sprung weight")


func _car_screen_height() -> float:
	var eye: Camera3D = _camera.camera
	var projection := eye.unproject_position(_car.global_position + Vector3.UP * 0.42)
	return projection.y / root.get_visible_rect().size.y


func _check_pedal_braking() -> void:
	var dry := await _brake_from_avenue_speed(0.0)
	var wet := await _brake_from_avenue_speed(1.0)
	_car.road_wetness = 0.0
	print("Full analog braking from 57.6 km/h stopped in %.2f m dry and %.2f m wet" % [dry, wet])
	_check(dry > 9.0 and dry < 20.0 and wet > dry * 1.15 and wet < 25.0,
		"the analog service brake gives longer stops on wet exposed asphalt")


func _brake_from_avenue_speed(wetness: float) -> float:
	_car.road_wetness = wetness
	_place(Layout.SPAWN, Vector2.RIGHT, 0.0)
	await _frames(18)
	var start := _car.global_position.x
	_car.velocity = Vector3.RIGHT * 16.0
	var pedal := InputEventJoypadMotion.new()
	pedal.axis = JOY_AXIS_TRIGGER_LEFT
	pedal.axis_value = 1.0
	FixtureInput.inject(pedal)
	await _frames(1)
	for frame in 220:
		if _car.get_speed_kmh() <= 0.7:
			break
		await _frames(1)
	pedal.axis_value = 0.0
	FixtureInput.inject(pedal)
	return _car.global_position.x - start


func _check_road_audio() -> void:
	var audio := current_scene.get_node("DrivingAudio")
	var asphalt: AudioStreamPlayer = audio.get_node("AsphaltRoll")
	var pavers: AudioStreamPlayer = audio.get_node("PaverRoll")
	var coast: AudioStreamPlayer = audio.get_node("EngineCoast")
	var loaded_engine: AudioStreamPlayer = audio.get_node("EngineLoad")
	var high: AudioStreamPlayer = audio.get_node("EngineHigh")
	_place(Layout.SPAWN, Vector2.RIGHT, 10.5)
	await _frames(32)
	var paved_road := asphalt.playing and asphalt.volume_db > -34.0 and not pavers.playing
	var coasting := coast.playing and coast.volume_db > -32.0
	Input.action_press("accelerate")
	await _frames(35)
	Input.action_release("accelerate")
	var loaded := maxf(loaded_engine.volume_db, high.volume_db) > -28.0 and coast.volume_db < -40.0
	_check(coasting and loaded and loaded_engine.stream != coast.stream,
		"the Gol crossfades to a separate exhaust bed when the driver lifts")
	_place(Vector2(-125.0, Layout.ROWS[1] + Layout.LOCAL_HALF + 1.23), Vector2.RIGHT, 10.5)
	await _frames(32)
	var paved_walk := pavers.playing and pavers.volume_db > -34.0 and not asphalt.playing
	_car.reset_car()
	_check(paved_road and paved_walk and not asphalt.playing and not pavers.playing,
		"rolling audio follows the supported asphalt and stone wheels and falls silent on reset")
	_check(not coast.playing and not loaded_engine.playing and not high.playing, "reset stops the loaded engine bands")
	_camera.view = 2
	await _frames(36)
	_check(root.get_node("WaveSettings").road_filter.cutoff_hz < 3000.0,
		"the cockpit applies the vehicle low-pass filter")
	_camera.view = 0
	await _frames(36)


func _check_radio() -> void:
	var radio := current_scene.get_node("DrivingAudio/Radio")
	var first: AudioStreamPlayer = radio._voices[radio._active]
	var first_stream := first.stream as AudioStreamOggVorbis
	_check(radio.track_index == 0 and first_stream != null and first_stream.get_length() > 60.0 and first.bus == "Música",
		"the driving radio opens with the first stereo arrangement on the independent music bus")
	var hud := current_scene.get_node("HUD")
	hud.set_paused(true)
	await _frames(2)
	var center := hud.get_node("Overlay/PauseMenu/Center")
	center.get_node("Buttons/Audio").pressed.emit()
	var options := center.get_node("AudioOptions")
	var selector := options.find_child("RadioTrack", true, false) as OptionButton
	selector.item_selected.emit(1)
	var second: AudioStreamPlayer = radio._voices[radio._active]
	_check(selector.visible and selector.item_count == 4 and selector.selected == 1 and radio.track_index == 1,
		"the in-game audio menu offers all four tracks and selects the requested song")
	_check(first.stream == null and second.stream_paused and second.stream != first_stream,
		"switching the song in pause keeps the new voice paused")
	options.close()
	hud.set_paused(false)
	await _frames(2)
	_check(not second.stream_paused, "resuming play restores the selected track")


func _check_horto() -> void:
	var road := Layout.urban_routes()[Layout.HORTO_ROUTE]
	var timer := current_scene.get_node("AlamedaSprint")
	var start := 13.0
	_place(road.offset_at(start, -2.04), road.direction_at(start), 10.0)
	timer.select_event(5, true)
	var margin := INF
	var unsupported := 0
	for frame in 3600:
		var position := Vector2(_car.global_position.x, _car.global_position.z)
		var station := road.project(position).x
		_drive(road.offset_at(station + 7.4, -2.04), maxf(28.0, 48.0 - absf(road.direction_at(station).angle_to(road.direction_at(station + 12.0))) * 90.0))
		margin = minf(margin, -Layout.road_distance(position))
		unsupported += int(frame > 6 and not _car.is_on_floor())
		if timer.last_time > 0.0:
			break
		await physics_frame
	_release()
	print("Horto %.3f s, %.2f m minimum pavement margin, %d unsupported frames" % [timer.last_time, margin, unsupported])
	_check(timer.last_time > 24.0 and timer.last_time < 58.0 and margin > 0.4 and unsupported <= 6, "a continuous timed drive climbs the Horto and rejoins the upper street")
	var staging := road.stop_station - 22.0
	var start_site := road.offset_at(staging, -9.2)
	_place(start_site, road.direction_at(staging), 4.0)
	var supported := 0
	var paving := 0
	for frame in 640:
		var site := Vector2(_car.global_position.x, _car.global_position.z)
		var station := road.project(site).x
		if station >= road.stop_station + 19.0:
			break
		_drive(road.offset_at(station + 5.8, -9.2), 21.0)
		supported += int(_car.is_on_floor())
		paving += int(_car.surface_name == "paralelepípedo")
		await physics_frame
	_release()
	_check(supported > 230 and paving > 170 and road.project(Vector2(_car.global_position.x, _car.global_position.z)).x >= road.stop_station + 18.9,
		"the Horto apron stays drivable between its openings and uses cobblestone grip")


func _check_market() -> void:
	var road := Layout.urban_routes()[Layout.MERCADO_ROUTE]
	var span := Layout.market_cover_span(road)
	var center := (span.x + span.y) * 0.5
	var city := current_scene.get_node("City")
	var preview: Vector3 = _camera.terrain_preview.call(road.point_at(41.0), road.direction_at(41.0), 16.0)
	_check(road.length > 150.0 and absf(preview.z) > 0.07 and preview.y > 0.65
		and city.get_node_or_null("CoberturaMercado/CoberturaMercadoSolid") is StaticBody3D,
		"the road look-ahead uses the actual curve and the market roof has collision")
	var weather := current_scene.get_node("Weather")
	weather.set_wet(true)
	_place(road.offset_at(center, -2.12), road.direction_at(center), 0.0)
	await _frames(46)
	var sheltered_grip := _car.surface_friction
	var open_roof := true
	var space := _car.get_world_3d().direct_space_state
	for lane: float in [-2.2, 0.0, 2.2]:
		var floor := Layout.surface_point(road.offset_at(center, lane))
		var ray := PhysicsRayQueryParameters3D.create(floor + Vector3.UP, floor + Vector3.UP * 8.4, 1, [_car.get_rid()])
		ray.hit_back_faces = true
		var roof := space.intersect_ray(ray)
		open_roof = open_roof and not roof.is_empty() and (roof.position.y - floor.y) >= 4.50
	_place(road.offset_at(30.0, -2.12), road.direction_at(30.0), 0.0)
	await _frames(31)
	_check(open_roof and sheltered_grip > 0.95 and _car.surface_friction < 0.86,
		"the roof clears both lanes and their sheltered asphalt retains more grip in the rain")
	var terrain := city.get_node("StreetAndTerrainSupport")
	var bay: Dictionary = current_scene._terrain_surface(Layout.surface_point(road.offset_at(center, 6.0)), terrain)
	_check(bay.get("surface") == "paralelepípedo" and bay.get("wet_scale", 1.0) < 0.5,
		"the loading bay has sheltered cobblestone grip")
	weather.set_wet(false)
	var timer := current_scene.get_node("AlamedaSprint")
	var line := _market_line(road)
	_place(line.sample_baked(0.0), Vector2.RIGHT, 0.0)
	await _frames(24)
	timer.select_event(6, true)
	var unsupported := 0
	var margin := INF
	var ticks := 0
	var traveled := 0.0
	var projector := _car.get_node("ContactShadow/TerrainProjection")
	var uploads := int(projector.receiver_updates)
	for frame in 3200:
		var site := Vector2(_car.global_position.x, _car.global_position.z)
		var station := line.get_closest_offset(site)
		traveled = maxf(traveled, station)
		if station >= line.get_baked_length() - 3.0:
			break
		var initial := line.sample_baked(station + 1.0) - line.sample_baked(station - 1.0)
		var later := line.sample_baked(station + 12.0) - line.sample_baked(station + 10.0)
		var turn := absf(initial.angle_to(later))
		_drive(line.sample_baked(station + 6.3, true), maxf(23.0, 37.0 - turn * 25.0))
		margin = minf(margin, -Layout.road_distance(site))
		unsupported += int(frame > 6 and not _car.is_on_floor())
		ticks += 1
		await physics_frame
	_release()
	uploads = int(projector.receiver_updates) - uploads
	print("Mercado %.3f s, %.1f travelled metres, %.2f m pavement margin, %d unsupported frames, %d shadow uploads / %d ticks" % [
		timer.last_time, traveled, margin, unsupported, uploads, ticks])
	_check(timer.last_time > 12.0 and timer.last_time < 44.0 and margin > 0.30 and unsupported <= 4
		and traveled >= line.get_baked_length() - 3.0,
		"the Mercado course can be driven continuously from the avenue and back into its eastbound lane")
	_check(uploads > 20 and uploads < ticks / 4, "the shadow advances across its cached floor without uploading geometry every frame")


func _market_line(road: Layout.Route) -> Curve2D:
	var line := Curve2D.new()
	line.bake_interval = 0.75
	line.add_point(Vector2(-181.0, 58.5))
	line.add_point(Vector2(-169.0, 58.5), Vector2.ZERO, Vector2(5.3, 0.0))
	var first := road.project(Vector2(-159.0, 68.0)).x
	var last := road.project(Vector2(-90.0, 68.0)).x
	line.add_point(road.offset_at(first, -2.02), Vector2(0, -5.2))
	for station in range(ceili(first) + 3, floori(last) - 2, 3):
		line.add_point(road.offset_at(station, -2.02))
	line.add_point(road.offset_at(last, -2.02), Vector2.ZERO, Vector2(0, -5.0))
	line.add_point(Vector2(-80.0, 58.5), Vector2(-5.4, 0.0))
	line.add_point(Vector2(-67.0, 58.5))
	return line


func _drive(aim: Vector2, target_speed: float) -> void:
	var site := Vector2(_car.global_position.x, _car.global_position.z)
	var heading := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
	var turn := clampf(heading.angle_to(aim - site) * 3.1, -1.0, 1.0)
	var pedal := clampf((target_speed - _car.get_speed_kmh()) * 0.18, -1.0, 1.0)
	Input.action_press("steer_left", maxf(-turn, 0.0))
	Input.action_press("steer_right", maxf(turn, 0.0))
	Input.action_press("accelerate", maxf(pedal, 0.0))
	Input.action_press("brake", maxf(-pedal, 0.0))


func _place(site: Vector2, direction: Vector2, speed: float) -> void:
	_release()
	_car.reset_car()
	var yaw := atan2(-direction.x, -direction.y)
	_car.global_transform = Transform3D(Basis(Vector3.UP, yaw), Layout.surface_point(site, 0.38))
	_car.velocity = Vector3(direction.x, 0, direction.y) * speed
	_camera.snap_to_target()


func _release() -> void:
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
