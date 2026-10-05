extends RefCounted

# Bicycle model: two loaded axles, front-wheel drive and combined tire forces.
# Positive lateral velocity / yaw point left; SI units throughout.
const MASS := 900.0
const WHEELBASE := 2.26
const FRONT_WEIGHT := 0.61
const CG_HEIGHT := 0.45
const INERTIA := 1150.0
const GRAVITY := 9.81
var yaw_rate := 0.0
var longitudinal_acceleration := 0.0
var lateral_acceleration := 0.0
var front_load := MASS * GRAVITY * FRONT_WEIGHT
var rear_load := MASS * GRAVITY * (1.0 - FRONT_WEIGHT)
var utilization := 0.0

func reset() -> void:
	yaw_rate = 0.0
	longitudinal_acceleration = 0.0
	lateral_acceleration = 0.0
	front_load = MASS * GRAVITY * FRONT_WEIGHT
	rear_load = MASS * GRAVITY * (1.0 - FRONT_WEIGHT)
	utilization = 0.0

func step(forward: float, left: float, steer: float, requested_acceleration: float, braking: bool, handbrake: float, friction: float, delta: float) -> Vector2:
	var transfer := MASS * clampf(longitudinal_acceleration, -GRAVITY, GRAVITY) * CG_HEIGHT / WHEELBASE
	front_load = clampf(MASS * GRAVITY * FRONT_WEIGHT - transfer, MASS * GRAVITY * 0.15, MASS * GRAVITY * 0.85)
	rear_load = MASS * GRAVITY - front_load
	var a := WHEELBASE * (1.0 - FRONT_WEIGHT)
	var b := WHEELBASE * FRONT_WEIGHT
	var front_side := left + a * yaw_rate
	var front_slip := atan2(forward * sin(steer) - front_side * cos(steer), maxf(absf(forward * cos(steer) + front_side * sin(steer)), 3.0))
	var rear_slip := atan2(-(left - b * yaw_rate), maxf(absf(forward), 3.0))
	var front_limit := friction * front_load
	var rear_limit := friction * rear_load
	var rear_lateral_limit := rear_limit * lerpf(1.0, 0.4, handbrake)
	var desired_force := requested_acceleration * MASS
	var front_x := desired_force * (0.70 if braking else 1.0)
	var rear_x := desired_force * (0.30 if braking else 0.0)
	if handbrake > 0.0:
		front_x = 0.0
		rear_x = desired_force
	var front := combined_force(front_x, front_limit * tanh(45000.0 * front_slip / maxf(front_limit, 1.0)), front_limit)
	var rear := combined_force(rear_x, rear_lateral_limit * tanh(42000.0 * rear_slip / maxf(rear_lateral_limit, 1.0)), rear_limit)
	var force_x := front.x * cos(steer) - front.y * sin(steer) + rear.x
	var force_left := front.x * sin(steer) + front.y * cos(steer) + rear.y
	longitudinal_acceleration = force_x / MASS
	lateral_acceleration = force_left / MASS
	var torque := a * (front.x * sin(steer) + front.y * cos(steer)) - b * rear.y
	yaw_rate += (torque / INERTIA - yaw_rate * 0.35) * delta
	# Near standstill, tire slip is ill-defined; blend toward rolling kinematics.
	var rolling_yaw := forward / WHEELBASE * tan(steer)
	var low_speed := 1.0 - smoothstep(0.5, 4.0, absf(forward))
	yaw_rate = lerpf(yaw_rate, rolling_yaw, low_speed * (1.0 - exp(-20.0 * delta)))
	utilization = maxf(front.length() / maxf(front_limit, 1.0), rear.length() / maxf(rear_limit, 1.0))
	return Vector2(longitudinal_acceleration, lateral_acceleration)

static func combined_force(longitudinal: float, lateral: float, limit: float) -> Vector2:
	return Vector2(longitudinal, lateral).limit_length(maxf(0.0, limit))
