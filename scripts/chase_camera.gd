extends Node3D

var hood_view := false
var look_offset := Vector2.ZERO
var _look_idle := 0.0

@export var distance: float = 7.0
@export var height: float = 3.2
@export var target_height: float = 0.8
@export var follow_speed: float = 6.0
@export var base_fov: float = 70.0
@export var speed_fov: float = 6.0
@export var mouse_sensitivity: float = 0.003
@export var stick_look_speed: float = 2.4
@export var look_return_delay: float = 1.2
@export var look_return_speed: float = 2.2

@onready var target: PlayerCar = $"../PlayerCar"
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	arm.add_excluded_object(target.get_rid())
	target.car_reset.connect(snap_to_target)
	get_window().focus_entered.connect(_capture_mouse)
	get_window().focus_exited.connect(_release_mouse)
	snap_to_target()
	_capture_mouse()


func _exit_tree() -> void:
	_release_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_release_mouse()
	elif what == NOTIFICATION_UNPAUSED and is_node_ready():
		_capture_mouse()


func _capture_mouse() -> void:
	if is_inside_tree() and not get_tree().paused and (get_window().has_focus() or DisplayServer.get_name() == "headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Physical pixels keep sensitivity stable between graphics resolutions.
		if event.screen_relative.length_squared() > 0.25:
			_add_look(-event.screen_relative * mouse_sensitivity)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_capture_mouse()


func _add_look(motion: Vector2) -> void:
	look_offset.x = wrapf(look_offset.x + motion.x, -PI, PI)
	look_offset.y = clampf(look_offset.y + motion.y, -0.55, 0.24)
	_look_idle = look_return_delay


func _update_look(delta: float) -> void:
	var stick := Vector2.ZERO
	if get_window().has_focus() or DisplayServer.get_name() == "headless":
		stick = Input.get_vector("camera_look_left", "camera_look_right", "camera_look_up", "camera_look_down", 0.18)
	if Input.is_action_just_pressed("camera_center"):
		_look_idle = 0.0
	elif stick.length_squared() > 0.0:
		_add_look(-stick * stick_look_speed * delta)
		return
	# Hold briefly after the last input, then ease back to automatic following.
	var return_delta := maxf(delta - _look_idle, 0.0)
	_look_idle = maxf(_look_idle - delta, 0.0)
	if return_delta > 0.0:
		look_offset *= exp(-look_return_speed * return_delta)
		if look_offset.length_squared() < 0.000001:
			look_offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_update_look(delta)
	if Input.is_action_just_pressed("camera_view"):
		hood_view = not hood_view
		look_offset = Vector2.ZERO
		_look_idle = 0.0
	if hood_view:
		global_transform = target.global_transform
		global_position = target.to_global(Vector3(0, 0.75, -0.85))
		arm.spring_length = 0.0
		arm.rotation = Vector3(look_offset.y, PI if Input.is_action_pressed("camera_back") else look_offset.x, 0)
		camera.position = Vector3.ZERO
		camera.fov = base_fov
		return
	rotation.x = 0.0
	rotation.z = 0.0
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
	arm.rotation.x = -atan2(vertical_distance, horizontal_distance) + look_offset.y
	# Rear view remains a direct switch; the orbit resumes when released.
	arm.rotation.y = PI if Input.is_action_pressed("camera_back") else look_offset.x


func snap_to_target() -> void:
	hood_view = false
	look_offset = Vector2.ZERO
	_look_idle = 0.0
	rotation.x = 0.0
	rotation.z = 0.0
	global_position = target.global_position + Vector3.UP * target_height
	rotation.y = target.get_heading()
	_update_arm(0.0)
	camera.position = Vector3(0.0, 0.0, arm.spring_length)
	camera.fov = base_fov
