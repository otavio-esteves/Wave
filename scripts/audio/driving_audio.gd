extends Node

const ENGINE = preload("res://assets/audio/wave-engine.wav")
const AMBIENCE = preload("res://assets/audio/wave-evening.wav")
const MUSIC = preload("res://assets/audio/wave-sunset.wav")
const TIRES = preload("res://assets/audio/wave-tires.wav")
const WIND = preload("res://assets/audio/wave-wind.wav")
const ASPHALT = preload("res://assets/audio/wave-road-asphalt.wav")
const PAVERS = preload("res://assets/audio/wave-road-pavers.wav")
const LOOSE = preload("res://assets/audio/wave-road-gravel.wav")
const WET_ROAD = preload("res://assets/audio/wave-road-wet.wav")
const ROAD_TIRES = preload("res://assets/audio/wave-wheel-squeal.wav")
const SHIFT = preload("res://assets/audio/wave-transmission-shift.wav")
const Radio = preload("res://scripts/audio/wave_radio.gd")
# The name, recording and reference RPM for each adjacent engine voice.
const GOL_BANDS := [
	["Engine", preload("res://assets/audio/wave-motor-idle.wav"), 960.0],
	["EngineLow", preload("res://assets/audio/wave-motor-low.wav"), 1710.0],
	["EngineLoad", preload("res://assets/audio/wave-motor-mid.wav"), 2880.0],
	["EngineHigh", preload("res://assets/audio/wave-motor-high.wav"), 4080.0],
	["EngineRedline", preload("res://assets/audio/wave-motor-redline.wav"), 5550.0],
]
const GOL_COAST = preload("res://assets/audio/wave-motor-overrun.wav")
const COAST_RPM := 2160.0
const GEAR_LIMITS := [0.0, 8.0, 17.0, 28.0, 42.0, 62.0]
const ROLL_GAIN := Vector3(-13.5, -11.0, -11.5)
var car: PlayerCar
var engine: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var tires: AudioStreamPlayer
var wind: AudioStreamPlayer
var _gear := 0
var _players: Array[AudioStreamPlayer] = []
var _rolling: Array[AudioStreamPlayer] = []
var _wet_tires: AudioStreamPlayer
var _engine_bands: Array[AudioStreamPlayer] = []
var _coast: AudioStreamPlayer
var _shift: AudioStreamPlayer
var _road_gear := 1
var _road_filter: AudioEffectLowPassFilter
var _view: Node3D
var _cabin := 0.0
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("wave_audio")
	car = get_parent().get_node("PlayerCar")
	var is_road := car.road_car_tuning
	var car_bus := &"Motor"
	if is_road:
		var settings := get_node("/root/WaveSettings")
		car_bus = settings.ROAD_VOICE_BUS
		_road_filter = settings.road_filter
	ambience = _player("Ambience", AMBIENCE, "Ambiente", -14.0)
	tires = _player("Tires", ROAD_TIRES if is_road else TIRES, car_bus, -60.0, false)
	wind = _player("Wind", WIND, car_bus, -60.0, false)
	if is_road:
		var radio := Radio.new()
		radio.name = "Radio"
		add_child(radio)
		for band: Array in GOL_BANDS:
			_engine_bands.append(_player(band[0], band[1], car_bus, -60.0, false))
		engine = _engine_bands[0]
		_coast = _player("EngineCoast", GOL_COAST, car_bus, -60.0, false)
		_shift = _player("GearShift", SHIFT, car_bus, -28.0, false, false)
		_view = get_parent().get_node_or_null("ChaseCamera")
		_rolling = [
			_player("AsphaltRoll", ASPHALT, car_bus, -60.0, false),
			_player("PaverRoll", PAVERS, car_bus, -60.0, false),
			_player("LooseRoll", LOOSE, car_bus, -60.0, false),
		]
		_wet_tires = _player("WetTireSpray", WET_ROAD, car_bus, -60.0, false)
		_reset_engine()
	else:
		engine = _player("Engine", ENGINE, car_bus, -11.0)
		music = _player("Music", MUSIC, "Música", -14.0)
	car.car_reset.connect(_reset_engine)


