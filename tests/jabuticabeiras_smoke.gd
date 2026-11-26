extends SceneTree

const STREET := "res://scenes/city/jabuticabeiras/drive_jabuticabeiras.tscn"
const FIGUEIRAS := "res://scenes/city/figueiras/drive_figueiras.tscn"
const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const FixtureInput = preload("fixture_input.gd")
const FixtureAudio = preload("fixture_audio.gd")

var _checks := 0
var _failures := 0
var _car: PlayerCar


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_render_loop_enabled(false)
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(startup == STREET, "the street is the opening world")
	if change_scene_to_file(startup) != OK:
		quit(1)
		return
	await scene_changed
	if current_scene.scene_file_path != STREET:
		quit(1)
		return
	FixtureInput.isolate()
	var world := current_scene
	var street := world.get_node("Street")
	_car = world.get_node("PlayerCar")
	await _frames(17)
	_check(street.get_meta("street_length") == Layout.LENGTH and street.get_meta("facade_count") == 28, "the offline street and both frontages are packaged")
	_check(_car.is_on_floor() and _car.surface_name == "asfalto", "the Gol starts on the asphalt")
	_check(_supported(street.get_node("StreetSupport")), "both lanes and sidewalks have continuous support")
	_check(_blocked(street.get_node("StreetObjects"), 2.4, -1.6)
		and _blocked(street.get_node("StreetObjects"), 153.7, 158.0), "the street ends at visible colliders")
	_check_graphics(world, street)

	var stayed_on_road := true
	var furthest := Layout.SPAWN_STATION
	for tick in 1200:
		var point := Vector2(_car.global_position.x, _car.global_position.z)
		var site := Layout.coordinates(point)
		furthest = maxf(furthest, site.y)
		if site.y > 147.0:
			break
		stayed_on_road = stayed_on_road and _car.is_on_floor() and _car.surface_name == "asfalto"
		var look_ahead := clampf(_car.get_speed_kmh() * 0.21 + 4.0, 6.0, 11.5)
		var aim := Layout.position_at(site.y + look_ahead, Layout.SPAWN_OFFSET)
		var heading := Vector2(-_car.global_basis.z.x, -_car.global_basis.z.z).normalized()
		var steering := clampf(heading.angle_to(Vector2(aim.x, aim.z) - point) * 3.1, -1.0, 1.0)
		var speed := lerpf(37.0, 14.0, smoothstep(130.0, 145.0, site.y))
		var pedal := clampf((speed - _car.get_speed_kmh()) * 0.18, -1.0, 1.0)
		Input.action_press("steer_left", maxf(-steering, 0.0))
		Input.action_press("steer_right", maxf(steering, 0.0))
		Input.action_press("accelerate", maxf(pedal, 0.0))
		Input.action_press("brake", maxf(-pedal, 0.0))
		await _frames(1)
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)
	_check(furthest > 147.0 and stayed_on_road, "the Gol drives the uphill curve to the turning area")

	var hud := world.get_node("HUD")
	hud.set_paused(true)
	hud.buttons.get_node("Reset").pressed.emit()
	await _frames(12)
	_check(_car.global_position.distance_to(Layout.spawn().origin) < 0.2 and not paused, "reset restores the opening lane and resumes")
	var rig := world.get_node("ChaseCamera")
	rig.view = rig.View.COCKPIT
	await _frames(3)
	_check(rig.is_cockpit_view() and _car.get_node("Visuals/Body/Instruments").visible, "the fixed-light street supports the Gol cockpit")
	_check(world.get_node("DrivingAudio").has_node("Radio"), "the Gol keeps its radio and recorded audio")

	hud.set_paused(true)
	hud.buttons.get_node("MainMenu").pressed.emit()
	await scene_changed
	var menu := current_scene
	_check(root.gui_get_focus_owner() == menu.street_button and not paused, "the pause menu opens Labs with return to the street focused")
	_check(ResourceLoader.exists(FIGUEIRAS) and menu.figueiras_button.visible, "the full district is available in Labs")
	menu.street_button.pressed.emit()
	await scene_changed
	await _frames(6)
	_check(current_scene.scene_file_path == STREET and not paused, "Labs reopen the playable street")
	await FixtureAudio.drain(self)
	print("Rua das Jabuticabeiras: %d checks, %d failures" % [_checks, _failures])
	quit(int(_failures > 0))


func _check_graphics(world: Node, street: Node) -> void:
	var settings := root.get_node("WaveSettings")
	var sun := world.get_node("Sun") as DirectionalLight3D
	var environment: Environment = world.get_node("WorldEnvironment").environment
	var pavement: ShaderMaterial = street.get_node("Pavement_0_32").mesh.surface_get_material(0)
	var surface_bake: Texture2D = pavement.get_shader_parameter("surface_bake")
	_check(surface_bake != null and surface_bake.get_width() > 0, "the street packages its offline surface lighting")

	settings.set_graphics_preset("economy")
	_check(not sun.shadow_enabled and pavement.get_shader_parameter("use_baked_shadow")
		and not pavement.get_shader_parameter("material_detail") and not environment.ssao_enabled,
		"economy uses baked shadows without the detail pass")
	settings.set_graphics_preset("high")
	_check(sun.shadow_enabled and not pavement.get_shader_parameter("use_baked_shadow") and environment.ssao_enabled,
		"quality uses dynamic shadows and enables ambient occlusion")
	settings.set_graphics_preset("medium")
	_check(sun.shadow_enabled and not environment.ssao_enabled and pavement.get_shader_parameter("material_detail"),
		"balanced restores material detail with the lower post-processing cost")
	settings.set_graphics_preset("economy")


func _supported(ground: StaticBody3D) -> bool:
	var space := ground.get_world_3d().direct_space_state
	for station in range(4, 154, 3):
		var edge := Layout.half_width(station)
		for offset: float in [-edge - 1.12, -1.63, 1.63, edge + 1.12]:
			var point := Layout.position_at(station, offset)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.55, point - Vector3.UP * 0.26)
			ray.exclude = [_car.get_rid()]
			var hit := space.intersect_ray(ray)
			if hit.get("collider") != ground:
				return false
	return true


func _blocked(solids: StaticBody3D, first: float, last: float) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(Layout.position_at(first, 0.0, 0.85), Layout.position_at(last, 0.0, 0.85))
	ray.exclude = [_car.get_rid()]
	return solids.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == solids


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
