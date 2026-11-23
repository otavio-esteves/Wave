extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")
const WORLD := "res://scenes/city/figueiras/drive_figueiras.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var preview := not headless and "--preview" in OS.get_cmdline_user_args()
	if headless or preview:
		RenderingServer.set_render_loop_enabled(false)
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("medium" if "--medium" in OS.get_cmdline_user_args() else "economy")
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(startup == WORLD, "the default scene is the playable district")
	if change_scene_to_file(startup) != OK:
		quit(1)
		return
	await scene_changed
	if not current_scene is DrivingWorld:
		push_error("The district world script did not load.")
		quit(1)
		return
	FixtureInput.isolate()
	var world := current_scene
	world.get_node("Traffic").set_active(false)
	var city := world.get_node("City")
	var car: PlayerCar = world.get_node("PlayerCar")
	var hud := world.get_node("HUD")
	var cycle := world.get_node("DayNightCycle")
	var environment: Environment = world.get_node("WorldEnvironment").environment
	var detailed: bool = settings.graphics.material_detail
	_check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
		and environment.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED
		and environment.adjustment_enabled == detailed, "Economy and Medium use timed ambient fill and no sky radiance filtering")
	_check(cycle._shop_glass.size() == 10 and cycle._fountain != null, "five authored shop interiors and the fountain are bound to the district clock")
	_check(cycle._lake != null and city.get_node_or_null("LagoDasFigueiras") is MeshInstance3D, "the lake and its daylight controls are present in the baked world")
	var shore := city.get_node_or_null("SomDaMargem") as AudioStreamPlayer3D
	_check(shore != null and shore.bus == &"Ambiente" and shore.autoplay and shore.stream is AudioStreamWAV
		and shore.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and shore.max_distance <= 62.0, "the baked lake has a local looping ambience on the existing ambience bus")
	_check(Layout.scenic_routes().size() == 4 and city.get_meta("scenic_road_length", 0.0) > 1850.0,
		"four scenic roads add more than 1.85 km of asphalt connected to the street grid")
	_check(city.get_node_or_null("AltoDoPasso") is Marker3D and city.get_meta("passo_length", 0.0) > 380.0,
		"Estrada do Passo has a playable summit between the Horto and Mirante roads")
	_check(cycle._creek != null and city.get_node_or_null("ArroioDoVale") is MeshInstance3D, "the creek surface is baked and animated by the district clock")
	var creek_audio := city.get_node_or_null("SomDoArroio") as AudioStreamPlayer3D
	_check(creek_audio != null and creek_audio.stream is AudioStreamWAV and creek_audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		and creek_audio.bus == &"Ambiente" and creek_audio.max_distance < 50.0, "the creek uses its own local sound and the existing ambience volume")
	_check(city.get_node_or_null("GaleriaDaPedraInterior") is MeshInstance3D and city.get_node_or_null("ApoioGaleriaDaPedra") is StaticBody3D, "the gallery includes its ceiling and wall collision")
	_check(cycle._gallery_lights.size() == 4 and not cycle._gallery_lights.any(func(light): return light.visible), "the gallery lights are outside the render list at the avenue")
	_check(city.get_meta("blocks") == 9 and city.get_meta("buildings") >= 200 and city.get_meta("trees") >= 350 and city.get_meta("parked_cars") >= 24 and city.get_meta("plantings") >= 2000, "the offline district includes its planned building fronts, trees, gardens and parked cars")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "PRAÇA DA FIGUEIRA"), "the plaza is signed in the world")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "MERCADO DAS FIGUEIRAS"), "the market is signed in the world")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "CINE FIGUEIRAS"), "the cinema is visible from the starting avenue")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "FIGUEIRAS" and sign.position.x > Layout.STREET_BOUNDS.end.x),
		"the hillside reservoir is present beyond the east approach")
	_check(_check_road_sections(), "local streets, collector and avenue have the measured widths and the major junction has curved corners")
	_check(city.get_meta("merged_draw_batches", 0) >= 80, "the baked district combines matte batches without removing their instances")
	_check(_check_distant_ground(city), "packed terrain groups switch beside valid source sectors with a buffered transition")
	_check(_check_transverse_lamp_markers(city), "every transverse street segment has lamp heads between its junctions")
	_check(_check_shadow_batches(city), "ground contact patches and small details stay out of the dynamic shadow passes")
	await _frames(25)
	_check(car.is_on_floor() and car.global_position.distance_to(Layout.spawn().origin) < 0.5 and car.get_heading() < -1.5, "the Gol starts supported in the avenue's right lane facing east")
	var contact_shadow := car.get_node("ContactShadow") as MeshInstance3D
	var projection := contact_shadow.mesh as ArrayMesh
	_check(contact_shadow.visible and contact_shadow.top_level and projection != null and projection.get_surface_count() == 1
		and projection.custom_aabb.size.y > 0.03, "the Gol contact shade follows the avenue grade using a reusable ground-projected mesh")
	_check(not paused and not hud.pause_menu.visible and hud.has_node("Overlay/Minimap"), "startup has driving HUD, minimap and no pause menu")
	_check(not hud.buttons.get_node("Race").visible and not hud.buttons.get_node("Rally").visible and hud.buttons.get_node("MainMenu").text == "Laboratórios", "the district pause menu keeps a single entry to the laboratories")
	var relief := _street_relief()
	print("Street relief: %.2f m across the grid, %.2f%% peak sustained grade over 6 m" % [relief.x, relief.y * 100.0])
	_check(relief.x >= 38.0 and relief.y <= 0.165 and relief.y >= 0.095, "the street grid has a pronounced but drivable relief")
	_check(_check_support(car), "the whole street grid and plaza have continuous support at the authored grades")
	_check(_scenic_support(car), "scenic lanes, pullouts and junctions share continuous collision with the visible terrain")
	_check(_urban_support(car, city), "all six urban links have continuous driving support through their junctions")
	_check(_bridge_support(car, city), "Ponte do Arroio has continuous driving support above the open stream bed")
	_check(_check_avenue_refuge(car), "the plaza crossing has an open refuge between the two raised noses")
	_check(_gallery_clearance(car), "each gallery lane has over 4 metres of clearance under the arch")
	_check(_nursery_access(car), "the nursery terrace keeps the entrance within a short flight of regular steps")
	if preview:
		cycle.running = false
		_capture("start")
		await _show_plaza(car, cycle)
		cycle.set_hour(16.5)
		_place_car(car, Vector2(-86.0, -52.15), PI * 0.5)
		await _frames(12)
		_capture("subida")
		await _show_storefront(city, hud)
		hud.visible = true
		cycle.set_hour(16.5)
		_place_car(car, Vector2(Layout.COLLECTOR - 2.40, Layout.AVENUE - 24.0), PI)
		current_scene.get_node("ChaseCamera").find_child("Camera3D").make_current()
		await _frames(12)
		_capture("coletora")
		_place_car(car, Vector2(-15.0, Layout.AVENUE + Layout.AVENUE_LANE * 0.5), -PI * 0.5)
		await _frames(12)
		_capture("travessia")
		await _show_scenic(car, cycle, hud)
		await _show_vale(car, cycle, hud)
		await _show_urban(car, hud)
		_finish()
		return
	cycle.running = false
	Input.action_press("accelerate")
	await _frames(390)
	Input.action_release("accelerate")
	print("Avenue drive: ", car.global_position, " at ", car.get_speed_kmh(), " km/h")
	_check(car.global_position.x > Layout.SPAWN.x + 60.0 and absf(car.global_position.z - Layout.SPAWN.y) < 3.0 and car.is_on_floor(), "accelerating from startup drives down the avenue without leaving the lane")
	await _check_collector_turn(car)
	await _check_alameda_turn(car)
	for link in Layout.urban_routes():
		await _drive_urban(car, link, 1.0)
		await _drive_urban(car, link, -1.0)
	for road in Layout.scenic_routes():
		for direction: float in [1, -1]:
			if road == Layout.scenic_routes()[Layout.PASSO_ROUTE]:
				await _drive_passo(car, road, direction)
			else:
				await _drive_scenic(car, road, direction)
		if road.stop_station >= 0.0:
			await _park_at_scenic_stop(car, road)
	await _check_hillside(car)
	cycle.running = true
	_check_solar_shadows(world, settings, cycle)
	var daytime: float = cycle.hour
	car.set_physics_process(false)
	_place_car(car, Vector2(Layout.COLUMNS[1] + 1.7, -104.0), 0.0)
	cycle.set_hour(23.0)
	await process_frame
	_check(cycle.hour != daytime and cycle.night_factor > 0.9, "the district clock reaches nighttime")
	_check(float(cycle._lake.get_shader_parameter("daylight")) < 0.05, "lake reflection dims at night")
	var body := car.get_node("Visuals/Body") as MeshInstance3D
	_check(is_equal_approx(body.get_instance_shader_parameter("reflection_daylight"), float(cycle.daylight)),
		"the district clock dims the hero car's paint and glass reflections at night")
	_check_lamp_handoff(car, cycle)
	_check(not cycle._shop_glass.is_empty() and cycle._shop_glass.all(func(glass: ShaderMaterial) -> bool: return glass.get_shader_parameter("light_inside") > 0.9), "the storefront light responds to night")
	car.set_physics_process(true)
	var pause_event := InputEventKey.new()
	pause_event.physical_keycode = KEY_ESCAPE
	pause_event.pressed = true
	FixtureInput.inject(pause_event)
	await process_frame
	_check(paused and hud.pause_menu.visible and root.gui_get_focus_owner() == hud.resume_button, "Escape pauses directly and focuses Resume")
	hud.buttons.get_node("Reset").pressed.emit()
	await _frames(10)
	_check(not paused and car.global_position.distance_to(Layout.spawn().origin) < 0.5, "reset from the pause menu returns to the avenue and resumes")
	hud.set_paused(true)
	hud.buttons.get_node("MainMenu").pressed.emit()
	await scene_changed
	var labs := current_scene
	_check(labs.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "the labs still open on request")
	labs.figueiras_button.pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path == WORLD and not paused, "the labs link returns directly to the district")
	_finish()


