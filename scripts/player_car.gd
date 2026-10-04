class_name PlayerCar
extends CharacterBody3D

signal car_reset

@export_group("Motor e freios")
@export var forward_speed: float = 22.0
@export var reverse_speed: float = 8.0
@export var acceleration: float = 12.0
@export var braking: float = 20.0
@export var rolling_resistance: float = 1.6
@export var air_resistance: float = 0.015
@export var reverse_delay: float = 0.25

@export_group("Direção e aderência")
@export var wheelbase: float = 2.26
@export var low_speed_steering_degrees: float = 32.0
@export var high_speed_steering_degrees: float = 10.0
@export var steering_response: float = 4.0
@export var lateral_grip: float = 12.0
@export var handbrake_grip: float = 1.8
@export var handbrake_deceleration: float = 8.0

@export_group("Terreno e suspensão")
@export var gravity: float = 20.0
@export var max_step_height: float = 0.20
@export var terrain_response: float = 14.0
@export var wheel_radius: float = 0.31
@export var suspension_travel: float = 0.16

var _wheel_offsets: Array[Vector3] = []
var _ground_normal := Vector3.UP
var _contacts: Array[Dictionary] = []

var drive_speed: float = 0.0
var lateral_speed: float = 0.0
var steering_input: float = 0.0
var steering_angle: float = 0.0
var spawn_transform: Transform3D
var _reverse_wait: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var front_left: Node3D = $Visuals/FrontLeft
@onready var front_right: Node3D = $Visuals/FrontRight
@onready var wheels: Array[Node3D] = [
	$Visuals/FrontLeft/Wheel, $Visuals/FrontRight/Wheel,
	$Visuals/RearLeft/Wheel, $Visuals/RearRight/Wheel,
]


func _ready() -> void:
	spawn_transform = global_transform
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(40.0)
	for wheel in wheels:
		_wheel_offsets.append(wheel.get_parent().position)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_car") or global_position.y < -4.0:
		reset_car()
		return

	var handbrake := Input.get_action_strength("handbrake")
	drive_speed = velocity.dot(-global_basis.z)
	if is_on_floor():
		_sample_ground()
		_align_to_ground(delta)
		drive_speed = velocity.dot(-global_basis.z)
		var before_motor := drive_speed
		_update_motor(delta, handbrake)
		var motor_change := drive_speed - before_motor
		_update_steering(delta)
		var forward := (-global_basis.z).slide(_ground_normal).normalized()
		var right := forward.cross(_ground_normal).normalized()
		# A turn redirects the tire forces, not the existing momentum.
		drive_speed = velocity.dot(forward) + motor_change
		lateral_speed = velocity.dot(right)
		var grip := lerpf(lateral_grip, handbrake_grip, handbrake)
		lateral_speed *= exp(-grip * delta)
		velocity = forward * drive_speed + right * lateral_speed - _ground_normal * 0.1
		_try_step(velocity * delta)
	else:
		# Keep launch momentum, including the vertical component of a climb.
		velocity.y -= gravity * delta
	move_and_slide()
	if is_on_floor():
		_sample_ground()
		_align_to_ground(delta)
	drive_speed = velocity.dot(-global_basis.z)
	lateral_speed = velocity.dot(global_basis.x)
	_update_visuals(delta)


func get_heading() -> float:
	return atan2(global_basis.z.x, global_basis.z.z)


func _sample_ground() -> void:
	_contacts.clear()
	var heading := Basis(Vector3.UP, get_heading())
	for offset in _wheel_offsets:
		var center := global_position + heading * Vector3(offset.x, 0, offset.z)
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.65, center - Vector3.UP * 0.95)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.dot(Vector3.UP) < cos(floor_max_angle):
			hit = {}
		_contacts.append(hit)
	_ground_normal = get_floor_normal()
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
	var impact := KinematicCollision3D.new()
	if not test_move(global_transform, horizontal, impact):
		return
	if impact.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return
	var lift := Vector3.UP * max_step_height
	if test_move(global_transform, lift):
		return
	var raised := global_transform
	raised.origin += lift
	if test_move(raised, horizontal):
		return
	var landing := KinematicCollision3D.new()
	raised.origin += horizontal
	if not test_move(raised, -Vector3.UP * (max_step_height + floor_snap_length), landing):
		return
	if landing.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	global_position += lift
	# move_and_slide handles the remaining motion; snapping settles on the curb.


func _update_motor(delta: float, handbrake: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	if handbrake > 0.0:
		drive_speed = move_toward(drive_speed, 0.0, handbrake_deceleration * handbrake * delta)
		_reverse_wait = 0.0
		return
	if throttle > 0.0 and brake_input > 0.0:
		drive_speed = move_toward(drive_speed, 0.0, braking * brake_input * delta)
		_reverse_wait = 0.0
		return

	var pedal := throttle - brake_input
	if is_zero_approx(pedal):
		var drag := rolling_resistance + air_resistance * drive_speed * drive_speed
		drive_speed = move_toward(drive_speed, 0.0, drag * delta)
		_reverse_wait = 0.0
		return

	if pedal * drive_speed < 0.0:
		drive_speed = move_toward(drive_speed, 0.0, braking * absf(pedal) * delta)
		_reverse_wait = reverse_delay
		return
	if _reverse_wait > 0.0:
		_reverse_wait = maxf(0.0, _reverse_wait - delta)
		return

	var limit := forward_speed if pedal > 0.0 else reverse_speed
	var torque_factor := lerpf(1.0, 0.5, clampf(absf(drive_speed) / limit, 0.0, 1.0))
	# The pedal controls torque; easing it must not select a lower target speed.
	drive_speed = move_toward(drive_speed, limit * signf(pedal), acceleration * torque_factor * absf(pedal) * delta)


func _update_steering(delta: float) -> void:
	var requested := Input.get_axis("steer_left", "steer_right")
	steering_input = move_toward(steering_input, requested, steering_response * delta)
	var speed_ratio := clampf(absf(drive_speed) / forward_speed, 0.0, 1.0)
	var angle_limit := lerpf(low_speed_steering_degrees, high_speed_steering_degrees, speed_ratio)
	steering_angle = -steering_input * deg_to_rad(angle_limit)
	global_basis = Basis(_ground_normal, drive_speed / wheelbase * tan(steering_angle) * delta) * global_basis


func _update_visuals(delta: float) -> void:
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
	var lean := steering_input * clampf(absf(drive_speed) / forward_speed, 0.0, 1.0) * 0.04
	$Visuals/Body.rotation.z = lerpf($Visuals/Body.rotation.z, lean, 1.0 - exp(-8.0 * delta))


func get_speed_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6


func reset_car() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	drive_speed = 0.0
	lateral_speed = 0.0
	steering_input = 0.0
	steering_angle = 0.0
	_reverse_wait = 0.0
	_ground_normal = Vector3.UP
	_contacts.clear()
	for index in wheels.size():
		wheels[index].get_parent().position = _wheel_offsets[index]
	$Visuals/Body.rotation = Vector3.ZERO
	visuals.rotation = Vector3.ZERO
	front_left.rotation.y = 0.0
	front_right.rotation.y = 0.0
	car_reset.emit()
