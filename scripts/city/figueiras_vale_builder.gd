extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Route = preload("res://scripts/city/figueiras_route.gd")
const WATER = preload("res://assets/shaders/figueiras/lake.gdshader")
const ROCK = preload("res://assets/shaders/figueiras/bedrock.gdshader")
const BEDROCK = preload("res://assets/textures/figueiras/gnaisse-vale.png")
const CREEK_AUDIO = preload("res://assets/audio/wave-creek.wav")
const GALLERY_HALF := 6.35
const GALLERY_SPRING := 1.62
const GALLERY_RISE := 4.12
const ARCH_SEGMENTS := 12

var _city: RefCounted
var _ground: RefCounted
var _bedrock: ShaderMaterial


func build(city: RefCounted, ground: RefCounted) -> void:
	_city = city
	_ground = ground
	_setup_materials()
	var routes := Layout.scenic_routes()
	_gallery(routes[0])
	var creek_crossing := Layout.vale_bridge_station()
	_creek(routes[2], creek_crossing)
	_bridge(routes[2], creek_crossing)
	_orchard(routes[2])


func _setup_materials() -> void:
	_bedrock = ShaderMaterial.new()
	_bedrock.resource_name = "figueiras_bedrock"
	_bedrock.shader = ROCK
	_bedrock.set_shader_parameter("rock_albedo", BEDROCK)
	var rock_placeholder: StandardMaterial3D = _city.materials["stone"].duplicate()
	rock_placeholder.resource_name = "bedrock"
	_city.materials["bedrock"] = rock_placeholder
	_city._object_finishes["bedrock"] = _bedrock
	_city.meshes["vale_boulder"] = _boulder()
	var concrete := StandardMaterial3D.new()
	concrete.resource_name = "gallery_concrete"
	concrete.albedo_color = Color("a89b86")
	concrete.albedo_texture = _city.materials["stone"].albedo_texture
	concrete.vertex_color_use_as_albedo = true
	concrete.roughness = 0.93
	concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	_city.materials["gallery_concrete"] = concrete
	var lamp := StandardMaterial3D.new()
	lamp.resource_name = "gallery_lamp"
	lamp.albedo_color = Color("edc391")
	lamp.emission_enabled = true
	lamp.emission = Color("ffbf78")
	lamp.emission_energy_multiplier = 1.30
	_city.materials["gallery_lamp"] = lamp


func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _boulder() -> ArrayMesh:
	var surface := _surface()
	var rings: Array[PackedVector3Array] = []
	for ring in 3:
		var vertices := PackedVector3Array()
		for corner in 8:
			var angle := TAU * corner / 8.0 + ring * 0.15
			var distortion := 0.76 + 0.24 * sin(corner * 2.23 + ring * 2.7)
			var radius: float = [0.58, 0.69, 0.39][ring] * distortion
			vertices.append(Vector3(cos(angle) * radius + ring * 0.07, -0.36 + ring * 0.38 + 0.09 * cos(angle * 3.0), sin(angle) * radius))
		rings.append(vertices)
	surface.set_smooth_group(-1)
	for corner in 8:
		var next := (corner + 1) % 8
		for level in 2:
			_quad(surface, rings[level][corner], rings[level][next], rings[level + 1][next], rings[level + 1][corner])
		for point: Vector3 in [Vector3(0.18, 0.48, 0), rings[2][corner], rings[2][next]]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()


func _commit(surface: SurfaceTool, title: String, material: Material, casts_shadow := true) -> MeshInstance3D:
	surface.generate_normals()
	surface.index()
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = surface.commit()
	node.material_override = material
	if not casts_shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_city.scene_root.add_child(node)
	return node


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone_a := Color.WHITE, tone_b := Color.WHITE) -> void:
	var points := [a, b, c, d]
	for corner: int in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = points[corner]
		surface.set_color(tone_a if corner < 2 else tone_b)
		surface.set_uv(Vector2((point.x + point.z) * 0.36, point.y * 0.34))
		surface.add_vertex(point)


