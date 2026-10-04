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
@export var wheelbase: float = 2.5
@export var low_speed_steering_degrees: float = 32.0
@export var high_speed_steering_degrees: float = 10.0
@export var steering_response: float = 4.0
@export var lateral_grip: float = 12.0
@export var handbrake_grip: float = 1.8
@export var handbrake_deceleration: float = 8.0

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
	floor_snap_length = 0.4


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_car") or global_position.y < -4.0:
		reset_car()
		return

	var handbrake := Input.get_action_strength("handbrake")
	drive_speed = velocity.dot(-global_basis.z)
	if is_on_floor():
		_update_motor(delta, handbrake)
		_update_steering(delta)

	# Preserve sideways momentum after a turn, then let the tires recover grip.
	var forward := -global_basis.z
	var right := global_basis.x
	lateral_speed = velocity.dot(right)
	if is_on_floor():
		var grip := lerpf(lateral_grip, handbrake_grip, handbrake)
		lateral_speed *= exp(-grip * delta)
	var horizontal := forward * drive_speed + right * lateral_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()

	# Read back collision response instead of restoring pre-impact speed.
	drive_speed = velocity.dot(forward)
	lateral_speed = velocity.dot(right)
	_update_visuals(delta)


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
	rotation.y += drive_speed / wheelbase * tan(steering_angle) * delta


func _update_visuals(delta: float) -> void:
	front_left.rotation.y = steering_angle
	front_right.rotation.y = steering_angle
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, -drive_speed / 0.34 * delta)
	var lean := steering_input * clampf(absf(drive_speed) / forward_speed, 0.0, 1.0) * 0.04
	visuals.rotation.z = lerpf(visuals.rotation.z, lean, 1.0 - exp(-8.0 * delta))


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
	visuals.rotation = Vector3.ZERO
	front_left.rotation.y = 0.0
	front_right.rotation.y = 0.0
	car_reset.emit()
