class_name DrivingWorld
extends Node3D

@export var world_title: String = "PISTA DE TESTES"
@export_file("*.tscn") var alternate_scene: String = "res://scenes/city/drive_neighborhood.tscn"
@export var alternate_scene_label: String = "Passear no bairro"
var _graphics_lights: Array[DirectionalLight3D] = []
var _lights_cached := false


func _enter_tree() -> void:
	InputSetup.configure()


func _ready() -> void:
	add_to_group("driving_world")
	apply_graphics()
	var audio := Node.new()
	audio.name = "DrivingAudio"
	audio.set_script(preload("res://scripts/audio/driving_audio.gd"))
	add_child(audio)
	var capture := Node.new()
	capture.name = "PerformanceCapture"
	capture.set_script(preload("res://scripts/tools/performance_capture.gd"))
	add_child(capture)


func apply_graphics() -> void:
	get_node("/root/WaveSettings").apply_world_graphics(self)


func graphics_lights() -> Array[DirectionalLight3D]:
	if not _lights_cached:
		_graphics_lights.assign(find_children("*", "DirectionalLight3D", true, false))
		_lights_cached = true
	return _graphics_lights
