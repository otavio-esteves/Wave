extends Node3D

const VehicleMesh = preload("res://scripts/city/parked_car_mesh.gd")
const Finish = preload("res://assets/shaders/figueiras/ghost_car.gdshader")
var _paint := ShaderMaterial.new()


func _ready() -> void:
	_paint.shader = Finish
	_add_part(VehicleMesh.build_traffic(Color.WHITE, 0), Transform3D.IDENTITY)
	var wheel := VehicleMesh.build_traffic_wheel()
	for side: float in [-1.0, 1.0]:
		for axle: float in [-1.0, 1.0]:
			_add_part(wheel, Transform3D(Basis.IDENTITY, Vector3(side * 0.755, -0.035, axle * 1.14)))
	hide()


func present(pose: Transform3D, player: Vector3) -> void:
	global_transform = pose
	var clearance := pose.origin.distance_to(player)
	visible = clearance > 2.25 and clearance < 135.0
	if visible:
		_paint.set_shader_parameter("strength", smoothstep(2.25, 6.0, clearance) * (1.0 - smoothstep(100.0, 135.0, clearance)))


func _add_part(mesh: Mesh, placement: Transform3D) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.transform = placement
	part.material_override = _paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