func _check_distant_ground(city: Node3D) -> bool:
	if city.has_meta("sector_lod_counts") and city.get_meta("sector_lod_counts").x > 0:
		var sectors := 0
		var simplified := 0
		var sources := 0
		for node in city.get_children():
			if node.has_meta("terrain_sector_lod"):
				sectors += 1
				var radius: float = node.mesh.get_aabb().size.length() * 0.5
				if node.visibility_range_begin - radius <= node.visibility_range_begin_margin or node.mesh.get_surface_count() != 1:
					return false
				var mesh := ImporterMesh.from_mesh(node.mesh)
				simplified += int(mesh.get_surface_lod_count(0) > 0)
				sources += int(node.get_meta("sector_source_count", 0))
			elif node is MeshInstance3D and node.name.begins_with("Ground_") and not node.visibility_parent.is_empty():
				var target := node.get_node_or_null(node.visibility_parent)
				if target == null or not target.has_meta("terrain_sector_lod"):
					return false
		return sectors == city.get_meta("sector_lod_counts").x and sectors >= 40 and sources >= sectors * 2 and simplified >= 20
	var groups := 0
	var source_sectors := 0
	for node in city.get_children():
		if node.has_meta("terrain_distant"):
			groups += 1
			if node.visibility_range_begin < 250.0 or node.visibility_range_begin_margin <= 0.0:
				return false
		if node.has_meta("terrain_lod") and not node.visibility_parent.is_empty():
			var group := node.get_node_or_null(node.visibility_parent)
			if group == null or not group.has_meta("terrain_distant") or group.material_override != node.material_override:
				return false
			source_sectors += 1
	return groups == city.get_meta("terrain_distant_batches", 0) and groups >= 12 and source_sectors >= groups * 2


