extends Node3D

enum View { CHASE, HOOD, COCKPIT, BUMPER, HIGH_CHASE }

const CHASE_SUBJECT_HEIGHT := 0.42
const CHASE_SCREEN_HEIGHT := 0.718
const REAR_BUMPER := Vector3(0.0, -0.208, 1.786)
const COCKPIT_FOV := 77.0
const PLAYER_MESH_LAYER := 1 << 19
const REAR_BODY_CLEARANCE := 1.96

var view := View.CHASE
var hood_view: bool:
	get: return view == View.HOOD
	set(value): view = View.HOOD if value else View.CHASE
var _impact := 0.0
var _impact_phase := 0.0
var _eye_offset := Vector2.ZERO
var _body: Node3D
var _label: Label
var look_offset := Vector2.ZERO
var _look_idle := 0.0
var _anchor_y := 0.0
var _speed := 0.0
var _focus := Vector2.ZERO
var _travel_offset := Vector3.ZERO
var _landing := 0.0
var _load := 0.0
var terrain_preview: Callable
var _arm_distance := -1.0
var _player_in_frame := true
var _preview_grade := 0.0
var _preview_yaw := 0.0
var _preview_tick := 0.0
var _preview_sample := Vector3.ZERO
var _rear_view := false
var _previous_view := View.CHASE
var _camera_cut := false
var _automatic_look := 1.0
var _chase_jolt := 0.0
var _follow_angular_velocity := 0.0
var _offset_velocity := Vector3.ZERO
var _anchor_velocity := 0.0
var _head_angles := Vector2.ZERO
var _fov_wide := 0.0
var _view_fov := 0.0
var _drift_follow := 0.0

@export var extended_views := false
@export var distance: float = 7.0
@export var height: float = 2.8
@export var target_height: float = 0.8
@export var follow_speed: float = 6.0
@export var base_fov: float = 70.0
@export var speed_fov: float = 14.0
@export var mouse_sensitivity: float = 0.003
@export var stick_look_speed: float = 2.4
@export var look_return_delay: float = 1.2
@export var look_return_speed: float = 2.2
@export var corner_look_time := 0.24
@export var horizon_lift := 0.055
@export var cockpit_eye := Vector3(-0.335, 0.787, 0.305)

