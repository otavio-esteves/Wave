class_name PlayerCar
extends CharacterBody3D

signal car_reset

const TireDynamics = preload("res://scripts/vehicle/tire_dynamics.gd")
@export var simulation_handling := false
var tires := TireDynamics.new()
var surface_name := "asfalto"
var surface_friction := 1.05

@export_group("Motor e freios")
@export var forward_speed: float = 220.0 / 3.6
@export var reverse_speed: float = 8.0
@export var acceleration: float = 9.6
@export_range(0.05, 1.0, 0.01) var arcade_acceleration_scale: float = 0.4
@export var braking: float = 11.0
@export var rolling_resistance: float = 0.6
@export var air_resistance: float = 0.0012
@export var reverse_delay: float = 0.25

@export_group("Direção e aderência")
@export var wheelbase: float = 2.26
@export var low_speed_steering_degrees: float = 32.0
@export var high_speed_steering_degrees: float = 10.0
@export var steering_response: float = 4.0
@export var max_lateral_acceleration: float = 12.0
@export var lateral_grip: float = 12.0
@export var handbrake_grip: float = 1.8
@export var handbrake_deceleration: float = 8.0
@export var yaw_response: float = 7.0
@export var slide_scrub: float = 0.45

@export_group("Terreno e suspensão")
@export var gravity: float = 20.0
@export var max_step_height: float = 0.35
@export var terrain_response: float = 14.0
@export var wheel_radius: float = 0.31
@export var suspension_travel: float = 0.16

var _wheel_offsets: Array[Vector3] = []
var _ground_normal := Vector3.UP
var _contacts: Array[Dictionary] = []
var _ground_query := PhysicsRayQueryParameters3D.new()
var _step_impact := KinematicCollision3D.new()
var _step_landing := KinematicCollision3D.new()
var _pedal_direction := 0.0
var contact_shadow_enabled := true

var drive_speed: float = 0.0
var lateral_speed: float = 0.0
var _reset_input_suppressed := false
var steering_input: float = 0.0
var steering_angle: float = 0.0
var spawn_transform: Transform3D
var _reverse_wait: float = 0.0
var _yaw_rate := 0.0
var _longitudinal_acceleration := 0.0
var _lateral_acceleration := 0.0
var _tail_lamps: Array[StandardMaterial3D] = []
var _reverse_lamps: Array[StandardMaterial3D] = []
var _head_lamps: Array[StandardMaterial3D] = []
var headlights_on := true

@onready var visuals: Node3D = $Visuals
@onready var front_left: Node3D = $Visuals/FrontLeft
@onready var front_right: Node3D = $Visuals/FrontRight
@onready var wheels: Array[Node3D] = [
	$Visuals/FrontLeft/Wheel, $Visuals/FrontRight/Wheel,
	$Visuals/RearLeft/Wheel, $Visuals/RearRight/Wheel,
]


func _ready() -> void:
	_setup_lamps()
	spawn_transform = global_transform
	floor_snap_length = 0.45
	floor_constant_speed = not simulation_handling
	if simulation_handling:
		gravity = 9.81
	floor_max_angle = deg_to_rad(45.0)
	_ground_query.exclude = [get_rid()]
	_ground_query.collision_mask = collision_mask
	for wheel in wheels:
		_wheel_offsets.append(wheel.get_parent().position)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("headlights"):
		headlights_on = not headlights_on
	var reset_requested := Input.is_action_just_pressed("reset_car") and not _reset_input_suppressed
	if _reset_input_suppressed and not Input.is_action_pressed("reset_car") and not Input.is_action_just_pressed("reset_car"):
		_reset_input_suppressed = false
	if reset_requested or global_position.y < -4.0:
		reset_car()
		return

	# Wheel support is sampled once per tick, independently of tire integration.
	# Swept body movement still detects thin barriers at any speed.
	if is_on_floor():
		_sample_ground()
	var steps := clampi(ceili(velocity.length() * delta / 0.65), 1, 4)
	if simulation_handling:
		steps = maxi(steps, 2)
	for step in steps:
		_simulate_step(delta / steps)
	_update_visuals(delta)
	_update_lamps()


