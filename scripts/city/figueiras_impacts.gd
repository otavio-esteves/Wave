extends Node3D

const MASONRY := [preload("res://assets/audio/wave-contact-wall-soft.wav"),
	preload("res://assets/audio/wave-contact-wall-hard.wav")]
const BODYWORK := [preload("res://assets/audio/wave-contact-bodywork-soft.wav"),
	preload("res://assets/audio/wave-contact-bodywork-hard.wav")]
const SUSPENSION = preload("res://assets/audio/wave-contact-suspension.wav")
const SCRAPES := [preload("res://assets/audio/wave-grind-wall.wav"),
	preload("res://assets/audio/wave-grind-metal.wav")]
const HIT_PITCH := [1.00, 1.045, 0.969, 1.023]

var _hits: Array[AudioStreamPlayer3D] = []
var _scrapes: Array[AudioStreamPlayer3D] = []
var _next_hit := 0
var _bump_cooldown := 0.0
@onready var _car: PlayerCar = $"../PlayerCar"


func _ready() -> void:
	add_to_group("wave_audio")
	for index in HIT_PITCH.size():
		_hits.append(_voice("Contact%d" % index))
	for index in SCRAPES.size():
		var voice := _voice("Scrape%d" % index)
		var loop := SCRAPES[index].duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		voice.stream = loop
		voice.volume_db = -60.0
		_scrapes.append(voice)
	_car.body_impact.connect(_play_impact)
	_car.car_reset.connect(_clear_contacts)


func _voice(label: String) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = label
	voice.bus = WaveSettings.ROAD_VOICE_BUS
	voice.unit_size = 7.5
	voice.max_distance = 34.0
	voice.max_db = 1.0
	add_child(voice)
	return voice


func _play_impact(strength: float, point: Vector3, bodywork: bool) -> void:
	var clips := BODYWORK if bodywork else MASONRY
	_play_hit(clips[int(strength >= 0.50)], point, lerpf(-29.0, -5.0, sqrt(strength)), lerpf(1.07, 0.91, strength))
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, strength * 0.40, strength * 0.60, lerpf(0.08, 0.19, strength))


func _play_hit(sound: AudioStreamWAV, point: Vector3, gain: float, pitch: float) -> void:
	var voice := _hits[_next_hit]
	var variation: float = HIT_PITCH[_next_hit]
	_next_hit = (_next_hit + 1) % _hits.size()
	voice.stream = sound
	voice.global_position = point
	voice.volume_db = gain
	voice.pitch_scale = pitch * variation
	voice.play()


func _physics_process(delta: float) -> void:
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	var bump := maxf(_car.landing_impulse, _car.curb_impulse)
	if bump > 0.06 and _bump_cooldown <= 0.0:
		_bump_cooldown = 0.15
		_play_hit(SUSPENSION, _car.global_position - Vector3.UP * 0.30,
			lerpf(-31.0, -11.0, sqrt(bump)), lerpf(1.16, 0.84, bump))
	var surface := int(_car.scrape_bodywork)
	for index in _scrapes.size():
		var voice := _scrapes[index]
		var grind := _car.scrape_strength if index == surface else 0.0
		if grind > 0.025:
			voice.global_position = _car.scrape_point
			voice.pitch_scale = lerpf(0.65, 1.25, smoothstep(1.2, 22.0, _car.scrape_speed))
			if not voice.playing:
				voice.play()
		if voice.playing:
			var amplitude := maxf(0.001, grind * 0.31)
			voice.volume_db = linear_to_db(lerpf(db_to_linear(voice.volume_db), amplitude, 1.0 - exp(-14.0 * delta)))
			if grind <= 0.025 and voice.volume_db < -54.0:
				voice.stop()
				voice.volume_db = -60.0


func _clear_contacts() -> void:
	for voice in _hits:
		voice.stop()
	for voice in _scrapes:
		voice.stop()
		voice.volume_db = -60.0
	_bump_cooldown = 0.0


func stop_audio() -> void:
	set_physics_process(false)
	_clear_contacts()
	for voice in _hits:
		voice.stream = null
	for voice in _scrapes:
		voice.stream = null


func _exit_tree() -> void:
	stop_audio()
