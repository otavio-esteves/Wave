extends SceneTree

const Layout = preload("res://scripts/rally/rally_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Rally previews require a real rendering window")
		quit(1)
		return
	root.size=Vector2i(1280,720)
	root.unresizable=true
	var settings := root.get_node("WaveSettings")
	settings.set_graphics("resolution","1280x720")
	settings.set_graphics("shadows",true)
	settings.set_graphics("antialiasing",true)
	change_scene_to_file("res://scenes/rally/drive_rally.tscn")
	await _frames(30)
	var world := current_scene
	var car: PlayerCar=world.get_node("PlayerCar")
	car.set_physics_process(false)
	var route: PackedVector3Array=world.get_node("RallyMap").get_meta("route")
	DirAccess.make_dir_recursive_absolute("res://builds/previews")
	for index in [15,260,480]:
		car.global_position=route[index]+Vector3.UP*0.5
		var forward := Layout.tangent(route,index)
		car.rotation=Vector3(0,atan2(-forward.x,-forward.z),0)
		world.get_node("ChaseCamera").snap_to_target()
		car.set_physics_process(true)
		await _frames(20)
		car.velocity = Vector3.ZERO
		car.set_physics_process(false)
		await _frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/previews/rally-%d.png" % index)
	world.get_node("ChaseCamera").hood_view=true
	await _frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/previews/rally-hood.png")
	world.queue_free()
	await process_frame
	OS.delay_msec(200)
	await process_frame
	quit()

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
