extends SceneTree

const OUTPUT := "res://builds/previews"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Car preview requires a rendered window.")
		quit(1)
		return
	var output := OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(960, 640)
	root.msaa_3d = Viewport.MSAA_2X
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	InputSetup.configure()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("343b40")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d3dd")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, -0.5, 0)
	sun.light_color = Color("ffe5c5")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.4, 2.4, 0)
	fill.light_color = Color("b6ccdf")
	fill.light_energy = 0.5
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(30, 0.1, 30)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("5b6468")
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	ground.mesh = floor_mesh
	ground.position.y = -0.05
	stage.add_child(ground)
	var car := load("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.position.y = 0.35
	stage.add_child(car)
	car.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 38
	stage.add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	var caption := Label.new()
	caption.text = "WAVE · " + str(car.get_meta("model_name", "CARRO"))
	caption.position = Vector2(28, 22)
	caption.add_theme_font_size_override("font_size", 26)
	canvas.add_child(caption)
	var views: Array[Vector3] = [Vector3(4.6, 2.8, -5.8), Vector3(4.6, 2.8, 5.8), Vector3(6.6, 2.0, 0.1), Vector3(-4.2, 3.8, -5.8)]
	var montage: Image
	for index in views.size():
		camera.position = views[index]
		camera.look_at(Vector3(0, 0.8, 0))
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		var error := screenshot.save_png(output.path_join("hatch-1000-%d.png" % index))
		if error != OK:
			push_error("Could not save preview: %s" % error_string(error))
			quit(1)
			return
		if montage == null:
			montage = Image.create_empty(screenshot.get_width() * 2, screenshot.get_height() * 2, false, screenshot.get_format())
		montage.blit_rect(screenshot, Rect2i(Vector2i.ZERO, screenshot.get_size()), Vector2i(index % 2, index / 2) * screenshot.get_size())
	montage.save_png(output.path_join("hatch-1000.png"))
	print("Hatch 1000 preview: " + ProjectSettings.globalize_path(output.path_join("hatch-1000.png")))
	stage.queue_free()
	await process_frame
	quit()