func _arch(route: Route, station: float, outside: bool, portal: bool) -> PackedVector3Array:
	var center := Layout.surface_point(route.point_at(station))
	var across := route.direction_at(station).orthogonal()
	var axis := Vector3(across.x, 0, across.y)
	var half := GALLERY_HALF + (1.25 if outside else 0.0)
	var ring := PackedVector3Array([center - axis * half - Vector3.UP * 0.78])
	for index in ARCH_SEGMENTS + 1:
		var angle := PI * index / ARCH_SEGMENTS
		var width := -cos(angle) * half
		var height := GALLERY_SPRING + sin(angle) * GALLERY_RISE
		if outside:
			var cap := 0.96 if portal else 1.35 + 0.32 * sin(station * 0.31 + angle * 5.3)
			height += sin(angle) * cap
		ring.append(center + axis * width + Vector3.UP * height)
	ring.append(center + axis * half - Vector3.UP * 0.78)
	return ring


func _gallery(route: Route) -> void:
	var inner_shell := _surface()
	var outer_shell := _surface()
	var portals := _surface()
	var start := Layout.GALLERY_START
	var end := Layout.GALLERY_END
	var previous_inner := _arch(route, start, false, true)
	var previous_outer := _arch(route, start, true, true)
	var shade := Color("b7afa1")
	var previous_tone := shade
	for offset in range(4, roundi(end - start) + 1, 4):
		var station := start + offset
		var portal := is_equal_approx(station, end)
		var inner := _arch(route, station, false, portal)
		var outer := _arch(route, station, true, portal)
		var tone := shade if portal else Color("80796e")
		for index in range(1, inner.size()):
			_quad(inner_shell, previous_inner[index], previous_inner[index - 1], inner[index - 1], inner[index], previous_tone, tone)
			_quad(outer_shell, previous_outer[index - 1], previous_outer[index], outer[index], outer[index - 1])
			if offset == 4:
				_quad(portals, previous_outer[index], previous_outer[index - 1], previous_inner[index - 1], previous_inner[index])
			if portal:
				_quad(portals, outer[index - 1], outer[index], inner[index], inner[index - 1])
		previous_inner = inner
		previous_outer = outer
		previous_tone = tone
	var interior := _commit(inner_shell, "GaleriaDaPedraInterior", _city.materials["gallery_concrete"], false)
	var collision := StaticBody3D.new()
	collision.name = "ApoioGaleriaDaPedra"
	var shape := CollisionShape3D.new()
	var shell := interior.mesh.create_trimesh_shape()
	shell.backface_collision = true
	shape.shape = shell
	collision.add_child(shape)
	_city.scene_root.add_child(collision)
	_commit(outer_shell, "GaleriaDaPedraRocha", _bedrock)
	_commit(portals, "GaleriaDaPedraPortais", _city.materials["gallery_concrete"])
	for station in range(roundi(start) + 4, roundi(end), 6):
		var forward := route.direction_at(station)
		var yaw := atan2(forward.x, forward.y)
		for side: float in [-1, 1]:
			var point := Layout.surface_point(route.offset_at(station, side * 2.30), 5.09)
			_city.add_box(point, Vector3(0.48, 0.15, 1.83), "metal", false, yaw, false)
			_city.add_box(point - Vector3.UP * 0.09, Vector3(0.38, 0.06, 1.60), "gallery_lamp", false, yaw, false)
		if (station - roundi(start) - 4) % 12 == 0:
			var light := OmniLight3D.new()
			light.name = "GalleryLight_%d" % station
			light.position = Layout.surface_point(route.point_at(station), 4.23)
			light.light_color = Color("f8ce9a")
			light.light_energy = 1.37
			light.light_specular = 0.19
			light.omni_range = 12.25
			light.omni_attenuation = 1.24
			light.visible = false
			_city.scene_root.add_child(light)
	for entrance: float in [start, end]:
		var facing := route.direction_at(entrance) * (-1.0 if entrance == start else 1.0)
		var yaw := atan2(facing.x, facing.y)
		var pose := Layout.surface_point(route.point_at(entrance), 6.12)
		_city.add_box(pose + Vector3(facing.x, 0, facing.y) * 0.16, Vector3(5.80, 0.54, 0.22), "sign_ink", false, yaw)
		_city.add_label("GALERIA DA PEDRA", pose + Vector3(facing.x, 0, facing.y) * 0.29, yaw, 0.0105)
	for side: float in [-1, 1]:
		_gallery_cut(route, start - 26, end + 24, side)


func _cut_point(route: Route, station: float, side: float, level: int) -> Vector3:
	var depth := float(level) / 3.0
	var rise := 2.2 + 2.1 * (0.5 + 0.5 * sin(station * 0.091))
	var edge := GALLERY_HALF + 1.1 + depth * 6.3 + 0.58 * sin(station * 0.16 + level)
	var foot := Layout.surface_point(route.offset_at(station, edge * side))
	var aligned := Layout.surface_point(route.offset_at(station, side * (GALLERY_HALF + 1.1))).y
	foot.y = lerpf(aligned - 0.44, maxf(foot.y + 0.22, aligned + rise), depth)
	foot.y += 0.45 * sin(station * 0.29 + level * 2.5) * sin(depth * PI)
	return foot