func _player(label: String, source: AudioStreamWAV, bus: StringName, gain: float, start := true, looping := true) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	# Duplicate the imported stream so loop setup never changes a shared asset.
	if looping:
		var loop := source.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		player.stream = loop
	else:
		player.stream = source
	player.bus = bus
	player.volume_db = gain
	add_child(player)
	_players.append(player)
	if start:
		player.play()
	return player


func _process(delta: float) -> void:
	var paused := get_tree().paused
	if paused != _paused:
		_paused = paused
		for player in _players:
			player.stream_paused = paused
	if paused:
		return
	var speed := absf(car.drive_speed)
	var throttle := Input.get_action_strength("accelerate")
	if car.drive_speed < -0.2:
		throttle = Input.get_action_strength("brake")
	var slip := absf(atan2(car.lateral_speed, maxf(speed, 1.0)))
	var scrub := smoothstep(deg_to_rad(4.0), deg_to_rad(24.0), slip) * smoothstep(4.0, 12.0, speed)
	if not car.is_on_floor() or car.surface_name != "asfalto":
		scrub = 0.0
	if _engine_bands.is_empty():
		_update_legacy_engine(speed, throttle, delta)
	else:
		_update_road_engine(throttle, delta)
		scrub = _update_road_audio(delta)
	var tire_level := -16.0 if _engine_bands.is_empty() else -11.0
	_mix_voice(tires, scrub, tire_level - 3.5 * _cabin, 0.79 + minf(speed / 48.0, 1.0) * 0.41, 1.0 - exp(-10.0 * delta))
	var airflow := smoothstep(12.0, 56.0, car.get_speed_kmh() / 3.6)
	_mix_voice(wind, airflow, -20.0 - 8.0 * _cabin, lerpf(0.83, 1.13, airflow), 1.0 - exp(-4.0 * delta))


func _update_legacy_engine(speed: float, throttle: float, delta: float) -> void:
	# Five gear ranges with downshift hysteresis, including a finite top gear.
	while _gear < GEAR_LIMITS.size() - 2 and speed > GEAR_LIMITS[_gear + 1]:
		_gear += 1
	while _gear > 0 and speed < GEAR_LIMITS[_gear] - 1.2:
		_gear -= 1
	var revs := clampf(inverse_lerp(GEAR_LIMITS[_gear], GEAR_LIMITS[_gear + 1], speed), 0.0, 1.0)
	var target_pitch := 0.8 + revs * 1.1 + throttle * 0.3
	engine.pitch_scale = lerpf(engine.pitch_scale, target_pitch, 1.0 - exp(-5.0 * delta))
	engine.volume_db = lerpf(engine.volume_db, -14.0 + throttle * 5.0 + minf(speed / 22.0, 1.0) * 3.0, 1.0 - exp(-4.0 * delta))


func _update_road_engine(throttle: float, delta: float) -> void:
	var smooth := 1.0 - exp(-16.0 * delta)
	var inside: bool = _view != null and _view.is_cockpit_view()
	_cabin = lerpf(_cabin, float(inside), 1.0 - exp(-7.0 * delta))
	var cutoff := lerpf(18000.0, 2480.0, _cabin)
	if absf(_road_filter.cutoff_hz - cutoff) > 65.0:
		_road_filter.cutoff_hz = cutoff
	var rpm := car.gearbox.rpm
	var load := smoothstep(0.06, 0.92, throttle) * clampf(car.gearbox.torque, 0.0, 1.0)
	var coast := smoothstep(1080.0, 2340.0, rpm) * (1.0 - smoothstep(0.05, 0.38, load)) * 0.93
	var band := 0
	while band < GOL_BANDS.size() - 2 and rpm > GOL_BANDS[band + 1][2]:
		band += 1
	# Only adjacent bands have a target above silence at any RPM.
	var blend := smoothstep(float(GOL_BANDS[band][2]), float(GOL_BANDS[band + 1][2]), rpm)
	var power_db := -13.5 + 6.4 * load
	for index in _engine_bands.size():
		var mix := 1.0 - blend if index == band else (blend if index == band + 1 else 0.0)
		var pitch := clampf(rpm / float(GOL_BANDS[index][2]), 0.50, 1.90)
		_mix_voice(_engine_bands[index], sqrt(mix * (1.0 - coast)), power_db, pitch, smooth)
	_mix_voice(_coast, sqrt(coast), -15.0 + _cabin * 1.2, clampf(rpm / COAST_RPM, 0.53, 2.80), smooth)
	if car.gearbox.gear != _road_gear:
		_road_gear = car.gearbox.gear
		if absf(car.drive_speed) > 4.0:
			_shift.volume_db = -23.0 + 3.0 * _cabin
			_shift.pitch_scale = 0.93 + 0.024 * _road_gear
			_shift.play()