func _check_road_sections() -> bool:
	var avenue := Vector2(-133.0, Layout.AVENUE)
	var collector := Vector2(Layout.COLLECTOR, -100.0)
	var local := Vector2(-104.0, Layout.ROWS[1])
	var half_widths := [Vector2(0, 10.70), Vector2(6.00, 0), Vector2(0, 3.80)]
	var points := [avenue, collector, local]
	for index in points.size():
		var offset: Vector2 = half_widths[index]
		var point: Vector2 = points[index]
		for side: float in [-1, 1]:
			if not is_zero_approx(Layout.road_distance(point + offset * side)):
				return false
			if Layout.road_distance(point + offset * side * 1.05) <= 0.0:
				return false
	var corner := Vector2(Layout.COLLECTOR + Layout.COLLECTOR_HALF, Layout.AVENUE + Layout.AVENUE_HALF)
	return Layout.road_distance(corner + Vector2(2, 2)) < -0.5 and Layout.road_distance(corner + Vector2(5, 5)) > 1.0


func _check_collector_turn(car: PlayerCar) -> void:
	var lane := Vector2(Layout.COLLECTOR - 2.4, Layout.AVENUE - Layout.AVENUE_MEDIAN_HALF - Layout.AVENUE_LANE * 0.5)
	var radius := 20.0
	var center := lane - Vector2(radius, radius)
	_place_car(car, Vector2(lane.x, center.y - 18.0), PI)
	await _frames(20)
	var room := INF
	var unsupported := 0
	var steps := 0
	var finished := false
	for frame in 680:
		var point := Vector2(car.global_position.x, car.global_position.z)
		if point.x < center.x - 16.5:
			finished = absf(point.y - lane.y) < 2.2 and car.get_speed_kmh() >= 32.0
			break
		var angle := (point - center).angle()
		var target := Vector2(lane.x, point.y + 7.0)
		if point.y > center.y - 7.0:
			var look := angle + 7.0 / radius
			target = center + Vector2.from_angle(minf(look, PI * 0.5)) * radius
			target.x -= maxf(0.0, look - PI * 0.5) * radius
			if point.x < center.x:
				target = Vector2(point.x - 7.0, lane.y)
		_drive_towards(car, point, target, 44.0)
		room = minf(room, -Layout.road_distance(point))
		unsupported += int(not car.is_on_floor())
		steps += 1
		await _frames(1)
	_release_drive()
	print("Collector turn: %d frames, %d unsupported, %.2f m minimum pavement margin, %.1f km/h at exit" % [steps, unsupported, room, car.get_speed_kmh()])
	_check(finished and room >= 0.95 and unsupported <= 2, "the Gol steers from the collector into the avenue under normal inputs with clearance and support")


func _drive_towards(car: PlayerCar, point: Vector2, target: Vector2, speed: float) -> void:
	var forward := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
	var steer := clampf(forward.angle_to(target - point) * 2.7, -1.0, 1.0)
	_release_drive()
	Input.action_press("steer_right" if steer >= 0.0 else "steer_left", absf(steer))
	var error := speed - car.get_speed_kmh()
	if absf(error) >= 0.9:
		Input.action_press("accelerate" if error > 0.0 else "brake", clampf(absf(error) * 0.19, 0.08, 1.0))


func _check_alameda_turn(car: PlayerCar) -> void:
	const RADIUS := 14.0
	var alameda := Layout.urban_routes()[1]
	var exit_lane := alameda.offset_at(21.0, -2.25)
	var start_lane := Layout.SPAWN.y + Layout.AVENUE_LANE
	var pivot := Vector2(exit_lane.x - RADIUS, start_lane + RADIUS)
	_place_car(car, Vector2(pivot.x - 18.0, start_lane), -PI * 0.5)
	await _frames(18)
	var pavement := INF
	var airborne := 0
	for frame in 520:
		var point := Vector2(car.global_position.x, car.global_position.z)
		if point.y >= exit_lane.y + 3.0:
			break
		var target := point + Vector2(6.0, 0.0)
		if point.y >= pivot.y:
			target = alameda.offset_at(alameda.project(point).x + 6.0, -2.25)
		elif point.x >= pivot.x - 6.0:
			var angle := clampf((point - pivot).angle(), -PI * 0.5, 0.0) + 6.0 / RADIUS
			target = pivot + Vector2.from_angle(minf(0.0, angle)) * RADIUS + Vector2.DOWN * (maxf(angle, 0.0) * RADIUS)
		_drive_towards(car, point, target, 31.0)
		pavement = minf(pavement, -Layout.road_distance(point))
		airborne += int(not car.is_on_floor())
		await _frames(1)
	_release_drive()
	var site := Vector2(car.global_position.x, car.global_position.z)
	print("Avenue to Alameda: %.2f m minimum pavement margin, %d unsupported frames, %.2f m from lane axis" % [pavement, airborne, alameda.project(site).y + 2.25])
	_check(site.y >= exit_lane.y + 3.0 and absf(alameda.project(site).y + 2.25) < 1.5 and pavement > 0.85 and airborne <= 2,
		"the Gol turns directly from the avenue into Alameda da Estação at driving speed")


func _release_drive() -> void:
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)


func _urban_support(car: PlayerCar, city: Node3D) -> bool:
	var routes := Layout.urban_routes()
	if routes.size() != 6 or city.get_meta("urban_link_length", 0.0) < 990.0:
		return false
	var space := car.get_world_3d().direct_space_state
	for road in routes:
		for station in range(2, floori(road.length), 3):
			for lateral: float in [-3.0, 0.0, 3.0]:
				var site := road.offset_at(station, lateral)
				var floor := Layout.surface_point(site)
				var ray := PhysicsRayQueryParameters3D.create(floor + Vector3.UP * 2.0, floor - Vector3.UP, 1, [car.get_rid()])
				var hit := space.intersect_ray(ray)
				if Layout.road_distance(site) >= -0.6 or hit.is_empty() or hit.collider.name != "StreetAndTerrainSupport" or absf(hit.position.y - floor.y) > 0.095:
					print("Unexpected urban support ", road.title, " at ", station, "/", lateral, ": ", hit)
					return false
	return true


