extends SceneTree

const OUTPUT := "res://builds/previews"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.get_node("WaveSettings").set_graphics("resolution", "1280x720")
	root.get_node("WaveSettings").set_graphics("shadows", true)
	for path in ["res://scenes/race/drive_race.tscn", "res://scenes/city/drive_neighborhood.tscn", "res://scenes/test_track.tscn"]:
		change_scene_to_file(path)
		for frame in 15:
			await process_frame
		var world := current_scene
		var car := world.get_node("PlayerCar") as PlayerCar
		var camera := Camera3D.new()
		camera.far = 2500
		camera.near = 5.0
		camera.fov = 50
		world.add_child(camera)
		camera.current = true
		world.get_node("HUD/Overlay").hide()
		var label := "city-overview"
		if "race" in path:
			label = "circuit-overview"
			camera.position = Vector3(0, 370, 170)
			camera.look_at(Vector3(0, 0, 30))
			world.get_node("WorldEnvironment").environment.fog_enabled = false
			for geometry in world.find_children("*", "GeometryInstance3D", true, false):
				geometry.visibility_range_end = 0.0
		elif "city" in path:
			camera.position = Vector3(0, 1100, 520)
			camera.look_at(Vector3.ZERO)
			world.get_node("WorldEnvironment").environment.fog_enabled = false
			for geometry in world.find_children("*", "GeometryInstance3D", true, false):
				geometry.visibility_range_end = 0.0
		else:
			label = "ramp-alignment"
			camera.near = 0.05
			camera.fov = 40
			car.reset_car()
			car.position = Vector3(-20, 0.36, 4)
			car.velocity = Vector3(0, 0, -10)
			Input.action_press("accelerate", 0.5)
			for frame in 45:
				await physics_frame
				await process_frame
			Input.action_release("accelerate")
			car.set_physics_process(false)
			camera.position = car.position + Vector3(4, 2.5, -5)
			camera.look_at(car.position + Vector3.UP * 0.4)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))
		if "test_track" in path:
			car.set_physics_process(true)
			car.reset_car()
			car.position = Vector3(-33, 0.36, 27)
			car.forward_speed = 8.0
			car.velocity = Vector3(0, 0, -8)
			Input.action_press("accelerate")
			for frame in 125:
				await physics_frame
				await process_frame
			Input.action_release("accelerate")
			car.set_physics_process(false)
			camera.fov = 50
			camera.position = Vector3(-13, 29, 29)
			camera.look_at(Vector3(-33, 0, -1))
			for frame in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT.path_join("practice-area.png"))
		if "race" in path:
			camera.current = false
			world.get_node("ChaseCamera/SpringArm3D/Camera3D").current = true
			world.get_node("HUD/Overlay").show()
			for frame in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT.path_join("circuit-driving.png"))
	print("World previews saved to " + ProjectSettings.globalize_path(OUTPUT))
	current_scene.queue_free()
	await process_frame
	OS.delay_msec(150)
	await process_frame
	await process_frame
	quit()
