extends DrivingWorld

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Cabin = preload("res://scripts/city/figueiras_cabin.gd")
const PAVEMENT = preload("res://assets/shaders/jabuticabeiras/pavement.gdshader")
const FACADE = preload("res://assets/shaders/jabuticabeiras/facade.gdshader")
const FOLIAGE = preload("res://assets/shaders/jabuticabeiras/leaves.gdshader")

const ASPHALT := {"surface": "asfalto", "friction": 1.05}
const SIDEWALK := {"surface": "calçada", "friction": 0.89, "rolling": 1.20}
const VERGE := {"surface": "gramado", "friction": 0.73, "rolling": 1.70}

var _finishes: Array[ShaderMaterial] = []
var _normal_materials: Array[StandardMaterial3D] = []
var _leaves: ShaderMaterial
var _restore_interpolation := false
var _cabin: Cabin
@onready var _car: PlayerCar = $PlayerCar
@onready var _support: StaticBody3D = $Street/StreetSupport
@onready var _shadow: MeshInstance3D = $PlayerCar/ContactShadow


func _enter_tree() -> void:
	super._enter_tree()
	_restore_interpolation = not get_tree().physics_interpolation
	get_tree().physics_interpolation = true
	$PlayerCar.transform = Layout.spawn()
	$PlayerCar.road_support = $Street/StreetSupport
	$PlayerCar.terrain_surface = _terrain_surface
	$ChaseCamera.terrain_preview = _preview


func _ready() -> void:
	$Sun.look_at(-Layout.SUN_DIRECTION, Vector3.UP)
	var sky := $WorldEnvironment.environment.sky.sky_material as ShaderMaterial
	sky.set_shader_parameter("sun_direction", Layout.SUN_DIRECTION.normalized())
	$ChaseCamera.camera.far = 350.0
	_shadow.material_override = _shadow.mesh.material.duplicate()
	for node in $Street.get_children():
		if not node is GeometryInstance3D:
			continue
		var finish: Material = node.material_override
		if node is MeshInstance3D and node.mesh != null:
			finish = node.mesh.surface_get_material(0)
			node.layers |= Cabin.ROAD_MIRROR_LAYER
		if finish is ShaderMaterial and finish not in _finishes:
			if finish.shader == FOLIAGE:
				_leaves = finish
			elif finish.shader == PAVEMENT or finish.shader == FACADE:
				_finishes.append(finish)
		elif finish is StandardMaterial3D:
			if finish.normal_texture != null and finish not in _normal_materials:
				_normal_materials.append(finish)
			if node is MultiMeshInstance3D and (str(node.name).begins_with("box_side_") or str(node.name).begins_with("tiled_hip_")):
				node.layers |= Cabin.ROAD_MIRROR_LAYER
	_cabin = Cabin.new()
	_cabin.name = "Instruments"
	_cabin.windshield_bounce = 1.7
	$PlayerCar/Visuals/Body.add_child(_cabin)
	$TireEffects.set_daylight(1.0)
	process_physics_priority = 2
	super._ready()


func _exit_tree() -> void:
	if _restore_interpolation:
		get_tree().physics_interpolation = false


func _physics_process(_delta: float) -> void:
	if not _car.is_on_floor():
		return
	var normal := _car.get_floor_normal()
	var rear := (_car.global_basis.z - normal * _car.global_basis.z.dot(normal)).normalized()
	_shadow.global_transform = Transform3D(Basis(normal.cross(rear), -rear, normal), _car.global_position - Vector3.UP * 0.324)


func apply_graphics() -> void:
	super.apply_graphics()
	var graphics := WaveSettings.graphics
	for material in _finishes:
		material.set_shader_parameter("material_detail", graphics.material_detail)
		if material.shader == PAVEMENT:
			material.set_shader_parameter("use_baked_shadow", not graphics.shadows)
	for material in _normal_materials:
		material.normal_enabled = graphics.material_detail
	if _leaves != null:
		_leaves.set_shader_parameter("antialias_leaves", graphics.antialiasing)
		_leaves.set_shader_parameter("sway", 0.010 if graphics.material_detail else 0.0)
	$WorldEnvironment.environment.ssao_enabled = graphics.post_effects
	_shadow.material_override.set_shader_parameter("opacity", 0.33 if graphics.shadows else 0.52)
	$TireEffects.set_material_detail(graphics.material_detail)
	_cabin.apply_graphics()


func _terrain_surface(point: Vector3, body: Object) -> Dictionary:
	if body != _support:
		return {}
	var site := Layout.coordinates(Vector2(point.x, point.z))
	var edge := absf(site.x) - Layout.half_width(site.y)
	if site.y < 0.0 or site.y > Layout.LENGTH or absf(site.x) > Layout.paving_edge(site.y):
		return VERGE
	return SIDEWALK if edge > 0.045 else ASPHALT


func _preview(point: Vector2, direction: Vector2, distance: float) -> Vector3:
	var site := Layout.coordinates(point)
	var across := Layout.right(site.y)
	var alignment := direction.dot(Vector2(across.y, -across.x))
	var next := clampf(site.y + distance * alignment, 0.0, Layout.LENGTH)
	var travel := absf(next - site.y)
	if travel < 0.5 or absf(site.x) > Layout.half_width(site.y):
		return Vector3.ZERO
	var ahead := Layout.center(next) + Layout.right(next) * site.x
	var confidence := smoothstep(0.76, 0.95, absf(alignment)) * smoothstep(1.0, 9.0, travel)
	return Vector3((Layout.grade(next) - Layout.grade(site.y)) / travel, confidence, -direction.angle_to(ahead - point))
