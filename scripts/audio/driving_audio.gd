extends Node

const ENGINE = preload("res://assets/audio/wave-engine.wav")
const AMBIENCE = preload("res://assets/audio/wave-evening.wav")
const MUSIC = preload("res://assets/audio/wave-sunset.wav")
var car: PlayerCar
var engine: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("wave_audio")
	car = get_parent().get_node("PlayerCar")
	engine = _player("Engine", ENGINE, "Motor", -10.0)
	ambience = _player("Ambience", AMBIENCE, "Ambiente", -14.0)
	music = _player("Music", MUSIC, "Música", -14.0)
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
	for player: AudioStreamPlayer in [engine, ambience, music]:
		player.stream_paused = paused
	if paused:
		return
	var speed := absf(car.drive_speed)
	var throttle := Input.get_action_strength("accelerate")
	if car.drive_speed < -0.2:
		throttle = Input.get_action_strength("brake")
	# Three simulated gear ranges lower the pitch after each upshift.
	var revs := fmod(speed, 8.0) / 8.0
	var target_pitch := 0.8 + revs * 1.1 + throttle * 0.3
	engine.pitch_scale = lerpf(engine.pitch_scale, target_pitch, 1.0 - exp(-5.0 * delta))
	engine.volume_db = lerpf(engine.volume_db, -14.0 + throttle * 5.0 + minf(speed / 22.0, 1.0) * 3.0, 1.0 - exp(-4.0 * delta))


func _reset_engine() -> void:
	engine.pitch_scale = 0.8
	engine.volume_db = -14.0


func stop_audio() -> void:
	set_process(false)
	for player: AudioStreamPlayer in [engine, ambience, music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_audio()
