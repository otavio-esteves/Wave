extends DrivingWorld

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Cabin = preload("res://scripts/city/figueiras_cabin.gd")
const StreetReflection = preload("res://scripts/city/jabuticabeiras_reflection.gd")
const Atmosphere = preload("res://scripts/city/jabuticabeiras_atmosphere.gd")
const PAVEMENT = preload("res://assets/shaders/jabuticabeiras/pavement.gdshader")
const MASONRY = preload("res://assets/shaders/jabuticabeiras/masonry.gdshader")
const FOLIAGE = preload("res://assets/shaders/jabuticabeiras/leaves.gdshader")
const DASHBOARD = preload("res://assets/shaders/jabuticabeiras/instruments.gdshader")

const ASPHALT := {"surface": "asfalto", "friction": 1.05}
const SIDEWALK := {"surface": "calçada", "friction": 0.89, "rolling": 1.20}
const VERGE := {"surface": "gramado", "friction": 0.73, "rolling": 1.70}

var _finishes: Array[ShaderMaterial] = []
var _normal_materials: Array[StandardMaterial3D] = []
var _foliage: Array[ShaderMaterial] = []
var _asphalt: Array[ShaderMaterial] = []
var _lamps: Array[OmniLight3D] = []
var _lamp_interval := 0.0
var _detailed_lighting := false
var _lamp_distance_squared := 576.0
var _street_reflection: StreetReflection
var _car_reflection: ReflectionProbe
var _atmosphere: Atmosphere
var _road_condition: Image
var _road_condition_bounds := Rect2()
var _ground_sun: Image
var _ground_sun_bounds := Rect2()
var _baked_body_shadow := false
var _moving_shadow := 0.0
var _static_casters: Dictionary[GeometryInstance3D, int] = {}
var _restore_interpolation := false
var _cabin: Cabin
@onready var _car: PlayerCar = $PlayerCar
@onready var _player_body: MeshInstance3D = $PlayerCar/Visuals/Body
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
	for child in $Street.get_children():
		var node := child as GeometryInstance3D
		if node == null:
			continue
		if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_static_casters[node] = node.cast_shadow
		var finish: Material = node.material_override
		var label := str(node.name)
		var remote_greenery := label.begins_with("Mata_") or label.begins_with("Encosta_") or label.begins_with("distant_")
		var ground_scatter := label.begins_with("Pavement_") or label.begins_with("VegetacaoRasteira")
		var reflects := not ground_scatter and not remote_greenery and label != "VidrosDoViveiro"
		if node is MeshInstance3D and node.mesh != null:
			finish = node.mesh.surface_get_material(0)
			if not remote_greenery:
				node.layers |= Cabin.ROAD_MIRROR_LAYER
		if reflects:
			node.layers |= StreetReflection.CAPTURE_LAYER
		if finish is ShaderMaterial and finish not in _finishes:
			if finish.shader == FOLIAGE and finish not in _foliage:
				_foliage.append(finish)
			elif finish.shader == PAVEMENT or finish.shader == MASONRY:
				_finishes.append(finish)
				if finish.shader == PAVEMENT and finish.get_shader_parameter("surface_kind") == 0:
					_asphalt.append(finish)
					_install_visual_water(finish)
					_install_ground_sun(finish)
		elif finish is StandardMaterial3D:
			if finish.normal_texture != null and finish not in _normal_materials:
				_normal_materials.append(finish)
			if node is MultiMeshInstance3D and (str(node.name).begins_with("box_side_") or str(node.name).begins_with("tiled_hip_")):
				node.layers |= Cabin.ROAD_MIRROR_LAYER
	_cabin = Cabin.new()
	_cabin.name = "Instruments"
	_cabin.windshield_bounce = 2.35
	_cabin.windshield_residue = 0.18
	_cabin.ambient_daylight = 0.78
	_cabin.dashboard_shader = DASHBOARD
	_cabin.tachometer_max = 7000.0
	_cabin.side_mirrors = true
	_player_body.add_child(_cabin)
	_player_body.set_instance_shader_parameter("reflection_overcast", 0.29)
	_player_body.set_instance_shader_parameter("body_water", 0.51)
	_apply_cabin_shade(_player_body)
	_apply_cabin_shade(_player_body.get_node("SteeringWheel"))
	_lamps.assign($Street.find_children("*", "OmniLight3D", true, false))
	if DisplayServer.get_name() != "headless":
		_street_reflection = StreetReflection.new()
		_street_reflection.name = "WetRoadReflection"
		add_child(_street_reflection)
		$ChaseCamera.camera.cull_mask &= ~StreetReflection.VEHICLE_LAYER
		for piece: MeshInstance3D in $PlayerCar/Visuals.find_children("*", "MeshInstance3D", true, false):
			piece.layers |= StreetReflection.VEHICLE_LAYER
		_car_reflection = ReflectionProbe.new()
		_car_reflection.name = "GolClearcoatReflection"
		_car_reflection.position = Layout.position_at(74.0, 0.0, 2.3)
		_car_reflection.size = Vector3(35.0, 16.0, 162.0)
		_car_reflection.max_distance = 109.0
		_car_reflection.cull_mask = StreetReflection.CAPTURE_LAYER
		_car_reflection.reflection_mask = _player_body.layers
		_car_reflection.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		_car_reflection.box_projection = true
		_car_reflection.intensity = 0.70
		_car_reflection.visible = false
		add_child(_car_reflection)
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "StreetAtmosphere"
		add_child(_atmosphere)
		_atmosphere.build(_lamps)
	$TireEffects.set_daylight(1.0)
	process_physics_priority = 2
	super._ready()