func _check_hillside(car: PlayerCar) -> void:
	for direction in [-1.0, 1.0]:
		var westbound: bool = direction < 0.0
		var lane := -52.15 if westbound else -55.85
		_place_car(car, Vector2(-87.0 if westbound else -171.0, lane), -direction * PI * 0.5)
		await _frames(20)
		var start := car.global_position
		var margin := INF
		Input.action_press("accelerate")
		for index in 350:
			var site := Vector2(car.global_position.x, car.global_position.z)
			var forward := Vector2(-car.global_basis.z.x, -car.global_basis.z.z).normalized()
			var steer := clampf(forward.angle_to(Vector2(direction * 9.0, lane - site.y)) * 2.8, -1.0, 1.0)
			Input.action_press("steer_right", maxf(steer, 0.0))
			Input.action_press("steer_left", maxf(-steer, 0.0))
			margin = minf(margin, -Layout.road_distance(site))
			await _frames(1)
		_release_drive()
		var travel := car.global_position - start
		print("Hillside drive: %.1f m along the road, %.1f m elevation change, %.2f m lane deviation, %.2f m pavement margin" % [
			travel.x, travel.y, travel.z, margin])
		_check(travel.x * direction > 34.0 and travel.y * -direction > 5.0 and absf(travel.z) < 1.0 and margin > 0.85 and car.is_on_floor(),
			"the Gol climbs and descends the cambered residential grade under normal driving inputs")


func _drive_urban(car: PlayerCar, road: Route, direction: float) -> void:
	var station := 2.0 if direction > 0.0 else road.length - 2.0
	var heading := road.direction_at(station) * direction
	var lane := -direction * road.half_width * 0.48
	_place_car(car, road.offset_at(station, lane), atan2(-heading.x, -heading.y))
	await _frames(20)
	var room := INF
	var unsupported := 0
	for frame in ceili(road.length * 13.0):
		var point := Vector2(car.global_position.x, car.global_position.z)
		var sample := road.project(point)
		station = sample.x
		var remaining := road.length - station if direction > 0.0 else station
		if remaining < 1.2 or sample.z > road.half_width:
			break
		_drive_towards(car, point, road.offset_at(station + direction * 5.8, lane), 36.0)
		room = minf(room, -Layout.road_distance(point))
		unsupported += int(not car.is_on_floor())
		await _frames(1)
	_release_drive()
	var exit_distance := road.length - station if direction > 0.0 else station
	print("Urban %s direction %d: %.2f m to exit, %.2f m minimum pavement margin, %d unsupported frames" % [road.title, direction, exit_distance, room, unsupported])
	_check(exit_distance < 1.2 and car.get_speed_kmh() >= 20.0 and room > 0.95 and unsupported <= 2,
		"%s is drivable in direction %d with support and clearance" % [road.title, direction])


func _drive_scenic(car: PlayerCar, road: Route, direction: float) -> void:
	var start := 0.0 if direction > 0.0 else road.length
	var finish := road.length - start
	var station := start
	var lane := -direction * 2.32
	var forward := road.direction_at(start) * direction
	var final_heading := road.direction_at(finish) * direction
	var final_lane := road.offset_at(finish, lane)
	_place_car(car, road.offset_at(start, lane) - forward * 13.0, atan2(-forward.x, -forward.y))
	await _frames(18)
	var room := INF
	var unsupported := 0
	var max_error := 0.0
	var finished := false
	var use_gallery := road == Layout.scenic_routes()[0]
	var active_gallery_lamps := 0
	var cycle := current_scene.get_node("DayNightCycle")
	var peak := car.global_position.y
	var low := peak
	for frame in ceili(road.length * 7.5):
		var point := Vector2(car.global_position.x, car.global_position.z)
		var projection := road.project(point)
		if not is_finite(projection.z):
			break
		station = projection.x
		if use_gallery and station > Layout.GALLERY_START and station < Layout.GALLERY_END:
			var local_lights: int = cycle._gallery_lights.filter(func(light): return light.visible).size()
			active_gallery_lamps = maxi(active_gallery_lamps, local_lights)
		var remaining := road.length - station if direction > 0.0 else station
		if remaining <= 0.5 and (point - final_lane).dot(final_heading) > 10.0:
			finished = car.is_on_floor() and car.get_speed_kmh() > 26.0
			break
		var target := road.offset_at(station + direction * 6.0, lane)
		if remaining < 6.0:
			var past_end := maxf(0.0, (point - final_lane).dot(final_heading))
			target = final_lane + final_heading * (6.0 - remaining + past_end)
		var base_speed := 49.0 - 7.0 * smoothstep(0.028, 0.052, absf(road.bank_at(station)))
		_drive_towards(car, point, target, base_speed)
		room = minf(room, -Layout.road_distance(point))
		max_error = maxf(max_error, absf(projection.y - lane))
		unsupported += int(not car.is_on_floor())
		peak = maxf(peak, car.global_position.y)
		low = minf(low, car.global_position.y)
		await _frames(1)
	_release_drive()
	print("Scenic %s direction %d station %.1f/%.1f: %.1f km/h exit, %.2f m minimum margin, %.2f m variation, %d unsupported frames, %.2f m lane error" %
		[road.title, direction, station, road.length, car.get_speed_kmh(), room, peak - low, unsupported, max_error])
	_check(finished and room > 1.0 and unsupported <= 4 and max_error < 2.15, "%s connects both streets with continuous support in direction %d" % [road.title, direction])
	if use_gallery:
		var budget := 4 if "--medium" in OS.get_cmdline_user_args() else 1
		_check(active_gallery_lamps >= 1 and active_gallery_lamps <= budget, "the gallery lamps stay within the active profile budget in direction %d" % direction)


