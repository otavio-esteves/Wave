extends Node

const ENGINE = preload("res://assets/audio/wave-engine.wav")
const AMBIENCE = preload("res://assets/audio/wave-evening.wav")
const MUSIC = preload("res://assets/audio/wave-sunset.wav")
const TIRES = preload("res://assets/audio/wave-tires.wav")
const WIND = preload("res://assets/audio/wave-wind.wav")
const ASPHALT = preload("res://assets/audio/wave-roll-asphalt.wav")
const PAVERS = preload("res://assets/audio/wave-roll-cobbles.wav")
const LOOSE = preload("res://assets/audio/wave-roll-loose.wav")
const GOL_IDLE = preload("res://assets/audio/wave-gol-idle.wav")
const GOL_LOAD = preload("res://assets/audio/wave-gol-load.wav")
const GOL_HIGH = preload("res://assets/audio/wave-gol-high.wav")
const GOL_COAST = preload("res://assets/audio/wave-gol-coast.wav")
const GOL_BAND_RPM := Vector4(960.0, 2640.0, 5040.0, 2400.0)
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
var _engine_bands: Array[AudioStreamPlayer] = []
var _view: Node3D
var _cabin := 0.0
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("wave_audio")
	car = get_parent().get_node("PlayerCar")
	engine = _player("Engine", GOL_IDLE if car.road_car_tuning else ENGINE, "Motor", -11.0)
	ambience = _player("Ambience", AMBIENCE, "Ambiente", -14.0)
	music = _player("Music", MUSIC, "Música", -14.0)
	tires = _player("Tires", TIRES, "Motor", -60.0, false)
	wind = _player("Wind", WIND, "Motor", -60.0, false)
	if car.road_car_tuning:
		engine.pitch_scale = car.gearbox.rpm / GOL_BAND_RPM.x
		_engine_bands = [
			engine,
			_player("EngineLoad", GOL_LOAD, "Motor", -60.0, false),
			_player("EngineHigh", GOL_HIGH, "Motor", -60.0, false),
			_player("EngineCoast", GOL_COAST, "Motor", -60.0, false),
		]
		_view = get_parent().get_node_or_null("ChaseCamera")
		_rolling = [
			_player("AsphaltRoll", ASPHALT, "Motor", -60.0, false),
			_player("PaverRoll", PAVERS, "Motor", -60.0, false),
			_player("LooseRoll", LOOSE, "Motor", -60.0, false),
		]
	car.car_reset.connect(_reset_engine)


func _player(label: String, source: AudioStreamWAV, bus: String, gain: float, start := true) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	# Duplicate the imported stream so loop setup never changes a shared asset.
	var loop := source.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	player.stream = loop
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
	_mix_voice(tires, scrub, -16.0 - 3.5 * _cabin, 0.79 + minf(speed / 48.0, 1.0) * 0.41, 1.0 - exp(-10.0 * delta))
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
	var smooth := 1.0 - exp(-14.0 * delta)
	var inside: bool = _view != null and _view.is_cockpit_view()
	_cabin = lerpf(_cabin, float(inside), 1.0 - exp(-7.0 * delta))
	var rpm := car.gearbox.rpm
	var load := smoothstep(0.06, 0.92, throttle) * clampf(car.gearbox.torque, 0.0, 1.0)
	var coast := smoothstep(1070.0, 2400.0, rpm) * (1.0 - smoothstep(0.07, 0.40, load))
	var above_idle := smoothstep(1320.0, 2560.0, rpm)
	var high := smoothstep(3300.0, 5000.0, rpm)
	var open_throttle := 1.0 - coast * 0.91
	# Crossfade energy between neighbouring RPM bands. Closed-throttle
	# overrun has its own waveform and falls back into idle as the car stops.
	var energy := Vector4(1.0 - above_idle, above_idle * (1.0 - high), high, 0.0) * open_throttle
	energy.w = coast * 0.91
	var power_db := -13.0 + 5.2 * load
	var gains := Vector4(power_db, power_db, power_db - 1.0 - 4.2 * _cabin, -14.5 + 2.2 * _cabin)
	for index in _engine_bands.size():
		var pitch := clampf(rpm / GOL_BAND_RPM[index], 0.40, 2.70)
		_mix_voice(_engine_bands[index], sqrt(energy[index]), gains[index], pitch, smooth)


func _mix_voice(player: AudioStreamPlayer, gain: float, base_db: float, pitch: float, weight: float) -> void:
	if gain > 0.014 and not player.playing:
		player.pitch_scale = pitch
		player.play()
	if not player.playing:
		return
	player.volume_db = lerpf(player.volume_db, maxf(-60.0, linear_to_db(maxf(0.001, gain)) + base_db), weight)
	player.pitch_scale = lerpf(player.pitch_scale, pitch, weight)
	if gain <= 0.014 and player.volume_db < -57.0:
		player.stop()


func _update_road_audio(delta: float) -> float:
	var speed := car.get_speed_kmh() / 3.6
	var load_by_material := Vector3.ZERO
	var squeal := 0.0
	if car.is_on_floor() and speed > 1.5:
		for wheel in 4:
			var contact := car.tire_contact(wheel)
			if contact.is_empty():
				continue
			var material: String = contact.get("surface", "asfalto")
			var load := car.wheel_loads[wheel]
			match material:
				"asfalto":
					load_by_material.x += load
					var wetness := float(contact.get("wetness", 0.0))
					squeal += sqrt(load) * car.tire_scrub(wheel) * lerpf(1.0, 0.65, wetness)
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
	return clampf(squeal, 0.0, 1.0)


func _reset_engine() -> void:
	engine.pitch_scale = 0.8 if _engine_bands.is_empty() else car.gearbox.rpm / GOL_BAND_RPM.x
	engine.volume_db = -14.0
	if not engine.playing:
		engine.play()
		engine.stream_paused = _paused
	for index in range(1, _engine_bands.size()):
		_engine_bands[index].volume_db = -60.0
		_engine_bands[index].stop()
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
