extends RefCounted

# This model works in vehicle coordinates, with positive force to the right
# and positive yaw turning right. Loads are fractions of sprung weight, while
# force divided by mass is expressed in m/s².
const STATIC_LOADS := Vector4(0.30, 0.30, 0.20, 0.20)
const FRONT_WEIGHT := 0.60
const CG_HEIGHT := 0.49
const GRAVITY := 9.81
const DRY_GRIP := 1.05
const YAW_INERTIA_PER_KG := 1.49
const FRONT_BRAKE_BIAS := 0.70
const MAXIMUM_BUMP_SPEED := 2.1
const CORNERING_STIFFNESS := Vector2(7.6, 11.4)
const RELAXATION_LENGTH := Vector2(0.61, 0.68)

var wheel_loads := STATIC_LOADS
var wheel_travel := Vector4.ZERO
var wheel_slip := Vector4.ZERO
var wheel_usage := Vector4.ZERO
var wheel_spin := Vector4.ZERO
var axle_grip := Vector2.ONE * DRY_GRIP
var yaw_rate := 0.0
var normal_load_scale := 1.0

var _wheelbase := 2.26
var _track := 1.54
var _dry_accel := GRAVITY * DRY_GRIP
var _grip := Vector4.ONE * DRY_GRIP
var _supported := Vector4.ONE
var _response := Vector2.ZERO
var _last_grade := INF
var _lateral_forces := Vector4.ZERO


func configure(wheelbase: float, track: float, dry_accel: float) -> void:
	_wheelbase = wheelbase
	_track = track
	_dry_accel = minf(dry_accel, GRAVITY * DRY_GRIP)


func steering_capacity() -> float:
	return _dry_accel * axle_grip.x / DRY_GRIP * normal_load_scale


func reset() -> void:
	wheel_loads = STATIC_LOADS
	wheel_travel = Vector4.ZERO
	wheel_slip = Vector4.ZERO
	wheel_usage = Vector4.ZERO
	wheel_spin = Vector4.ZERO
	axle_grip = Vector2.ONE * DRY_GRIP
	yaw_rate = 0.0
	normal_load_scale = 1.0
	_grip = Vector4.ONE * DRY_GRIP
	_supported = Vector4.ONE
	_response = Vector2.ZERO
	_last_grade = INF
	_lateral_forces = Vector4.ZERO


func sample(grip: Vector4, travel: Vector4, contact: Vector4, measured_accel: Vector2,
		grade: float, upright: float, speed: float, delta: float) -> void:
	_grip = grip
	_supported = contact
	var weight := 1.0 - exp(-12.5 * delta)
	_response = _response.lerp(measured_accel.clamp(Vector2(-10.0, -13.0), Vector2(8.0, 13.0)), weight)
	var front := clampf(FRONT_WEIGHT - _response.x * CG_HEIGHT / (_wheelbase * GRAVITY), 0.42, 0.80)
	var left := clampf(0.5 + _response.y * CG_HEIGHT / (_track * GRAVITY), 0.24, 0.76)
	var transfer := Vector4(front * left, front * (1.0 - left), (1.0 - front) * left, (1.0 - front) * (1.0 - left))
	var previous_travel := wheel_travel
	wheel_travel = wheel_travel.lerp(travel, 1.0 - exp(-21.0 * delta))
	var wheel_speed := ((wheel_travel - previous_travel) / delta).clamp(Vector4.ONE * -MAXIMUM_BUMP_SPEED, Vector4.ONE * MAXIMUM_BUMP_SPEED)
	var diagonal_twist := (wheel_travel.x - wheel_travel.y - wheel_travel.z + wheel_travel.w) * 0.25
	var warp := Vector4(1.0, -1.0, -1.0, 1.0) * (diagonal_twist * 0.56)
	var support := (transfer + warp + wheel_speed * 0.015).maxf(0.025) * contact
	var total := support.dot(Vector4.ONE)
	if total > 0.001:
		wheel_loads = wheel_loads.lerp(support / total, weight)
		wheel_loads *= contact
		wheel_loads /= maxf(wheel_loads.dot(Vector4.ONE), 0.001)
	else:
		wheel_loads = Vector4.ZERO
	var front_load := wheel_loads.x + wheel_loads.y
	var rear_load := wheel_loads.z + wheel_loads.w
	axle_grip.x = (wheel_loads.x * grip.x + wheel_loads.y * grip.y) / front_load if front_load > 0.001 else 0.0
	axle_grip.y = (wheel_loads.z * grip.z + wheel_loads.w * grip.w) / rear_load if rear_load > 0.001 else 0.0
	var vertical_accel := speed * (grade - _last_grade) / delta if is_finite(_last_grade) else 0.0
	_last_grade = grade
	var grounded_scale := clampf(upright + vertical_accel / GRAVITY, 0.25, 1.57)
	normal_load_scale = lerpf(normal_load_scale, grounded_scale, 1.0 - exp(-9.0 * delta))


func release(delta: float) -> void:
	var weight := exp(-14.0 * delta)
	_lateral_forces *= weight
	wheel_spin *= exp(-0.66 * delta)
	wheel_usage = Vector4.ZERO
	wheel_slip = Vector4.ZERO
	_supported = Vector4.ZERO
	wheel_loads = Vector4.ZERO
	normal_load_scale = 0.0
	wheel_travel = wheel_travel.lerp(Vector4.ONE * -0.11, 1.0 - exp(-8.0 * delta))
	_last_grade = INF
	yaw_rate *= exp(-1.25 * delta)