@onready var target: PlayerCar = $"../PlayerCar"
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	arm.add_excluded_object(target.get_rid())
	target.car_reset.connect(snap_to_target)
	if extended_views:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		target.impact.connect(_on_impact)
		_body = target.get_node("Visuals/Body")
		# Keep the car and camera at the same render time. Each transform is
		# finalized in physics, after the spring arm has checked for collision.
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		for mesh: MeshInstance3D in target.get_node("Visuals").find_children("*", "MeshInstance3D", true, false):
			mesh.layers = PLAYER_MESH_LAYER
		_make_view_label()
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
	var switch_view := Input.is_action_just_pressed("camera_view")
	if switch_view:
		view = ((view + 1) % (5 if extended_views else 2)) as View
	if view != _previous_view:
		look_offset = Vector2.ZERO
		_look_idle = 0.0
		_focus = Vector2.ZERO
		_travel_offset = Vector3.ZERO
		_eye_offset = Vector2.ZERO
		_head_angles = Vector2.ZERO
		_arm_distance = -1.0
		_anchor_y = target.global_position.y
		_anchor_velocity = 0.0
		_follow_angular_velocity = 0.0
		_offset_velocity = Vector3.ZERO
		_fov_wide = 0.0
		_previous_view = view
		_camera_cut = true
		if extended_views and switch_view:
			_show_view_label()
	var weight := 1.0 - exp(-follow_speed * delta)
	_speed = lerpf(_speed, target.get_speed_kmh(), 1.0 - exp(-5.4 * delta))
	var speed_ratio := smoothstep(27.0, 133.0, _speed) if extended_views else smoothstep(3.0, 160.0, _speed)
	_impact *= exp(-12.0 * delta)
	_impact_phase += delta * 36.0
	var jolt := sin(_impact_phase) * _impact
	var rear_view := Input.is_action_pressed("camera_back")
	if rear_view != _rear_view:
		_rear_view = rear_view
		_camera_cut = true
		_arm_distance = -1.0
	camera.near = 0.035 if view == View.COCKPIT else 0.1
	_automatic_look = 0.0 if _rear_view else 1.0 - smoothstep(0.035, 0.30, look_offset.length())
	var rolling_forward := smoothstep(2.0, 9.0, target.drive_speed)
	var chassis_grade := asin(clampf(-target.global_basis.z.y, -1.0, 1.0))
	if extended_views:
		_update_road_preview(delta, speed_ratio, rolling_forward, chassis_grade)
	var chasing := view == View.CHASE or view == View.HIGH_CHASE
	if arm.is_physics_processing_internal() != chasing:
		arm.set_physics_process_internal(chasing)
	if not chasing:
		_close_view(delta, speed_ratio, jolt, chassis_grade)
		return
	rotation.x = 0.0
	rotation.z = 0.0
	var heading := target.get_heading()
	var manual_look := look_offset.length_squared() > 0.0001 or _rear_view
	var look_weight := _automatic_look if extended_views else float(not manual_look)
	var vehicle_position := target.global_position
	var focus_yaw := 0.0
	var anticipation := Vector3.ZERO
	var travel_direction := Vector3.ZERO
	if look_weight > 0.0 and rolling_forward > 0.0:
		travel_direction = Vector3(target.velocity.x, 0.0, target.velocity.z).normalized()
		var slip_heading := atan2(-travel_direction.x, -travel_direction.z)
		var slip_angle := angle_difference(heading, slip_heading)
		if extended_views:
			heading += clampf(slip_angle, -0.65, 0.65) * look_weight * rolling_forward * (0.17 + 0.52 * target.drift_amount)
		else:
			heading += slip_angle * look_weight * rolling_forward * (0.14 + 0.49 * target.drift_amount)
		var turn_rate := target.get_turn_rate()
		if extended_views:
			# The current steering can read the beginning of a bend before the
			# chassis has swung around. Reduce this during a deliberate slide.
			var steer_rate := target.drive_speed * tan(target.steering_angle) / target.wheelbase
			turn_rate = lerpf(turn_rate, steer_rate, 0.20 * (1.0 - target.drift_amount))
		else:
			anticipation = travel_direction * speed_ratio * 1.15
		focus_yaw = clampf(turn_rate * corner_look_time, -0.15, 0.15) * rolling_forward
	var focus_pitch := horizon_lift + clampf(chassis_grade * 0.57, -0.115, 0.135)
	if extended_views:
		focus_yaw = clampf(focus_yaw + _preview_yaw * 0.42, -0.145, 0.145)
		focus_pitch = clampf(lerpf(chassis_grade, _preview_grade, 0.68) * 0.44, -0.082, 0.092)
		var corner := clampf(2.1 * focus_yaw, -0.27, 0.27)
		# The mount stays within the swept vehicle envelope. Its sideways
		# displacement opens the view on the outside of the current bend.
		var outside := Basis(Vector3.UP, heading).x * corner
		var along := travel_direction * speed_ratio * 0.35
		anticipation = (outside + along) * look_weight * rolling_forward * (1.0 - target.drift_amount * 0.61)
		_chase_jolt = jolt
	_focus = _focus.lerp(Vector2(focus_yaw, focus_pitch) * look_weight, 1.0 - exp(-8.0 * delta))
	if extended_views:
		var vertical_lead := clampf(target.velocity.y * 0.04, -0.12, 0.12) if target.is_on_floor() else 0.0
		_follow_mount(anticipation, vehicle_position.y + vertical_lead, delta)
		var near_heading := rotation.y + angle_difference(rotation.y, heading)
		if _camera_cut:
			rotation.y = heading
			_follow_angular_velocity = 0.0
		else:
			var follow_rate := lerpf(18.0, 11.5, rolling_forward)
			var orbit := _spring(rotation.y, _follow_angular_velocity, near_heading, follow_rate, delta)
			rotation.y = orbit.x
			_follow_angular_velocity = orbit.y
	else:
		_travel_offset = _travel_offset.lerp(anticipation, 1.0 - exp(-5.0 * delta))
		_anchor_y = lerpf(_anchor_y, vehicle_position.y, 1.0 - exp(-10.0 * delta))
		rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-lerpf(follow_speed * 1.7, follow_speed, rolling_forward) * delta))
	_anchor_y = clampf(_anchor_y, vehicle_position.y - 0.30, vehicle_position.y + 0.30)
	_landing = maxf(_landing * exp(-10.0 * delta), target.landing_impulse * 0.16)
	var acceleration_shift := clampf(target.get_longitudinal_acceleration() * 0.055, -0.44, 0.33)
	_load = lerpf(_load, acceleration_shift, weight)
	_drift_follow = lerpf(_drift_follow, target.drift_amount * rolling_forward, 1.0 - exp(-4.5 * delta)) if extended_views else 0.0
	global_position = Vector3(vehicle_position.x, _anchor_y + target_height - _landing, vehicle_position.z) + _travel_offset
	_update_arm(speed_ratio)
	if not extended_views:
		camera.rotation = Vector3.ZERO if _rear_view else Vector3(_focus.y + 0.031 * jolt, _focus.x, 0.024 * jolt)
		camera.fov = lerpf(camera.fov, base_fov + speed_fov * speed_ratio, weight)
		_camera_cut = false
	else:
		var lens := base_fov + speed_fov * speed_ratio + _drift_follow * 1.35
		_view_fov = lens if _camera_cut else lerpf(_view_fov, lens, weight)


