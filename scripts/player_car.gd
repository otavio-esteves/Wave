class_name PlayerCar
extends CharacterBody3D

signal car_reset
signal impact(strength: float)
signal body_impact(strength: float, point: Vector3, bodywork: bool)

const Gearbox = preload("res://scripts/vehicle/arcade_gearbox.gd")
const TireDynamics = preload("res://scripts/vehicle/tire_dynamics.gd")
const ArcadeDrift = preload("res://scripts/vehicle/arcade_drift.gd")
const RoadChassis = preload("res://scripts/vehicle/road_chassis.gd")
const RoadContacts = preload("res://scripts/vehicle/road_contacts.gd")
const ROAD_COLLISION = preload("res://assets/models/hatch_1000/road_collision.tres")
const ROAD_GRAVITY := 9.81
@export var simulation_handling := false
@export var road_car_tuning := false
var gearbox := Gearbox.new()
var axle_grip := Vector2(1.05, 1.05)
var wheel_loads := RoadChassis.STATIC_LOADS
var _road: RoadChassis
var _road_contacts: RoadContacts
var tires := TireDynamics.new()
var _drift := ArcadeDrift.new()
var drift_amount: float:
	get: return _road_slide if _road != null else _drift.amount
var surface_name := "asfalto"
var surface_friction := 1.05
var terrain_surface: Callable
var road_support: StaticBody3D
var road_wetness := 0.0
var surface_water := 0.0
var impact_strength := 0.0
var scrape_strength := 0.0
var scrape_point := Vector3.ZERO
var scrape_bodywork := false
var scrape_speed := 0.0
var curb_impulse := 0.0
var _last_wheel_travel := Vector4.ZERO
var _last_wheel_support := Vector4.ZERO
var _impact_cooldown := 0.0
var _ride := Vector3.ZERO
var _ride_velocity := Vector3.ZERO
var _base_body_height := 0.0
var _road_brake_pressure := 0.0
var _road_throttle := 0.0
var _road_slide := 0.0

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
@export var progressive_steering := false

@export_group("Terreno e suspensão")
@export var gravity: float = 20.0
@export var max_step_height: float = 0.35
@export var terrain_response: float = 14.0
@export var wheel_radius: float = 0.31
@export var suspension_travel: float = 0.16

var _wheel_offsets: Array[Vector3] = []
var _ground_normal := Vector3.UP
var _rolling_scale := 1.0
var _contacts: Array[Dictionary] = []
var _ground_query := PhysicsRayQueryParameters3D.new()
var _step_impact := KinematicCollision3D.new()
var _step_landing := KinematicCollision3D.new()
var _pedal_direction := 0.0
var _throttle := 0.0
var _brake := 0.0
var _steer := 0.0
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
var landing_impulse := 0.0
var _tail_lamps: Array[StandardMaterial3D] = []
var _reverse_lamps: Array[StandardMaterial3D] = []
var _head_lamps: Array[StandardMaterial3D] = []
var _headlight_energy := Vector2.ONE
var _headlight_beam := 1.0
var headlights_on := true
var _lamp_state := -1

@onready var visuals: Node3D = $Visuals
@onready var _body: MeshInstance3D = $Visuals/Body
@onready var _steering_wheel: MeshInstance3D = _body.get_node_or_null("SteeringWheel")
@onready var _headlight_left: SpotLight3D = $Visuals/Body/HeadlightLeft
@onready var _headlight_right: SpotLight3D = $Visuals/Body/HeadlightRight
@onready var front_left: Node3D = $Visuals/FrontLeft
@onready var front_right: Node3D = $Visuals/FrontRight
@onready var wheels: Array[Node3D] = [
	$Visuals/FrontLeft/Wheel, $Visuals/FrontRight/Wheel,
	$Visuals/RearLeft/Wheel, $Visuals/RearRight/Wheel,
]


