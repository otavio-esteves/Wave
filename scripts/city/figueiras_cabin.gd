extends Node3D

signal mirror_camera_changed(camera: Camera3D)

const ROAD_MIRROR_LAYER := 2
const DASHBOARD = preload("res://assets/shaders/figueiras/dashboard.gdshader")
const ChaseCamera = preload("res://scripts/chase_camera.gd")
const WINDSHIELD_NORMAL := Vector3(0, 0.46, 0.89)
const BODY_PIVOT := Vector3(-0.34, 0.557, -0.339)
var windshield_bounce := 1.0
var windshield_residue := 0.0
var ambient_daylight := 1.0
var dashboard_shader: Shader = DASHBOARD
var tachometer_max := 6350.0
var side_mirrors := false
var _face: ShaderMaterial
var _wiper: Node3D
var _sweep := 0.0
var _speed := 0.0
var _mirror_view: SubViewport
var _mirror_camera: Camera3D
var _mirror_face: MeshInstance3D
var _side_faces: Array[MeshInstance3D] = []
var _mirror_interval := 0.0
var _cabin_fill: OmniLight3D
var _water := 0.0
var _was_inside := false
@onready var _body := get_parent() as MeshInstance3D
var _day_and_night: Node
@onready var _rig: Node3D = $"../../../../ChaseCamera"
@onready var _car: PlayerCar = $"../../.."
@onready var _weather := get_node_or_null("../../../../Weather")


func _ready() -> void:
	position = BODY_PIVOT
	rotation.x = -0.13
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("363b3b")
	body.roughness = 0.82
	_face = ShaderMaterial.new()
	_face.shader = dashboard_shader
	var panel := QuadMesh.new()
	panel.size = Vector2(0.268, 0.102)
	var lens := MeshInstance3D.new()
	lens.mesh = panel
	lens.material_override = _face
	lens.position = Vector3(0, -0.001, 0.009)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lens)
	_make_wiper(body)
	_day_and_night = get_node_or_null("../../../../DayNightCycle")
	hide()
	if DisplayServer.get_name() != "headless":
		_make_cabin_fill()


func _process(delta: float) -> void:
	var driving_inside: bool = _rig.is_cockpit_view()
	var daylight: float = _day_and_night.daylight if _day_and_night != null else ambient_daylight
	var rain: float = _weather.intensity if _weather != null else 0.0
	visible = driving_inside
	if driving_inside != _was_inside:
		_was_inside = driving_inside
		_body.set_instance_shader_parameter("windscreen_view", driving_inside)
	if driving_inside:
		_speed = lerpf(_speed, _car.get_speed_kmh(), 1.0 - exp(-10.0 * delta))
		_face.set_shader_parameter("speed", clampf(_speed / 220.0, 0.0, 1.0))
		_face.set_shader_parameter("rpm", clampf(_car.gearbox.rpm / tachometer_max, 0.0, 1.0))
		_face.set_shader_parameter("daylight", daylight)
		_face.set_shader_parameter("lights", 1.0 if _car.headlights_on else 0.0)
	if rain > 0.12 or _sweep > 0.0:
		_sweep += delta / 1.14
		if _sweep >= 1.0:
			_sweep = fposmod(_sweep, 1.0) if rain > 0.12 else 0.0
	var blade := 1.24 * sin(PI * smoothstep(0.0, 0.79, _sweep))
	_wiper.basis = Basis(WINDSHIELD_NORMAL.normalized(), -blade)
	var water := maxf(rain, windshield_residue) if driving_inside and WaveSettings.graphics.material_detail else 0.0
	if water > 0.01 or _water > 0.0:
		_body.set_instance_shader_parameter("windscreen_water", water)
		_body.set_instance_shader_parameter("windscreen_blade", blade)
		_water = water
	if _cabin_fill != null:
		_cabin_fill.visible = driving_inside
		if driving_inside:
			var fill := (0.26 + daylight * 0.72 - rain * 0.12) * windshield_bounce
			if absf(_cabin_fill.light_energy - fill) > 0.004:
				_cabin_fill.light_energy = fill
	_update_mirror(delta, driving_inside)


func _make_cabin_fill() -> void:
	_cabin_fill = OmniLight3D.new()
	_cabin_fill.name = "WindshieldBounce"
	_cabin_fill.position = Vector3(-0.20, 0.76, -0.19)
	_cabin_fill.omni_range = 1.12
	_cabin_fill.omni_attenuation = 1.28
	_cabin_fill.light_color = Color("b1bbc8")
	_cabin_fill.light_specular = 0.0
	_cabin_fill.light_bake_mode = Light3D.BAKE_DISABLED
	_cabin_fill.light_cull_mask = ChaseCamera.PLAYER_MESH_LAYER
	_cabin_fill.hide()
	get_parent().add_child.call_deferred(_cabin_fill)


