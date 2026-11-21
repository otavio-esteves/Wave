extends "res://scripts/city/neighborhood_day_night.gd"

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const LAMP_GLOW = preload("res://assets/shaders/figueiras/lamp_glow.gdshader")
const LAMP_ACTIVE_LIMIT := 4
const LAMP_TRANSITION_SLOTS := 2
const LAMP_REFRESH_SECONDS := 0.125
const LAMP_FADE_SECONDS := 0.32
const LAMP_ACTIVATION_DISTANCE := 76.0
const LAMP_MOVE_SNAP_DISTANCE := 40.0
const MIN_LAMP_PHASE := 0.002

var _shop_glass: Array[ShaderMaterial] = []
var _fountain: ShaderMaterial
var _water_time := 0.0
var _sun_shadows_requested := false
var _lamp_aims: Array[Vector3] = []
var _park_lamps: Array[bool] = []
var _target_lamps: Array[int] = []
var _lamp_assignments := PackedInt32Array()
var _lamp_weights := PackedFloat32Array()
var _lamp_glows: Array[ShaderMaterial] = []
var _glow_quad := QuadMesh.new()
var _last_lamp_sample := Vector3.INF
var _snap_lamps := true
var _lamps_fading := false


func _ready() -> void:
	_glow_quad.size = Vector2(2.0, 2.0)
	_lamp_assignments.resize(_lamp_pool_capacity())
	_lamp_assignments.fill(-1)
	_lamp_weights.resize(_lamp_pool_capacity())
	var world := get_parent()
	var copies: Dictionary[ShaderMaterial, ShaderMaterial] = {}
	for node in world.get_node("City").get_children():
		if not node is GeometryInstance3D or not node.material_override is ShaderMaterial:
			continue
		var original: ShaderMaterial = node.material_override
		if not original.resource_name.begins_with("figueiras_shop") and original.resource_name != "figueiras_water":
			continue
		if not copies.has(original):
			var material := original.duplicate() as ShaderMaterial
			copies[original] = material
			if original.resource_name == "figueiras_water":
				_fountain = material
			else:
				_shop_glass.append(material)
		node.material_override = copies[original]
	super._ready()
	_environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 4.5
	_environment.ambient_light_sky_contribution = 0.34
	_environment.adjustment_contrast = 1.042
	_environment.adjustment_saturation = 0.96


func _process(delta: float) -> void:
	super._process(delta)
	_advance_lamp_fades(delta)
	if _fountain != null:
		_water_time += delta
		_fountain.set_shader_parameter("wave_time", _water_time)


func set_hour(value: float) -> void:
	_snap_lamps = true
	super.set_hour(value)


func set_sun_shadows_enabled(enabled: bool) -> void:
	_sun_shadows_requested = enabled
	if _sun != null:
		_update_sun_shadows()


func _update_lighting() -> void:
	super._update_lighting()
	_sun.light_energy *= 0.87 * smoothstep(0.0, 0.095, sun_direction.y)
	_moon.light_energy *= 0.70 * smoothstep(0.0, 0.14, -sun_direction.y)
	_sun.visible = _sun.light_energy > 0.0
	_moon.visible = _moon.light_energy > 0.0
	_update_sun_shadows()
	_environment.tonemap_exposure = lerpf(1.37, 1.08, daylight)
	_environment.ambient_light_energy = lerpf(0.245, 0.49, daylight)
	_environment.fog_light_color = _environment.fog_light_color.lerp(Color("a3b3c2"), daylight * 0.29)
	for glass in _shop_glass:
		glass.set_shader_parameter("light_inside", night_factor)


func _update_sun_shadows() -> void:
	var opacity := smoothstep(0.035, 0.18, sun_direction.y)
	_sun.shadow_opacity = opacity
	_sun.shadow_enabled = _sun_shadows_requested and _sun.visible and opacity > 0.0
	_moon.shadow_enabled = false


func _register_lamp(marker: Marker3D) -> void:
	super._register_lamp(marker)
	var position := marker.global_position
	var authored_aim: Variant = marker.get_meta("lamp_aim", Vector3.DOWN)
	var aim := Vector3.DOWN
	if authored_aim is Vector3 and authored_aim.is_finite() and not authored_aim.is_zero_approx():
		aim = authored_aim.normalized()
	_lamp_aims.append((marker.global_basis * aim).normalized())
	_park_lamps.append(position.y - Layout.height_at(Vector2(position.x, position.z)) < 4.0)


func _create_lamp() -> Light3D:
	var light := SpotLight3D.new()
	light.light_specular = 0.30
	light.spot_attenuation = 1.16
	light.spot_angle_attenuation = 1.75
	light.light_bake_mode = Light3D.BAKE_DISABLED
	var material := ShaderMaterial.new()
	material.shader = LAMP_GLOW
	var glow := MeshInstance3D.new()
	glow.mesh = _glow_quad
	glow.material_override = material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position.z = 0.13
	light.add_child(glow)
	_lamp_glows.append(material)
	return light


