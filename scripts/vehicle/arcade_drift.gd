extends RefCounted

# An intentional handbrake entry opens a controllable slide. Ordinary steering
# never arms it. Throttle carries the slide; lifting or countersteering catches it.
var amount := 0.0
var direction := 0.0


func reset() -> void:
	amount = 0.0
	direction = 0.0


func step(speed: float, slip: float, steer: float, throttle: float, brake: float, handbrake: float, delta: float) -> void:
	var entry := speed > 8.0 and absf(steer) > 0.2 and handbrake > 0.2
	if entry:
		direction = -signf(steer)
	var carrying := amount > 0.05 and speed > 8.0 and slip * direction > deg_to_rad(0.5)
	carrying = carrying and steer * direction < -0.15 and throttle > 0.15 and brake < 0.1
	var desired := maxf(handbrake, smoothstep(0.15, 0.55, throttle) if carrying else 0.0) if entry or carrying else 0.0
	amount = move_toward(amount, desired, (6.0 if desired > amount else 3.5) * delta)
	if is_zero_approx(amount):
		direction = 0.0


func desired_slip(throttle: float, steer: float) -> float:
	return direction * deg_to_rad(lerpf(16.0, 30.0, throttle)) * lerpf(0.65, 1.0, absf(steer))