func _ready() -> void:
	_setup_lamps()
	_base_body_height = _body.position.y
	if road_car_tuning and not simulation_handling:
		_road = RoadChassis.new()
		_road_contacts = RoadContacts.new()
		_road.configure(wheelbase, front_right.position.x - front_left.position.x, max_lateral_acceleration)
		$Collision.shape = ROAD_COLLISION
		_body.set_instance_shader_parameter("road_finish", true)
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
	if reset_input_requested() or global_position.y < -4.0:
		reset_car()
		return

	# Wheel support is sampled once per tick, independently of tire integration.
	# Swept body movement still detects thin barriers at any speed.
	impact_strength = 0.0
	scrape_strength = 0.0
	scrape_speed = 0.0
	curb_impulse = 0.0
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	_throttle = Input.get_action_strength("accelerate")
	_brake = Input.get_action_strength("brake")
	_steer = Input.get_axis("steer_left", "steer_right")
	var handbrake := Input.get_action_strength("handbrake")
	if _road != null:
		_road_contacts.begin_tick(delta)
		var speed := velocity.dot(-global_basis.z)
		_advance_road_pedals(speed, delta)
		var backwards := speed < -0.4 or (absf(speed) <= 0.4 and _road_throttle < 0.0)
		gearbox.step(speed, wheel_radius, absf(_road_throttle), backwards, delta)
	var supported := is_on_floor()
	var previous_velocity := velocity
	if supported:
		_sample_ground(delta)
	else:
		_contacts.clear()
		if _road != null:
			_road.release(delta)
			wheel_loads = Vector4.ZERO
			_last_wheel_support = Vector4.ZERO
	var steps := clampi(ceili(velocity.length() * delta / 0.65), 1, 4)
	if simulation_handling:
		steps = maxi(steps, 2)
	for step in steps:
		_simulate_step(delta / steps, handbrake)
	landing_impulse = 0.0
	var grounded := is_on_floor()
	if grounded and not supported:
		var onset := 1.9 if _road != null else 2.8
		landing_impulse = smoothstep(onset, 7.8 if _road != null else 8.0, -previous_velocity.y)
	var acceleration_world := (velocity - previous_velocity) / delta if grounded and supported else Vector3.ZERO
	_longitudinal_acceleration = acceleration_world.dot(-global_basis.z)
	_lateral_acceleration = acceleration_world.dot(global_basis.x)
	if _road != null:
		var forward_speed_magnitude := absf(drive_speed)
		var slip_ratio := absf(lateral_speed) / maxf(forward_speed_magnitude, 5.0)
		var slide := smoothstep(0.07, 0.34, slip_ratio) * smoothstep(4.0, 9.0, forward_speed_magnitude) if grounded else 0.0
		_road_slide = lerpf(_road_slide, slide, 1.0 - exp(-11.0 * delta))
	_update_visuals(delta)
	_update_lamps()
	if _road_contacts != null:
		var bump := _road_contacts.impact
		if bump != null:
			impact.emit(impact_strength)
			body_impact.emit(impact_strength, bump.position, bump.bodywork)
	elif impact_strength > 0.0 and _impact_cooldown <= 0.0:
		_impact_cooldown = 0.24
		impact.emit(impact_strength)


func _simulate_step(delta: float, handbrake: float) -> void:
	drive_speed = velocity.dot(-global_basis.z)
	if is_on_floor():
		_align_to_ground(delta)
		drive_speed = velocity.dot(-global_basis.z)
		if simulation_handling:
			_simulate_tires(delta, handbrake)
		elif _road != null:
			_simulate_road_chassis(delta, handbrake)
		else:
			var slip := atan2(velocity.dot(global_basis.x), maxf(drive_speed, 0.1))
			_drift.step(drive_speed, slip, _steer, _throttle, _brake, handbrake, delta)
			var before_motor := drive_speed
			# Gravity acts along the road; braking and rolling resistance oppose it.
			var road_forward := (-global_basis.z).slide(_ground_normal).normalized()
			var slope_change := Vector3.DOWN.dot(road_forward) * _grade_gravity() * delta
			drive_speed += slope_change
			_update_motor(delta, handbrake)
			var motor_change := drive_speed - before_motor
			var total_grip := max_lateral_acceleration * surface_friction / 1.05
			var corner_budget := _lateral_budget(total_grip, motor_change / delta)
			_update_steering(delta, handbrake, corner_budget)
			var forward := (-global_basis.z).slide(_ground_normal).normalized()
			var right := forward.cross(_ground_normal).normalized()
			# A turn redirects the tire forces, not the existing momentum.
			drive_speed = velocity.dot(forward) + motor_change
			lateral_speed = velocity.dot(right)
			var slide_blend := maxf(handbrake, drift_amount)
			var grip := lerpf(lateral_grip, handbrake_grip, slide_blend)
			var recovered := absf(lateral_speed) * (1.0 - exp(-grip * delta))
			# Acceleration/braking consume some of the available cornering grip.
			var tire_force := minf(corner_budget, lerpf(total_grip, 5.5, drift_amount))
			tire_force = minf(tire_force, lerpf(total_grip, 3.5, handbrake))
			# Locked tires must also stop a car travelling sideways. This remains
			# available when longitudinal braking uses the entire grip budget.
			tire_force = maxf(tire_force, minf(total_grip, 3.5) * handbrake)
			lateral_speed = move_toward(lateral_speed, 0.0, minf(recovered, tire_force * delta))
			# Sliding dissipates energy rather than behaving like a frictionless turn.
			var scrub := slide_scrub * lerpf(1.0, 0.3, drift_amount)
			drive_speed = move_toward(drive_speed, 0.0, minf(absf(lateral_speed) * scrub, total_grip * 0.3) * delta)
			velocity = forward * drive_speed + right * lateral_speed - Vector3.UP * 0.1
		_try_step(velocity * delta)
	else:
		_drift.reset()
		# Keep launch momentum, including the vertical component of a climb.
		velocity.y -= _grade_gravity() * delta
		if simulation_handling:
			global_basis = Basis(Vector3.UP, tires.yaw_rate * delta) * global_basis
		elif _road != null:
			_yaw_rate = -_road.yaw_rate
			global_basis = Basis(Vector3.UP, _yaw_rate * delta) * global_basis
	# move_and_slide uses the engine's whole physics delta internally.
	# Scale its velocity for this substep, then recover collision-adjusted speed.
	var motion_scale := delta / get_physics_process_delta_time()
	var was_grounded := is_on_floor()
	var incoming := velocity
	velocity *= motion_scale
	move_and_slide()
	velocity /= motion_scale
	if _road != null:
		_resolve_road_contacts(incoming)
	else:
		for index in get_slide_collision_count():
			var normal := get_slide_collision(index).get_normal()
			if absf(normal.y) < 0.48:
				impact_strength = maxf(impact_strength, smoothstep(2.8, 17.0, -incoming.dot(normal)))
	# A tangent velocity can point upward in world space on an incline. Keep
	# support over small crests instead of treating that as a deliberate jump.
	if was_grounded and not is_on_floor():
		var road_speed := _road != null and absf(drive_speed) < 14.0
		if road_speed or velocity.dot(_ground_normal) <= 0.15:
			apply_floor_snap()
	if is_on_floor():
		# Floor snapping clears vertical velocity. Restore only its tangent part,
		# preserving the horizontal response from walls and other collisions.
		velocity.y = -(velocity.x * _ground_normal.x + velocity.z * _ground_normal.z) / _ground_normal.y
		_align_to_ground(delta)
	drive_speed = velocity.dot(-global_basis.z)
	lateral_speed = velocity.dot(global_basis.x)


