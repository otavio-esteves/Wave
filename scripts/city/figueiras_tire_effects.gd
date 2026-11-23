extends Node3D

const MARK_LIMIT := 192
const MARK_SPACING := 0.36
const MARK_WIDTH := 0.087
const CULL_DISTANCE := 62.0
const CLOUD_SHADER = preload("res://assets/shaders/figueiras/tire_cloud.gdshader")
const RUBBER_SHADER = preload("res://assets/shaders/figueiras/rubber_on_road.gdshader")
const MARK_UV := [Vector2.ZERO, Vector2.DOWN, Vector2.RIGHT, Vector2.ONE]
const CLOUD_LIMIT := 38
const CLOUD_LIFETIME := 1.08
const MARK_UPLOAD_INTERVAL := 1.0 / 30.0

class Puff:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var age := 0.0
	var strength := 0.0
	var angle := 0.0
	var loose := false
	var spray := false

var _car: PlayerCar
var _last_contact: Array[Vector3] = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
var _emission_delay := Vector4.ZERO
var _marks: Array[PackedVector3Array] = []
var _puffs: Array[Puff] = []
var _pool: Array[Puff] = []
var _opacities := PackedFloat32Array()
var _map_mesh := ArrayMesh.new()
var _mark_instance := MeshInstance3D.new()
var _mark_finish := ShaderMaterial.new()
var _cloud := MultiMeshInstance3D.new()
var _cloud_material := ShaderMaterial.new()
var _cloud_interval := 0.073
var _daylight := -1.0
var _random := RandomNumberGenerator.new()
var _marks_dirty := false
var _mark_upload_delay := 0.0


func _ready() -> void:
	_car = get_parent().get_node("PlayerCar")
	_car.car_reset.connect(clear)
	_mark_finish.shader = RUBBER_SHADER
	_mark_instance.name = "Rubber"
	_mark_instance.mesh = _map_mesh
	_mark_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark_instance)
	_random.seed = 3141
	_pool.resize(CLOUD_LIMIT)
	for index in CLOUD_LIMIT:
		_pool[index] = Puff.new()
	_make_cloud()


func set_material_detail(enabled: bool) -> void:
	_cloud_interval = 0.048 if enabled else 0.086


func _physics_process(delta: float) -> void:
	var speed := _car.get_speed_kmh() / 3.6
	for index in 4:
		var contact := _car.tire_contact(index)
		_emission_delay[index] = maxf(0.0, _emission_delay[index] - delta)
		if contact.is_empty() or _car.wheel_loads[index] < 0.035:
			_last_contact[index] = Vector3.INF
			continue
		var asphalt: bool = contact.get("surface", "") == "asfalto"
		var loose: bool = contact.get("surface", "") in ["gramado", "acostamento"]
		var spray := asphalt and float(contact.get("wetness", _car.road_wetness)) > 0.5 and speed > 5.8
		var scrub := _car.tire_scrub(index)
		var active := spray or asphalt and scrub > 0.20 or loose and speed > 5.6
		if active:
			var density := smoothstep(5.6, 19.0, speed) if spray or loose else scrub
			if _emission_delay[index] <= 0.0:
				_spawn_puff(contact.position + contact.normal * 0.20, density, loose, spray)
				_emission_delay[index] = _cloud_interval * (1.35 if index < 2 and (spray or loose) else 1.0)
		if asphalt and not spray and scrub > 0.29:
			_marks_dirty = _add_mark(index, contact, scrub) or _marks_dirty
		else:
			_last_contact[index] = Vector3.INF
	_mark_upload_delay = maxf(0.0, _mark_upload_delay - delta)
	if _marks_dirty and _mark_upload_delay <= 0.0:
		_draw_marks()
		_marks_dirty = false
		_mark_upload_delay = MARK_UPLOAD_INTERVAL
	_update_cloud(delta)


func set_daylight(value: float) -> void:
	var tint := smoothstep(0.0, 0.75, value)
	if not is_equal_approx(_daylight, tint):
		_daylight = tint
		_cloud_material.set_shader_parameter("daylight", tint)


func _add_mark(index: int, contact: Dictionary, strength: float) -> bool:
	var position: Vector3 = contact.position + contact.normal * 0.017
	var last := _last_contact[index]
	if not last.is_finite() or position.distance_squared_to(last) > 3.24:
		_last_contact[index] = position
		return false
	if position.distance_squared_to(last) < MARK_SPACING * MARK_SPACING:
		return false
	var side := (position - last).cross(contact.normal).normalized() * MARK_WIDTH
	_marks.append(PackedVector3Array([last - side, position - side, last + side, position + side]))
	_opacities.append(lerpf(0.13, 0.44, strength))
	if _marks.size() > MARK_LIMIT:
		_marks.pop_front()
		_opacities.remove_at(0)
	_last_contact[index] = position
	return true