func _mix_voice(player: AudioStreamPlayer, gain: float, base_db: float, pitch: float, weight: float) -> void:
	if gain > 0.014 and not player.playing:
		player.pitch_scale = pitch
		player.play()
	if not player.playing:
		return
	var target := maxf(0.001, gain * db_to_linear(base_db))
	player.volume_db = linear_to_db(lerpf(db_to_linear(player.volume_db), target, weight))
	player.pitch_scale = lerpf(player.pitch_scale, pitch, weight)
	if gain <= 0.014 and player.volume_db < -57.0:
		player.stop()


func _update_road_audio(delta: float) -> float:
	var speed := car.get_speed_kmh() / 3.6
	var load_by_material := Vector3.ZERO
	var squeal := 0.0
	var wet_tire_load := 0.0
	if car.is_on_floor() and speed > 1.5:
		for wheel in 4:
			var contact := car.tire_contact(wheel)
			if contact.is_empty():
				continue
			var material: String = contact.get("surface", "asfalto")
			var load := car.wheel_loads[wheel]
			var wetness := float(contact.get("wetness", 0.0))
			wet_tire_load += load * wetness
			match material:
				"asfalto":
					load_by_material.x += load
					squeal += sqrt(load) * car.tire_scrub(wheel) * lerpf(1.0, 0.46, wetness)
				"calçada", "paralelepípedo", "concreto":
					load_by_material.y += load
				_:
					load_by_material.z += load
	var strength := sqrt(smoothstep(1.5, 23.0, speed)) * clampf(car.suspension_load(), 0.0, 1.1)
	var fade := 1.0 - exp(-9.0 * delta)
	var pitch := lerpf(0.59, 1.50, smoothstep(1.5, 32.0, speed))
	for material in _rolling.size():
		var player := _rolling[material]
		var gain := sqrt(load_by_material[material]) * strength
		_mix_voice(player, gain, ROLL_GAIN[material] - _cabin * 2.0, pitch, fade)
	_mix_voice(_wet_tires, sqrt(wet_tire_load) * smoothstep(3.0, 18.0, speed), -15.0 - _cabin * 3.0, pitch, fade)
	return clampf(squeal, 0.0, 1.0)


func _reset_engine() -> void:
	engine.pitch_scale = 0.8 if _engine_bands.is_empty() else car.gearbox.rpm / float(GOL_BANDS[0][2])
	engine.volume_db = -14.0
	if not engine.playing:
		engine.play()
		engine.stream_paused = _paused
	for index in range(1, _engine_bands.size()):
		_engine_bands[index].volume_db = -60.0
		_engine_bands[index].stop()
	if _coast != null:
		_coast.volume_db = -60.0
		_coast.stop()
		_shift.stop()
		_wet_tires.volume_db = -60.0
		_wet_tires.stop()
		_road_gear = car.gearbox.gear
	_gear = 0
	tires.volume_db = -60.0
	wind.volume_db = -60.0
	tires.stop()
	wind.stop()
	for player in _rolling:
		player.volume_db = -60.0
		player.stop()


func stop_audio() -> void:
	set_process(false)
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_audio()