func _resolve_road_contacts(incoming: Vector3) -> void:
	_road_contacts.resolve(self, incoming, _yaw_rate, road_support)
	velocity = _road_contacts.motion
	_yaw_rate = _road_contacts.yaw_rate
	_road.yaw_rate = -_yaw_rate
	var bump := _road_contacts.impact
	if bump != null:
		impact_strength = bump.strength()
	var grind := _road_contacts.scrape
	if grind != null:
		scrape_strength = _road_contacts.scrape_strength
		scrape_point = grind.position
		scrape_speed = grind.sliding
		scrape_bodywork = grind.bodywork


func _grade_gravity() -> float:
	return ROAD_GRAVITY if road_car_tuning and not simulation_handling else gravity


func _simulate_road_chassis(delta: float, handbrake: float) -> void:
	var forward := (-global_basis.z).slide(_ground_normal).normalized()
	var right := forward.cross(_ground_normal).normalized()
	var motion := Vector2(velocity.dot(forward), velocity.dot(right))
	# The scene origin is halfway between the axles. The tire forces and
	# yaw moments act about the center of mass, slightly ahead of it.
	var center_of_mass_offset := wheelbase * (RoadChassis.FRONT_WEIGHT - 0.5)
	motion.y += _road.yaw_rate * center_of_mass_offset
	var rolling := smoothstep(0.45, 3.0, motion.length())
	var slope := Vector2(-forward.y, -right.y * rolling) * ROAD_GRAVITY
	var requested := _road_longitudinal_request(motion.x, slope.x, delta)
	var base_angle := _advance_steering(delta, handbrake)
	var lateral_limit := _road.steering_capacity()
	# The rack stays precise near center and gives access to its full travel in
	# tight bends. Tire forces decide the result when steering and braking overlap.
	var input_magnitude := absf(steering_input)
	var city_reserve := 0.62 + 0.31 * input_magnitude * input_magnitude * input_magnitude
	var steering_reserve := lerpf(city_reserve, 0.90, smoothstep(11.5, 23.0, absf(motion.x)))
	var guided_limit := lateral_limit * lerpf(steering_reserve, 1.08, handbrake)
	var slip_budget := atan(wheelbase * guided_limit / maxf(motion.x * motion.x, 1.0))
	steering_angle = -steering_input * minf(base_angle, slip_budget)
	var acceleration_on_road := _road.step(motion, -steering_angle, requested, _road_brake_pressure,
		_road_brake_pressure == 0.0 and requested * _road_throttle > 0.0, handbrake, handbrake_deceleration, slope, delta)
	motion += acceleration_on_road * delta
	motion.y -= _road.yaw_rate * center_of_mass_offset
	velocity = forward * motion.x + right * motion.y - Vector3.UP * 0.10
	_yaw_rate = -_road.yaw_rate
	global_basis = Basis(_ground_normal, _yaw_rate * delta) * global_basis