func _drive_passo(car: PlayerCar, road: Route, direction: float) -> void:
	var horto := Layout.urban_routes()[Layout.HORTO_ROUTE]
	var mirante := Layout.scenic_routes()[0]
	var outbound := direction > 0.0
	var entry := horto if outbound else mirante
	var exit := mirante if outbound else horto
	var entry_station := Layout.PASSO_HORTO_STATION if outbound else Layout.PASSO_MIRANTE_STATION
	var exit_station := Layout.PASSO_MIRANTE_STATION if outbound else Layout.PASSO_HORTO_STATION
	var start := entry_station - direction * 15.0
	var lane := -direction * 1.65
	var approach := entry.direction_at(start) * direction
	_place_car(car, entry.offset_at(start, lane), atan2(-approach.x, -approach.y))
	await _frames(18)
	var timing := current_scene.get_node("AlamedaSprint")
	var prior_event: int = timing.selected
	if outbound:
		timing.select_event(timing._index_of("passo"), true, false)
	var near := false
	var through := false
	var finished := false
	var unsupported := 0
	var margin := INF
	var peak := -INF
	var low := INF
	for frame in 4400:
		var point := Vector2(car.global_position.x, car.global_position.z)
		var pass_sample := road.project(point)
		var from_entry := pass_sample.x if outbound else road.length - pass_sample.x
		var remaining := road.length - from_entry
		var target := Vector2.ZERO
		var speed := 22.0
		if not near:
			var entry_projection := entry.project(point)
			var to_junction := (entry_station - entry_projection.x) * direction
			if to_junction > 6.5:
				target = entry.offset_at(entry_projection.x + 4.5 * direction, lane)
			else:
				var into_pass := clampf(5.5 - to_junction, 2.5, 8.5)
				target = road.offset_at(into_pass if outbound else road.length - into_pass, lane)
			near = from_entry > 3.0 and pass_sample.z < 4.5
		elif not through:
			var current := road.direction_at(pass_sample.x)
			var ahead := road.direction_at(pass_sample.x + direction * 10.0)
			speed = lerpf(41.0, 22.0, smoothstep(0.11, 0.62, absf(current.angle_to(ahead))))
			var look := clampf(car.get_speed_kmh() * 0.14, 3.4, 5.4)
			target = road.offset_at(pass_sample.x + direction * look, lane)
			if remaining < 5.0:
				target = exit.offset_at(exit_station + direction * 4.8, lane)
				speed = 21.0
				through = remaining < 2.8 or (exit.project(point).x - exit_station) * direction > 1.0
		else:
			var exit_projection := exit.project(point)
			if (exit_projection.x - exit_station) * direction > 11.5 and exit_projection.z < 3.7:
				finished = car.is_on_floor() and car.get_speed_kmh() > 18.0
				break
			target = exit.offset_at(exit_projection.x + direction * 5.0, lane)
			speed = 29.0
		_drive_towards(car, point, target, speed)
		unsupported += int(not car.is_on_floor())
		margin = minf(margin, -Layout.road_distance(point))
		peak = maxf(peak, car.global_position.y)
		low = minf(low, car.global_position.y)
		await _frames(1)
	_release_drive()
	print("Passo %d: finished=%s, %.2f m clearance, %.2f m climb, %d unsupported frames" % [direction, finished, margin, peak - low, unsupported])
	_check(finished and margin > 0.65 and peak - low > 23.0 and unsupported <= 4,
		"Estrada do Passo connects the Horto and Mirante lanes under normal inputs in direction %d" % direction)
	if outbound:
		_check(timing.last_time > 0.0 and timing.next_gate < 0 and timing._fault.is_empty()
			and timing._splits.size() == timing.gates.size() - 1,
			"one continuous drive clears all four timing gates on the Passo without a course fault")
		timing.select_event(prior_event)


func _park_at_scenic_stop(car: PlayerCar, road: Route) -> void:
	var stop := road.stop_station
	var start := stop - 34.0
	var traffic_lane := -2.32
	var parking_lane := -road.half_width - 2.65
	var forward := road.direction_at(start)
	_place_car(car, road.offset_at(start, traffic_lane), atan2(-forward.x, -forward.y))
	await _frames(18)
	var parked := false
	var rejoined := false
	var margin := INF
	var unsupported := 0
	for frame in 1100:
		var point := Vector2(car.global_position.x, car.global_position.z)
		var sample := road.project(point)
		if not is_finite(sample.z):
			break
		margin = minf(margin, -Layout.road_distance(point))
		unsupported += int(not car.is_on_floor())
		if absf(sample.x - stop) < 3.1 and absf(sample.y - parking_lane) < 1.35 and car.get_speed_kmh() < 2.5 and not parked:
			_release_drive()
			Input.action_press("handbrake")
			await _frames(30)
			Input.action_release("handbrake")
			parked = car.get_speed_kmh() < 2.5 and car.is_on_floor()
		if parked and sample.x > stop + 29.0:
			rejoined = absf(sample.y - traffic_lane) < 1.35 and car.is_on_floor()
			break
		var look := sample.x + 4.4
		var offset := lerpf(traffic_lane, parking_lane, smoothstep(stop - 26.0, stop - 10.0, look))
		var speed := clampf((stop - sample.x) * 3.3, 0.0, 26.0)
		if parked:
			offset = lerpf(parking_lane, traffic_lane, smoothstep(stop + 5.0, stop + 25.0, look))
			speed = 27.0
		_drive_towards(car, point, road.offset_at(look, offset), speed)
		await _frames(1)
	_release_drive()
	print("Scenic stop %s: parked %s, rejoined %s, %.2f m minimum margin, %d unsupported frames" % [road.title, parked, rejoined, margin, unsupported])
	_check(parked and rejoined and margin > 0.65 and unsupported <= 3, "%s pullout supports braking, parking and rejoining by normal inputs" % road.title)


func _scenic_support(car: PlayerCar) -> bool:
	var space := car.get_world_3d().direct_space_state
	for road in Layout.scenic_routes():
		for station in range(2, floori(road.length), 7):
			for lane: float in [-3.4, 0.0, 3.4]:
				var point := Layout.surface_point(road.offset_at(station, lane))
				var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.7, point - Vector3.UP * 1.7, 1, [car.get_rid()])
				var hit := space.intersect_ray(ray)
				if hit.is_empty() or hit.collider.name != "StreetAndTerrainSupport" or absf(hit.position.y - point.y) > 0.12 or hit.normal.y < 0.965:
					print("Unexpected scenic support ", road.title, " at ", station, "/", lane, ": ", hit)
					return false
		if road.stop_station >= 0.0:
			var bay := Layout.surface_point(road.offset_at(road.stop_station, -road.half_width - 3.0))
			var ray := PhysicsRayQueryParameters3D.create(bay + Vector3.UP, bay - Vector3.UP, 1, [car.get_rid()])
			if space.intersect_ray(ray).is_empty():
				return false
	return true