func _lamp_pool_capacity() -> int:
	return mini(street_light_count, LAMP_ACTIVE_LIMIT) + LAMP_TRANSITION_SLOTS if street_light_count > 0 else 0


func _lamp_refresh_interval() -> float:
	return LAMP_REFRESH_SECONDS


func _update_lamps() -> void:
	if night_factor <= MIN_LAMP_PHASE or _pool.is_empty():
		_snap_lamps = true
		return
	var car := get_parent().get_node("PlayerCar") as PlayerCar
	var sample := car.global_position
	var forward := -car.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# Start feeding the next pool into the road visible ahead of the car.
	var look_ahead := clampf(car.velocity.dot(forward) * LAMP_REFRESH_SECONDS, 0.0, 8.0)
	var selected := _nearby_lamps(sample + forward * look_ahead)
	var snap := _snap_lamps or not _last_lamp_sample.is_finite() or _last_lamp_sample.distance_to(sample) > LAMP_MOVE_SNAP_DISTANCE
	_snap_lamps = false
	_last_lamp_sample = sample
	if snap:
		_target_lamps = selected
		_lamp_assignments.fill(-1)
		_lamp_weights.fill(0.0)
		for slot in selected.size():
			_assign_lamp(slot, selected[slot])
			_lamp_weights[slot] = 1.0
		_update_lamp_energy()
		_lamps_fading = false
	elif selected != _target_lamps:
		_target_lamps = selected
		_fill_lamp_slots()
		_lamps_fading = true


func _nearby_lamps(point: Vector3) -> Array[int]:
	var candidates: Array[int] = []
	var distances: Dictionary[int, float] = {}
	for anchor in _lamps.size():
		var distance := _lamps[anchor].distance_to(point)
		if distance < LAMP_ACTIVATION_DISTANCE:
			candidates.append(anchor)
			distances[anchor] = distance - (2.0 if _target_lamps.has(anchor) else 0.0)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		if distances[a] == distances[b]:
			return a < b
		return distances[a] < distances[b]
	)
	return candidates.slice(0, mini(street_light_count, LAMP_ACTIVE_LIMIT))


func _assign_lamp(slot: int, anchor: int) -> void:
	_lamp_assignments[slot] = anchor
	var light := _pool[slot] as SpotLight3D
	var aim := _lamp_aims[anchor]
	var up := Vector3.FORWARD if absf(aim.y) > 0.95 else Vector3.UP
	var park_lamp := _park_lamps[anchor]
	light.position = _lamps[anchor]
	light.basis = Basis.looking_at(aim, up)
	light.light_color = Color("ffce93") if park_lamp else Color("ffd6a5")
	light.spot_range = 14.0 if park_lamp else 32.0
	light.spot_angle = 75.0 if park_lamp else 72.0
	_lamp_glows[slot].set_shader_parameter("light_color", light.light_color)
	_lamp_glows[slot].set_shader_parameter("radius", 0.51 if park_lamp else 0.93)


func _fill_lamp_slots() -> void:
	for anchor in _target_lamps:
		if _lamp_assignments.has(anchor):
			continue
		var slot := _lamp_assignments.find(-1)
		if slot < 0:
			return
		_assign_lamp(slot, anchor)


func _advance_lamp_fades(delta: float) -> void:
	if not _lamps_fading or night_factor <= MIN_LAMP_PHASE:
		return
	_fill_lamp_slots()
	var pending := false
	for slot in _pool.size():
		var anchor := _lamp_assignments[slot]
		if anchor < 0:
			continue
		var target := 1.0 if _target_lamps.has(anchor) else 0.0
		_lamp_weights[slot] = move_toward(_lamp_weights[slot], target, delta / LAMP_FADE_SECONDS)
		_apply_lamp_energy(slot)
		if target == 0.0 and _lamp_weights[slot] == 0.0:
			_lamp_assignments[slot] = -1
		pending = pending or _lamp_weights[slot] != target
	_lamps_fading = pending or _target_lamps.any(func(anchor: int) -> bool: return not _lamp_assignments.has(anchor))


func _update_lamp_energy() -> void:
	for slot in _pool.size():
		_apply_lamp_energy(slot)


func _apply_lamp_energy(slot: int) -> void:
	var anchor := _lamp_assignments[slot]
	var energy := 0.0
	var intensity := 0.0
	if anchor >= 0 and night_factor > MIN_LAMP_PHASE:
		var power := 1.10 if _park_lamps[anchor] else 4.90
		intensity = night_factor * smoothstep(0.0, 1.0, _lamp_weights[slot])
		energy = power * intensity
	var light := _pool[slot]
	light.light_energy = energy
	_lamp_glows[slot].set_shader_parameter("strength", intensity * 0.24)
	light.visible = energy > 0.0