func _advance_road_pedals(speed: float, delta: float) -> void:
	var pedal := _throttle - _brake
	var both_pedals := _brake > 0.02 and _throttle > 0.02
	var moving := absf(speed) > 0.17
	var direction_change := not both_pedals and moving and pedal * speed < 0.0
	# This pedal doubles as reverse only after a stop and a short hold.
	if direction_change:
		_reverse_wait = reverse_delay
	elif moving or is_zero_approx(pedal) or both_pedals:
		_reverse_wait = 0.0
	var waiting := _reverse_wait > 0.0 and not direction_change
	if waiting:
		_reverse_wait = maxf(0.0, _reverse_wait - delta)
	var braking_now := direction_change or waiting or both_pedals
	var requested_brake := absf(pedal) if direction_change else 0.0
	if waiting or both_pedals:
		requested_brake = 1.0 if waiting else _brake
	var requested_throttle := 0.0 if braking_now else pedal
	_road_brake_pressure = move_toward(_road_brake_pressure, requested_brake, delta * (16.0 if braking_now else 22.0))
	_road_throttle = move_toward(_road_throttle, requested_throttle, delta * (8.5 if requested_throttle != 0.0 else 16.0))


func _road_longitudinal_request(speed: float, grade: float, delta: float) -> float:
	var speed_with_grade := speed + grade * delta
	if _road_brake_pressure > 0.0:
		var service_force := minf(braking, surface_friction * ROAD_GRAVITY) * _road_brake_pressure
		return (move_toward(speed_with_grade, 0.0, service_force * delta) - speed_with_grade) / delta
	if absf(_road_throttle) > 0.001:
		var direction := signf(_road_throttle)
		var directed_speed := direction * speed_with_grade
		var limit := forward_speed if direction > 0.0 else reverse_speed
		var next_speed := directed_speed + direction * _powered_acceleration(speed_with_grade, _road_throttle) * delta
		var bounded := clampf(next_speed, minf(0.0, directed_speed), maxf(limit, directed_speed))
		return direction * (bounded - directed_speed) / delta
	var drag := _rolling_drag(speed) + gearbox.engine_drag(speed)
	return (move_toward(speed_with_grade, 0.0, drag * delta) - speed_with_grade) / delta


func _lateral_budget(capacity: float, longitudinal: float) -> float:
	return sqrt(maxf(0.0, capacity * capacity - longitudinal * longitudinal))


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
	if absf(longitudinal) < 0.5 and (handbrake > 0.0 or _brake > 0.0 and _throttle == 0.0 and _reverse_wait > 0.0):
		requested -= slope_gravity.dot(forward)
	var pedal := _throttle - _brake
	var braking_now := pedal * longitudinal < 0.0 or (_throttle > 0.0 and _brake > 0.0)
	steering_input = move_toward(steering_input, _steer, steering_response * delta)
	var angle := lerpf(low_speed_steering_degrees, high_speed_steering_degrees, clampf(absf(longitudinal) / forward_speed, 0.0, 1.0))
	steering_angle = -steering_input * deg_to_rad(angle)
	var acceleration_local := tires.step(longitudinal, sideways, steering_angle, requested, braking_now, handbrake, surface_friction, delta)
	velocity += (forward * acceleration_local.x + left * acceleration_local.y + slope_gravity) * delta
	velocity = velocity.slide(_ground_normal) - Vector3.UP * 0.1
	global_basis = Basis(_ground_normal, tires.yaw_rate * delta) * global_basis

func get_heading() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func get_turn_rate() -> float:
	return tires.yaw_rate if simulation_handling else _yaw_rate


func get_longitudinal_acceleration() -> float:
	return _longitudinal_acceleration


func get_lateral_acceleration() -> float:
	return _lateral_acceleration


func tire_contact(index: int) -> Dictionary:
	if not is_on_floor() or index < 0 or index >= _contacts.size():
		return {}
	if _road != null and wheel_loads[index] <= 0.0:
		return {}
	return _contacts[index]


func tire_scrub(index: int) -> float:
	return _road.wheel_slip[index] if _road != null and is_on_floor() else 0.0


func suspension_load() -> float:
	return _road.normal_load_scale if _road != null and is_on_floor() else 0.0