static func _spring(position: float, velocity: float, target_position: float, rate: float, delta: float) -> Vector2:
	var error := position - target_position
	var momentum := velocity + rate * error
	var decay := exp(-rate * delta)
	return Vector2(target_position + (error + momentum * delta) * decay, (velocity - momentum * rate * delta) * decay)


func _follow_mount(goal: Vector3, height_goal: float, delta: float) -> void:
	var x := _spring(_travel_offset.x, _offset_velocity.x, goal.x, 10.0, delta)
	var z := _spring(_travel_offset.z, _offset_velocity.z, goal.z, 10.0, delta)
	var y := _spring(_anchor_y, _anchor_velocity, height_goal, 16.0, delta)
	_travel_offset = Vector3(x.x, 0.0, z.x)
	_offset_velocity = Vector3(x.y, 0.0, z.y)
	_anchor_y = y.x
	_anchor_velocity = y.y


func _update_road_preview(delta: float, speed_ratio: float, rolling_forward: float, grade: float) -> void:
	if terrain_preview.is_valid() and rolling_forward > 0.0 and _automatic_look > 0.0 and target.is_on_floor():
		_preview_tick -= delta
		if _preview_tick <= 0.0001:
			_preview_tick = lerpf(1.0 / 12.0, 1.0 / 22.0, speed_ratio)
			_preview_sample = _read_road_preview()
	else:
		_preview_tick = 0.0
		_preview_sample = Vector3.ZERO
	var confidence := _preview_sample.y * rolling_forward * (1.0 - target.drift_amount)
	var slope := lerpf(grade, atan(_preview_sample.x), confidence)
	_preview_grade = lerpf(_preview_grade, slope, 1.0 - exp(-4.6 * delta))
	var yaw := clampf(_preview_sample.z, -0.24, 0.24) * confidence * (1.0 - absf(target.steering_input) * 0.42)
	_preview_yaw = lerpf(_preview_yaw, yaw, 1.0 - exp(-6.0 * delta))


func _read_road_preview() -> Vector3:
	var position := Vector2(target.global_position.x, target.global_position.z)
	var chassis := Vector2(-target.global_basis.z.x, -target.global_basis.z.z).normalized()
	var travel := Vector2(target.velocity.x, target.velocity.z).normalized()
	var direction := chassis.lerp(travel, 0.22 * (1.0 - target.drift_amount)).normalized()
	var look_ahead := clampf(target.drive_speed * 1.08 + 5.0, 8.0, 31.0)
	return terrain_preview.call(position, direction, look_ahead)


func finish_camera_step(delta: float) -> void:
	if view == View.CHASE or view == View.HIGH_CHASE:
		# Enter obstructions immediately and ease out after a pillar or roof.
		var safe := clampf(arm.get_hit_length(), 0.06, arm.spring_length)
		var compression_cut := _arm_distance >= 0.0 and safe < _arm_distance - 0.09
		if _arm_distance < 0.0 or safe < _arm_distance:
			_arm_distance = safe
		else:
			_arm_distance = lerpf(_arm_distance, safe, 1.0 - exp(-4.4 * delta))
		camera.position = Vector3(0.0, 0.0, _arm_distance)
		var compression := 1.0 - smoothstep(1.17, arm.spring_length * 0.77, _arm_distance)
		var close_fov := compression * 5.75
		_fov_wide = lerpf(_fov_wide, close_fov, 1.0 - exp(-(16.0 if close_fov > _fov_wide else 5.0) * delta))
		camera.fov = _view_fov + _fov_wide
		_frame_chase_subject()
		# Suppress the cabin shell when the camera can no longer clear the car.
		# Extra clearance on release avoids blinking meshes at the threshold.
		var clearance := REAR_BODY_CLEARANCE if _player_in_frame else REAR_BODY_CLEARANCE + 0.28
		_set_player_in_frame(_arm_distance >= clearance)
		if compression_cut:
			camera.reset_physics_interpolation()
	else:
		_set_player_in_frame(not _rear_view)
	if _camera_cut:
		reset_physics_interpolation()
		_camera_cut = false


