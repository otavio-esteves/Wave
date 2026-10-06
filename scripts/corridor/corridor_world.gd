extends DrivingWorld

var _contact_shadow: MeshInstance3D
@onready var _car: PlayerCar = $PlayerCar


func _ready() -> void:
	super._ready()
	process_physics_priority = 11
	# This authored corridor has a level floor. A single small blob anchors the
	# car on Legacy; it is cosmetic and never participates in contact/physics.
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "CarContactShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 4.5)
	_contact_shadow.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/corridor/contact_shadow.gdshader")
	_contact_shadow.material_override = material
	_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact_shadow)


func _physics_process(_delta: float) -> void:
	_contact_shadow.position = Vector3(_car.position.x, 0.045, _car.position.z)
	_contact_shadow.rotation.y = _car.get_heading()
