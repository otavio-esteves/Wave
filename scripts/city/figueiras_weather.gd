extends Node3D

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const RAIN = preload("res://assets/shaders/figueiras/rain_streak.gdshader")
const RAIN_AUDIO = preload("res://assets/audio/wave-rain.wav")
const ROAD_LAMP_CAPACITY := 6

var wet := false
var intensity := 0.0
var finishes: Array[ShaderMaterial] = []
var _rain := GPUParticles3D.new()
var _rain_finish := ShaderMaterial.new()
var _rain_sound := AudioStreamPlayer.new()
var _asphalt: Array[ShaderMaterial] = []
var _reflective_surfaces: Array[ShaderMaterial] = []
var _road_lamps := PackedVector4Array()
var _road_horizon := Color.TRANSPARENT
var _road_zenith := Color.TRANSPARENT
var _detailed := false
var _shelter := 0.0
var _streak_brightness := -1.0
var _weather_tick := 0.0
var _lamp_tick := 0.0
var _wetness := -1.0
@onready var _car: PlayerCar = $"../PlayerCar"
@onready var _body: MeshInstance3D = $"../PlayerCar/Visuals/Body"
@onready var _cycle: Node = $"../DayNightCycle"
@onready var _camera: Node3D = $"../ChaseCamera"
@onready var _event: Node3D = $"../AlamedaSprint"


func _ready() -> void:
	add_to_group("wave_audio")
	for finish in finishes:
		if finish.resource_name.begins_with("figueiras_surface_asphalt"):
			_asphalt.append(finish)
			finish.set_shader_parameter("wet_road_lamp_count", 0)
		if int(finish.get_shader_parameter("surface_kind")) < 2:
			_reflective_surfaces.append(finish)
	_make_rain()
	_rain_sound.name = "RainPatters"
	_rain_sound.bus = "Ambiente"
	_rain_sound.volume_db = -60.0
	var clip := RAIN_AUDIO.duplicate() as AudioStreamWAV
	clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
	clip.loop_end = roundi(RAIN_AUDIO.get_length() * RAIN_AUDIO.mix_rate)
	_rain_sound.stream = clip
	add_child(_rain_sound)
	if _event.cup.active and _event.cup.wet:
		set_wet(true)


func set_material_detail(enabled: bool) -> void:
	_detailed = enabled
	_rain.amount = 740 if enabled else 355
	if not enabled:
		_update_road_lamps(PackedVector4Array())


func set_wet(value: bool) -> void:
	if value == wet or (_event.cup.active and value != _event.cup.wet):
		return
	wet = value
	_car.road_wetness = 1.0 if wet else 0.0
	_event.set_wet(wet)
	if wet and not _rain_sound.playing:
		_rain_sound.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("city_weather") and not event.is_echo():
		set_wet(not wet)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var target := 1.0 if wet else 0.0
	if intensity == target and intensity == 0.0:
		return
	intensity = move_toward(intensity, target, delta * (0.48 if wet else 0.22))
	_weather_tick -= delta
	if (_weather_tick <= 0.0 and absf(_wetness - intensity) > 0.014) or (intensity in [0.0, 1.0] and _wetness != intensity):
		_weather_tick = 0.13
		_wetness = intensity
		_cycle.set_overcast(intensity)
		_body.set_instance_shader_parameter("body_water", intensity)
		for material in finishes:
			material.set_shader_parameter("wetness", intensity)
	_lamp_tick -= delta
	if _lamp_tick <= 0.0:
		_lamp_tick = 0.16
		_update_reflected_sky()
		if _detailed:
			_update_road_lamps(_cycle.reflected_lamps())
	var site := Vector2(_car.global_position.x, _car.global_position.z)
	_shelter = lerpf(_shelter, Layout.rain_shelter(site), 1.0 - exp(-6.0 * delta))
	var drops := intensity * (1.0 - _shelter)
	var lead := _car.velocity * 0.28
	_rain.global_position = _car.global_position + Vector3(lead.x, 10.7, lead.z)
	var emits := drops > 0.04
	if emits != _rain.emitting:
		_rain.emitting = emits
	var brightness: float = drops * (0.38 + _cycle.daylight * 0.62)
	if absf(brightness - _streak_brightness) > 0.003:
		_streak_brightness = brightness
		_rain_finish.set_shader_parameter("intensity", brightness)
	var inside: bool = _camera.is_cockpit_view()
	var rain_exposure := intensity * (1.0 - 0.84 * _shelter)
	var road_spray := smoothstep(13.0, 42.0, _car.get_speed_kmh() / 3.6) * 3.0
	var volume := linear_to_db(maxf(0.001, rain_exposure)) - 22.0 + road_spray + (2.5 if inside else 0.0)
	if absf(volume - _rain_sound.volume_db) > 0.05:
		_rain_sound.volume_db = volume
	if intensity == 0.0 and _rain_sound.playing:
		_rain_sound.stop()


func stop_audio() -> void:
	set_process(false)
	_rain_sound.stop()
	_rain_sound.stream = null


func _exit_tree() -> void:
	stop_audio()


func _update_reflected_sky() -> void:
	var horizon: Color = _cycle.horizon_color
	var zenith: Color = _cycle.zenith_color
	if horizon != _road_horizon or zenith != _road_zenith:
		_road_horizon = horizon
		_road_zenith = zenith
		for material in _reflective_surfaces:
			material.set_shader_parameter("road_horizon", horizon)
			material.set_shader_parameter("road_zenith", zenith)


func _update_road_lamps(lamps: PackedVector4Array) -> void:
	if lamps == _road_lamps:
		return
	_road_lamps = lamps
	var count := mini(lamps.size(), ROAD_LAMP_CAPACITY)
	lamps.resize(ROAD_LAMP_CAPACITY)
	for material in _asphalt:
		material.set_shader_parameter("wet_road_lamp_count", count)
		if count > 0:
			material.set_shader_parameter("wet_road_lamps", lamps)


func _make_rain() -> void:
	_rain.name = "RainStreaks"
	_rain.amount = 740
	_rain.emitting = false
	_rain.local_coords = false
	_rain.lifetime = 0.76
	_rain.fixed_fps = 60
	# Include old drops left behind while the emitter follows a fast car.
	_rain.visibility_aabb = AABB(Vector3(-88, -31, -88), Vector3(176, 39, 176))
	var motion := ParticleProcessMaterial.new()
	motion.lifetime_randomness = 0.28
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(15.0, 4.5, 16.0)
	motion.gravity = Vector3(3.0, -10.0, 1.5)
	motion.direction = Vector3(0.21, -1.0, 0.09)
	motion.spread = 4.0
	motion.initial_velocity_min = 16.0
	motion.initial_velocity_max = 23.5
	motion.particle_flag_align_y = true
	_rain.process_material = motion
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_finish.shader = RAIN
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.024, 0.54)
	mesh.material = _rain_finish
	_rain.draw_pass_1 = mesh
	add_child(_rain)
