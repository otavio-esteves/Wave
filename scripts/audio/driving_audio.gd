extends Node

const ENGINE = preload("res://assets/audio/wave-engine.wav")
const AMBIENCE = preload("res://assets/audio/wave-evening.wav")
const MUSIC = preload("res://assets/audio/wave-sunset.wav")
const TIRES = preload("res://assets/audio/wave-tires.wav")
const WIND = preload("res://assets/audio/wave-wind.wav")
const GEAR_LIMITS := [0.0, 8.0, 17.0, 28.0, 42.0, 62.0]
var car: PlayerCar
var engine: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var tires: AudioStreamPlayer
var wind: AudioStreamPlayer
var _gear := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("wave_audio")
	car = get_parent().get_node("PlayerCar")
	engine = _player("Engine", ENGINE, "Motor", -10.0)
	ambience = _player("Ambience", AMBIENCE, "Ambiente", -14.0)
	music = _player("Music", MUSIC, "Música", -14.0)
	tires = _player("Tires", TIRES, "Motor", -60.0)
	wind = _player("Wind", WIND, "Motor", -60.0)
	car.car_reset.connect(_reset_engine)


func _player(label: String, source: AudioStreamWAV, bus: String, gain: float) -> AudioStreamPlayer:
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
	player.play()
	return player


func _process(delta: float) -> void:
	var paused := get_tree().paused
	for player: AudioStreamPlayer in [engine, ambience, music, tires, wind]:
		player.stream_paused = paused
	if paused:
		return
	var speed := absf(car.drive_speed)
	var throttle := Input.get_action_strength("accelerate")
	if car.drive_speed < -0.2:
		throttle = Input.get_action_strength("brake")
	# Five gear ranges with downshift hysteresis, including a finite top gear.
	# Pitch no longer drops repeatedly at arbitrary 8 m/s boundaries.
	while _gear < GEAR_LIMITS.size() - 2 and speed > GEAR_LIMITS[_gear + 1]:
		_gear += 1
	while _gear > 0 and speed < GEAR_LIMITS[_gear] - 1.2:
		_gear -= 1
	var revs := clampf(inverse_lerp(GEAR_LIMITS[_gear], GEAR_LIMITS[_gear + 1], speed), 0.0, 1.0)
	var target_pitch := 0.8 + revs * 1.1 + throttle * 0.3
	engine.pitch_scale = lerpf(engine.pitch_scale, target_pitch, 1.0 - exp(-5.0 * delta))
	engine.volume_db = lerpf(engine.volume_db, -14.0 + throttle * 5.0 + minf(speed / 22.0, 1.0) * 3.0, 1.0 - exp(-4.0 * delta))
	var slip := absf(atan2(car.lateral_speed, maxf(speed, 1.0)))
	var scrub := smoothstep(deg_to_rad(4.0), deg_to_rad(24.0), slip) * smoothstep(4.0, 12.0, speed)
	if not car.is_on_floor() or car.surface_name != "asfalto":
		scrub = 0.0
	var tire_gain := linear_to_db(maxf(0.001, scrub)) - 17.0
	tires.volume_db = lerpf(tires.volume_db, maxf(-60.0, tire_gain), 1.0 - exp(-10.0 * delta))
	tires.pitch_scale = lerpf(tires.pitch_scale, 0.85 + minf(speed / 45.0, 1.0) * 0.3, 1.0 - exp(-5.0 * delta))
	var airflow := smoothstep(12.0, 61.0, car.get_speed_kmh() / 3.6)
	wind.volume_db = lerpf(wind.volume_db, maxf(-60.0, linear_to_db(maxf(0.001, airflow)) - 22.0), 1.0 - exp(-3.0 * delta))


func _reset_engine() -> void:
	engine.pitch_scale = 0.8
	engine.volume_db = -14.0
	_gear = 0
	tires.volume_db = -60.0
	wind.volume_db = -60.0


func stop_audio() -> void:
	set_process(false)
	for player: AudioStreamPlayer in [engine, ambience, music, tires, wind]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_audio()
