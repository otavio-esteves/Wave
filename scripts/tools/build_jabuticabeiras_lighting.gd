extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const GroundShadow = preload("res://scripts/tools/build_jabuticabeiras_ground_shadow.gd")
const SurfaceBake = preload("res://scripts/tools/build_jabuticabeiras_shadows.gd")
const BOUNDS := Rect2(-22.0, -174.0, 48.0, 188.0)
const GRID := Vector2i(58, 224)
const TILES := Vector2i(3, 3)
const HEIGHTS := [0.23, 0.91, 1.68, 2.64, 3.74, 5.12, 6.85, 9.45]
const RAY_COUNT := 32
const MAX_DISTANCE := 12.0
const MASK := 1 << 20

var _proxy: StaticBody3D
var _space: PhysicsDirectSpaceState3D
var _query := PhysicsRayQueryParameters3D.new()
var _hemisphere := PackedVector3Array()
var _sunbeam := PackedVector3Array()
var _lamp_sites: Array[Vector4] = []
var _lamp_ranges := PackedFloat32Array()
var _local_lamps: Array[int] = []
var _sky_weight := 0.0


func prepare(map: Node3D) -> void:
	_proxy = StaticBody3D.new()
	_proxy.collision_layer = MASK
	_proxy.collision_mask = 0
	_proxy.name = "StaticLightBake"
	map.add_child(_proxy)
	for node in map.get_children():
		if node is MeshInstance3D and (str(node.name).begins_with("Alvenaria_") or node.has_meta("bake_occluder")):
			_shape(node.mesh.create_trimesh_shape(), node.transform)
		elif node is OmniLight3D:
			_lamp_sites.append(Vector4(node.position.x, node.position.y, node.position.z, node.light_energy))
			_lamp_ranges.append(node.omni_range)
	for body in [map.get_node("StreetSupport"), map.get_node("StreetObjects")]:
		for node: CollisionShape3D in body.get_children():
			if node.shape is BoxShape3D:
				var size: Vector3 = node.shape.size
				# Baked walls use their rendered geometry. The coarse vehicle
				# hulls would seal the shop fronts, arches and recesses.
				if size.y >= 2.80 and size.x > 3.0 and size.z > 2.3:
					continue
			_shape(node.shape, body.transform * node.transform)
	_query.collision_mask = MASK
	_query.hit_back_faces = true
	_directions()


func _shape(shape: Shape3D, frame: Transform3D) -> void:
	if shape == null:
		return
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = frame
	_proxy.add_child(collision)


func _directions() -> void:
	var sun := Layout.SUN_DIRECTION.normalized()
	var across := sun.cross(Vector3.UP).normalized()
	var vertical := across.cross(sun).normalized()
	_sunbeam = PackedVector3Array([
		(sun - across * 0.028).normalized(), sun, (sun + vertical * 0.032).normalized(),
	])
	for index in RAY_COUNT:
		var y := 1.0 - (index + 0.5) * 2.0 / RAY_COUNT
		var angle := index * 2.3999632297
		var radial := sqrt(1.0 - y * y)
		_hemisphere.append(Vector3(radial * cos(angle), y, radial * sin(angle)))
		_sky_weight += maxf(y, 0.0)


func bake(map: Node3D) -> void:
	_space = map.get_world_3d().direct_space_state
	var stride := GRID + Vector2i(2, 2)
	var atlas_size := stride * TILES
	var lighting := PackedByteArray()
	var direction := PackedByteArray()
	lighting.resize(atlas_size.x * atlas_size.y * 4)
	direction.resize(lighting.size())
	var start := Time.get_ticks_msec()
	for slice in HEIGHTS.size():
		var offset := Vector2i((slice % TILES.x) * stride.x, (slice / TILES.x) * stride.y)
		for row in GRID.y:
			var z := BOUNDS.position.y + (float(row) + 0.5) * BOUNDS.size.y / GRID.y
			var height: float = Layout.grade(-z) + HEIGHTS[slice]
			_lamps_in_row(z)
			for column in GRID.x:
				var x := BOUNDS.position.x + (float(column) + 0.5) * BOUNDS.size.x / GRID.x
				var site := Vector3(x, height, z)
				var pixel := ((offset.y + 1 + row) * atlas_size.x + offset.x + 1 + column) * 4
				var result := _sample(site)
				var values: Vector4 = result[0]
				var bent: Vector3 = result[1]
				for channel in 4:
					lighting[pixel + channel] = roundi(clampf(values[channel], 0.0, 1.0) * 255.0)
				for channel in 3:
					direction[pixel + channel] = roundi(clampf(bent[channel] * 0.5 + 0.5, 0.0, 1.0) * 255.0)
				direction[pixel + 3] = 255
		_border(lighting, atlas_size.x, offset)
		_border(direction, atlas_size.x, offset)
		print("Iluminação da rua: fatia %d/%d em %.1f s" % [slice + 1, HEIGHTS.size(), (Time.get_ticks_msec() - start) / 1000.0])
	var volume := ImageTexture.create_from_image(Image.create_from_data(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8, lighting))
	var bent_volume := ImageTexture.create_from_image(Image.create_from_data(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8, direction))
	var ground_sun := GroundShadow.new().bake(map, _space, MASK, _sunbeam)
	print("Sombra da rua: %dx%d em %.1f s" % [GroundShadow.SIZE.x, GroundShadow.SIZE.y, (Time.get_ticks_msec() - start) / 1000.0])
	_apply(map, volume, bent_volume, ground_sun)
	_proxy.free()


