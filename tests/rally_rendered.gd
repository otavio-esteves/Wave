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
	root.get_node("WaveSettings").set_quality_mode()
	change_scene_to_file("res://scenes/rally/drive_rally.tscn")
	await _frames(30)
	var world:=current_scene
	var car: PlayerCar=world.get_node("PlayerCar")
	var points: PackedVector3Array=world.get_node("RallyMap").get_meta("route")
	car.global_position=points[215]+Vector3.UP*0.5
	var forward:=Layout.tangent(points,215)
	car.rotation=Vector3(0,atan2(-forward.x,-forward.z),0)
	car.velocity=Vector3.ZERO
	car.forward_speed=8.0
	world.get_node("ChaseCamera").snap_to_target()
	await create_timer(5.0).timeout
	root.get_node("WaveSettings").apply_graphics()
	await _frames(2)
	var capture:=world.get_node("PerformanceCapture")
	capture.toggle()
	var waypoint:=220
	var next_log:=0.0
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
		Input.action_press("accelerate")
		await _frames(1)
		if car.is_on_floor():
			grounded+=1
		samples+=1
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
	print("Rendered rally: size=%s renderer=%s waypoint=%d road_error=%.2f grounded=%.3f" % [root.size,RenderingServer.get_current_rendering_method(),waypoint,max_error,float(grounded)/maxi(samples,1)])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://rally-rendered.png")
	var valid:=root.size==Vector2i(1600,900) and waypoint>285 and max_error<Layout.HALF_WIDTH and float(grounded)/maxi(samples,1)>0.95
	world.queue_free()
	await process_frame
	OS.delay_msec(200)
	await process_frame
	quit(0 if valid else 1)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
