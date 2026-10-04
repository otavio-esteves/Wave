extends CanvasLayer

var _diagnostic_timer: float = 0.0

@onready var world: DrivingWorld = get_parent()
@onready var car: PlayerCar = $"../PlayerCar"
@onready var readout: Label = $Overlay/Telemetry/Readout
@onready var pause_menu: Control = $Overlay/PauseMenu
@onready var resume_button: Button = $Overlay/PauseMenu/Center/Buttons/Resume
@onready var diagnostics: Label = $Overlay/Diagnostics
@onready var world_button: Button = $Overlay/PauseMenu/Center/Buttons/World
@onready var buttons: VBoxContainer = $Overlay/PauseMenu/Center/Buttons
@onready var audio_options: PanelContainer = $Overlay/PauseMenu/Center/AudioOptions


func _ready() -> void:
	resume_button.pressed.connect(func() -> void: set_paused(false))
	$Overlay/PauseMenu/Center/Buttons/Reset.pressed.connect(_reset_car)
	$Overlay/PauseMenu/Center/Buttons/Exit.pressed.connect(WaveSettings.quit_game)
	world_button.text = world.alternate_scene_label
	world_button.visible = not world.alternate_scene.is_empty()
	world_button.pressed.connect(_change_world)
	$Overlay/PauseMenu/Center/Buttons/Audio.pressed.connect(_open_audio)
	audio_options.closed.connect(_close_audio)
	$Overlay/Controls.text = "WAVE · %s\nWASD / setas: dirigir   Espaço: freio de mão   C: olhar atrás   R: reset   Esc: pausar   F3: FPS" % world.world_title


func _process(delta: float) -> void:
	var gear := "N"
	if car.drive_speed > 0.2:
		gear = "D"
	elif car.drive_speed < -0.2:
		gear = "R"
	var status := ""
	if absf(car.lateral_speed) > 2.0:
		status = "  ·  DERRAPANDO"
	readout.text = "%02d km/h   %s%s" % [roundi(car.get_speed_kmh()), gear, status]
	if diagnostics.visible:
		_diagnostic_timer += delta
		if _diagnostic_timer >= 0.5:
			_diagnostic_timer = 0.0
			_refresh_diagnostics()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if audio_options.visible:
			audio_options.close()
		else:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics") and not event.is_echo():
		diagnostics.visible = not diagnostics.visible
		_refresh_diagnostics()
		get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	if audio_options.visible:
		audio_options.close()
	buttons.show()
	get_tree().paused = value
	pause_menu.visible = value
	if value:
		resume_button.grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()


func _open_audio() -> void:
	buttons.hide()
	audio_options.open()


func _close_audio() -> void:
	buttons.show()
	$Overlay/PauseMenu/Center/Buttons/Audio.grab_focus()


func _reset_car() -> void:
	car.reset_car()
	set_paused(false)


func _change_world() -> void:
	set_paused(false)
	_load_world.call_deferred(world.alternate_scene)


func _load_world(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Could not change scene: %s" % error_string(error))
		set_paused(true)


func _refresh_diagnostics() -> void:
	var fps := Engine.get_frames_per_second()
	if fps == 0:
		diagnostics.text = "FPS: aguardando medição"
		return
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	diagnostics.text = "FPS: %d  ·  %.1f ms/quadro  ·  Draw calls: %d" % [fps, 1000.0 / fps, draw_calls]