func _sample_ground(delta: float) -> void:
	_contacts.clear()
	var heading := Basis(Vector3.UP, get_heading())
	var ground_limit := cos(floor_max_angle)
	var space := get_world_3d().direct_space_state
	for offset in _wheel_offsets:
		var center := global_position + heading * Vector3(offset.x, 0, offset.z)
		_ground_query.from = center + Vector3.UP * 0.65
		_ground_query.to = center - Vector3.UP * 0.95
		var hit := space.intersect_ray(_ground_query)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP) < ground_limit:
			hit = {}
		_contacts.append(hit)
	_ground_normal = get_floor_normal()
	var count := 0
	var grip_by_wheel := Vector4.ZERO
	var contact_by_wheel := Vector4.ZERO
	var travel_by_wheel := Vector4.ONE * -suspension_travel
	if not _contacts.is_empty():
		surface_friction = 0.0
		var rolling := 0.0
		var water := 0.0
		var surfaces: Dictionary = {}
		var friction_by_axle := Vector2.ZERO
		var contacts_by_axle := Vector2i.ZERO
		for index in _contacts.size():
			var hit := _contacts[index]
			if hit.is_empty():
				continue
			var ground: Object = hit.collider
			var surface: Dictionary = terrain_surface.call(hit.position, ground) if terrain_surface.is_valid() else {}
			var kind: String = surface.get("surface", ground.get_meta("surface", "asfalto"))
			hit["surface"] = kind
			surfaces[kind] = int(surfaces.get(kind, 0)) + 1
			var loss := 0.21 if kind == "asfalto" else (0.27 if kind in ["calçada", "paralelepípedo"] else 0.12)
			var wet_contact := road_wetness * float(surface.get("wet_scale", 1.0))
			hit["wetness"] = wet_contact
			water += wet_contact
			var water_grip := 1.0 - loss * wet_contact
			var contact_grip := float(surface.get("friction", ground.get_meta("friction", 1.05))) * water_grip
			grip_by_wheel[index] = contact_grip
			if _road != null:
				var distance: Vector3 = hit.position - global_position
				var travel := distance.dot(global_basis.y) + wheel_radius - _wheel_offsets[index].y
				travel_by_wheel[index] = clampf(travel, -suspension_travel, suspension_travel)
				contact_by_wheel[index] = float(travel > -suspension_travel * 1.4)
			surface_friction += contact_grip
			var axle := index / 2
			friction_by_axle[axle] += contact_grip
			contacts_by_axle[axle] += 1
			rolling += float(surface.get("rolling", 1.0))
			count += 1
		if count > 0:
			surface_friction /= count
			surface_water = water / count
			_rolling_scale = rolling / count
			for axle in 2:
				axle_grip[axle] = friction_by_axle[axle] / contacts_by_axle[axle] if contacts_by_axle[axle] > 0 else surface_friction
			var most := 0
			for kind: String in surfaces:
				if surfaces[kind] > most:
					most = surfaces[kind]
					surface_name = kind
		else:
			surface_name = "asfalto"
			surface_water = road_wetness
			surface_friction = 1.05 * (1.0 - 0.21 * road_wetness)
			axle_grip = Vector2.ONE * surface_friction
			_rolling_scale = 1.0
	if count == _wheel_offsets.size():
		var front: Vector3 = (_contacts[0].position + _contacts[1].position) * 0.5
		var rear: Vector3 = (_contacts[2].position + _contacts[3].position) * 0.5
		var left: Vector3 = (_contacts[0].position + _contacts[2].position) * 0.5
		var right: Vector3 = (_contacts[1].position + _contacts[3].position) * 0.5
		var fitted := (right - left).cross(front - rear).normalized()
		if fitted.dot(Vector3.UP) >= ground_limit:
			_ground_normal = fitted
	if _road != null:
		var grade := (-global_basis.z).slide(_ground_normal).normalized().y
		var compression := (travel_by_wheel - _last_wheel_travel) * contact_by_wheel * _last_wheel_support
		var rise := maxf(maxf(compression.x, compression.y), maxf(compression.z, compression.w))
		curb_impulse = smoothstep(0.05, 0.18, rise) * smoothstep(2.0, 11.0, velocity.length())
		_last_wheel_travel = travel_by_wheel
		_last_wheel_support = contact_by_wheel
		_road.sample(grip_by_wheel, travel_by_wheel, contact_by_wheel,
			Vector2(_longitudinal_acceleration, _lateral_acceleration), grade, _ground_normal.y, drive_speed, delta)
		wheel_loads = _road.wheel_loads
		if wheel_loads != Vector4.ZERO:
			axle_grip = _road.axle_grip
			surface_friction = lerpf(surface_friction, grip_by_wheel.dot(wheel_loads), 0.82)
		# Small crests keep the traversable floor margin. At a fast crest that
		# unloads the body, snapping reaches only the compressed tire length.
		var launch := smoothstep(14.0, 28.0, absf(drive_speed)) * (1.0 - smoothstep(0.45, 0.83, _road.normal_load_scale))
		floor_snap_length = lerpf(0.45, 0.15, launch)


