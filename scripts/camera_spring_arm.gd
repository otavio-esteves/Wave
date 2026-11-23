extends SpringArm3D

@onready var _rig: Node3D = get_parent()


func _ready() -> void:
	set_physics_process(_rig.extended_views)


func _physics_process(delta: float) -> void:
	# The native arm sweep runs first in this node's physics notification.
	_rig.finish_camera_step(delta)