func _gallery_cut(route: Route, start: float, end: float, side: float) -> void:
	var surface := _surface()
	for station in range(roundi(start), roundi(end), 5):
		if station >= Layout.GALLERY_START + 4.0 and station < Layout.GALLERY_END - 4.0 and side < 0.0:
			continue
		for level in 3:
			var a := _cut_point(route, station, side, level)
			var b := _cut_point(route, station + 5.0, side, level)
			var c := _cut_point(route, station + 5.0, side, level + 1)
			var d := _cut_point(route, station, side, level + 1)
			_quad(surface, a, b, c, d)
		if station % 2 == 0:
			var crest := _cut_point(route, station + 1.1, side, 3) - Vector3.UP * 0.42
			var size := Vector3(7.3 + cos(station * 0.42), 3.8 + sin(station * 0.33), 3.6)
			_city.add_instance("vale_boulder", "bedrock", crest, size, station * 0.17)
	_commit(surface, "CorteDaEncostaNorte" if side > 0.0 else "CorteDaEncostaSul", _bedrock)


func _creek(route: Route, crossing: float) -> void:
	var surface := _surface()
	var water_height := Layout.CREEK_WATER_LEVEL
	for z in range(230, int(Layout.CREEK_RANGE.y), 3):
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var along := z + corner.y * 3.0
			var x := Layout.creek_axis(along) + (corner.x - 0.5) * 16.8
			surface.set_uv(Vector2(corner.x, along / 12.0))
			surface.add_vertex(Vector3(x, water_height, along))
	var material := ShaderMaterial.new()
	material.resource_name = "figueiras_creek"
	material.shader = WATER
	material.set_shader_parameter("stream", true)
	_commit(surface, "ArroioDoVale", material, false)
	var crossing_point := route.point_at(crossing)
	var sound := AudioStreamPlayer3D.new()
	sound.name = "SomDoArroio"
	var stream := CREEK_AUDIO.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	sound.stream = stream
	sound.bus = &"Ambiente"
	sound.volume_db = -8.5
	sound.unit_size = 15.0
	sound.max_distance = 47.0
	var sound_z := crossing_point.y + 19.0
	sound.position = Vector3(Layout.creek_axis(sound_z), water_height + 0.52, sound_z)
	sound.autoplay = true
	_city.scene_root.add_child(sound)
	for z in range(248, int(Layout.CREEK_RANGE.y) - 22, 7):
		var center := Vector2(Layout.creek_axis(z + 3.5), z + 3.5)
		if absf(z - crossing_point.y) >= 20.0 and Layout.bridge_opening(center) < 0.05 and Layout.road_distance(center) > 3.0:
			var wet := PackedVector2Array([_bank_edge(z, -1), _bank_edge(z, 1), _bank_edge(z + 7, 1), _bank_edge(z + 7, -1)])
			_ground.patch_polygon(wet, "mulch", 0.022)
		for side: float in [-1, 1]:
			var point := Vector2(Layout.creek_axis(z) + side * (5.8 + 1.9 * sin(z * 0.76)), z)
			var bank: Vector3 = _ground.surface_point(point)
			if Layout.road_distance(point) < 6.0 or bank.y > water_height + 5.1:
				continue
			var size := Vector3(1.66, 1.0, 1.46) * (0.77 + 0.24 * sin(z * 0.51 + side))
			_city.add_instance("vale_boulder", "bedrock", bank + Vector3.UP * 0.15, size, z * 0.76)
			if Layout.bridge_opening(point) < 0.15:
				_city._garden(point + Vector2(side * 1.04, 0.7), 1.8, 9)
			else:
				for reed in 5:
					var stem := point + Vector2(side * (0.24 + 0.32 * reed), sin(z + reed * 2.7) * 1.36)
					var foot: Vector3 = _ground.surface_point(stem)
					if foot.y >= water_height - 0.2:
						_city.add_instance("tuft", "grass_blade", foot, Vector3(0.72, 1.10, 0.76), reed * 2.39, false)


