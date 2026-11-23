extends Node3D

const VehicleMesh = preload("res://scripts/city/parked_car_mesh.gd")
const ContactShade = preload("res://assets/shaders/car_contact_shadow.gdshader")
const Optics = preload("res://assets/shaders/figueiras/traffic_lamps.gdshader")
const COLORS := ["aeb7ad", "a14e3e", "577b8e", "c1ad86", "315957", "54545d", "d5d0bd"]
const AXLES := [1.14, 1.28, 1.19]
const DRAW_DISTANCE_SQUARED := 190.0 * 190.0
const WHEEL_DISTANCE_SQUARED := 148.0 * 148.0
# Includes the bumper and contact shadow, with room for camera interpolation.
const CULL_RADIUS := 6.0

class Batch:
	var mesh: MultiMesh
	var colors := PackedColorArray()
	var count := 0

	func _init(value: MultiMesh) -> void:
		mesh = value
		if mesh.use_custom_data:
			colors.resize(mesh.instance_count)

	func append(pose: Transform3D) -> void:
		mesh.set_instance_transform(count, pose)
		count += 1

	func append_lamp(pose: Transform3D, color: Color) -> void:
		if colors[count] != color:
			colors[count] = color
			mesh.set_instance_custom_data(count, color)
		append(pose)

	func submit() -> void:
		if mesh.visible_instance_count != count:
			mesh.visible_instance_count = count
		count = 0

var _shells: Array[Batch] = []
var _wheels: Batch
var _lamps: Batch
var _shade: Batch
var _physics_frame := -1
var _last_night := -1.0
var _last_view_position := Vector3.INF
var _rearview_camera: Camera3D
@onready var _traffic: Node3D = get_parent()
@onready var _car: PlayerCar = $"../../PlayerCar"
@onready var _day_cycle: Node = $"../../DayNightCycle"


func _ready() -> void:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.metallic = 0.23
	paint.roughness = 0.62
	var lamp := ShaderMaterial.new()
	lamp.shader = Optics
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(0.27, 0.13, 0.035)
	var shadow := ShaderMaterial.new()
	shadow.shader = ContactShade
	shadow.set_shader_parameter("opacity", 0.36)
	var footprint := PlaneMesh.new()
	footprint.size = Vector2(2.23, 5.03)
	var meshes: Array = get_node("../../City").get_meta("traffic_meshes", [])
	if meshes.size() != COLORS.size() + 1:
		meshes = make_meshes()
	for index in COLORS.size():
		var count := ceili(float(_traffic.drivers.size() - index) / COLORS.size())
		_shells.append(_batch("Shells%d" % index, meshes[index], paint, count))
	_wheels = _batch("Wheels", meshes[-1], paint, _traffic.drivers.size() * 4)
	_lamps = _batch("Lamps", light_mesh, lamp, _traffic.drivers.size() * 4, true)
	_shade = _batch("GroundShadows", footprint, shadow, _traffic.drivers.size())
	_process(0.0)


static func make_meshes() -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for index in COLORS.size():
		meshes.append(VehicleMesh.build_traffic(Color(COLORS[index]), index % 3))
	meshes.append(VehicleMesh.build_traffic_wheel())
	return meshes


func _batch(label: String, mesh: Mesh, material: Material, count: int, custom := false) -> Batch:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.layers |= 2
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = custom
	batch.mesh = mesh
	batch.instance_count = count
	batch.visible_instance_count = 0
	node.multimesh = batch
	add_child(node)
	return Batch.new(batch)


func set_rearview_camera(camera: Camera3D) -> void:
	_rearview_camera = camera
	_physics_frame = -1


func _process(_delta: float) -> void:
	if not _traffic.active:
		return
	var night: float = 1.0 - _day_cycle.daylight
	var frame := Engine.get_physics_frames()
	var scene_position := _car.global_position
	if frame == _physics_frame and night == _last_night and scene_position == _last_view_position:
		return
	_physics_frame = frame
	_last_night = night
	_last_view_position = scene_position
	var camera := get_viewport().get_camera_3d()
	var front_planes: Array[Plane]
	var rear_planes: Array[Plane]
	if camera != null:
		front_planes = camera.get_frustum()
	if _rearview_camera != null:
		rear_planes = _rearview_camera.get_frustum()
	for index in _traffic.drivers.size():
		var driver = _traffic.drivers[index]
		var pose: Transform3D = driver.pose
		var distance := scene_position.distance_squared_to(pose.origin)
		if distance > DRAW_DISTANCE_SQUARED:
			continue
		if _outside_view(front_planes, pose.origin) and (rear_planes.is_empty() or _outside_view(rear_planes, pose.origin)):
			continue
		var shell: int = index % _shells.size()
		_shells[shell].append(pose)
		if distance > WHEEL_DISTANCE_SQUARED:
			continue
		_shade.append(pose.translated_local(Vector3(0, -0.315, 0)))
		var spin := Basis(Vector3.RIGHT, -driver.odometer / 0.31)
		var front_steer := Basis(Vector3.UP, -driver.steering) * spin
		for side: float in [-1, 1]:
			for end: float in [-1, 1]:
				var wheel := Transform3D(front_steer if end < 0 else spin, Vector3(side * 0.755, -0.035, AXLES[shell % 3] * end))
				_wheels.append(pose * wheel)
				var light := Vector3(side * 0.555, 0.333, (driver.length * 0.5 + 0.08) * end)
				var color := Color(1.0, 0.83, 0.56, 0.22 + night * 0.52) if end < 0 else Color(0.92, 0.15, 0.09, 0.95 if driver.braking else 0.18 + night * 0.23)
				_lamps.append_lamp(pose.translated_local(light), color)
	for shell in _shells:
		shell.submit()
	_wheels.submit()
	_lamps.submit()
	_shade.submit()


static func _outside_view(planes: Array[Plane], point: Vector3) -> bool:
	for plane in planes:
		if plane.distance_to(point) > CULL_RADIUS:
			return true
	return false