func _align_to_ground(delta: float) -> void:
	var forward := Basis(Vector3.UP, get_heading()) * Vector3.FORWARD
	# Keep the heading fixed while pitching the car onto the road. Projecting
	# the whole vector would also steer it on grades that slope across the lane.
	forward.y = -forward.dot(_ground_normal) / _ground_normal.y
	forward = forward.normalized()
	var right := forward.cross(_ground_normal).normalized()
	var target_basis := Basis(right, _ground_normal, -forward)
	global_basis = global_basis.orthonormalized().slerp(target_basis, 1.0 - exp(-terrain_response * delta)).orthonormalized()


func _try_step(motion: Vector3) -> void:
	var horizontal := Vector3(motion.x, 0, motion.z)
	if horizontal.length_squared() < 0.000001:
		return
	if not test_move(global_transform, horizontal, _step_impact):
		return
	# Let the slide solver follow ramps. Raising the body on a walkable
	# face can bounce the Gol off the pavement near the end of a grade.
	var maximum_rise := max_step_height
	if _road != null:
		if _step_impact.get_normal().y >= cos(floor_max_angle):
			return
		if road_support == null or _step_impact.get_collider() != road_support:
			if RoadContacts.is_bodywork(_step_impact, 0):
				return
			maximum_rise = minf(maximum_rise, 0.23)
	# Confirm that the entire body clears the lip and lands on support.
	var lift := Vector3.UP * max_step_height
	if test_move(global_transform, lift):
		return
	var raised := global_transform
	raised.origin += lift
	# Probe past the lip even while crawling: a very short per-frame motion can
	# otherwise land back on the low road and never discover the curb's top.
	var minimum_probe := wheel_radius * (0.24 if _road != null else 0.65)
	var probe := horizontal.normalized() * maxf(horizontal.length(), minimum_probe)
	if test_move(raised, probe):
		return
	raised.origin += probe
	if not test_move(raised, -Vector3.UP * (max_step_height + floor_snap_length), _step_landing):
		return
	if _step_landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	var rise := max_step_height + _step_landing.get_travel().y
	if rise <= safe_margin or rise > maximum_rise + safe_margin:
		return
	global_position += Vector3.UP * (rise + safe_margin)
	if _road != null:
		curb_impulse = maxf(curb_impulse, smoothstep(0.022, 0.19, rise) * smoothstep(0.9, 10.0, velocity.length()))
	# Lift only by the obstacle height, then let normal movement settle the car.


func _update_motor(delta: float, handbrake: float) -> void:
	var throttle := _throttle
	var brake_input := _brake
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
		drive_speed = move_toward(drive_speed, 0.0, _rolling_drag(drive_speed) * delta)
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

	var previous_speed := drive_speed
	drive_speed += _powered_acceleration(drive_speed, pedal) * delta
	# The governor never brakes an already faster car coasting downhill.
	if pedal > 0.0:
		drive_speed = minf(drive_speed, maxf(forward_speed, previous_speed))
	else:
		drive_speed = maxf(drive_speed, minf(-reverse_speed, previous_speed))


func _rolling_drag(speed: float) -> float:
	return rolling_resistance * _rolling_scale + air_resistance * speed * speed


func _powered_acceleration(speed: float, pedal: float) -> float:
	var direction := signf(pedal)
	var limit := forward_speed if pedal > 0.0 else reverse_speed
	# Constant torque at launch, then approximately constant power. Rolling and
	# aerodynamic losses act under power too, instead of vanishing on throttle.
	var torque_factor := minf(1.0, 36.0 / maxf(absf(speed), 1.0))
	var driven_grip := surface_friction
	if _road != null:
		driven_grip = axle_grip.x
		torque_factor *= gearbox.torque
	var motor := minf(acceleration * torque_factor * absf(pedal), driven_grip * 9.81)
	if pedal < 0.0:
		motor *= 0.65
	if speed * direction >= limit:
		motor = 0.0
	var change := motor * direction - _rolling_drag(speed) * signf(speed)
	if not simulation_handling and change * direction > 0.0:
		# Scale the net powered acceleration, preserving the engine/drag balance
		# at top speed and the existing coasting and braking response.
		# Uphill load is retained within available torque so slower acceleration
		# still allows the car to climb the authored roads.
		var road_forward := (-global_basis.z).slide(_ground_normal).normalized()
		var uphill_load := maxf(0.0, -Vector3.DOWN.dot(road_forward) * _grade_gravity() * direction)
		var net_acceleration := absf(change)
		change = direction * lerpf(minf(uphill_load, net_acceleration), net_acceleration, arcade_acceleration_scale)
	return change


func _advance_steering(delta: float, handbrake: float) -> float:
	var requested := _steer
	var demand := requested
	if progressive_steering:
		var precision := smoothstep(7.0, 29.0, absf(drive_speed)) * (1.0 - maxf(handbrake, drift_amount))
		demand = signf(requested) * lerpf(absf(requested), pow(absf(requested), 1.46), precision)
	var response := steering_response / (1.0 + absf(drive_speed) / 45.0)
	# Opposite input catches a slide promptly without making highway steering twitchy.
	if requested * steering_input < 0.0:
		response *= 1.65
	elif road_car_tuning and absf(requested) < absf(steering_input):
		response *= 1.28
	steering_input = move_toward(steering_input, demand, response * delta)
	var speed_ratio := clampf(absf(drive_speed) / forward_speed, 0.0, 1.0)
	return deg_to_rad(lerpf(low_speed_steering_degrees, high_speed_steering_degrees, speed_ratio))


