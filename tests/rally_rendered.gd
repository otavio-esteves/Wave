extends SceneTree

const Layout = preload("res://scripts/rally/rally_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Rendered rally benchmark requires a window")
		quit(1)
		return
	root.unresizable=true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var settings := root.get_node("WaveSettings")
	settings.set_quality_mode()
	if "--balanced" in OS.get_cmdline_user_args():
		settings.set_balanced_mode()
	elif "--economy" in OS.get_cmdline_user_args():
		settings.set_economy_mode()
	var expected_size: Vector2i = settings.RESOLUTIONS[settings.graphics["resolution"]]
	change_scene_to_file("res://scenes/rally/drive_rally.tscn")
	await _frames(30)
	var world:=current_scene
	if "--baseline-map" in OS.get_cmdline_user_args():
		var old := world.get_node("RallyMap")
		world.remove_child(old)
		old.queue_free()
		var baseline: PackedScene = load("/tmp/wave-opt-before-map.tscn")
		world.add_child(baseline.instantiate())

	if "--no-vegetation" in OS.get_cmdline_user_args():
		for geometry in world.get_node("RallyMap").get_children():
			if geometry is MultiMeshInstance3D and geometry.material_override.resource_name in ["conifer","tussock"]:
				geometry.hide()
	if "--no-postfx" in OS.get_cmdline_user_args():
		var environment: Environment = world.get_node("WorldEnvironment").environment
		environment.ssao_enabled = false
		environment.ssil_enabled = false
		environment.volumetric_fog_enabled = false
		environment.glow_enabled = false
	var car: PlayerCar=world.get_node("PlayerCar")
	var points: PackedVector3Array=world.get_node("RallyMap").get_meta("route")
	# Physical keyboard/controller events must not contaminate automated runs.
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "reset_car", "camera_view", "camera_back"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	car.reset_car()
	car.global_position=points[215]+Vector3.UP*0.5
	var forward:=Layout.tangent(points,215)
	car.rotation=Vector3(0,atan2(-forward.x,-forward.z),0)
	car.velocity=Vector3.ZERO
	car.forward_speed=8.0
	var stationary := "--static" in OS.get_cmdline_user_args()
	if stationary:
		# Shared pose independent of controller settling, for a fair GPU comparison.
		car.set_physics_process(false)
		var normal := Layout.normal_at(points[215].x, points[215].z)
		forward = forward.slide(normal).normalized()
		car.global_basis = Basis(forward.cross(normal).normalized(), normal, -forward)
	world.get_node("ChaseCamera").snap_to_target()
	await create_timer(5.0).timeout
	root.get_node("WaveSettings").apply_graphics()
	await _frames(2)
	if "--no-postfx" in OS.get_cmdline_user_args():
		var environment: Environment = world.get_node("WorldEnvironment").environment
		environment.ssao_enabled = false
		environment.ssil_enabled = false
		environment.volumetric_fog_enabled = false
		environment.glow_enabled = false
	var capture:=world.get_node("PerformanceCapture")
	capture.toggle()
	var waypoint:=220
	var next_log:=0.0
	var render_cpu: Array[float] = []
	var render_gpu: Array[float] = []
	var grounded:=0
	var samples:=0
	var max_error:=0.0
	while capture.elapsed<30.0 and waypoint<points.size()-4:
		var flat:=Vector3(car.global_position.x,0,car.global_position.z)
		var target:=Vector3(points[waypoint].x,0,points[waypoint].z)
		while flat.distance_to(target)<5 and waypoint<points.size()-4:
			waypoint+=1
			target=Vector3(points[waypoint].x,0,points[waypoint].z)
		var direction:=(target-flat).normalized()
		var heading:=atan2(-direction.x,-direction.z)
		var error:=wrapf(heading-car.get_heading(),-PI,PI)
		var steering:=clampf(-error*2.4,-1,1)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_press("steer_left" if steering<0 else "steer_right",absf(steering))
		if not stationary:
			Input.action_press("accelerate")
		await _frames(1)
		if car.is_on_floor():
			grounded+=1
		samples+=1
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		if capture.elapsed>=next_log:
			print("Rally driving at %.1fs: speed=%.2f input=%.2f brake=%.2f pos=%s floor=%s steer=%.2f" % [capture.elapsed,car.drive_speed,Input.get_action_strength("accelerate"),Input.get_action_strength("brake"),car.global_position,car.is_on_floor(),car.steering_angle])
			next_log+=5.0
		var closest:=INF
		for point in points:
			closest=minf(closest,Vector2(point.x-flat.x,point.z-flat.z).length())
		max_error=maxf(max_error,closest)
	for action in ["accelerate","steer_left","steer_right"]:
		Input.action_release(action)
	capture.finish()
	var cpu_sum:=0.0
	var gpu_sum:=0.0
	for index in render_cpu.size():
		cpu_sum+=render_cpu[index]
		gpu_sum+=render_gpu[index]
	print("Mean viewport render: CPU %.2f ms, GPU %.2f ms" % [cpu_sum/maxi(samples,1),gpu_sum/maxi(samples,1)])
	print("Rendered rally: size=%s renderer=%s waypoint=%d road_error=%.2f grounded=%.3f" % [root.size,RenderingServer.get_current_rendering_method(),waypoint,max_error,float(grounded)/maxi(samples,1)])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rally-rendered.png")
	var valid:=root.size==expected_size and (stationary or waypoint>285) and max_error<Layout.HALF_WIDTH and (stationary or float(grounded)/maxi(samples,1)>0.95)
	world.queue_free()
	await process_frame
	OS.delay_msec(200)
	await process_frame
	quit(0 if valid else 1)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
