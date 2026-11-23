extends "res://scripts/city/neighborhood_day_night.gd"

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const LAMP_GLOW = preload("res://assets/shaders/figueiras/lamp_glow.gdshader")
const DISTANT_HILLS = preload("res://assets/shaders/figueiras/distant_hills.gdshader")
const LAMP_ACTIVE_LIMIT := 4
const LAMP_TRANSITION_SLOTS := 2
const LAMP_REFRESH_SECONDS := 0.125
const LAMP_FADE_SECONDS := 0.32
const LAMP_ACTIVATION_DISTANCE := 76.0
const LAMP_MOVE_SNAP_DISTANCE := 40.0
const MIN_LAMP_PHASE := 0.002
const CANOPY_PATTERN = preload("res://assets/textures/pilot/finish-grass-albedo.res")
const RAIN_PANORAMA = preload("res://assets/textures/figueiras/ceu-de-chuva.png")

var horizon_color := Color("b1bcc2")
var zenith_color := Color("7190af")

var _shop_glass: Array[ShaderMaterial] = []
var _fountain: ShaderMaterial
var _lake: ShaderMaterial
var _creek: ShaderMaterial
var _hills: ShaderMaterial
var _gallery_lights: Array[OmniLight3D] = []
var _water_time := 0.0
var _civic_hands: Array[Node3D] = []
var _rain_road_lamps := PackedVector4Array()
var _overcast := 0.0
var _sun_shadows_requested := false
var _soften_rain_shadows := true
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
	var backdrop := world.get_node_or_null("City/EncostasAoFundo") as MeshInstance3D
	if backdrop != null:
		_hills = ShaderMaterial.new()
		_hills.shader = DISTANT_HILLS
		_hills.set_shader_parameter("canopy_pattern", CANOPY_PATTERN)
		backdrop.material_override = _hills
	for light in world.get_node("City").find_children("GalleryLight_*", "OmniLight3D", false, false):
		_gallery_lights.append(light)
	var copies: Dictionary[ShaderMaterial, ShaderMaterial] = {}
	for node in world.get_node("City").get_children():
		if not node is GeometryInstance3D or not node.material_override is ShaderMaterial:
			continue
		var original: ShaderMaterial = node.material_override
		if not original.resource_name.begins_with("figueiras_shop") and original.resource_name not in ["figueiras_water", "figueiras_lake", "figueiras_creek"]:
			continue
		if not copies.has(original):
			var material := original.duplicate() as ShaderMaterial
			copies[original] = material
			if original.resource_name == "figueiras_water":
				_fountain = material
			elif original.resource_name == "figueiras_lake":
				_lake = material
			elif original.resource_name == "figueiras_creek":
				_creek = material
			else:
				_shop_glass.append(material)
		node.material_override = copies[original]
	_install_clock(world.get_node_or_null("City/CivicClock"))
	super._ready()
	_sky.set_shader_parameter("rain_panorama", RAIN_PANORAMA)
	_environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.ambient_light_sky_contribution = 0.19
	_environment.adjustment_contrast = 1.04
	_environment.glow_intensity = 0.24
	_environment.glow_hdr_threshold = 1.14
	_environment.glow_hdr_scale = 0.84


func _process(delta: float) -> void:
	super._process(delta)
	_advance_lamp_fades(delta)
	_water_time += delta
	if _fountain != null:
		_fountain.set_shader_parameter("wave_time", _water_time)
	if _lake != null:
		_lake.set_shader_parameter("wave_time", _water_time)
	if _creek != null:
		_creek.set_shader_parameter("wave_time", _water_time)


func set_hour(value: float) -> void:
	_snap_lamps = true
	super.set_hour(value)


func set_sun_shadows_enabled(enabled: bool, soften_rain: bool) -> void:
	_sun_shadows_requested = enabled
	_soften_rain_shadows = soften_rain
	if _sun != null:
		_update_sun_shadows()


func set_overcast(amount: float) -> void:
	if amount == _overcast or (absf(amount - _overcast) < 0.014 and amount not in [0.0, 1.0]):
		return
	_overcast = amount
	_sky.set_shader_parameter("overcast", amount)
	if _player_body != null:
		_player_body.set_instance_shader_parameter("reflection_overcast", amount)
	_update_lighting()


func reflected_lamps() -> PackedVector4Array:
	_rain_road_lamps.clear()
	var phase := _street_light_phase()
	if phase <= MIN_LAMP_PHASE:
		return _rain_road_lamps
	for slot in _pool.size():
		var anchor := _lamp_assignments[slot]
		if anchor >= 0 and not _park_lamps[anchor]:
			var intensity := phase * smoothstep(0.0, 1.0, _lamp_weights[slot])
			if intensity > 0.012:
				var point := _lamps[anchor]
				_rain_road_lamps.append(Vector4(point.x, point.y, point.z, intensity))
	return _rain_road_lamps


func _street_light_phase() -> float:
	return maxf(night_factor, smoothstep(0.52, 1.0, _overcast) * 0.68)


