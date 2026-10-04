extends Node3D

@export var distance: float = 7.0
@export var height: float = 3.2
@export var target_height: float = 0.8
@export var follow_speed: float = 6.0
@export var base_fov: float = 70.0
@export var speed_fov: float = 6.0

@onready var target: PlayerCar = $"../PlayerCar"
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	arm.add_excluded_object(target.get_rid())
	target.car_reset.connect(snap_to_target)
	snap_to_target()


func _physics_process(delta: float) -> void:
	global_position = target.global_position + Vector3.UP * target_height
	var weight := 1.0 - exp(-follow_speed * delta)
	rotation.y = lerp_angle(rotation.y, target.get_heading(), weight)
	var speed_ratio := clampf(target.get_speed_kmh() / (target.forward_speed * 3.6), 0.0, 1.0)
	_update_arm(speed_ratio)
	camera.fov = lerpf(camera.fov, base_fov + speed_fov * speed_ratio, weight)


func _update_arm(speed_ratio: float) -> void:
	var horizontal_distance := distance + speed_ratio
	var vertical_distance := height - target_height
	arm.spring_length = Vector2(horizontal_distance, vertical_distance).length()
	arm.rotation.x = -atan2(vertical_distance, horizontal_distance)
	# Switch views directly so looking behind never sweeps the camera through the car.
	arm.rotation.y = PI if Input.is_action_pressed("camera_back") else 0.0


func snap_to_target() -> void:
	global_position = target.global_position + Vector3.UP * target_height
	rotation.y = target.get_heading()
	_update_arm(0.0)
	camera.position = Vector3(0.0, 0.0, arm.spring_length)
	camera.fov = base_fov
