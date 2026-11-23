extends Node3D

const MASONRY = preload("res://assets/audio/wave-hit-masonry.wav")
const BODYWORK = preload("res://assets/audio/wave-hit-bodywork.wav")
const SUSPENSION = preload("res://assets/audio/wave-hit-suspension.wav")
const SCRAPE = preload("res://assets/audio/wave-scrape.wav")

var _hits: Array[AudioStreamPlayer3D] = []
var _scrape: AudioStreamPlayer3D
var _next_hit := 0
var _bump_cooldown := 0.0
@onready var _car: PlayerCar = $"../PlayerCar"


func _ready() -> void:
	add_to_group("wave_audio")
	for index in 3:
		_hits.append(_voice("Contact%d" % index))
	_scrape = _voice("Scrape")
	var loop := SCRAPE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	_scrape.stream = loop
	_scrape.volume_db = -60.0
	_car.body_impact.connect(_play_impact)
	_car.car_reset.connect(_clear_contacts)


func _voice(label: String) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = label
	voice.bus = "Motor"
	voice.unit_size = 7.5
	voice.max_distance = 34.0
	add_child(voice)
	return voice


func _play_impact(strength: float, point: Vector3, bodywork: bool) -> void:
	_play_hit(BODYWORK if bodywork else MASONRY, point,
		lerpf(-27.0, -6.0, sqrt(strength)), lerpf(1.13, 0.87, strength))
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, strength * 0.40, strength * 0.60, lerpf(0.08, 0.19, strength))


func _play_hit(sound: AudioStreamWAV, point: Vector3, gain: float, pitch: float) -> void:
	var voice := _hits[_next_hit]
	_next_hit = (_next_hit + 1) % _hits.size()
	voice.stream = sound
	voice.global_position = point
	voice.volume_db = gain
	voice.pitch_scale = pitch
	voice.play()


func _physics_process(delta: float) -> void:
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	var bump := maxf(_car.landing_impulse, _car.curb_impulse)
	if bump > 0.06 and _bump_cooldown <= 0.0:
		_bump_cooldown = 0.15
		_play_hit(SUSPENSION, _car.global_position - Vector3.UP * 0.30,
			lerpf(-31.0, -11.0, sqrt(bump)), lerpf(1.16, 0.84, bump))
	var grind := _car.scrape_strength
	if grind > 0.025:
		_scrape.global_position = _car.scrape_point
		var pitch := lerpf(0.70, 1.28, smoothstep(2.0, 23.0, _car.velocity.length()))
		_scrape.pitch_scale = pitch * (1.18 if _car.scrape_bodywork else 1.0)
		if not _scrape.playing:
			_scrape.play()
	if _scrape.playing:
		var target := maxf(-60.0, linear_to_db(maxf(0.001, grind)) - 12.0)
		_scrape.volume_db = lerpf(_scrape.volume_db, target, 1.0 - exp(-12.0 * delta))
		if grind <= 0.025 and _scrape.volume_db < -56.0:
			_scrape.stop()


func _clear_contacts() -> void:
	for voice in _hits:
		voice.stop()
	_scrape.stop()
	_scrape.volume_db = -60.0
	_bump_cooldown = 0.0


func stop_audio() -> void:
	set_physics_process(false)
	_clear_contacts()
	for voice in _hits:
		voice.stream = null
	_scrape.stream = null


func _exit_tree() -> void:
	stop_audio()
