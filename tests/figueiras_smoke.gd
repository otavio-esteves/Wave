extends SceneTree

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const FixtureInput = preload("fixture_input.gd")
const WORLD := "res://scenes/city/figueiras/drive_figueiras.tscn"
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var preview := DisplayServer.get_name() != "headless" and "--preview" in OS.get_cmdline_user_args()
	if preview:
		RenderingServer.set_render_loop_enabled(false)
	var settings := root.get_node("WaveSettings")
	settings.set_graphics_preset("medium" if "--medium" in OS.get_cmdline_user_args() else "economy")
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(startup == WORLD, "the default scene is the playable district")
	if change_scene_to_file(startup) != OK:
		quit(1)
		return
	await scene_changed
	FixtureInput.isolate()
	var world := current_scene
	var city := world.get_node("City")
	var car: PlayerCar = world.get_node("PlayerCar")
	var hud := world.get_node("HUD")
	var cycle := world.get_node("DayNightCycle")
	var environment: Environment = world.get_node("WorldEnvironment").environment
	var detailed: bool = settings.graphics.material_detail
	var ambient_mode := Environment.AMBIENT_SOURCE_SKY if detailed else Environment.AMBIENT_SOURCE_COLOR
	_check(environment.ambient_light_source == ambient_mode and environment.adjustment_enabled == detailed, "the selected profile uses the matching ambient-light and color-adjustment cost")
	_check(cycle._shop_glass.size() == 2 and cycle._fountain != null, "authored shop glazing and the fountain are bound to the district clock")
	_check(city.get_meta("blocks") == 9 and city.get_meta("buildings") >= 200 and city.get_meta("trees") >= 350 and city.get_meta("parked_cars") >= 24 and city.get_meta("plantings") >= 2000, "the offline district includes its planned building fronts, trees, gardens and parked cars")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "PRAÇA DA FIGUEIRA"), "the plaza is signed in the world")
	_check(city.find_children("Sign_*", "Label3D", false, false).any(func(sign): return sign.text == "MERCADO DAS FIGUEIRAS"), "the market is signed in the world")
	_check(_check_transverse_lamp_markers(city), "every transverse street segment has lamp heads between its junctions")
	_check(_check_shadow_batches(city), "ground contact patches and small details stay out of the dynamic shadow passes")
	await _frames(25)
	_check(car.is_on_floor() and car.global_position.distance_to(Layout.spawn().origin) < 0.5 and car.get_heading() < -1.5, "the Gol starts supported in the avenue's right lane facing east")
	var contact_shadow := car.get_node("ContactShadow") as MeshInstance3D
	_check(contact_shadow.visible and contact_shadow.top_level and contact_shadow.mesh.get_surface_count() == 1 and contact_shadow.mesh.get_aabb().size.y > 0.03, "the Gol contact shade follows the avenue grade inside its own ground-projected mesh")
	_check(not paused and not hud.pause_menu.visible and hud.has_node("Overlay/Minimap"), "startup has driving HUD, minimap and no pause menu")
	_check(not hud.buttons.get_node("Race").visible and not hud.buttons.get_node("Rally").visible and hud.buttons.get_node("MainMenu").text == "Laboratórios", "the district pause menu keeps a single entry to the laboratories")
	var relief := _street_relief()
	print("Street relief: %.2f m across the grid, %.2f%% peak sustained grade over 6 m" % [relief.x, relief.y * 100.0])
	_check(relief.x >= 28.0 and relief.y <= 0.165 and relief.y >= 0.095, "the street grid has a pronounced but drivable relief")
	_check(_check_support(car), "the whole street grid and plaza have continuous support at the authored grades")
	if preview:
		cycle.running = false
		_capture("start")
		await _show_plaza(car, cycle)
		cycle.set_hour(16.5)
		_place_car(car, Vector2(-86.0, -52.15), PI * 0.5)
		await _frames(12)
		_capture("subida")
		await _show_storefront(city, hud)
		_finish()
		return
	Input.action_press("accelerate")
	await _frames(390)
	Input.action_release("accelerate")
	print("Avenue drive: ", car.global_position, " at ", car.get_speed_kmh(), " km/h")
	_check(car.global_position.x > Layout.SPAWN.x + 60.0 and absf(car.global_position.z - Layout.SPAWN.y) < 3.0 and car.is_on_floor(), "accelerating from startup drives down the avenue without leaving the lane")
	for direction: float in [-1, 1]:
		var westbound := direction < 0.0
		_place_car(car, Vector2(-87.0 if westbound else -171.0, -52.15 if westbound else -55.85), -direction * PI * 0.5)
		await _frames(20)
		var start := car.global_position
		Input.action_press("accelerate")
		await _frames(350)
		Input.action_release("accelerate")
		var travel := car.global_position - start
		print("Hillside drive: %.1f m along the road, %.1f m elevation change" % [travel.x, travel.y])
		_check(travel.x * direction > 34.0 and travel.y * -direction > 5.0 and absf(travel.z) < 1.0 and car.is_on_floor(), "the Gol climbs and descends the residential grade under normal driving input")
	_check_solar_shadows(world, settings, cycle)
	var daytime: float = cycle.hour
	car.set_physics_process(false)
	_place_car(car, Vector2(Layout.COLUMNS[1] + 1.7, -104.0), 0.0)
	cycle.set_hour(23.0)
	await process_frame
	_check(cycle.hour != daytime and cycle.night_factor > 0.9, "the district clock reaches nighttime")
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
	for group in ["tree", "parked"]:
		var patches := city.find_children("Ground_shade_%s_*" % group, "MeshInstance3D", false, false)
		if patches.is_empty():
			return false
		for patch: MeshInstance3D in patches:
			if patch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				return false
	var expected := {"cable": false, "grass_blade": false, "canopy": true, "roof": true}
	var found := {}
	for batch: MultiMeshInstance3D in city.find_children("*", "MultiMeshInstance3D", false, false):
		var material_name := batch.material_override.resource_name
		if not expected.has(material_name):
			continue
		found[material_name] = true
		if (batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF) != expected[material_name]:
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
	_check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and first_split >= 16.0 and not sun.directional_shadow_blend_splits, "the Gol and nearby street fixtures stay in the detailed shadow cascade")
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
			for lane: float in [-1.8, 0, 1.8]:
				points.append(Vector2(x, z + lane))
	for point in points:
		var center := Layout.surface_point(point)
		var ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2, center - Vector3.UP * 2, 1, [car.get_rid()])
		var hit := car.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider.name != "StreetAndTerrainSupport" or absf(hit.position.y - center.y) > 0.08 or hit.normal.y < 0.97:
			print("Unexpected support at ", point, ": ", hit)
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
	var frame := cafe.global_position + 6.9 * facing - 1.8 * cafe.global_basis.x
	camera.global_position = Layout.surface_point(Vector2(frame.x, frame.z), 1.65)
	camera.look_at(cafe.global_position - 1.10 * Vector3.UP)
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
	call_group("wave_audio", "stop_audio")
	await process_frame
	OS.delay_msec(120)
	await process_frame
	quit(0 if failures == 0 else 1)
