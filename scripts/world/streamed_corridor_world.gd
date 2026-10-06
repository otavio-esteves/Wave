extends "res://scripts/corridor/corridor_world.gd"

@onready var streamer: WorldStreamer = $WorldStreamer


func teleport_to(position: Vector3, heading: float = 0.0) -> void:
	_car.reset_car()
	streamer.teleport_to(Transform3D(Basis(Vector3.UP, heading), position))
	get_node("ChaseCamera").snap_to_target()