func _set_player_in_frame(visible_from_camera: bool) -> void:
	if _player_in_frame != visible_from_camera:
		_player_in_frame = visible_from_camera
		if visible_from_camera:
			camera.cull_mask |= PLAYER_MESH_LAYER
		else:
			camera.cull_mask &= ~PLAYER_MESH_LAYER


func is_cockpit_view() -> bool:
	return view == View.COCKPIT and not _rear_view


func _frame_chase_subject() -> void:
	if _rear_view:
		camera.rotation = Vector3.ZERO
		return
	var subject := arm.to_local(target.global_position + Vector3.UP * CHASE_SUBJECT_HEIGHT)
	var depth := maxf(camera.position.z - subject.z, 0.25)
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var vertical_extent := tan(deg_to_rad(camera.fov * 0.5)) / maxf(aspect, 0.01)
	# Maintain the car's vertical screen position as the collision arm moves.
	# The target is slightly higher in the exploration view to show near ground.
	var screen_height := CHASE_SCREEN_HEIGHT if view == View.CHASE else 0.68
	var subject_angle := atan(vertical_extent * (2.0 * screen_height - 1.0))
	var composition := atan(subject.y / depth) + subject_angle
	var pitch := clampf(composition, -0.13, 0.23) * _automatic_look
	var yaw := clampf(-atan2(subject.x, depth), -0.12, 0.12) * _automatic_look
	var glance := clampf(_focus.x + yaw, -0.153, 0.153)
	var minimum_arm := arm.spring_length * 0.76
	var open_view := smoothstep(REAR_BODY_CLEARANCE, minimum_arm, _arm_distance)
	var uphill_limit := atan(vertical_extent * 0.53) - subject_angle
	var grade_framing := clampf(_focus.y, -0.062, uphill_limit)
	pitch += grade_framing * open_view + 0.016 * _chase_jolt
	var full_arm := smoothstep(arm.spring_length * 0.81, arm.spring_length * 0.97, _arm_distance) * _automatic_look
	if full_arm > 0.0:
		# Follow the visible bumper down the slope while retaining the look into the bend.
		var bumper := arm.to_local(_body.to_global(REAR_BUMPER)) - camera.position
		bumper = bumper.rotated(Vector3.UP, -glance)
		var bottom_pitch := atan2(bumper.y, maxf(-bumper.z, 0.25)) + atan(vertical_extent * 0.92)
		pitch = lerpf(pitch, minf(pitch, bottom_pitch), full_arm)
	camera.rotation = Vector3(pitch, glance, 0.011 * _chase_jolt)


func _update_arm(speed_ratio: float) -> void:
	var horizontal_distance := distance + (2.65 if view == View.HIGH_CHASE else 0.0) + speed_ratio * 0.58 + _load + _drift_follow * 0.53
	var vertical_distance := height + (2.1 if view == View.HIGH_CHASE else 0.0) - target_height - speed_ratio * 0.29 + _drift_follow * 0.19
	arm.spring_length = Vector2(horizontal_distance, vertical_distance).length()
	arm.rotation.x = -atan2(vertical_distance, horizontal_distance) + look_offset.y
	# Rear view remains a direct switch; the orbit resumes when released.
	arm.rotation.y = PI if _rear_view else look_offset.x


