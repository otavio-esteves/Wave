extends SceneTree

const Layout = preload("res://scripts/race/circuit_layout.gd")
const OUTPUT := "res://builds/previews"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var settings := root.get_node("WaveSettings")
	settings.set_graphics("resolution", "1280x720")
	settings.set_graphics("shadows", true)
	settings.set_graphics("antialiasing", true)
	change_scene_to_file("res://scenes/race/drive_race.tscn")
	for frame in 15:
		await process_frame
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	car.set_physics_process(false)
	await _save("circuit-driving")
	var route := Layout.route()
	for sector in [["circuit-industrial", Vector3(490, 0, -10)], ["circuit-forest", Vector3(-480, 0, -100)]]:
		var index := 0
		var distance := INF
		for candidate in route.size():
			var current := route[candidate].distance_squared_to(sector[1])
			if current < distance:
				distance = current
				index = candidate
		var forward := Layout.tangent(route, index)
		car.position = route[index] + Vector3.UP * 0.36
		car.basis = Basis(forward.cross(Vector3.UP), Vector3.UP, -forward)
		world.get_node("ChaseCamera").snap_to_target()
		await _save(sector[0])
	var camera := Camera3D.new()
	camera.far = 2500
	camera.near = 5
	camera.fov = 50
	world.add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 1250, 580)
	camera.look_at(Vector3.ZERO)
	world.get_node("HUD/Overlay").hide()
	world.get_node("WorldEnvironment").environment.fog_enabled = false
	for geometry in world.find_children("*", "GeometryInstance3D", true, false):
		geometry.visibility_range_end = 0
	await _save("circuit-overview")
	print("Race previews saved to " + ProjectSettings.globalize_path(OUTPUT))
	current_scene.queue_free()
	await process_frame
	OS.delay_msec(150)
	await process_frame
	await process_frame
	quit()

func _save(label: String) -> void:
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))