func _update_steering(delta: float, handbrake: float, corner_budget: float) -> void:
	var angle_limit := _advance_steering(delta, handbrake)
	var grip_limit := lerpf(corner_budget * 0.85, max_lateral_acceleration * surface_friction / 1.05 * 1.6, handbrake)
	var stable_angle := atan(wheelbase * grip_limit / maxf(drive_speed * drive_speed, 1.0))
	steering_angle = -steering_input * minf(angle_limit, stable_angle)
	var target_yaw := drive_speed / wheelbase * tan(steering_angle)
	var slip := absf(velocity.dot(global_basis.x)) / maxf(absf(drive_speed), 4.0)
	target_yaw /= 1.0 + slip * 2.0 * (1.0 - handbrake)
	if drift_amount > 0.0:
		var signed_slip := atan2(velocity.dot(global_basis.x), maxf(drive_speed, 0.1))
		var desired := _drift.desired_slip(_throttle, _steer)
		# Balance the sideways tire force, then approach a bounded slip angle.
		# This steers the body; momentum still changes only through tire forces.
		var drift_force := minf(corner_budget, 5.5)
		drift_force = lerpf(drift_force, minf(drift_force, 3.5), handbrake)
		var drift_yaw := _drift.direction * drift_force / maxf(absf(drive_speed), 8.0) + (desired - signed_slip) * 2.4
		var yaw_limit := max_lateral_acceleration * surface_friction / 1.05 * 1.6 / maxf(absf(drive_speed), 8.0)
		target_yaw = lerpf(target_yaw, clampf(drift_yaw, -yaw_limit, yaw_limit), drift_amount)
	_yaw_rate = lerpf(_yaw_rate, target_yaw, 1.0 - exp(-yaw_response * delta))
	# Rotation fades with motion, including the final moments of a handbrake stop.
	_yaw_rate = clampf(_yaw_rate, -absf(drive_speed) / wheelbase, absf(drive_speed) / wheelbase)
	global_basis = Basis(_ground_normal, _yaw_rate * delta) * global_basis


func _update_visuals(delta: float) -> void:
	$ContactShadow.visible = contact_shadow_enabled and is_on_floor()
	front_left.rotation.y = steering_angle
	front_right.rotation.y = steering_angle
	if _road != null:
		var angles := _road.ackermann(-steering_angle)
		front_left.rotation.y = -angles.x
		front_right.rotation.y = -angles.y
	var visual_response := 1.0 - exp(-terrain_response * delta)
	for index in wheels.size():
		var wheel := wheels[index]
		var roll_speed := _road.wheel_spin[index] if _road != null else drive_speed
		wheel.rotate_object_local(Vector3.UP, -roll_speed / wheel_radius * delta)
		var pivot := wheel.get_parent() as Node3D
		var resting_y := _wheel_offsets[index].y
		var target_y := resting_y
		if _road != null:
			target_y += _road.wheel_travel[index]
		elif is_on_floor() and index < _contacts.size() and not _contacts[index].is_empty():
			target_y = clampf(to_local(_contacts[index].position).y + wheel_radius, resting_y - suspension_travel, resting_y + suspension_travel)
		pivot.position.y = lerpf(pivot.position.y, target_y, visual_response)
	if _steering_wheel != null:
		_steering_wheel.basis = Basis(Vector3.BACK.rotated(Vector3.RIGHT, -0.29), steering_angle * 4.5)
	var brake_dive := clampf(_longitudinal_acceleration * 0.0090, -0.084, 0.062)
	var corner_roll := clampf(_lateral_acceleration * 0.0092, -0.098, 0.098)
	if _road != null:
		var travel := _road.wheel_travel
		var wheel_pitch := (travel.x + travel.y - travel.z - travel.w) * 0.5 / wheelbase
		var track := front_right.position.x - front_left.position.x
		var wheel_roll := (travel.y + travel.w - travel.x - travel.z) * 0.5 / track
		var ride_height := travel.dot(Vector4.ONE) * 0.10 - landing_impulse * 0.16
		var demand := Vector3(clampf(brake_dive + wheel_pitch * 0.54, -0.116, 0.102),
			clampf(corner_roll + wheel_roll * 0.46, -0.12, 0.12), clampf(ride_height, -0.11, 0.075))
		# Separate frequencies for pitch, roll and vertical suspension travel.
		_ride_velocity += ((demand - _ride) * Vector3(176.0, 120.0, 216.0) - _ride_velocity * Vector3(18.8, 15.6, 19.0)) * delta
		_ride += _ride_velocity * delta
		_body.rotation.x = _ride.x
		_body.rotation.z = _ride.y
		_body.position.y = _base_body_height + _ride.z
	else:
		var weight := 1.0 - exp(-9.0 * delta)
		_body.rotation.x = lerpf(_body.rotation.x, brake_dive, weight)
		_body.rotation.z = lerpf(_body.rotation.z, corner_roll, weight)


