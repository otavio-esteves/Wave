extends Node

# One full in-game day lasts 24 real minutes; pause stops both the clock and clouds.
@export_range(60.0, 7200.0) var day_duration_seconds := 1440.0
@export_range(0.0, 24.0) var hour := 16.5
@export var running := true
var daylight := 1.0
var night_factor := 0.0
var sun_direction := Vector3.UP
var _sky: ShaderMaterial
var _environment: Environment
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _lamps: Array[Vector3] = []
var _pool: Array[OmniLight3D] = []
var _emissive: Array[StandardMaterial3D] = []
var _elapsed := 0.0
var _lighting_timer := 0.0
var _lamp_timer := 0.0


func _ready() -> void:
	var world := get_parent()
	_environment = world.get_node("WorldEnvironment").environment.duplicate(true)
	world.get_node("WorldEnvironment").environment = _environment
	_sky = _environment.sky.sky_material as ShaderMaterial
	_sun = world.get_node("Sun")
	_moon = world.get_node("Moon")
	for marker in world.get_node("City").find_children("StreetLamp*", "Marker3D", false, false):
		_lamps.append(marker.global_position)
	var copies: Dictionary = {}
	for geometry in world.get_node("City").get_children():
		if not geometry is GeometryInstance3D:
			continue
		var material := geometry.material_override as StandardMaterial3D
		if material == null or material.resource_name not in ["light", "glass", "downtown_window"]:
			continue
		var key := material.resource_name
		if not copies.has(key):
			var copy: StandardMaterial3D = material.duplicate()
			copy.emission_enabled = true
			copy.emission = Color("ffe0a1") if key == "light" else Color("b8a16e")
			copies[key] = copy
			_emissive.append(copy)
		geometry.material_override = copies[key]
	for index in 8:
		var light := OmniLight3D.new()
		light.name = "NearbyStreetLight%d" % index
		light.light_color = Color("ffdda6")
		light.omni_range = 17.0
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		world.add_child.call_deferred(light)
		_pool.append(light)
	set_hour(hour)


func _process(delta: float) -> void:
	if running:
		hour = fposmod(hour + delta * 24.0 / day_duration_seconds, 24.0)
		_elapsed += delta
	_lighting_timer += delta
	_lamp_timer += delta
	if _lighting_timer >= 0.25:
		_lighting_timer = 0.0
		_update_lighting()
	if _lamp_timer >= 0.5:
		_lamp_timer = 0.0
		_update_lamps()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_time") and not event.is_echo():
		set_hour(hour + 3.0)
		get_viewport().set_input_as_handled()


func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	if _sky != null:
		_update_lighting()
		_update_lamps()


func clock_text() -> String:
	var minutes := floori(hour * 60.0) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _update_lighting() -> void:
	var angle := (hour - 6.0) / 24.0 * TAU
	sun_direction = Vector3(cos(angle) * 0.86, sin(angle), cos(angle) * 0.51).normalized()
	daylight = smoothstep(-0.12, 0.22, sun_direction.y)
	night_factor = 1.0 - smoothstep(-0.20, 0.04, sun_direction.y)
	var twilight := (1.0 - smoothstep(0.04, 0.32, absf(sun_direction.y))) * (1.0 - night_factor * 0.8)
	var up := Vector3.FORWARD if absf(sun_direction.y) > 0.99 else Vector3.UP
	_sun.look_at(_sun.global_position - sun_direction, up)
	_moon.look_at(_moon.global_position + sun_direction, up)
	_sun.light_energy = 1.12 * smoothstep(-0.035, 0.22, sun_direction.y)
	_sun.light_color = Color("ffae70").lerp(Color("fff3dc"), smoothstep(0.02, 0.5, sun_direction.y))
	_moon.light_energy = 0.13 * night_factor
	_environment.ambient_light_color = Color("7185b0").lerp(Color("bbc8d5"), daylight)
	_environment.ambient_light_energy = lerpf(0.13, 0.42, daylight)
	_environment.fog_light_color = Color("172238").lerp(Color("a1b3bd"), daylight).lerp(Color("b67c65"), twilight * 0.45)
	_environment.fog_light_energy = lerpf(0.25, 0.8, daylight)
	var parameters := {"sun_direction": sun_direction, "daylight": daylight, "twilight": twilight, "night_factor": night_factor, "cloud_time": _elapsed}
	for entry in parameters:
		_sky.set_shader_parameter(entry, parameters[entry])
	for material in _emissive:
		material.emission_energy_multiplier = night_factor * (1.8 if material.resource_name == "light" else 0.3)
	for light in _pool:
		light.light_energy = 1.6 * night_factor


func _update_lamps() -> void:
	var car := get_parent().get_node("PlayerCar") as Node3D
	var candidates: Array[Vector3] = []
	for position in _lamps:
		if position.distance_squared_to(car.global_position) < 85.0 * 85.0:
			candidates.append(position)
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(car.global_position) < b.distance_squared_to(car.global_position))
	for index in _pool.size():
		var light := _pool[index]
		light.visible = index < candidates.size() and night_factor > 0.01
		if index < candidates.size():
			light.position = candidates[index]