func ackermann(steer: float) -> Vector2:
	if absf(steer) < 0.0001:
		return Vector2(steer, steer)
	var direction := signf(steer)
	var radius := _wheelbase / tan(absf(steer))
	return direction * Vector2(atan2(_wheelbase, radius + direction * _track * 0.5),
		atan2(_wheelbase, radius - direction * _track * 0.5))


func step(motion: Vector2, steering: float, request: float, brake: float, driving: bool,
		handbrake: float, handbrake_force: float, slope: Vector2, delta: float) -> Vector2:
	var angles := ackermann(steering)
	var net := Vector2.ZERO
	var moment := 0.0
	var front_share := 1.0 if driving else lerpf(FRONT_WEIGHT, FRONT_BRAKE_BIAS, brake)
	var speed := absf(motion.x)
	var scrub_speed := smoothstep(3.2, 13.5, motion.length())
	var spin_response := 1.0 - exp(-24.0 * delta)
	var rear_load := maxf(wheel_loads.z + wheel_loads.w, 0.001)
	var brake_bias := brake * 0.76
	var contact_scale := _dry_accel * normal_load_scale / DRY_GRIP
	for wheel in 4:
		var front := wheel < 2
		if _supported[wheel] <= 0.0:
			_lateral_forces[wheel] = 0.0
			wheel_slip[wheel] = 0.0
			wheel_usage[wheel] = 0.0
			continue
		var x := _track * (-0.5 if wheel % 2 == 0 else 0.5)
		var station := _wheelbase * (1.0 - FRONT_WEIGHT if front else -FRONT_WEIGHT)
		var rolling := Vector2.from_angle(angles[wheel]) if front else Vector2.RIGHT
		var across := rolling.orthogonal()
		var speed_at_wheel := motion + Vector2(-yaw_rate * x, yaw_rate * station)
		var roll_speed := speed_at_wheel.dot(rolling)
		var side_speed := speed_at_wheel.dot(across)
		var patch_angle := atan2(-side_speed, maxf(2.75, absf(roll_speed)))
		var patch_magnitude := absf(patch_angle)
		var load := wheel_loads[wheel]
		# An inside wheel remains less valuable than two evenly loaded tires.
		var load_efficiency := clampf(1.10 - 0.10 * load / STATIC_LOADS[wheel], 0.73, 1.10)
		var capacity := load * load_efficiency * _grip[wheel] * contact_scale
		var footprint := (front_share if front else 1.0 - front_share) * 0.5
		# Service braking requests a nominal slip. Equal pressure produces a
		# smaller contact force on a wheel supported by the slicker surface.
		var axle := 0 if front else 1
		var response := lerpf(1.0, _grip[wheel] / maxf(axle_grip[axle], 0.10), brake_bias) if brake_bias > 0.0 else 1.0
		var commanded := request * footprint * response
		var locked := handbrake if not front else 0.0
		var grip_progression := lerpf(0.63, 1.0, smoothstep(0.56, 1.04, _grip[wheel]))
		var target := capacity * (1.0 - locked) * tanh(CORNERING_STIFFNESS[axle] * grip_progression * patch_angle)
		var response_time := maxf(3.4, absf(roll_speed)) * delta / RELAXATION_LENGTH[axle]
		_lateral_forces[wheel] = lerpf(_lateral_forces[wheel], target, 1.0 - exp(-response_time))
		# Both requests share a contact patch. A tire at the combined limit gives
		# up some stopping power as cornering demand rises, and vice versa.
		var slide := smoothstep(0.19, 0.55, patch_magnitude)
		var available := capacity * lerpf(1.0, 0.84, slide)
		var demand := Vector2(clampf(commanded, -capacity * 1.20, capacity * 1.20), _lateral_forces[wheel])
		var force_size := demand.length()
		if force_size > available:
			demand *= available / force_size
			force_size = available
		var force := rolling * demand.x + across * demand.y
		if locked > 0.0:
			# A locked rear tire scrubs in its actual direction of travel. The
			# limited stopping impulse also lets the lever hold on an incline.
			var patch_motion := speed_at_wheel + slope * delta
			var hold := patch_motion * (-load / (rear_load * delta))
			var sliding_grip := lerpf(1.0, 0.74, smoothstep(0.4, 2.5, patch_motion.length()))
			var locked_force := hold.limit_length(minf(capacity * sliding_grip, handbrake_force * 0.5))
			force = force.lerp(locked_force, locked)
			force_size = force.length()
		net += force
		moment += station * force.y - x * force.x
		var scrub := smoothstep(0.068, 0.33, patch_magnitude)
		var straight_slip := smoothstep(capacity * 0.82, capacity * 1.32 + 0.001, absf(commanded))
		wheel_slip[wheel] = maxf(maxf(scrub, straight_slip * 0.64), locked) * scrub_speed
		wheel_usage[wheel] = force_size / maxf(capacity, 0.001)
		var skid := maxf(locked, straight_slip * 0.29 if brake > 0.0 else 0.0)
		var spinning := straight_slip * clampf(absf(roll_speed) * 0.22, 1.2, 4.0) * signf(request) if driving and front else 0.0
		wheel_spin[wheel] = lerpf(wheel_spin[wheel], roll_speed * (1.0 - skid) + spinning, spin_response)
	net += slope
	yaw_rate += (moment / YAW_INERTIA_PER_KG - yaw_rate * 0.48) * delta
	var parking := 1.0 - smoothstep(1.15, 5.80, speed)
	var rolling_yaw := motion.x / _wheelbase * tan(steering)
	yaw_rate = lerpf(yaw_rate, rolling_yaw, parking * (1.0 - exp(-31.0 * delta)))
	return net
