extends "res://scripts/driving_world.gd"

func _ready() -> void:
	super._ready()
	var timing := Node.new()
	timing.name = "RaceTiming"
	timing.set_script(preload("res://scripts/race/race_timing.gd"))
	add_child(timing)