func get_speed_kmh() -> float:
	return velocity.slide(_ground_normal).length() * 3.6 if is_on_floor() else Vector2(velocity.x, velocity.z).length() * 3.6


func suppress_reset_until_release() -> void:
	# Menu cancel shares a button with reset; discard that press until neutral.
	_reset_input_suppressed = true


func reset_input_requested() -> bool:
	# Streaming also polls reset while vehicle simulation is suspended. Both
	# paths must consume menu cancellation consistently, including its release.
	var just_pressed := Input.is_action_just_pressed("reset_car")
	if _reset_input_suppressed:
		if not Input.is_action_pressed("reset_car") and not just_pressed:
			_reset_input_suppressed = false
		return false
	return just_pressed


func reset_car() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	drive_speed = 0.0
	lateral_speed = 0.0
	steering_input = 0.0
	steering_angle = 0.0
	_yaw_rate = 0.0
	_drift.reset()
	_longitudinal_acceleration = 0.0
	_lateral_acceleration = 0.0
	landing_impulse = 0.0
	impact_strength = 0.0
	scrape_strength = 0.0
	scrape_speed = 0.0
	curb_impulse = 0.0
	_last_wheel_travel = Vector4.ZERO
	_last_wheel_support = Vector4.ZERO
	_impact_cooldown = 0.0
	_reverse_wait = 0.0
	_road_brake_pressure = 0.0
	_road_throttle = 0.0
	_road_slide = 0.0
	_pedal_direction = 0.0
	_ground_normal = Vector3.UP
	tires.reset()
	gearbox.reset()
	if _road != null:
		_road.reset()
		_road_contacts.reset()
		floor_snap_length = 0.45
	axle_grip = Vector2.ONE * 1.05
	wheel_loads = RoadChassis.STATIC_LOADS
	surface_water = road_wetness
	surface_name = "asfalto"
	surface_friction = 1.05
	_rolling_scale = 1.0
	_contacts.clear()
	for index in wheels.size():
		wheels[index].get_parent().position = _wheel_offsets[index]
	_ride = Vector3.ZERO
	_ride_velocity = Vector3.ZERO
	_body.position.y = _base_body_height
	_body.rotation = Vector3.ZERO
	visuals.rotation = Vector3.ZERO
	front_left.rotation.y = 0.0
	front_right.rotation.y = 0.0
	_update_lamps()
	car_reset.emit()


func _setup_lamps() -> void:
	_headlight_energy = Vector2(_headlight_left.light_energy, _headlight_right.light_energy)
	for surface in _body.mesh.get_surface_count():
		var material := _body.mesh.surface_get_material(surface) as StandardMaterial3D
		if material != null and material.resource_name in ["Hatch1000_tail_lamp", "Hatch1000_reverse_lamp", "Hatch1000_headlight_glass"]:
			# Per-car overrides keep the player's brake lights out of parked vehicles.
			var lamp: StandardMaterial3D = material.duplicate()
			_body.set_surface_override_material(surface, lamp)
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
	var reversing := drive_speed < -0.2
	var braking_now := Input.get_action_strength("brake") > 0.05 and drive_speed >= -0.2
	braking_now = braking_now or Input.get_action_strength("accelerate") > 0.05 and reversing
	var state := int(headlights_on) | (int(braking_now) << 1) | (int(reversing) << 2)
	if state == _lamp_state:
		return
	_lamp_state = state
	for material in _tail_lamps:
		material.emission_energy_multiplier = 2.8 if braking_now else (0.3 if headlights_on else 0.12)
	for material in _head_lamps:
		material.emission_energy_multiplier = 0.65 if headlights_on else 0.0
	_update_headlight_beams()
	for material in _reverse_lamps:
		material.emission_energy_multiplier = 1.4 if reversing else 0.0


func set_headlight_beam(value: float) -> void:
	if value != _headlight_beam:
		_headlight_beam = value
		_update_headlight_beams()


func _update_headlight_beams() -> void:
	var enabled := headlights_on and _headlight_beam > 0.01
	_headlight_left.visible = enabled
	_headlight_right.visible = enabled
	if enabled:
		_headlight_left.light_energy = _headlight_energy.x * _headlight_beam
		_headlight_right.light_energy = _headlight_energy.y * _headlight_beam
