extends ReflectionProbe

# One local environment capture for the hero car. Moving the one-shot probe
# refreshes its cubemap; the city and car never reflect the car back into itself.
const VEHICLE_LAYER := 2
var target: PlayerCar
var _last_position := Vector3.INF
var _last_hour := -1.0
var _timer := 0.0
var _refresh_serial := 0

func _ready() -> void:
	target = get_parent().get_node("PlayerCar")
	cull_mask = 1
	reflection_mask = VEHICLE_LAYER
	# Keep the car inside the capture volume even at its 220 km/h speed cap
	# between one-second checks; geometry capture still ends at 90 metres.
	size = Vector3(160, 32, 160)
	max_distance = 90
	intensity = 0.85
	ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	update_mode = ReflectionProbe.UPDATE_ONCE
	for geometry: GeometryInstance3D in target.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = VEHICLE_LAYER
	target.car_reset.connect(refresh)
	set_enabled(bool(get_node("/root/WaveSettings").graphics["material_detail"]))

func set_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if enabled and target != null:
		refresh()

func _process(delta: float) -> void:
	_timer += delta
	if _timer < 1.0:
		return
	_timer = 0.0
	var cycle := get_parent().get_node("DayNightCycle")
	var hour: float = cycle.hour
	var hour_delta := absf(wrapf(hour - _last_hour, -12.0, 12.0))
	if target.global_position.distance_squared_to(_last_position) >= 24.0 * 24.0 or hour_delta >= 0.25:
		refresh()

func refresh() -> void:
	if not visible or target == null:
		return
	_last_position = target.global_position
	_last_hour = get_parent().get_node("DayNightCycle").hour
	_refresh_serial += 1
	# Alternating millimetres also refresh stationary captures after a clock jump.
	global_position = target.global_position + Vector3(0, 1.4, 0.001 * (_refresh_serial % 2))
