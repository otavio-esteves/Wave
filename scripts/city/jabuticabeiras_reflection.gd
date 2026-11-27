extends Node

# A small secondary view renders the actual street about the road's local grade.
# The road itself is outside the capture layer to avoid sampling its own viewport.
const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const CAPTURE_LAYER := 1 << 13
const VEHICLE_LAYER := 1 << 15

var _materials: Array[ShaderMaterial] = []
var _viewport: SubViewport
var _camera: Camera3D
var _remaining := 0.0
var _interval := 1.0 / 23.0


func configure(materials: Array[ShaderMaterial], enabled: bool, quality: bool) -> void:
	_materials = materials
	for material in _materials:
		material.set_shader_parameter("use_street_reflection", false)
	_remaining = 0.0
	set_process(enabled)
	if not enabled:
		if _viewport != null:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _viewport == null:
		_create_view()
	_viewport.size = Vector2i(512, 288) if quality else Vector2i(288, 162)
	_camera.far = 164.0 if quality else 104.0
	_camera.cull_mask = CAPTURE_LAYER | VEHICLE_LAYER if quality else CAPTURE_LAYER
	_interval = 1.0 / (30.0 if quality else 17.0)


func _create_view() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "StreetReflectionView"
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	_viewport.mesh_lod_threshold = 3.1
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.cull_mask = CAPTURE_LAYER
	_camera.current = true
	_camera.far = 210.0
	_camera.near = 0.084
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_camera)
	for material in _materials:
		material.set_shader_parameter("street_reflection", _viewport.get_texture())


func _exit_tree() -> void:
	for material in _materials:
		material.set_shader_parameter("use_street_reflection", false)
		material.set_shader_parameter("street_reflection", null)


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0:
		return
	var main := get_viewport().get_camera_3d()
	if main == null:
		return
	var eye := main.get_camera_transform()
	var site := Layout.coordinates(Vector2(eye.origin.x, eye.origin.z))
	var station := clampf(site.y + 3.0, 0.5, Layout.LENGTH - 0.5)
	var left_to_right := Layout.right(station)
	var across := Vector3(left_to_right.x, 0.0, left_to_right.y)
	var along := Layout.position_at(station + 0.48, 0.0) - Layout.position_at(station - 0.48, 0.0)
	var normal := across.cross(along).normalized()
	var plane := Plane(normal, Layout.position_at(station, 0.0, -0.046))
	var perspective := Basis(-_reflected(eye.basis.x, normal),
		_reflected(eye.basis.y, normal), _reflected(eye.basis.z, normal))
	var reflected_eye := eye.origin - normal * 2.0 * plane.distance_to(eye.origin)
	_camera.global_transform = Transform3D(perspective.orthonormalized(), reflected_eye)
	_camera.keep_aspect = main.keep_aspect
	_camera.fov = main.fov
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var matrix := _camera.get_camera_projection() * Projection(_camera.get_camera_transform().affine_inverse())
	for material in _materials:
		material.set_shader_parameter("street_reflection_matrix", matrix)
		material.set_shader_parameter("use_street_reflection", true)
	_remaining = _interval


func _reflected(direction: Vector3, normal: Vector3) -> Vector3:
	return direction - 2.0 * direction.dot(normal) * normal
