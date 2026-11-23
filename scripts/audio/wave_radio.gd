extends Node

signal track_changed(index: int)

const TITLES := ["Brisa do Arroio", "Alameda 92", "Depois da Chuva", "Fim de Tarde"]
const TRACKS := [
	"res://assets/audio/wave-radio-brisa.ogg",
	"res://assets/audio/wave-radio-alameda.ogg",
	"res://assets/audio/wave-radio-chuva.ogg",
	"res://assets/audio/wave-sunset.wav",
]
const TRANSITION := 1.40
const LEVEL_DB := -8.5
const SILENT_DB := -60.0

var track_index := -1
var _voices: Array[AudioStreamPlayer] = []
var _active := 0
var _fade := 1.0
var _paused := false
var _duck := 0.0
var _duck_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("wave_audio")
	add_to_group("wave_radio")
	var car: PlayerCar = get_parent().car
	car.impact.connect(_on_impact)
	for i in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "Music%d" % i
		voice.bus = "Música"
		add_child(voice)
		_voices.append(voice)
	play_track(0)


func play_track(index: int) -> void:
	if index < 0 or index >= TRACKS.size() or index == track_index:
		return
	var track := load(TRACKS[index]) as AudioStream
	if track == null:
		return
	var outgoing := _voices[_active]
	var crossfade := outgoing.playing and not get_tree().paused
	if not crossfade:
		outgoing.stop()
		outgoing.stream = null
	_active = 1 - _active
	var incoming := _voices[_active]
	incoming.stop()
	incoming.stream = track
	incoming.volume_db = SILENT_DB if crossfade else LEVEL_DB - _duck
	_fade = 0.0 if crossfade else 1.0
	incoming.play()
	incoming.stream_paused = get_tree().paused
	track_index = index
	track_changed.emit(track_index)


func _process(delta: float) -> void:
	var paused := get_tree().paused
	if paused != _paused:
		_paused = paused
		for voice in _voices:
			voice.stream_paused = paused
	if paused or track_index < 0:
		return
	var incoming := _voices[_active]
	var previous_duck := _duck
	_duck = move_toward(_duck, _duck_target, delta * (40.0 if _duck_target > _duck else 14.0))
	_duck_target = move_toward(_duck_target, 0.0, delta * 7.0)
	var volume := LEVEL_DB - _duck
	if _fade < 1.0:
		var outgoing := _voices[1 - _active]
		_fade = minf(1.0, _fade + delta / TRANSITION)
		incoming.volume_db = volume + linear_to_db(maxf(0.001, sin(_fade * PI * 0.5)))
		outgoing.volume_db = volume + linear_to_db(maxf(0.001, cos(_fade * PI * 0.5)))
		if _fade == 1.0:
			outgoing.stop()
			outgoing.stream = null
	elif _duck != previous_duck:
		incoming.volume_db = volume
	if not incoming.playing or incoming.get_playback_position() >= incoming.stream.get_length() - TRANSITION:
		play_track((track_index + 1) % TRACKS.size())


func _on_impact(strength: float) -> void:
	_duck_target = maxf(_duck_target, smoothstep(0.26, 0.9, strength) * 4.5)


func stop_audio() -> void:
	set_process(false)
	for voice in _voices:
		voice.stop()
		voice.stream = null


func _exit_tree() -> void:
	stop_audio()