func _bridge_support(car: PlayerCar, city: Node3D) -> bool:
	if not city.get_node_or_null("PonteDoArroioTabuleiro") is MeshInstance3D:
		return false
	var support := city.get_node("StreetAndTerrainSupport")
	if support.get_meta("vale_bridge_collision_triangles", 0) < 100:
		return false
	var road := Layout.scenic_routes()[2]
	var crossing := Layout.vale_bridge_station()
	var center := Layout.surface_point(road.point_at(crossing))
	var space := car.get_world_3d().direct_space_state
	var deck_ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2.0, center - Vector3.UP, 1, [car.get_rid()])
	var deck := space.intersect_ray(deck_ray)
	if deck.is_empty() or deck.collider != support or absf(deck.position.y - center.y) > 0.10:
		return false
	for z in range(roundi(center.z) - 15, roundi(center.z) + 16, 2):
		var site := Vector3(Layout.creek_axis(z), Layout.CREEK_WATER_LEVEL + 0.10, z)
		var bed_ray := PhysicsRayQueryParameters3D.create(site, site - Vector3.UP * 4.0, 1, [car.get_rid()])
		var bed := space.intersect_ray(bed_ray)
		if bed.is_empty() or bed.collider != support or bed.position.y > Layout.CREEK_WATER_LEVEL - 0.20:
			return false
	return true


