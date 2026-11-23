extends Node3D

const ENGINE = preload("res://assets/audio/wave-gol-coast.wav")
const VOICES := 3
var _voices: Array[AudioStreamPlayer3D] = []
var _assignments := PackedInt32Array([-1, -1, -1])
var _playing := PackedInt32Array([-1, -1, -1])
var _refresh := 0.0
@onready var _traffic: Node3D = $"../Traffic"
@onready var _player: PlayerCar = $"../PlayerCar"


func _ready() -> void:
	add_to_group("wave_audio")
	var loop := ENGINE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	for index in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Ambiente"
		voice.stream = loop
		voice.volume_db = -60.0
		voice.unit_size = 8.0
		voice.max_distance = 47.0
		voice.attenuation_filter_cutoff_hz = 2850
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		add_child(voice)
		_voices.append(voice)


func _physics_process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.20
		_refresh_voices()
	for index in VOICES:
		var voice := _voices[index]
		if _playing[index] != _assignments[index]:
			voice.volume_db = move_toward(voice.volume_db, -60.0, 220.0 * delta)
			if voice.playing and voice.volume_db > -51.0:
				continue
			voice.stop()
			_playing[index] = _assignments[index]
		var assigned := _playing[index]
		if assigned < 0:
			continue
		var driver = _traffic.drivers[assigned]
		voice.position = driver.body.position
		var pitch: float = (1180.0 + driver.speed * 76.0) / 2400.0
		var volume: float = -29.5 + minf(driver.speed * 0.43, 6.2) - 2.5 * float(driver.braking)
		var response := 1.0 - exp(-8.0 * delta)
		voice.pitch_scale = lerpf(voice.pitch_scale, pitch, response)
		voice.volume_db = lerpf(voice.volume_db, volume, response)
		if not voice.playing:
			voice.pitch_scale = pitch
			voice.play(fmod(0.29 * assigned, voice.stream.get_length()))


func _refresh_voices() -> void:
	if not _traffic.active:
		_assignments.fill(-1)
		return
	var distances := PackedFloat32Array()
	var closest := PackedInt32Array()
	for index in _traffic.drivers.size():
		var distance: float = _player.global_position.distance_squared_to(_traffic.drivers[index].body.global_position)
		# Favour existing sources slightly so the mix stays stable at the cutoff.
		if index in _assignments:
			distance -= 42.0
		if distance < 42.0 * 42.0:
			var order := distances.bsearch(distance)
			distances.insert(order, distance)
			closest.insert(order, index)
	closest.resize(mini(VOICES, closest.size()))
	for slot in VOICES:
		if _assignments[slot] not in closest:
			_assignments[slot] = -1
	for index in closest:
		if index not in _assignments:
			var slot := _assignments.find(-1)
			_assignments[slot] = index


func stop_audio() -> void:
	set_physics_process(false)
	for voice in _voices:
		voice.stop()
		voice.stream = null


func _exit_tree() -> void:
	stop_audio()