func snap_to_target() -> void:
	view = View.CHASE
	_previous_view = View.CHASE
	_camera_cut = extended_views
	_impact = 0.0
	_eye_offset = Vector2.ZERO
	_head_angles = Vector2.ZERO
	camera.near = 0.1
	if extended_views:
		_label.hide()
	look_offset = Vector2.ZERO
	_look_idle = 0.0
	_travel_offset = Vector3.ZERO
	_focus = Vector2.ZERO if extended_views else Vector2(0.0, horizon_lift)
	_speed = 0.0
	_load = 0.0
	_landing = 0.0
	_chase_jolt = 0.0
	_rear_view = false
	_automatic_look = 1.0
	_preview_grade = 0.0
	_preview_yaw = 0.0
	_preview_tick = 0.0
	_preview_sample = Vector3.ZERO
	_arm_distance = -1.0
	_anchor_y = target.global_position.y
	_anchor_velocity = 0.0
	_offset_velocity = Vector3.ZERO
	_follow_angular_velocity = 0.0
	_fov_wide = 0.0
	_view_fov = base_fov
	_drift_follow = 0.0
	rotation.x = 0.0
	rotation.z = 0.0
	global_position = target.global_position + Vector3.UP * target_height
	rotation.y = target.get_heading()
	_update_arm(0.0)
	camera.position = Vector3(0.0, 0.0, arm.spring_length)
	camera.fov = base_fov
	camera.rotation = Vector3(_focus.y, 0.0, 0.0)
	if extended_views:
		_set_player_in_frame(true)
		_frame_chase_subject()
		target.reset_physics_interpolation()
		reset_physics_interpolation()


func _close_view(delta: float, speed_ratio: float, jolt: float, chassis_grade: float) -> void:
	var eye := Vector3(0, 0.75, -0.85)
	var fov := base_fov + minf(speed_fov * 0.30, 4.3) * speed_ratio
	var driver_pose := target.global_transform
	var seat := view == View.COCKPIT
	var rear_check := extended_views and _rear_view
	if rear_check:
		var rear_eye := driver_pose * Vector3(0.0, 0.88, 1.48)
		global_transform = Transform3D(Basis(Vector3.UP, target.get_heading()), rear_eye)
		fov = 76.0
	elif seat:
		var shift := Vector2(target.get_longitudinal_acceleration() * 0.0034, target.get_lateral_acceleration() * -0.0039)
		_eye_offset = _eye_offset.lerp(shift.limit_length(0.038), 1.0 - exp(-8.0 * delta))
		eye = cockpit_eye + Vector3(_eye_offset.y, jolt * 0.008, _eye_offset.x)
		var posture := _body.global_basis.orthonormalized().get_euler()
		var head_pitch := chassis_grade + (posture.x - chassis_grade) * 0.38
		var horizon := Vector2(head_pitch, posture.z * 0.28)
		_head_angles = horizon if _camera_cut else _head_angles.lerp(horizon, 1.0 - exp(-12.0 * delta))
		var head_basis := Basis.from_euler(Vector3(_head_angles.x, posture.y, _head_angles.y))
		global_transform = Transform3D(head_basis, _body.to_global(eye))
		fov = COCKPIT_FOV + speed_ratio * 1.8
	else:
		if view == View.BUMPER:
			eye = Vector3(0.0, 0.07, -2.01)
			fov = 77.0 + speed_ratio * 8.0
		var angles := driver_pose.basis.get_euler()
		angles.z *= 0.35
		global_transform = Transform3D(Basis.from_euler(angles), driver_pose * eye)
	arm.spring_length = 0.0
	var pitch := -0.091 if seat else (0.075 if view == View.BUMPER else 0.0)
	if seat:
		pitch += clampf((_preview_grade - chassis_grade) * 0.48, -0.065, 0.065) * _automatic_look
	var apex := clampf(target.get_turn_rate() * 0.105 + _preview_yaw * 0.30, -0.088, 0.088) * _automatic_look * (1.0 - target.drift_amount)
	var yaw := clampf(look_offset.x + apex, -1.7, 1.7) if seat else look_offset.x
	arm.rotation = Vector3(0.0, PI, 0.0) if rear_check else Vector3(pitch + look_offset.y + jolt * 0.014, PI if _rear_view else yaw, 0.0)
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = fov if _camera_cut and extended_views else lerpf(camera.fov, fov, 1.0 - exp(-follow_speed * delta))
	if not extended_views:
		_camera_cut = false


func _on_impact(strength: float) -> void:
	_impact = maxf(_impact, strength)
	_impact_phase = 0.0


func _make_view_label() -> void:
	_label = Label.new()
	var overlay := get_parent().get_node("HUD/Overlay") as Control
	var timer := Timer.new()
	timer.name = "ViewCaptionTimer"
	timer.one_shot = true
	timer.wait_time = 1.6
	add_child(timer)
	timer.timeout.connect(_label.hide)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color("17292b"))
	_label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -145
	_label.offset_right = 145
	_label.offset_top = -56
	_label.offset_bottom = -25


func _show_view_label() -> void:
	_label.text = ["Câmera traseira", "Capô", "Cabine", "Para-choque", "Câmera elevada"][view]
	_label.show()
	get_node("ViewCaptionTimer").start()