func _gallery_clearance(car: PlayerCar) -> bool:
	var ridge := Layout.scenic_routes()[0]
	var space := car.get_world_3d().direct_space_state
	for station in range(roundi(Layout.GALLERY_START) + 3, roundi(Layout.GALLERY_END), 6):
		for lane: float in [-2.32, 0, 2.32]:
			var floor := Layout.surface_point(ridge.offset_at(station, lane))
			var ray := PhysicsRayQueryParameters3D.create(floor + Vector3.UP * 4.0, floor + Vector3.UP * 7.0, 1, [car.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.collider.name != &"ApoioGaleriaDaPedra":
				return false
	return true


func _nursery_access(car: PlayerCar) -> bool:
	var frame := Layout.nursery_frame()
	var porch := Layout.height_at(frame.origin) + 0.91
	var space := car.get_world_3d().direct_space_state
	var previous := porch
	for index in 9:
		var site := frame.origin + frame.y * (6.18 + float(index) * 0.30)
		var start := Vector3(site.x, porch + 1.5, site.y)
		var ray := PhysicsRayQueryParameters3D.create(start, start - Vector3.UP * 5.0, 1, [car.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf(previous - hit.position.y) > 0.26:
			return false
		previous = hit.position.y
	return porch - previous < 1.40


func _show_scenic(car: PlayerCar, cycle: Node, hud: CanvasLayer) -> void:
	var roads := Layout.scenic_routes()
	var ridge := roads[0]
	var station := ridge.length * 0.19
	var forward := ridge.direction_at(station)
	_place_car(car, ridge.offset_at(station, -2.3), atan2(-forward.x, -forward.y))
	await _frames(16)
	_capture("mirante-pista")
	var lake := roads[1]
	station = lake.length * 0.33
	forward = lake.direction_at(station)
	_place_car(car, lake.offset_at(station, -2.3), atan2(-forward.x, -forward.y))
	await _frames(16)
	_capture("contorno-pista")
	var passo := roads[Layout.PASSO_ROUTE]
	await _view_along(car, passo, 91.0, "passo-corte")
	await _view_along(car, passo, passo.stop_station + 16.0, "passo-crista")
	var camera := Camera3D.new()
	camera.fov = 56.0
	current_scene.add_child(camera)
	camera.make_current()
	hud.visible = false
	camera.position = Layout.surface_point(ridge.offset_at(ridge.stop_station - 2.0, -7.1), 1.62)
	camera.look_at(Layout.surface_point(ridge.offset_at(ridge.stop_station + 4.0, ridge.half_width + 3.6), 2.1))
	await process_frame
	_capture("azulejo")
	camera.position = Layout.surface_point(Layout.LAKE + Vector2(43.0, 14.0), 4.2)
	camera.look_at(Vector3(Layout.LAKE.x, Layout.LAKE_LEVEL + 0.8, Layout.LAKE.y))
	await process_frame
	_capture("lago")
	cycle.set_hour(17.55)
	await process_frame
	_capture("lago-entardecer")


func _show_vale(car: PlayerCar, cycle: Node, hud: CanvasLayer) -> void:
	var routes := Layout.scenic_routes()
	var chase := current_scene.get_node("ChaseCamera").find_child("Camera3D") as Camera3D
	chase.make_current()
	hud.visible = true
	cycle.set_hour(16.5)
	await _view_along(car, routes[0], Layout.GALLERY_START - 18.0, "galeria-entrada")
	await _view_along(car, routes[0], Layout.GALLERY_START + 16.0, "galeria-interior")
	cycle.set_hour(20.0)
	await _view_along(car, routes[0], Layout.GALLERY_START + 16.0, "galeria-noite")
	cycle.set_hour(16.5)
	await _view_along(car, routes[2], routes[2].length * 0.31, "vale-pista")
	await _view_along(car, routes[2], Layout.vale_bridge_station() - 11.0, "ponte-tabuleiro")
	var camera := Camera3D.new()
	camera.fov = 54.0
	current_scene.add_child(camera)
	camera.make_current()
	hud.visible = false
	cycle.set_hour(14.0)
	camera.position = Layout.surface_point(Vector2(Layout.creek_axis(265.0) - 15.5, 264.0), 5.1)
	camera.look_at(Vector3(Layout.creek_axis(281.0), Layout.CREEK_WATER_LEVEL + 2.4, 281.0))
	await process_frame
	_capture("arroio")
	var bridge := routes[2].point_at(Layout.vale_bridge_station())
	var bank_z := bridge.y - 18.5
	camera.position = Vector3(Layout.creek_axis(bank_z) - 4.6, Layout.CREEK_WATER_LEVEL + 2.9, bank_z)
	camera.look_at(Vector3(bridge.x, Layout.CREEK_WATER_LEVEL + 2.6, bridge.y))
	await process_frame
	_capture("ponte-arroio")
	cycle.set_hour(16.5)
	var nursery := current_scene.get_node("City").find_children("Sign_*", "Label3D", false, false).filter(func(label): return label.text == "VIVEIRO DO VALE").back() as Label3D
	var aim := nursery.global_position
	var facing := nursery.global_basis.z
	camera.position = aim + facing * 7.6 - nursery.global_basis.x * 10.0 + Vector3.UP * 3.4
	camera.look_at(aim - Vector3.UP * 1.2)
	await process_frame
	_capture("viveiro")
	var cinema := current_scene.get_node("City").find_children("Sign_*", "Label3D", false, false).filter(func(label): return label.text == "CINE FIGUEIRAS").front() as Label3D
	aim = cinema.global_position
	facing = cinema.global_basis.z
	camera.position = aim + facing * 16.0 - cinema.global_basis.x * 6.0 + Vector3.UP * 0.8
	camera.look_at(aim + Vector3.UP * 1.70)
	await process_frame
	_capture("cinema")


func _show_urban(car: PlayerCar, hud: CanvasLayer) -> void:
	var chase := current_scene.get_node("ChaseCamera").find_child("Camera3D") as Camera3D
	chase.make_current()
	hud.visible = true
	await _view_along(car, Layout.urban_routes()[0], 45.0, "jabuticabeiras")
	await _view_along(car, Layout.urban_routes()[1], 40.0, "alameda")
	await _view_along(car, Layout.urban_routes()[Layout.GALERIA_ROUTE], 22.0, "galeria-da-praca")
	await _view_along(car, Layout.urban_routes()[Layout.ESTACAO_ROUTE], 17.0, "patio-da-estacao")
	var camera := Camera3D.new()
	camera.fov = 54.0
	current_scene.add_child(camera)
	camera.make_current()
	hud.visible = false
	camera.position = Vector3(-245.0, 180.0, 205.0)
	camera.look_at(Vector3(45.0, 31.0, -5.0))
	await process_frame
	_capture("panorama")


func _view_along(car: PlayerCar, road: Route, station: float, title: String) -> void:
	var forward := road.direction_at(station)
	_place_car(car, road.offset_at(station, -2.3), atan2(-forward.x, -forward.y))
	await _frames(16)
	_capture(title)


func _check_transverse_lamp_markers(city: Node3D) -> bool:
	var markers := city.find_children("StreetLamp_*", "Marker3D", false, false)
	for column: float in Layout.COLUMNS:
		for row in range(Layout.ROWS.size() - 1):
			var count := 0
			for marker: Marker3D in markers:
				var position := marker.position
				if absf(position.x - column) < 8.0 and position.z > Layout.ROWS[row] + 15.0 and position.z < Layout.ROWS[row + 1] - 15.0:
					count += 1
			if count < 3:
				print("Transverse lamp gap at ", Vector2(column, Layout.ROWS[row]), ": ", count)
				return false
	return true


func _check_shadow_batches(city: Node3D) -> bool:
	if city.has_meta("ground_contact"):
		var contact: Dictionary = city.get_meta("ground_contact")
		if contact.patches < 3 or contact.triangles < 100 or not city.find_children("Ground_shade_*", "MeshInstance3D", false, false).is_empty():
			return false
		var road := city.find_children("Ground_asphalt_*", "MeshInstance3D", false, false)
		if road.is_empty():
			return false
		var finish := (road[0] as MeshInstance3D).material_override as ShaderMaterial
		var mask := finish.get_shader_parameter("ground_contact") as ImageTexture
		if not finish.get_shader_parameter("has_ground_contact") or mask == null or mask.get_size() != Vector2(contact.size):
			return false
	else:
		for group in ["tree", "parked", "building"]:
			var patches := city.find_children("Ground_shade_%s_*" % group, "MeshInstance3D", false, false)
			if patches.is_empty():
				return false
			for patch: MeshInstance3D in patches:
				if patch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					return false
	var expected := {"grass_blade": false, "canopy": false, "roof": true}
	var found := {}
	for batch: MultiMeshInstance3D in city.find_children("*", "MultiMeshInstance3D", false, false):
		var material_name := batch.material_override.resource_name
		if not expected.has(material_name):
			continue
		var has_shadows := batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		found[material_name] = true
		if has_shadows != expected[material_name]:
			return false
	return found.size() == expected.size()


func _check_lamp_handoff(car: PlayerCar, cycle: Node) -> void:
	var stable: Array = _active_lamps(cycle)
	_check(cycle._pool.size() == 6 and stable.size() == 4 and stable.all(func(light: Light3D) -> bool: return light is SpotLight3D and light.global_basis.z.y > 0.6), "the settled night uses four downward-facing lamps and leaves two transition slots free")
	var positions := {}
	for light: Light3D in stable:
		positions[light] = light.global_position
	var targets: Array[int] = cycle._target_lamps.duplicate()
	car.global_position = Layout.surface_point(Vector2(Layout.COLUMNS[1] + 1.7, -75.0), 0.39)
	cycle._update_lamps()
	cycle._advance_lamp_fades(0.10)
	var fading := _active_lamps(cycle)
	var keeps_old_lights := stable.all(func(light: Light3D) -> bool: return light in fading and light.global_position.is_equal_approx(positions[light]))
	_check(cycle._target_lamps != targets and keeps_old_lights and fading.size() > 4 and fading.size() <= 6, "a short drive crossfades streetlights while the outgoing lights keep their positions")
	for step in 3:
		cycle._advance_lamp_fades(1.0)
	_check(_active_lamps(cycle).size() == 4, "streetlight handoff returns to four active spots")


func _active_lamps(cycle: Node) -> Array:
	return cycle._pool.filter(func(light: Light3D) -> bool: return light.visible and light.light_energy > 0.0)


func _check_solar_shadows(world: Node3D, settings: Node, cycle: Node) -> void:
	var sun := world.get_node("Sun") as DirectionalLight3D
	var moon := world.get_node("Moon") as DirectionalLight3D
	var original_hour: float = cycle.hour
	var original_shadows: bool = settings.graphics["shadows"]
	settings.set_graphics("shadows", true)
	cycle.set_hour(12.0)
	var direction: Vector3 = cycle.sun_direction
	var tilt := rad_to_deg(acos(clampf(direction.y, -1.0, 1.0)))
	_check(absf(tilt - 17.0) < 0.5 and sun.global_basis.z.dot(direction) > 0.999, "noon sunlight follows the tilted solar path and can project a street pole's shaft")
	_check(sun.visible and sun.shadow_enabled and not moon.visible and not moon.shadow_enabled, "only the active daytime sun casts directional shadows at noon")
	var first_split := sun.directional_shadow_split_1 * sun.directional_shadow_max_distance
	var limited := sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and is_equal_approx(sun.directional_shadow_max_distance, 58.0)
	var detailed := sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and first_split >= 16.0
	_check(detailed if settings.graphics["post_effects"] else limited, "the graphics profile uses the corresponding directional shadow budget")
	cycle.set_hour(11.7)
	var before_noon := sun.global_basis.y
	cycle.set_hour(12.3)
	_check(before_noon.dot(sun.global_basis.y) > 0.97, "the sunlight projection keeps a continuous basis across noon")
	cycle.set_hour(17.65)
	_check(sun.visible and sun.shadow_enabled and sun.shadow_opacity > 0.0 and sun.shadow_opacity < 0.9, "directional shadows fade with the low evening sun")
	cycle.set_hour(23.0)
	_check(not sun.visible and moon.visible and not moon.shadow_enabled, "night lighting hides the inactive sun and leaves moonlight without directional shadow passes")
	settings.set_graphics("shadows", false)
	cycle.set_hour(12.0)
	_check(sun.visible and sun.light_energy > 0.0 and not sun.shadow_enabled, "turning shadows off preserves direct daylight")
	settings.set_graphics("shadows", original_shadows)
	cycle.set_hour(original_hour)


func _check_support(car: PlayerCar) -> bool:
	var points: Array[Vector2] = [Layout.SPAWN, Layout.PLAZA.get_center()]
	for x: float in Layout.COLUMNS:
		for z in range(int(Layout.ROWS[0]), int(Layout.ROWS[-1]), 7):
			for lane: float in [-1.8, 0, 1.8]:
				points.append(Vector2(x + lane, z))
	for z: float in Layout.ROWS:
		for x in range(int(Layout.COLUMNS[0]), int(Layout.COLUMNS[-1]), 7):
			var lanes := [-6.5, -2.8, 2.8, 6.5] if z == Layout.AVENUE else [-1.8, 0, 1.8]
			for lane: float in lanes:
				points.append(Vector2(x, z + lane))
	for point in points:
		var center := Layout.surface_point(point)
		var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2, center - Vector3.UP * 2, 1, [car.get_rid()])
		var hit := car.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider.name != "StreetAndTerrainSupport" or absf(hit.position.y - center.y) > 0.08 or hit.normal.y < 0.97:
			print("Unexpected support at ", point, ": ", hit)
			return false
	return true


func _check_avenue_refuge(car: PlayerCar) -> bool:
	var space := car.get_world_3d().direct_space_state
	for offset: float in [-2.44, 0.0, 2.44]:
		var floor := Layout.surface_point(Vector2(8.75 + offset, Layout.AVENUE))
		var ray := PhysicsRayQueryParameters3D.create(floor + Vector3.UP, floor - Vector3.UP, 1, [car.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.collider.name == "StreetAndTerrainSupport") != is_zero_approx(offset):
			return false
	return true


func _street_relief() -> Vector2:
	var min_height := INF
	var max_height := -INF
	var grade := 0.0
	for axis in [0, 1]:
		var roads: Array = Layout.COLUMNS if axis == 0 else Layout.ROWS
		var crossing: Array = Layout.ROWS if axis == 0 else Layout.COLUMNS
		for road: float in roads:
			var previous := INF
			for sample in range(int(crossing.front()), int(crossing.back()) + 1, 6):
				var point := Vector2(road, sample) if axis == 0 else Vector2(sample, road)
				var height := Layout.height_at(point)
				min_height = minf(min_height, height)
				max_height = maxf(max_height, height)
				if is_finite(previous):
					grade = maxf(grade, absf(height - previous) / 6.0)
				previous = height
	return Vector2(max_height - min_height, grade)


func _place_car(car: PlayerCar, site: Vector2, heading: float) -> void:
	car.reset_car()
	car.global_transform = Transform3D(Basis(Vector3.UP, heading), Layout.surface_point(site, 0.39))
	car.velocity = Vector3.ZERO
	current_scene.get_node("ChaseCamera").snap_to_target()


func _show_plaza(car: PlayerCar, cycle: Node) -> void:
	_place_car(car, Vector2(-7.2, Layout.SPAWN.y), -0.15)
	await _frames(12)
	_capture("plaza")
	cycle.set_hour(21.0)
	await _frames(12)
	_capture("night")


func _show_storefront(city: Node3D, hud: CanvasLayer) -> void:
	var cafe: Label3D
	for sign: Label3D in city.find_children("Sign_*", "Label3D", false, false):
		if sign.text == "CAFÉ DA PRAÇA":
			cafe = sign
			break
	if cafe == null:
		_check(false, "a storefront is available for close inspection")
		return
	var facing := cafe.global_basis.z
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 50.0
	var storefront := cafe.global_position - 2.0 * facing
	var frame := storefront + 6.9 * facing - 1.8 * cafe.global_basis.x
	camera.global_position = Layout.surface_point(Vector2(frame.x, frame.z), 1.65)
	camera.look_at(storefront - 1.10 * Vector3.UP)
	camera.make_current()
	hud.visible = false
	await process_frame
	_capture("vitrine")


func _capture(view: String) -> void:
	RenderingServer.force_draw(false)
	var result := root.get_texture().get_image().save_png("user://figueiras-%s.png" % view)
	_check(result == OK, "the %s view was rendered and saved" % view)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	print("Vila das Figueiras smoke: %d checks, %d failures" % [checks, failures])
	await FixtureAudio.drain(self)
	quit(0 if failures == 0 else 1)