func _simulate_step(delta: float) -> void:
	var handbrake := Input.get_action_strength("handbrake")
	drive_speed = velocity.dot(-global_basis.z)
	if is_on_floor():
		_align_to_ground(delta)
		drive_speed = velocity.dot(-global_basis.z)
		if simulation_handling:
			_simulate_tires(delta, handbrake)
		else:
			var before_motor := drive_speed
			# Gravity acts along the road; braking and rolling resistance oppose it.
			var road_forward := (-global_basis.z).slide(_ground_normal).normalized()
			drive_speed += Vector3.DOWN.dot(road_forward) * gravity * delta
			_update_motor(delta, handbrake)
			var motor_change := drive_speed - before_motor
			# Reserve tire force for recovering lateral momentum before requesting yaw.
			# Otherwise full throttle can rotate the body faster than the tires can
			# redirect its velocity, sustaining an unintended powered slide.
			var total_grip := max_lateral_acceleration * surface_friction / 1.05
			var longitudinal_force := minf(absf(motor_change / delta), total_grip)
			var corner_budget := sqrt(maxf(0.0, total_grip * total_grip - longitudinal_force * longitudinal_force))
			_update_steering(delta, handbrake, corner_budget)
			var forward := (-global_basis.z).slide(_ground_normal).normalized()
			var right := forward.cross(_ground_normal).normalized()
			# A turn redirects the tire forces, not the existing momentum.
			drive_speed = velocity.dot(forward) + motor_change
			lateral_speed = velocity.dot(right)
			var grip := lerpf(lateral_grip, handbrake_grip, handbrake)
			var recovered := absf(lateral_speed) * (1.0 - exp(-grip * delta))
			# Acceleration/braking consume some of the available cornering grip.
			var tire_force := minf(corner_budget, lerpf(total_grip, 3.5, handbrake))
			# Locked tires must also stop a car travelling sideways. This remains
			# available when longitudinal braking uses the entire grip budget.
			tire_force = maxf(tire_force, minf(total_grip, 3.5) * handbrake)
			lateral_speed = move_toward(lateral_speed, 0.0, minf(recovered, tire_force * delta))
			# Sliding dissipates energy rather than behaving like a frictionless turn.
			drive_speed = move_toward(drive_speed, 0.0, minf(absf(lateral_speed) * slide_scrub, total_grip * 0.3) * delta)
			_longitudinal_acceleration = (drive_speed - before_motor) / delta
			_lateral_acceleration = -_yaw_rate * drive_speed
			velocity = forward * drive_speed + right * lateral_speed - Vector3.UP * 0.1
		_try_step(velocity * delta)
	else:
		# Keep launch momentum, including the vertical component of a climb.
		_longitudinal_acceleration = 0.0
		_lateral_acceleration = 0.0
		velocity.y -= gravity * delta
		if simulation_handling:
			global_basis = Basis(Vector3.UP, tires.yaw_rate * delta) * global_basis
	# move_and_slide uses the engine's whole physics delta internally.
	# Scale its velocity for this substep, then recover collision-adjusted speed.
	var motion_scale := delta / get_physics_process_delta_time()
	var was_grounded := is_on_floor()
	velocity *= motion_scale
	move_and_slide()
	velocity /= motion_scale
	# A tangent velocity can point upward in world space on an incline. Keep
	# support over small crests instead of treating that as a deliberate jump.
	if was_grounded and not is_on_floor() and velocity.dot(_ground_normal) <= 0.15:
		apply_floor_snap()
	if is_on_floor():
		# Floor snapping clears vertical velocity. Restore only its tangent part,
		# preserving the horizontal response from walls and other collisions.
		velocity.y = -(velocity.x * _ground_normal.x + velocity.z * _ground_normal.z) / _ground_normal.y
		_align_to_ground(delta)
	drive_speed = velocity.dot(-global_basis.z)
	lateral_speed = velocity.dot(global_basis.x)



func _simulate_tires(delta: float, handbrake: float) -> void:
	var forward := (-global_basis.z).slide(_ground_normal).normalized()
	var left := -forward.cross(_ground_normal).normalized()
	var longitudinal := velocity.dot(forward)
	var sideways := velocity.dot(left)
	drive_speed = longitudinal
	_update_motor(delta, handbrake)
	var requested := (drive_speed - longitudinal) / delta
	var slope_gravity := Vector3.DOWN.slide(_ground_normal) * gravity
	# Static brake force balances gravity, avoiding a small perpetual creep.
	if absf(longitudinal) < 0.5 and (handbrake > 0.0 or Input.is_action_pressed("brake") and not Input.is_action_pressed("accelerate") and _reverse_wait > 0.0):
		requested -= slope_gravity.dot(forward)
	var pedal := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	var braking_now := pedal * longitudinal < 0.0 or (Input.is_action_pressed("accelerate") and Input.is_action_pressed("brake"))
	steering_input = move_toward(steering_input, Input.get_axis("steer_left", "steer_right"), steering_response * delta)
	var angle := lerpf(low_speed_steering_degrees, high_speed_steering_degrees, clampf(absf(longitudinal) / forward_speed, 0.0, 1.0))
	steering_angle = -steering_input * deg_to_rad(angle)
	var acceleration_local := tires.step(longitudinal, sideways, steering_angle, requested, braking_now, handbrake, surface_friction, delta)
	velocity += (forward * acceleration_local.x + left * acceleration_local.y + slope_gravity) * delta
	velocity = velocity.slide(_ground_normal) - Vector3.UP * 0.1
	global_basis = Basis(_ground_normal, tires.yaw_rate * delta) * global_basis