func _exit_tree() -> void:
	if _restore_interpolation:
		get_tree().physics_interpolation = false


func _apply_cabin_shade(part: MeshInstance3D) -> void:
	for surface in part.mesh.get_surface_count():
		var material := part.get_active_material(surface) as StandardMaterial3D
		if material == null or material.resource_name not in ["Hatch1000_dark", "Hatch1000_fabric"]:
			continue
		var interior := material.duplicate() as StandardMaterial3D
		interior.emission_enabled = true
		interior.emission = Color("484b4b")
		interior.emission_energy_multiplier = 0.22
		if material.resource_name == "Hatch1000_fabric":
			interior.albedo_color = Color("cfd0c8")
			interior.normal_scale = 0.71
		part.set_surface_override_material(surface, interior)


func _install_visual_water(road: ShaderMaterial) -> void:
	var condition := road.get_shader_parameter("road_condition") as Texture2D
	if condition == null:
		return
	var bounds: Vector4 = road.get_shader_parameter("road_condition_bounds")
	_road_condition_bounds = Rect2(bounds.x, bounds.y, bounds.z, bounds.w)
	_road_condition = condition.get_image()
	if _road_condition != null and not _road_condition.is_empty():
		$TireEffects.visual_road_wetness = _visual_road_wetness


func _install_ground_sun(road: ShaderMaterial) -> void:
	if road.get_shader_parameter("has_ground_sun") != true:
		return
	var sun := road.get_shader_parameter("surface_bake") as Texture2D
	if sun == null:
		return
	var bounds: Vector4 = road.get_shader_parameter("bake_bounds")
	_ground_sun_bounds = Rect2(bounds.x, bounds.y, bounds.z, bounds.w)
	_ground_sun = sun.get_image()


func _visual_road_wetness(point: Vector3) -> float:
	var coordinates := Layout.coordinates(Vector2(point.x, point.z))
	return smoothstep(0.44, 0.88, _sample_field(_road_condition, _road_condition_bounds, coordinates))