func _bank_edge(z: float, side: float) -> Vector2:
	var bank := Layout.creek_width(z) + 1.10 + 0.92 * cos(z * 0.25 + side)
	return Vector2(Layout.creek_axis(z) + bank * side, z)


func _bridge(route: Route, crossing: float) -> void:
	var fascia := _surface()
	var span := Layout.VALE_BRIDGE_HALF_SPAN
	const SEGMENTS := 8
	var tone := Color("c9c3b4")
	for section in SEGMENTS:
		var start := crossing + lerpf(-span, span, float(section) / SEGMENTS)
		var end := start + span * 2.0 / SEGMENTS
		var a := Layout.surface_point(route.offset_at(start, -route.edge_at(start, -1.0)))
		var b := Layout.surface_point(route.offset_at(end, -route.edge_at(end, -1.0)))
		var c := Layout.surface_point(route.offset_at(end, route.edge_at(end, 1.0)))
		var d := Layout.surface_point(route.offset_at(start, route.edge_at(start, 1.0)))
		var soffit := Vector3.UP * 0.58
		_quad(fascia, a, b, b - soffit, a - soffit, tone, Color("7d796c"))
		_quad(fascia, c, d, d - soffit, c - soffit, tone, Color("7d796c"))
		_quad(fascia, a - soffit, b - soffit, c - soffit, d - soffit, Color("918b7a"), Color("918b7a"))
		for lateral: float in [-3.55, 0.0, 3.55]:
			var first := Layout.surface_point(route.offset_at(start, lateral), -0.85)
			var last := Layout.surface_point(route.offset_at(end, lateral), -0.85)
			_city._add_tilted_box((first + last) * 0.5, Basis.looking_at((last - first).normalized()), Vector3(0.48, 0.64, first.distance_to(last) + 0.04), "gallery_concrete", false)
		for side: float in [-1.0, 1.0]:
			var rail_start := route.offset_at(start, side * (route.edge_at(start, side) - 0.09))
			var rail_end := route.offset_at(end, side * (route.edge_at(end, side) - 0.09))
			_city._rail(rail_start, rail_end, 0.23, 0.40, "gallery_concrete", true)
			_city._rail(rail_start, rail_end, 0.91, 0.16, "steel_plate", true)
			if section % 2 == 0:
				_city.add_box(Layout.surface_point(rail_start, 0.55), Vector3(0.22, 1.1, 0.22), "steel_plate")
	_commit(fascia, "PonteDoArroioTabuleiro", _city.materials["gallery_concrete"])
	for side: float in [-1.0, 1.0]:
		var station := crossing + (span - 3.1) * side
		var forward := route.direction_at(station)
		var yaw := atan2(forward.x, forward.y)
		var center := Layout.surface_point(route.point_at(station))
		var foundation := Layout.CREEK_WATER_LEVEL - 0.75
		var top := center.y - 0.6
		_city.add_box(Vector3(center.x, (top + foundation) * 0.5, center.z), Vector3(route.half_width * 1.82, top - foundation, 1.56), "gallery_concrete", false, yaw)
		_city.add_box(center - Vector3.UP * 0.85, Vector3(route.half_width * 1.94, 0.61, 2.13), "gallery_concrete", false, yaw)
		var sign_station := crossing + (span + 7.0) * side
		var sign_forward := route.direction_at(sign_station) * side
		var sign_yaw := atan2(sign_forward.x, sign_forward.y)
		var sign := Layout.surface_point(route.offset_at(sign_station, side * (route.half_width + 2.08)))
		_city.add_part(sign, Vector3(0, 0.84, 0), Vector3(0.13, 1.68, 0.13), "steel_plate", sign_yaw)
		_city.add_part(sign, Vector3(0, 1.75, 0), Vector3(3.70, 0.69, 0.16), "sign_ink", sign_yaw)
		_city.add_label("PONTE DO ARROIO", sign + Vector3(0, 1.75, 0) + Vector3(sign_forward.x, 0, sign_forward.y) * 0.104, sign_yaw, 0.0083)


