class_name DrivingWorld
extends Node3D

@export var world_title: String = "PISTA DE TESTES"
@export_file("*.tscn") var alternate_scene: String = "res://scenes/city/drive_neighborhood.tscn"
@export var alternate_scene_label: String = "Passear no bairro"


func _enter_tree() -> void:
	InputSetup.configure()


func _ready() -> void:
	var audio := Node.new()
	audio.name = "DrivingAudio"
	audio.set_script(preload("res://scripts/audio/driving_audio.gd"))
	add_child(audio)