func get_heading() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func _sample_ground() -> void:
	_contacts.clear()
	var heading := Basis(Vector3.UP, get_heading())
	for offset in _wheel_offsets:
		var center := global_position + heading * Vector3(offset.x, 0, offset.z)
		_ground_query.from = center + Vector3.UP * 0.65
		_ground_query.to = center - Vector3.UP * 0.95
		var hit := get_world_3d().direct_space_state.intersect_ray(_ground_query)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP) < cos(floor_max_angle):
			hit = {}
		_contacts.append(hit)
	_ground_normal = get_floor_normal()
	if not _contacts.is_empty():
		surface_friction = 0.0
		var count := 0
		var surfaces: Dictionary = {}
		for hit in _contacts:
			if hit.is_empty():
				continue
			var ground: Object = hit.collider
			var kind: String = ground.get_meta("surface", "asfalto")
			surfaces[kind] = int(surfaces.get(kind, 0)) + 1
			surface_friction += float(ground.get_meta("friction", 1.05))
			count += 1
		if count > 0:
			surface_friction /= count
			var most := 0
			for kind: String in surfaces:
				if surfaces[kind] > most:
					most = surfaces[kind]
					surface_name = kind
		else:
			surface_friction = 1.05
	if _contacts.all(func(hit: Dictionary) -> bool: return not hit.is_empty()):
		var front: Vector3 = (_contacts[0].position + _contacts[1].position) * 0.5
		var rear: Vector3 = (_contacts[2].position + _contacts[3].position) * 0.5
		var left: Vector3 = (_contacts[0].position + _contacts[2].position) * 0.5
		var right: Vector3 = (_contacts[1].position + _contacts[3].position) * 0.5
		var fitted := (right - left).cross(front - rear).normalized()
		if fitted.dot(Vector3.UP) >= cos(floor_max_angle):
			_ground_normal = fitted


func _align_to_ground(delta: float) -> void:
	var flat_forward := Basis(Vector3.UP, get_heading()) * Vector3.FORWARD
	var forward := flat_forward.slide(_ground_normal).normalized()
	var right := forward.cross(_ground_normal).normalized()
	var target_basis := Basis(right, _ground_normal, -forward)
	global_basis = global_basis.orthonormalized().slerp(target_basis, 1.0 - exp(-terrain_response * delta)).orthonormalized()


func _try_step(motion: Vector3) -> void:
	var horizontal := Vector3(motion.x, 0, motion.z)
	if horizontal.length_squared() < 0.000001:
		return
	if not test_move(global_transform, horizontal, _step_impact):
		return
	# Even a walkable face can catch the leading corner of the box on a
	# changing incline or where the wheel-fitted pitch meets a sidewalk lip.
	# The raised sweep and landing below decide whether this is traversable.
	var lift := Vector3.UP * max_step_height
	if test_move(global_transform, lift):
		return
	var raised := global_transform
	raised.origin += lift
	if test_move(raised, horizontal):
		return
	# Probe past the lip even while crawling: a very short per-frame motion can
	# otherwise land back on the low road and never discover the curb's top.
	var probe := horizontal.normalized() * maxf(horizontal.length(), wheel_radius * 0.65)
	if test_move(raised, probe):
		return
	raised.origin += probe
	if not test_move(raised, -Vector3.UP * (max_step_height + floor_snap_length), _step_landing):
		return
	if _step_landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	var rise := max_step_height + _step_landing.get_travel().y
	if rise <= safe_margin or rise > max_step_height + safe_margin:
		return
	global_position += Vector3.UP * (rise + safe_margin)
	# Lift only by the obstacle height, then let normal movement settle the car.