func _orchard(route: Route) -> void:
	var station := route.stop_station + 4.0
	var frame := Layout.nursery_frame()
	var path := frame.x
	var across := frame.y
	var center := frame.origin
	var yaw := atan2(across.x, across.y)
	var base := Layout.surface_point(center)
	_city.add_part(base, Vector3(0, 0.08, 0), Vector3(13.1, 2.2, 8.2), "bedrock", yaw, true)
	_city.add_part(base, Vector3(0, 2.62, 0), Vector3(12.6, 3.0, 7.6), "cream", yaw, true)
	_city.add_part(base, Vector3(0, 4.78, 0), Vector3(8.5, 1.52, 13.1), "roof", yaw + PI * 0.5, false, "hip_roof")
	_city.add_part(base, Vector3(0, 3.48, 4.88), Vector3(12.8, 0.19, 2.38), "roof_gray", yaw)
	var porch_level := base.y + 0.86
	var porch_bottom := porch_level - 0.38
	for outer: float in [-6.25, 0.0, 6.25]:
		for depth: float in [3.8, 6.15]:
			porch_bottom = minf(porch_bottom, Layout.height_at(center + path * outer + across * depth) - 0.27)
	var porch := center + across * 5.05
	_city.add_box(Vector3(porch.x, (porch_level + porch_bottom) * 0.5, porch.y), Vector3(12.64, porch_level - porch_bottom, 2.58), "stone", true, yaw)
	_city.add_box(Vector3(porch.x, porch_level + 0.045, porch.y), Vector3(12.72, 0.09, 2.63), "paving", false, yaw)
	for x: float in [-5.9, -2.0, 2.0, 5.9]:
		_city.add_part(base, Vector3(x, 2.17, 5.84), Vector3(0.22, 2.58, 0.24), "wood", yaw)
	for x: float in [-4.36, 4.36]:
		_city._window(base, Vector3(x, 2.73, 3.8), Vector2(2.07, 1.54), yaw, "glass")
	_city.add_part(base, Vector3(0, 1.96, 3.88), Vector3(1.55, 2.18, 0.16), "door", yaw)
	_city.add_part(base, Vector3(0, 2.86, 5.95), Vector3(5.87, 0.69, 0.17), "sign_ink", yaw)
	_city.add_label("VIVEIRO DO VALE", base + Basis(Vector3.UP, yaw) * Vector3(0, 2.86, 6.06), yaw, 0.012)
	var access_start := route.offset_at(station, -route.half_width - 7.2)
	var access_end := center + across * 8.65
	var landing := Layout.height_at(access_end) + 0.04
	var tread_count := maxi(1, ceili((porch_level - landing) / 0.18))
	var tread_depth := 2.34 / tread_count
	for step in tread_count:
		var site := center + across * (6.32 + (step + 0.5) * tread_depth)
		var top := lerpf(porch_level, landing, float(step + 1) / tread_count)
		var bottom := minf(top - 0.18, minf(Layout.height_at(site - path * 1.48), Layout.height_at(site + path * 1.48)) - 0.22)
		_city.add_box(Vector3(site.x, (top + bottom) * 0.5, site.y), Vector3(3.16, top - bottom, tread_depth + 0.018), "stone", true, yaw)
	var edge := path * 1.62
	var stones := PackedVector2Array([access_start - edge, access_end - edge, access_end + edge, access_start + edge])
	if (stones[1] - stones[0]).cross(stones[2] - stones[0]) < 0.0:
		stones.reverse()
	_ground.patch_polygon(stones, "cobbles", 0.043)
	for side: float in [-1, 1]:
		var crate := center + across * 5.44 + path * side * 4.70
		var foot := Vector3(crate.x, porch_level + 0.095, crate.y)
		_city.add_box(foot + Vector3.UP * 0.32, Vector3(1.42, 0.65, 0.88), "bench", true, yaw)
		for tag in 4:
			var x := (tag - 1.5) * 0.31
			_city.add_part(foot, Vector3(x, 0.72, 0.11), Vector3(0.21, 0.20, 0.20), "terracotta_pot", yaw, false, "cylinder")
			_city.add_part(foot, Vector3(x, 0.88, 0.11), Vector3(0.29, 0.24, 0.29), "bush", yaw, false, "shrub")
	for row in 3:
		for column in 8:
			var site := center - across * (10.0 + row * 6.1) + path * (column - 3.5) * 6.6
			_city._tree(site, 3.85 + 0.42 * sin(column * 4.0 + row), 1 + column % 2, false)
			if row == 0:
				_city._garden(site, 1.87, 7)
	for sign: float in [-1, 1]:
		var first := center + across * 7.1 + path * sign * 6.4
		for index in 6:
			var a := first + path * sign * (index * 3.1)
			var b := first + path * sign * ((index + 1) * 3.1)
			_city._rail(a, b, 0.53, 0.16, "wood")
			_city.add_box(Layout.surface_point(a, 0.53), Vector3(0.15, 1.15, 0.15), "wood")
