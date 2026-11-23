extends RefCounted

# A short automatic road box tied to wheel speed. The torque curve is scaled
# to the existing arcade acceleration rather than simulating an exact engine.
const RATIOS := [3.45, 1.94, 1.29, 0.91, 0.73]
const FINAL_DRIVE := 4.12
const IDLE := 860.0
const LIMIT := 6350.0
const SHIFT_TIME := 0.19
var rpm := IDLE
var gear := 1
var torque := 1.0
var _shift_remaining := 0.0
var _cooldown := 0.0


func step(speed: float, radius: float, throttle: float, backwards: bool, delta: float) -> void:
	var wheel_rpm := absf(speed) / radius * 60.0 / TAU
	_shift_remaining = maxf(0.0, _shift_remaining - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	var ratio: float = RATIOS[gear - 1]
	var coupled := wheel_rpm * FINAL_DRIVE * (3.20 if backwards else ratio)
	if backwards:
		gear = 1
	elif _cooldown == 0.0:
		var upshift := lerpf(3700.0, 5770.0, throttle)
		if coupled > upshift and gear < RATIOS.size():
			_shift(gear + 1)
		elif gear > 1:
			var lower_rpm: float = wheel_rpm * FINAL_DRIVE * RATIOS[gear - 2]
			var kickdown := (throttle > 0.78 and coupled < 3270.0) or coupled < 1610.0
			if kickdown and lower_rpm < 5330.0:
				_shift(gear - 1)
	ratio = RATIOS[gear - 1]
	coupled = wheel_rpm * FINAL_DRIVE * (3.20 if backwards else ratio)
	var converter := (1.0 - smoothstep(0.5, 7.0, absf(speed))) * throttle * 1090.0
	var target := clampf(maxf(IDLE + 90.0 * throttle, coupled + converter), IDLE, LIMIT)
	rpm = lerpf(rpm, target, 1.0 - exp(-delta * (17.0 if _shift_remaining > 0.0 else 8.0)))
	# First gear has enough wheel torque to start on the residential grades.
	# Keep the original arcade power scale as the box goes into taller ratios.
	var curve := 0.89 + smoothstep(1000.0, 3100.0, target) * 0.145 - smoothstep(5300.0, LIMIT, target) * 0.09
	var reduction_gain := 1.12 if gear == 1 and not backwards else 1.0
	var transmission := lerpf(0.62, 1.0, 1.0 - _shift_remaining / SHIFT_TIME)
	torque = curve * reduction_gain * transmission


func _shift(next: int) -> void:
	gear = next
	_shift_remaining = SHIFT_TIME
	_cooldown = 0.38


func engine_drag(speed: float) -> float:
	var coupled := smoothstep(1.4, 5.5, absf(speed))
	var revs := smoothstep(IDLE + 350.0, 4500.0, rpm)
	var reduction: float = RATIOS[gear - 1] / RATIOS[0]
	return coupled * lerpf(0.26, 0.70, revs) * lerpf(0.58, 1.0, reduction)


func reset() -> void:
	rpm = IDLE
	gear = 1
	torque = 1.0
	_shift_remaining = 0.0
	_cooldown = 0.0