func _update_lighting() -> void:
	super._update_lighting()
	if _civic_hands.size() == 2:
		_civic_hands[0].rotation.z = -hour / 12.0 * TAU
		_civic_hands[1].rotation.z = -fposmod(hour, 1.0) * TAU
	_sun.light_energy *= lerpf(1.03, 0.30, _overcast) * smoothstep(0.0, 0.095, sun_direction.y)
	var low_sun := 1.0 - smoothstep(0.06, 0.36, sun_direction.y)
	_sun.light_color = _sun.light_color.lerp(Color("ffddbc"), low_sun * 0.46)
	_sun.light_color = _sun.light_color.lerp(Color("e1e8ef"), _overcast * 0.80)
	_moon.light_energy *= 0.64 * smoothstep(0.0, 0.14, -sun_direction.y)
	_sun.visible = _sun.light_energy > 0.0
	_moon.visible = _moon.light_energy > 0.0
	_update_sun_shadows()
	_update_atmosphere()
	for glass in _shop_glass:
		glass.set_shader_parameter("light_inside", night_factor)
		glass.set_shader_parameter("outside_color", horizon_color)
	if _lake != null:
		_lake.set_shader_parameter("daylight", daylight)
		_lake.set_shader_parameter("sun_direction", sun_direction)
		_lake.set_shader_parameter("horizon", horizon_color)
		_lake.set_shader_parameter("zenith", zenith_color)
	if _creek != null:
		_creek.set_shader_parameter("daylight", daylight)
		_creek.set_shader_parameter("sun_direction", sun_direction)
		_creek.set_shader_parameter("horizon", horizon_color)
		_creek.set_shader_parameter("zenith", zenith_color)


func _update_atmosphere() -> void:
	var light_above_terrain := smoothstep(-0.23, 0.25, sun_direction.y)
	var afterglow := (1.0 - smoothstep(0.02, 0.36, absf(sun_direction.y))) * (1.0 - night_factor * 0.76)
	var clear_horizon := Color("354258").lerp(Color("bbc9ce"), light_above_terrain)
	clear_horizon = clear_horizon.lerp(Color("c3a48c"), afterglow * 0.72)
	var rain_horizon := Color("293744").lerp(Color("9baab3"), light_above_terrain)
	horizon_color = clear_horizon.lerp(rain_horizon, _overcast)
	var clear_zenith := Color("142238").lerp(Color("537ca0"), light_above_terrain)
	var rain_zenith := Color("141e29").lerp(Color("566776"), light_above_terrain)
	zenith_color = clear_zenith.lerp(rain_zenith, _overcast)
	if _sky.get_shader_parameter("horizon") != horizon_color:
		_sky.set_shader_parameter("horizon", horizon_color)
	if _sky.get_shader_parameter("zenith") != zenith_color:
		_sky.set_shader_parameter("zenith", zenith_color)
	_environment.tonemap_exposure = lerpf(1.17, 1.09, daylight)
	_environment.ambient_light_color = Color("65799b").lerp(Color("b8cbdc"), daylight).lerp(horizon_color, _overcast * 0.46)
	_environment.ambient_light_energy = lerpf(0.36, lerpf(0.57, 0.62, _overcast), daylight)
	var air := horizon_color.lerp(zenith_color, 0.18 + 0.24 * night_factor)
	_environment.fog_light_color = air
	_environment.fog_light_energy = lerpf(0.63, 0.83, daylight)
	_environment.fog_density = lerpf(0.48, 0.69, _overcast)
	_environment.fog_depth_begin = lerpf(lerpf(168.0, 110.0, afterglow), 72.0, _overcast)
	_environment.fog_depth_end = lerpf(lerpf(1480.0, 960.0, afterglow), 525.0, _overcast)
	_environment.adjustment_saturation = lerpf(1.03, 0.86, _overcast)
	if _hills != null:
		_hills.set_shader_parameter("air", air)
		_hills.set_shader_parameter("air_above", horizon_color.lerp(zenith_color, 0.61))
		_hills.set_shader_parameter("sun_direction", sun_direction)
		_hills.set_shader_parameter("daylight", daylight)
		_hills.set_shader_parameter("overcast", _overcast)


func _install_clock(pivot: Marker3D) -> void:
	if pivot == null:
		return
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("26332f")
	for index in 2:
		var hand := Node3D.new()
		hand.position.z = index * 0.021
		pivot.add_child(hand)
		var geometry := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var length := 0.44 if index == 0 else 0.61
		mesh.size = Vector3(0.076 if index == 0 else 0.050, length + 0.06, 0.025)
		geometry.mesh = mesh
		geometry.material_override = ink
		geometry.position.y = length * 0.5
		hand.add_child(geometry)
		_civic_hands.append(hand)


func _update_sun_shadows() -> void:
	var opacity := 0.88 * smoothstep(0.035, 0.18, sun_direction.y) * (1.0 - 0.84 * _overcast)
	if _soften_rain_shadows:
		opacity *= 1.0 - smoothstep(0.60, 0.90, _overcast)
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


func _update_gallery_lamps(point: Vector3) -> void:
	var detailed: bool = WaveSettings.graphics.material_detail
	var nearest: OmniLight3D
	var minimum := 31.0 * 31.0
	for light in _gallery_lights:
		var distance := light.global_position.distance_squared_to(point)
		if detailed:
			light.visible = distance < 19.0 * 19.0
		elif distance < minimum:
			minimum = distance
			nearest = light
	if not detailed:
		for light in _gallery_lights:
			light.visible = light == nearest


func _update_lamps() -> void:
	var car := get_parent().get_node("PlayerCar") as PlayerCar
	var sample := car.global_position
	_update_gallery_lamps(sample)
	if _street_light_phase() <= MIN_LAMP_PHASE or _pool.is_empty():
		_snap_lamps = true
		return
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
	if not _lamps_fading or _street_light_phase() <= MIN_LAMP_PHASE:
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
	var light_phase := _street_light_phase()
	if anchor >= 0 and light_phase > MIN_LAMP_PHASE:
		var power := 1.10 if _park_lamps[anchor] else 4.90
		intensity = light_phase * smoothstep(0.0, 1.0, _lamp_weights[slot])
		energy = power * intensity
	var light := _pool[slot]
	if not is_equal_approx(light.light_energy, energy):
		light.light_energy = energy
		_lamp_glows[slot].set_shader_parameter("strength", intensity * 0.24)
		light.visible = energy > 0.0