func _draw_marks() -> void:
	_map_mesh.clear_surfaces()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var point := _car.global_position
	for index in _marks.size():
		var mark := _marks[index]
		if mark[0].distance_squared_to(point) > CULL_DISTANCE * CULL_DISTANCE:
			continue
		var strength := _opacities[index] * smoothstep(0.0, 28.0, MARK_LIMIT - _marks.size() + index)
		var start := vertices.size()
		vertices.append_array(mark)
		for uv: Vector2 in MARK_UV:
			colors.append(Color(1.0, 1.0, 1.0, strength))
			uvs.append(uv)
		indices.append(start)
		indices.append(start + 1)
		indices.append(start + 2)
		indices.append(start + 2)
		indices.append(start + 1)
		indices.append(start + 3)
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_map_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_map_mesh.surface_set_material(0, _mark_finish)


func clear() -> void:
	_marks.clear()
	_pool.append_array(_puffs)
	_puffs.clear()
	_opacities.clear()
	_last_contact.fill(Vector3.INF)
	_emission_delay = Vector4.ZERO
	_marks_dirty = false
	_mark_upload_delay = 0.0
	_map_mesh.clear_surfaces()
	_cloud.multimesh.visible_instance_count = 0


func _spawn_puff(position: Vector3, density: float, loose: bool, spray: bool) -> void:
	var puff: Puff = _puffs.pop_front() if _pool.is_empty() else _pool.pop_back()
	puff.age = 0.0
	puff.position = position
	puff.velocity = _car.velocity * 0.10 + Vector3(_random.randf_range(-0.85, 0.85), _random.randf_range(0.33, 0.89), _random.randf_range(-0.85, 0.85))
	puff.strength = lerpf(0.30, 0.59, density)
	puff.angle = _random.randf_range(-PI, PI)
	puff.loose = loose
	puff.spray = spray
	if spray:
		puff.velocity += _car.global_basis.z * 3.5 + Vector3.UP * 0.65
		puff.strength *= 0.70
	# Recycle an old cloud whenever all slots are occupied.
	_puffs.append(puff)


func _update_cloud(delta: float) -> void:
	var instances := _cloud.multimesh
	if _puffs.is_empty() and instances.visible_instance_count == 0:
		return
	for index in range(_puffs.size() - 1, -1, -1):
		var puff := _puffs[index]
		puff.age += delta
		if puff.age >= CLOUD_LIFETIME:
			_pool.append(puff)
			_puffs.remove_at(index)
	for index in _puffs.size():
		var puff := _puffs[index]
		puff.position += puff.velocity * delta
		var age := puff.age / CLOUD_LIFETIME
		if puff.spray:
			age = minf(1.0, age * 1.7)
		var expansion := lerpf(0.51, 2.15, smoothstep(0.0, 1.0, age))
		var opacity := puff.strength * smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(0.40, 1.0, age))
		instances.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * expansion), puff.position))
		instances.set_instance_custom_data(index, Color(opacity, float(puff.loose), puff.angle + age * 0.45, float(puff.spray)))
	instances.visible_instance_count = _puffs.size()


func _make_cloud() -> void:
	const SIZE := 96
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.062
	noise.fractal_octaves = 3
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var radius := Vector2(x, y).distance_to(Vector2.ONE * (SIZE - 1) * 0.5) / (SIZE * 0.5)
			var cloud := clampf(0.58 + noise.get_noise_2d(x, y) * 0.60, 0.0, 1.0)
			var opacity := (1.0 - smoothstep(0.14, 1.0, radius)) * cloud
			image.set_pixel(x, y, Color(1, 1, 1, opacity))
	image.generate_mipmaps()
	_cloud_material.shader = CLOUD_SHADER
	_cloud_material.set_shader_parameter("cloud", ImageTexture.create_from_image(image))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = quad
	instances.instance_count = CLOUD_LIMIT
	instances.visible_instance_count = 0
	instances.custom_aabb = AABB(Vector3(-440.0, -8.0, -424.0), Vector3(880.0, 185.0, 848.0))
	_cloud.name = "TireCloud"
	_cloud.multimesh = instances
	_cloud.material_override = _cloud_material
	_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud)