func _update_motor(delta: float, handbrake: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var effective_braking := minf(braking, surface_friction * 9.81)
	if handbrake > 0.0:
		drive_speed = move_toward(drive_speed, 0.0, minf(handbrake_deceleration, effective_braking) * handbrake * delta)
		_reverse_wait = 0.0
		return
	if throttle > 0.0 and brake_input > 0.0:
		drive_speed = move_toward(drive_speed, 0.0, effective_braking * brake_input * delta)
		_reverse_wait = 0.0
		return

	var pedal := throttle - brake_input
	if is_zero_approx(pedal):
		var drag := rolling_resistance + air_resistance * drive_speed * drive_speed
		drive_speed = move_toward(drive_speed, 0.0, drag * delta)
		_reverse_wait = 0.0
		return

	var direction := signf(pedal)
	# Only a deliberate change of drive direction arms the reverse delay.
	# Small rollback on a slope must not prevent the motor from taking up load.
	if pedal * drive_speed < 0.0 and absf(drive_speed) > 0.8:
		drive_speed = move_toward(drive_speed, 0.0, effective_braking * absf(pedal) * delta)
		if _pedal_direction != direction:
			_reverse_wait = reverse_delay
		_pedal_direction = direction
		return
	_pedal_direction = direction
	if _reverse_wait > 0.0:
		# Hold tiny downhill creep during the brake/reverse delay.
		drive_speed = move_toward(drive_speed, 0.0, effective_braking * delta)
		_reverse_wait = maxf(0.0, _reverse_wait - delta)
		return

	var limit := forward_speed if pedal > 0.0 else reverse_speed
	# Constant torque at launch, then approximately constant power. Rolling and
	# aerodynamic losses act under power too, instead of vanishing on throttle.
	var torque_factor := minf(1.0, 36.0 / maxf(absf(drive_speed), 1.0))
	var drag := rolling_resistance + air_resistance * drive_speed * drive_speed
	var motor := minf(acceleration * torque_factor * absf(pedal), surface_friction * 9.81)
	if pedal < 0.0:
		motor *= 0.65
	if drive_speed * signf(pedal) >= limit:
		motor = 0.0
	var previous_speed := drive_speed
	var change := motor * signf(pedal) - drag * signf(drive_speed)
	if not simulation_handling and change * direction > 0.0:
		# Scale the net powered acceleration, preserving the engine/drag balance
		# at top speed and the existing coasting and braking response.
		# Uphill load is retained within available torque so slower acceleration
		# still allows the car to climb the authored roads.
		var road_forward := (-global_basis.z).slide(_ground_normal).normalized()
		var uphill_load := maxf(0.0, -Vector3.DOWN.dot(road_forward) * gravity * direction)
		var net_acceleration := absf(change)
		change = direction * lerpf(minf(uphill_load, net_acceleration), net_acceleration, arcade_acceleration_scale)
	drive_speed += change * delta
	# The governor never brakes an already faster car coasting downhill.
	if pedal > 0.0:
		drive_speed = minf(drive_speed, maxf(forward_speed, previous_speed))
	else:
		drive_speed = maxf(drive_speed, minf(-reverse_speed, previous_speed))


func _update_steering(delta: float, handbrake: float, corner_budget: float) -> void:
	var requested := Input.get_axis("steer_left", "steer_right")
	var response := steering_response / (1.0 + absf(drive_speed) / 45.0)
	steering_input = move_toward(steering_input, requested, response * delta)
	var speed_ratio := clampf(absf(drive_speed) / forward_speed, 0.0, 1.0)
	var angle_limit := lerpf(low_speed_steering_degrees, high_speed_steering_degrees, speed_ratio)
	var grip_limit := lerpf(corner_budget * 0.85, max_lateral_acceleration * surface_friction / 1.05 * 1.6, handbrake)
	var stable_angle := atan(wheelbase * grip_limit / maxf(drive_speed * drive_speed, 1.0))
	steering_angle = -steering_input * minf(deg_to_rad(angle_limit), stable_angle)
	var target_yaw := drive_speed / wheelbase * tan(steering_angle)
	var slip := absf(velocity.dot(global_basis.x)) / maxf(absf(drive_speed), 4.0)
	target_yaw /= 1.0 + slip * 2.0 * (1.0 - handbrake)
	_yaw_rate = lerpf(_yaw_rate, target_yaw, 1.0 - exp(-yaw_response * delta))
	# Rotation fades with motion, including the final moments of a handbrake stop.
	_yaw_rate = clampf(_yaw_rate, -absf(drive_speed) / wheelbase, absf(drive_speed) / wheelbase)
	global_basis = Basis(_ground_normal, _yaw_rate * delta) * global_basis


func _update_visuals(delta: float) -> void:
	$ContactShadow.visible = contact_shadow_enabled and is_on_floor()
	front_left.rotation.y = steering_angle
	front_right.rotation.y = steering_angle
	for index in wheels.size():
		var wheel := wheels[index]
		wheel.rotate_object_local(Vector3.UP, -drive_speed / wheel_radius * delta)
		var pivot := wheel.get_parent() as Node3D
		var resting_y := _wheel_offsets[index].y
		var target_y := resting_y
		if is_on_floor() and index < _contacts.size() and not _contacts[index].is_empty():
			target_y = clampf(to_local(_contacts[index].position).y + wheel_radius, resting_y - suspension_travel, resting_y + suspension_travel)
		pivot.position.y = lerpf(pivot.position.y, target_y, 1.0 - exp(-terrain_response * delta))
	if simulation_handling:
		var weight := 1.0 - exp(-7.0 * delta)
		$Visuals/Body.rotation.z = lerpf($Visuals/Body.rotation.z, clampf(tires.lateral_acceleration * 0.009, -0.09, 0.09), weight)
		$Visuals/Body.rotation.x = lerpf($Visuals/Body.rotation.x, clampf(-tires.longitudinal_acceleration * 0.006, -0.06, 0.06), weight)
		return
	var weight := 1.0 - exp(-6.0 * delta)
	$Visuals/Body.rotation.z = lerpf($Visuals/Body.rotation.z, clampf(_lateral_acceleration * 0.007, -0.075, 0.075), weight)
	$Visuals/Body.rotation.x = lerpf($Visuals/Body.rotation.x, clampf(-_longitudinal_acceleration * 0.005, -0.055, 0.055), weight)


func get_speed_kmh() -> float:
	return velocity.slide(_ground_normal).length() * 3.6 if is_on_floor() else Vector2(velocity.x, velocity.z).length() * 3.6


func suppress_reset_until_release() -> void:
	# Menu cancel shares a button with reset; discard that press until neutral.
	_reset_input_suppressed = true


func reset_car() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	drive_speed = 0.0
	lateral_speed = 0.0
	steering_input = 0.0
	steering_angle = 0.0
	_yaw_rate = 0.0
	_longitudinal_acceleration = 0.0
	_lateral_acceleration = 0.0
	_reverse_wait = 0.0
	_pedal_direction = 0.0
	_ground_normal = Vector3.UP
	tires.reset()
	surface_name = "asfalto"
	surface_friction = 1.05
	_contacts.clear()
	for index in wheels.size():
		wheels[index].get_parent().position = _wheel_offsets[index]
	$Visuals/Body.rotation = Vector3.ZERO
	visuals.rotation = Vector3.ZERO
	front_left.rotation.y = 0.0
	front_right.rotation.y = 0.0
	_update_lamps()
	car_reset.emit()


func _setup_lamps() -> void:
	var body := $Visuals/Body as MeshInstance3D
	for surface in body.mesh.get_surface_count():
		var material := body.mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null and material.resource_name in ["Hatch1000_tail_lamp", "Hatch1000_reverse_lamp", "Hatch1000_headlight_glass"]:
			# Per-car overrides keep the player's brake lights out of parked vehicles.
			var lamp: StandardMaterial3D = material.duplicate()
			body.set_surface_override_material(surface, lamp)
			if material.resource_name == "Hatch1000_tail_lamp":
				_tail_lamps.append(lamp)
			elif material.resource_name == "Hatch1000_reverse_lamp":
				_reverse_lamps.append(lamp)
			else:
				lamp.emission_enabled = true
				lamp.emission = Color(1, 0.94, 0.78)
				_head_lamps.append(lamp)
	_update_lamps()


func _update_lamps() -> void:
	var braking_now := Input.get_action_strength("brake") > 0.05 and drive_speed >= -0.2
	braking_now = braking_now or Input.get_action_strength("accelerate") > 0.05 and drive_speed < -0.2
	for material in _tail_lamps:
		material.emission_energy_multiplier = 2.8 if braking_now else (0.3 if headlights_on else 0.12)
	for material in _head_lamps:
		material.emission_energy_multiplier = 1.7 if headlights_on else 0.0
	for node in [$Visuals/Body/HeadlightLeft, $Visuals/Body/HeadlightRight]:
		node.visible = headlights_on
	for material in _reverse_lamps:
		material.emission_energy_multiplier = 1.4 if drive_speed < -0.2 else 0.0
