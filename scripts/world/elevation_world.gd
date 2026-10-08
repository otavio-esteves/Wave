extends DrivingWorld

@onready var streamer: WorldStreamer = $WorldStreamer


func _ready() -> void:
	super._ready()
	var trip := Node.new()
	trip.name = "LookoutTrip"
	trip.set_script(preload("res://scripts/world/lookout_trip.gd"))
	add_child(trip)


func teleport_to(position: Vector3, heading: float = 0.0) -> void:
	$PlayerCar.reset_car()
	streamer.teleport_to(Transform3D(Basis(Vector3.UP, heading), position))
	$LookoutTrip.cancel()
	$ChaseCamera.snap_to_target()