func _sample_field(field: Image, bounds: Rect2, coordinates: Vector2) -> float:
	if not bounds.has_point(coordinates):
		return 0.0
	var uv := (coordinates - bounds.position) / bounds.size
	var size := field.get_size()
	var sample := uv * Vector2(size) - Vector2.ONE * 0.5
	var first := Vector2i(sample.floor())
	var last := (first + Vector2i.ONE).clamp(Vector2i.ZERO, size - Vector2i.ONE)
	first = first.clamp(Vector2i.ZERO, size - Vector2i.ONE)
	var weight := sample - sample.floor()
	return lerpf(
		lerpf(field.get_pixel(first.x, first.y).r, field.get_pixel(last.x, first.y).r, weight.x),
		lerpf(field.get_pixel(first.x, last.y).r, field.get_pixel(last.x, last.y).r, weight.x), weight.y)


func _physics_process(delta: float) -> void:
	if _detailed_lighting:
		_lamp_interval -= delta
		if _lamp_interval <= 0.0:
			_update_light_range()
			_lamp_interval = 0.20
	if _baked_body_shadow:
		var point := Vector2(_car.global_position.x, _car.global_position.z)
		var target_shadow := _sample_field(_ground_sun, _ground_sun_bounds, point)
		_moving_shadow = lerpf(_moving_shadow, target_shadow, 1.0 - exp(-11.0 * delta))
		_player_body.set_instance_shader_parameter("body_shadow", _moving_shadow)
	if not _car.is_on_floor():
		return
	var normal := _car.get_floor_normal()
	var rear := (_car.global_basis.z - normal * _car.global_basis.z.dot(normal)).normalized()
	_shadow.global_transform = Transform3D(Basis(normal.cross(rear), -rear, normal), _car.global_position - Vector3.UP * 0.324)


func apply_graphics() -> void:
	super.apply_graphics()
	var graphics := WaveSettings.graphics
	var baked: bool = _ground_sun != null and not _ground_sun.is_empty() and not graphics.post_effects
	_baked_body_shadow = baked
	if not baked:
		_player_body.set_instance_shader_parameter("body_shadow", 0.0)
	for caster: GeometryInstance3D in _static_casters:
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if baked else _static_casters[caster]
	for material in _finishes:
		material.set_shader_parameter("material_detail", graphics.material_detail)
		material.set_shader_parameter("use_baked_shadow", baked or not graphics.shadows)
		if material.shader == MASONRY:
			material.set_shader_parameter("use_bent_bake", graphics.post_effects)
			material.set_shader_parameter("vertex_light_bake", not graphics.material_detail)
	for material in _normal_materials:
		material.normal_enabled = graphics.material_detail
	for foliage in _foliage:
		foliage.set_shader_parameter("antialias_leaves", graphics.antialiasing)
		foliage.set_shader_parameter("sway", 0.047 if graphics.material_detail else 0.0)
	$WorldEnvironment.environment.ssao_enabled = graphics.post_effects
	_detailed_lighting = graphics.material_detail
	_lamp_distance_squared = 576.0 if graphics.post_effects else 268.96
	_update_light_range()
	if _street_reflection != null:
		_street_reflection.configure(_asphalt, graphics.material_detail, graphics.post_effects)
		_car_reflection.visible = graphics.post_effects
		_atmosphere.apply(graphics.post_effects and graphics.material_detail, graphics.post_effects)
	_shadow.material_override.set_shader_parameter("opacity", 0.33 if graphics.shadows else 0.52)
	$TireEffects.set_material_detail(graphics.material_detail)
	_cabin.apply_graphics()


func _update_light_range() -> void:
	var car_position := _car.global_position
	var camera := get_viewport().get_camera_3d()
	var viewpoint := camera.global_position if camera != null else car_position
	for lamp in _lamps:
		var location := lamp.global_position
		lamp.visible = _detailed_lighting and minf(location.distance_squared_to(car_position),
			location.distance_squared_to(viewpoint)) < _lamp_distance_squared


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