func _make_mirror() -> void:
	_mirror_view = SubViewport.new()
	_mirror_view.name = "Rearview"
	_mirror_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mirror_view.msaa_3d = Viewport.MSAA_DISABLED
	_mirror_view.positional_shadow_atlas_size = 0
	add_child(_mirror_view)
	_mirror_camera = Camera3D.new()
	_mirror_camera.current = true
	_mirror_camera.top_level = true
	_mirror_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mirror_camera.cull_mask = ROAD_MIRROR_LAYER
	_mirror_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_mirror_camera.fov = 94.0 if side_mirrors else 69.0
	_mirror_camera.near = 0.1
	_mirror_view.add_child(_mirror_camera)
	apply_graphics()
	_mirror_face = _mirror_panel("MirrorFace", Vector2(0.181, 0.047), Vector3(0, 0.764, -0.087),
		Vector2(0.5, 0.5), Vector2(0.64, 0.64) if side_mirrors else Vector2.ONE, 0.0)
	_mirror_face.layers = 8
	if side_mirrors:
		for side: float in [-1.0, 1.0]:
			var place := Vector3(side * 0.847, 0.490, -0.4759)
			var view := Vector2(0.5 - side * 0.26, 0.52)
			_side_faces.append(_mirror_panel("LeftMirror" if side < 0.0 else "RightMirror",
				Vector2(0.132, 0.065), place, view, Vector2(0.39, 0.65), 0.16))


func _mirror_panel(label: String, size: Vector2, point: Vector3, center: Vector2,
		extent: Vector2, radius: float) -> MeshInstance3D:
	var image := ShaderMaterial.new()
	image.shader = preload("res://assets/shaders/figueiras/mirror.gdshader")
	image.set_shader_parameter("rearview", _mirror_view.get_texture())
	image.set_shader_parameter("view_center", center)
	image.set_shader_parameter("view_extent", extent)
	image.set_shader_parameter("corner_radius", radius)
	var mesh := QuadMesh.new()
	mesh.size = size
	var panel := MeshInstance3D.new()
	panel.name = label
	panel.layers = ChaseCamera.PLAYER_MESH_LAYER
	panel.mesh = mesh
	panel.material_override = image
	panel.position = point
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.hide()
	get_parent().add_child.call_deferred(panel)
	return panel


func apply_graphics() -> void:
	if _mirror_view == null:
		return
	var extended: bool = WaveSettings.graphics.post_effects
	_mirror_view.size = Vector2i(256, 76) if extended else Vector2i(192, 57)
	_mirror_view.mesh_lod_threshold = 2.0 if extended else 5.2
	_mirror_camera.far = 137.0 if extended else 76.0
	_mirror_interval = 0.0


func _update_mirror(delta: float, driving_inside: bool) -> void:
	var visible_from_seat: bool = driving_inside and WaveSettings.graphics.material_detail
	if _mirror_view == null:
		if not visible_from_seat or DisplayServer.get_name() == "headless":
			return
		_make_mirror()
	if _mirror_face.visible != visible_from_seat:
		_mirror_interval = 0.0
		_mirror_face.visible = visible_from_seat
		for side in _side_faces:
			side.visible = visible_from_seat
		mirror_camera_changed.emit(_mirror_camera if visible_from_seat else null)
	if not visible_from_seat:
		return
	_mirror_interval -= delta
	if _mirror_interval > 0.0:
		return
	var refresh_rate := 12.0 if WaveSettings.graphics.post_effects else 8.0
	if _car.velocity.length_squared() < 0.75:
		refresh_rate = 2.5
	elif Engine.get_frames_per_second() < 27.0:
		refresh_rate = minf(refresh_rate, 5.0)
	_mirror_interval = 1.0 / refresh_rate
	var yaw := Basis(Vector3.UP, _car.get_heading() + PI)
	var eye := _car.to_global(Vector3(0, 1.15, 1.66))
	_mirror_camera.global_transform = Transform3D(yaw, eye)
	_mirror_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _make_wiper(body: Material) -> void:
	_wiper = Node3D.new()
	_wiper.name = "WindshieldWiper"
	_wiper.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_parent().add_child.call_deferred(_wiper)
	_wiper.position = Vector3(0.16, 0.462, -0.674)
	_box(_wiper, Vector3(-0.195, 0.016, 0.010), Vector3(0.39, 0.011, 0.010), body)
	_box(_wiper, Vector3(-0.35, 0.019, 0.014), Vector3(0.28, 0.018, 0.012), body)


func _box(parent: Node3D, site: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = site
	part.material_override = material
	part.layers = ChaseCamera.PLAYER_MESH_LAYER
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
