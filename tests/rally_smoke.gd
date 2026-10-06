extends SceneTree

const Dynamics = preload("res://scripts/vehicle/tire_dynamics.gd")
const Layout = preload("res://scripts/rally/rally_layout.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var force := Dynamics.combined_force(7000,7000,6000)
	_check(absf(force.length()-6000)<0.01 and force.x<6000, "braking and cornering share the friction circle")
	var asphalt := Dynamics.new()
	var gravel := Dynamics.new()
	var asphalt_speed := 12.0
	var gravel_speed := 12.0
	for step in 240:
		asphalt_speed += asphalt.step(asphalt_speed,0,0,9.6,false,0,1.05,1.0/240).x/240
		gravel_speed += gravel.step(gravel_speed,0,0,9.6,false,0,0.68,1.0/240).x/240
	_check(asphalt_speed > gravel_speed+1 and asphalt_speed < 21.6, "front-wheel traction limits acceleration more on gravel")
	_check(asphalt.front_load < Dynamics.MASS*Dynamics.GRAVITY*Dynamics.FRONT_WEIGHT, "acceleration transfers load away from the driven front axle")
	asphalt.step(12,0,0,-15,true,0,1.05,1.0/240)
	asphalt.step(12,0,0,-15,true,0,1.05,1.0/240)
	_check(asphalt.front_load > Dynamics.MASS*Dynamics.GRAVITY*Dynamics.FRONT_WEIGHT, "braking transfers load toward the front axle")
	asphalt.reset()
	var response := asphalt.step(18,0,0.08,0,false,0,1.05,1.0/240)
	_check(response.y>0 and asphalt.yaw_rate>0, "steering develops tire force and angular acceleration")
	_check(asphalt.yaw_rate < 18/Dynamics.WHEELBASE*tan(0.08), "yaw inertia delays the turning response")
	asphalt.reset()
	_check(asphalt.yaw_rate==0 and asphalt.longitudinal_acceleration==0, "reset clears tire and yaw state")
	var rolling := Dynamics.new()
	var held := rolling.step(0,0,0.3,0,false,0,0.68,1.0/240)
	_check(held==Vector2.ZERO and rolling.yaw_rate==0, "stationary steering injects no movement")
	var turning := rolling.step(-12,0,0.08,0,false,0,1.05,1.0/240)
	_check(turning.y<0 and rolling.yaw_rate<0, "reverse steering reverses the yaw response")
	rolling.reset()
	var free_grip := rolling.step(15,3,0,0,false,0,0.68,1.0/240).y
	rolling.reset()
	var locked_grip := rolling.step(15,3,0,0,false,1,0.68,1.0/240).y
	_check(absf(locked_grip)<absf(free_grip), "rear handbrake reduces lateral recovery on gravel")
	var coarse := _integrate_turn(120)
	var fine := _integrate_turn(240)
	_check(coarse.distance_to(fine)<0.1, "tire and yaw integration are stable across time steps")
	change_scene_to_file("res://scenes/rally/drive_rally.tscn")
	await _frames(45)
	var world := current_scene
	var car: PlayerCar = world.get_node("PlayerCar")
	var timing := world.get_node("StageTiming")
	var camera := world.get_node("ChaseCamera")
	var route: PackedVector3Array = timing.route
	_check(car.simulation_handling and car.is_on_floor(), "rally starts grounded with the new handling profile")
	_check(absf(car.forward_speed*3.6-220)<0.01 and car.acceleration==9.6, "220 km/h limit and reduced motor torque remain configured")
	_check(timing.length_m>1400 and timing.length_m<1700 and timing.gates.size()==13, "complete 1.5 km point-to-point stage has ordered controls")
	var highest := -INF
	var lowest := INF
	for point in route:
		highest = maxf(highest,point.y)
		lowest = minf(lowest,point.y)
	_check(highest-lowest>15, "stage has substantial real elevation changes")
	_check(car.surface_name=="asfalto" and car.surface_friction>1, "wheel rays identify starting asphalt")
	Input.action_press("accelerate")
	await _frames(180)
	Input.action_release("accelerate")
	_check(car.get_speed_kmh()<100 and car.get_speed_kmh()>25, "traction-based launch is progressive, below 100 km/h after three seconds")
	_check(timing.active and timing.next_gate>=1, "physically crossing the start activates the stage clock")
	# Traverse the whole route under power at a conservative test speed.
	car.reset_car()
	await _frames(30)
	car.forward_speed=10.0
	var waypoint:=12
	var grounded:=0
	var frames:=0
	var max_error:=0.0
	while waypoint < route.size()-8 and frames<18000:
		var flat := Vector3(car.global_position.x,0,car.global_position.z)
		var target := Vector3(route[waypoint].x,0,route[waypoint].z)
		while flat.distance_to(target)<5 and waypoint<route.size()-8:
			waypoint+=1
			target=Vector3(route[waypoint].x,0,route[waypoint].z)
		var direction := (target-flat).normalized()
		var heading := atan2(-direction.x,-direction.z)
		var error := wrapf(heading-car.get_heading(),-PI,PI)
		var steering := clampf(-error*2.4,-1,1)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		Input.action_press("steer_left" if steering<0 else "steer_right",absf(steering))
		Input.action_press("accelerate")
		await _frames(1)
		frames+=1
		if car.is_on_floor():
			grounded+=1
		max_error=maxf(max_error,car.global_position.distance_to(route[maxi(0,waypoint-2)]))
	for action in ["accelerate","steer_left","steer_right"]:
		Input.action_release(action)
	print("Rally route: waypoint=%d/%d frames=%d floor=%.3f max waypoint distance=%.2f surface=%s" % [waypoint,route.size(),frames,float(grounded)/maxi(frames,1),max_error,car.surface_name])
	_check(waypoint>=route.size()-8, "car drives the complete asphalt/gravel stage through elevation and bends")
	_check(float(grounded)/maxi(frames,1)>0.98, "suspension contact remains stable through the stage")
	_check(timing.finished_time>100 and timing.next_gate==13 and not timing.active, "ordered physical crossings finish the timed stage")
	_check(timing.valid and timing.best_time==timing.finished_time, "clean physical stage records the best time")
	_check(car.surface_name=="cascalho" and absf(car.surface_friction-0.68)<0.01, "gravel contacts switch tire adhesion")
	_check(car.global_basis.y.dot(Layout.normal_at(car.global_position.x,car.global_position.z))>0.995, "car follows the actual terrain angle")
	car.reset_car()
	car.global_position=route[215]+Vector3.UP*0.5
	var uphill_forward:=Layout.tangent(route,215)
	car.rotation=Vector3(0,atan2(-uphill_forward.x,-uphill_forward.z),0)
	await _frames(120)
	var hill_start:=car.global_position
	Input.action_press("accelerate")
	await _frames(120)
	Input.action_release("accelerate")
	_check(car.get_speed_kmh()>15 and car.global_position.distance_to(hill_start)>4, "tiny rollback on a hill cannot repeatedly lock the reverse delay")
	Input.action_press("camera_view")
	await _frames(1)
	Input.action_release("camera_view")
	await _frames(2)
	_check(camera.hood_view and camera.arm.spring_length==0, "V selects the hood camera")
	car.reset_car()
	await _frames(3)
	_check(not camera.hood_view and timing.next_gate==0 and timing.elapsed==0, "reset restores the chase view and a fresh run")
	world.get_node("HUD").set_paused(true)
	var before: float=timing.elapsed
	await _frames(5)
	_check(timing.elapsed==before, "pausing stops the stage clock")
	world.get_node("HUD").set_paused(false)
	var settings := root.get_node("WaveSettings")
	settings.set_quality_mode()
	_check(settings.graphics["resolution"]=="1920x1080" and settings.graphics["shadows"] and settings.graphics["antialiasing"], "quality preset selects 1080p with shadows and MSAA")
	_check(world.get_node("WorldEnvironment").environment.ssao_enabled, "quality preset enables ambient occlusion in the rally")
	settings.set_economy_mode()
	_check(not world.get_node("WorldEnvironment").environment.ssao_enabled, "economy preset disables additional rally effects")
	world.queue_free()
	await process_frame
	OS.delay_msec(150)
	await process_frame
	print("Rally checks: %d passed / %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks+=1
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _integrate_turn(hz: int) -> Vector2:
	var dynamics := Dynamics.new()
	var velocity := Vector2(18,0)
	var dt := 1.0/hz
	for frame in hz*3:
		velocity += dynamics.step(velocity.x,velocity.y,0.04,0,false,0,1.05,dt)*dt
		var turn := dynamics.yaw_rate*dt
		velocity=Vector2(velocity.x*cos(turn)+velocity.y*sin(turn),-velocity.x*sin(turn)+velocity.y*cos(turn))
	return velocity