func _lamps_in_row(z: float) -> void:
	_local_lamps.clear()
	for index in _lamp_sites.size():
		if absf(z - _lamp_sites[index].z) < _lamp_ranges[index] * 1.33:
			_local_lamps.append(index)


func _sample(site: Vector3) -> Array:
	var sky := 0.0
	var bounce := 0.0
	var bent := Vector3.ZERO
	for index in RAY_COUNT:
		var direction := _hemisphere[index]
		var hit := _cast(site, site + direction * MAX_DISTANCE)
		var openness := 1.0
		if not hit.is_empty():
			var separation: float = site.distance_to(hit.position)
			openness = smoothstep(1.8, MAX_DISTANCE, separation) * 0.72
			if index % 4 == 1:
				var normal: Vector3 = hit.normal
				var from: Vector3 = hit.position + normal * 0.055
				var sun := _sunbeam[1]
				var incidence := maxf(normal.dot(sun), 0.0)
				var diffuse := 0.20 + maxf(normal.y, 0.0) * 0.25
				if incidence > 0.08 and _cast(from, from + sun * 35.0).is_empty():
					diffuse += incidence * 0.67
				bounce += diffuse * (1.0 - smoothstep(0.0, MAX_DISTANCE, separation))
		sky += maxf(direction.y, 0.0) * openness
		bent += direction * openness

	var sunlight := 0.0
	for ray in _sunbeam:
		if _cast(site, site + ray * 42.0).is_empty():
			sunlight += 1.0 / _sunbeam.size()

	var warm := 0.0
	for index in _local_lamps:
		var lamp := _lamp_sites[index]
		var light := Vector3(lamp.x, lamp.y, lamp.z)
		var reach := _lamp_ranges[index] * 1.32
		var distance := site.distance_to(light)
		if distance < reach and _cast(site, light).is_empty():
			var attenuation := 1.0 - smoothstep(0.28, reach, distance)
			warm += lamp.w * attenuation * attenuation * 0.75

	return [Vector4(sky / _sky_weight, warm, bounce * (4.0 / RAY_COUNT), sunlight),
		bent * (2.07 / RAY_COUNT)]


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_query.from = from
	_query.to = to
	return _space.intersect_ray(_query)


func _border(pixels: PackedByteArray, width: int, offset: Vector2i) -> void:
	for row in range(1, GRID.y + 1):
		var first := ((offset.y + row) * width + offset.x) * 4
		var last := first + (GRID.x + 1) * 4
		for channel in 4:
			pixels[first + channel] = pixels[first + 4 + channel]
			pixels[last + channel] = pixels[last - 4 + channel]
	for column in range(GRID.x + 2):
		var first := (offset.y * width + offset.x + column) * 4
		var last := first + (GRID.y + 1) * width * 4
		for channel in 4:
			pixels[first + channel] = pixels[first + width * 4 + channel]
			pixels[last + channel] = pixels[last - width * 4 + channel]


func _apply(map: Node3D, volume: ImageTexture, bent: ImageTexture, ground_sun: PackedByteArray) -> void:
	var materials: Array[ShaderMaterial] = []
	var packed_ground: ImageTexture
	for child in map.get_children():
		if not child is GeometryInstance3D:
			continue
		var material := child.material_override as ShaderMaterial
		if material == null and child is MeshInstance3D and child.mesh != null:
			material = child.mesh.surface_get_material(0) as ShaderMaterial
		if material == null or material in materials:
			continue
		var path := material.shader.resource_path.get_file()
		if path not in ["masonry.gdshader", "pavement.gdshader", "leaves.gdshader", "shop_glass.gdshader"]:
			continue
		materials.append(material)
		material.set_shader_parameter("street_light_volume", volume)
		material.set_shader_parameter("street_light_bent", bent)
		material.set_shader_parameter("street_light_bounds", Vector4(BOUNDS.position.x, BOUNDS.position.y, BOUNDS.size.x, BOUNDS.size.y))
		material.set_shader_parameter("street_light_grid", Vector2(GRID))
		material.set_shader_parameter("has_street_light", true)
		if path == "pavement.gdshader":
			if packed_ground == null:
				packed_ground = _pack_ground_sun(material.get_shader_parameter("surface_bake"), ground_sun)
			material.set_shader_parameter("surface_bake", packed_ground)
			material.set_shader_parameter("has_ground_sun", true)
	map.set_meta("light_samples", GRID.x * GRID.y * HEIGHTS.size())
	map.set_meta("light_bake_rays", RAY_COUNT)


func _pack_ground_sun(source: Texture2D, ground_sun: PackedByteArray) -> ImageTexture:
	var former := source.get_image()
	former.clear_mipmaps()
	var payload := former.get_data()
	var size := former.get_size()
	# Both fields use six texels per metre. Replace only the sun channel;
	# the contact, material wear and practical-light channels share this map.
	var offset := Vector2i((GroundShadow.BOUNDS.position - SurfaceBake.BOUNDS.position) * SurfaceBake.PIXELS_PER_METER)
	for y in GroundShadow.SIZE.y:
		var old_row := (offset.y + y) * size.x + offset.x
		var new_row := y * GroundShadow.SIZE.x
		for x in GroundShadow.SIZE.x:
			payload[(old_row + x) * 4] = ground_sun[new_row + x]
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, payload)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
