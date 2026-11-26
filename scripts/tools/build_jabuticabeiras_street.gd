extends "res://scripts/city/offline_scene_builder.gd"

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Ground = preload("res://scripts/tools/build_jabuticabeiras_ground.gd")
const Facades = preload("res://scripts/tools/build_jabuticabeiras_facades.gd")
const Ends = preload("res://scripts/tools/build_jabuticabeiras_ends.gd")
const ShadowBake = preload("res://scripts/tools/build_jabuticabeiras_shadows.gd")
const Backdrop = preload("res://scripts/tools/build_jabuticabeiras_backdrop.gd")
const StreetMeshes = preload("res://scripts/city/figueiras_street_meshes.gd")
const TreeMesh = preload("res://scripts/tools/build_jabuticabeiras_trees.gd")
const FlowerMesh = preload("res://scripts/city/neighborhood_flower_mesh.gd")
const ParkedCar = preload("res://scripts/city/parked_car_mesh.gd")
const F = Facades.Facade

# Station, frontage, height, elevation, setback and tiled roof. Lots follow
# the curve individually, with a few yards breaking up the row of facades.
const LEFT := [
	[5.6, 8.8, 3.65, F.IVORY, 0.66, true], [15.7, 8.2, 5.8, F.GARAGE, 0.05, false],
	[25.0, 8.5, 6.1, F.WORKSHOP, 0.17, false], [36.8, 8.2, 5.6, F.BLUE, 0.74, false],
	[45.9, 8.2, 6.9, F.BRICK, 0.20, false], [56.7, 7.0, 3.25, F.OLIVE, 2.20, true],
	[68.8, 8.1, 4.95, F.IVORY, 0.72, true], [78.1, 7.2, 6.3, F.OLIVE, 0.06, false],
	[89.7, 8.9, 6.0, F.GARAGE, 0.37, false], [101.0, 7.4, 5.8, F.BRICK, 0.48, true],
	[112.7, 8.3, 3.4, F.OLIVE, 0.73, true], [122.0, 7.7, 6.35, F.BLUE, 0.28, false],
	[129.7, 7.2, 5.6, F.IVORY, 0.30, false], [142.4, 8.6, 5.2, F.GARAGE, 0.18, false],
]
const RIGHT := [
	[5.4, 9.9, 5.8, F.BRICK, 0.49, true], [15.9, 8.0, 6.0, F.BAKERY, 0.05, false],
	[23.9, 7.6, 5.22, F.HARDWARE, 0.14, false], [39.1, 8.7, 5.8, F.OLIVE, 0.91, true],
	[48.6, 7.3, 6.6, F.BLUE, 0.10, false], [56.3, 7.8, 4.89, F.IVORY, 0.74, false],
	[66.7, 7.9, 3.35, F.BRICK, 1.01, true], [77.7, 8.7, 5.7, F.GARAGE, 0.02, false],
	[88.4, 8.4, 6.65, F.OLIVE, 0.35, false], [97.9, 7.9, 5.32, F.BRICK, 0.92, true],
	[105.1, 6.8, 6.1, F.IVORY, 0.04, false], [115.8, 7.8, 5.35, F.BLUE, 1.19, true],
	[127.9, 8.4, 3.55, F.OLIVE, 0.65, true], [143.0, 9.4, 5.9, F.BRICK, 0.43, false],
]
const STUCCO = preload("res://assets/textures/neighborhood/stucco-albedo.res")
const STONE = preload("res://assets/textures/neighborhood/limestone-albedo.res")
const STONE_NORMAL = preload("res://assets/textures/neighborhood/limestone-normal.res")
const BASALT = preload("res://assets/textures/jabuticabeiras/basalto-assentado.png")
const ROOF = preload("res://assets/textures/neighborhood/roof_tiles-albedo.res")
const ROOF_NORMAL = preload("res://assets/textures/neighborhood/roof_tiles-normal.res")
const LEAVES = preload("res://assets/textures/jabuticabeiras/jabuticaba-spray.png")
const FOLIAGE = preload("res://assets/shaders/jabuticabeiras/leaves.gdshader")
const BARK = preload("res://assets/textures/rally/bark.png")
const BARK_NORMAL = preload("res://assets/textures/rally/bark_normal.png")

var _random := RandomNumberGenerator.new()
var _shade_trees: Array[Vector4] = []


func build() -> Node3D:
	_random.seed = 982733
	_shade_trees.clear()
	batch_size = 38.0
	center_batches_vertically = true
	begin("RuaDasJabuticabeiras", "StreetObjects")
	StreetMeshes.install(meshes)
	_setup_finishes()
	_install_plant_meshes()
	var ground := Ground.new()
	ground.build(scene_root)
	var facades := Facades.new(self)
	_frontage(facades, LEFT, -1.0)
	_frontage(facades, RIGHT, 1.0)
	Ends.new(self).build(facades)
	facades.finish(scene_root)
	Backdrop.new().build(scene_root)
	_plants()
	_utilities()
	_street_furniture()
	_parked_car()
	ground.set_surface_bake(ShadowBake.new().bake(_colliders, _shade_trees), ShadowBake.BOUNDS)
	finish()
	_finish_foliage()
	scene_root.set_meta("street_length", Layout.LENGTH)
	scene_root.set_meta("facade_count", LEFT.size() + RIGHT.size())
	return scene_root


func _setup_finishes() -> void:
	var paints := {
		"coping": "999183", "window_sill": "aea396", "zinc": "808481", "armature": "515653",
		"dark_iron": "353936", "cable": "555650", "steel_gate": "48625b", "grate": "45433c",
		"address_plate": "404a42", "shop_sign_green": "314a3b", "shop_sign_gray": "4d5151", "awning_cloth": "e2dfce",
		"water_tank": "333f4d", "planter": "9d634e", "soil": "514638", "wood": "97704e",
		"lens": "e0dbc9", "sign_green": "355247", "brick_wall": "a3977b", "parked_car": "ffffff",
		"basalt_wall": "a3a39a", "ceramic": "a07556", "tile_green": "314f3e", "plaster_trim": "aca08a",
		"awning_metal": "354749", "ipe_gold": "d4a436", "ipe_light": "e4bc55",
	}
	for name: String in paints:
		var material := StandardMaterial3D.new()
		material.resource_name = name
		material.albedo_color = Color(paints[name])
		material.roughness = 0.86
		materials[name] = material
	for name in ["window_sill", "coping", "armature"]:
		var material := materials[name]
		material.albedo_texture = STONE
		material.normal_texture = STONE_NORMAL
		material.normal_enabled = true
		material.normal_scale = 0.36
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.56
	materials["zinc"].metallic = 0.38
	materials["zinc"].roughness = 0.57
	materials["grate"].metallic = 0.56
	materials["grate"].roughness = 0.64
	materials["steel_gate"].metallic = 0.32
	materials["steel_gate"].roughness = 0.65
	materials["awning_metal"].metallic = 0.27
	materials["awning_metal"].roughness = 0.67
	for name: String in ["ipe_gold", "ipe_light"]:
		materials[name].cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[name].diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	materials["parked_car"].vertex_color_use_as_albedo = true
	materials["parked_car"].vertex_color_is_srgb = true
	materials["parked_car"].roughness = 0.43
	materials["awning_cloth"].vertex_color_use_as_albedo = true
	materials["awning_cloth"].vertex_color_is_srgb = true
	materials["wood"].albedo_texture = preload("res://assets/textures/neighborhood/timber-albedo.res")
	materials["wood"].uv1_triplanar = true
	materials["wood"].uv1_world_triplanar = true
	materials["wood"].uv1_scale = Vector3.ONE * 0.92
	materials["brick_wall"].albedo_texture = STUCCO
	materials["brick_wall"].uv1_triplanar = true
	materials["brick_wall"].uv1_world_triplanar = true
	materials["brick_wall"].uv1_scale = Vector3.ONE * 0.40
	materials["basalt_wall"].albedo_texture = BASALT
	materials["basalt_wall"].uv1_triplanar = true
	materials["basalt_wall"].uv1_world_triplanar = true
	materials["basalt_wall"].uv1_scale = Vector3(0.38, 0.58, 0.38)
	materials["basalt_wall"].texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["plaster_trim"].albedo_texture = STUCCO
	materials["plaster_trim"].uv1_triplanar = true
	materials["plaster_trim"].uv1_world_triplanar = true
	materials["plaster_trim"].uv1_scale = Vector3.ONE * 0.68
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color("c5a393")
	roof.albedo_texture = ROOF
	roof.normal_enabled = true
	roof.normal_texture = ROOF_NORMAL
	roof.normal_scale = 0.56
	roof.roughness = 0.94
	roof.uv1_scale = Vector3(4.2, 4.0, 1.0)
	materials["roof_tile"] = roof
	var bark := StandardMaterial3D.new()
	bark.roughness = 0.96
	bark.albedo_color = Color("b9a692")
	bark.albedo_texture = BARK
	bark.normal_enabled = true
	bark.normal_texture = BARK_NORMAL
	bark.normal_scale = 0.32
	bark.uv1_triplanar = true
	bark.uv1_world_triplanar = true
	bark.uv1_scale = Vector3(1.78, 0.62, 1.78)
	materials["tree_bark"] = bark
	# The shared builder batches by a standard material palette. Replace this
	# entry after batching so the generated canopy can use its own shader.
	materials["tree_leaves"] = StandardMaterial3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.73
	pole.bottom_radius = 1.0
	pole.height = 1.0
	pole.radial_segments = 8
	pole.rings = 1
	meshes["pole"] = pole
	var tank := pole.duplicate() as CylinderMesh
	tank.top_radius = 0.47
	tank.bottom_radius = 0.50
	tank.radial_segments = 16
	meshes["tank"] = tank
	var blade := pole.duplicate() as CylinderMesh
	blade.top_radius = 1.0
	blade.radial_segments = 6
	meshes["beam"] = blade


func _finish_foliage() -> void:
	var material := ShaderMaterial.new()
	material.resource_name = "street_leaves"
	material.shader = FOLIAGE
	material.set_shader_parameter("leaf_spray", LEAVES)
	for instance in scene_root.get_children():
		if instance is MultiMeshInstance3D and instance.material_override == materials["tree_leaves"]:
			instance.material_override = material


func _frontage(facades: RefCounted, lots: Array, side: float) -> void:
	for index in lots.size():
		var lot: Array = lots[index]
		var station: float = lot[0]
		var width: float = lot[1]
		var height: float = lot[2]
		var setback: float = lot[4]
		var curb := maxf(Layout.half_width(station), maxf(Layout.half_width(station - width * 0.5), Layout.half_width(station + width * 0.5)))
		var offset := side * (curb + Layout.SIDEWALK_WIDTH + setback)
		var land := _edge(station, offset, 0.13)
		var depth := 6.6 + float(index % 4) * 0.77
		facades.add(land, width, height, depth, _facade_yaw(station, side), lot[3], lot[5], 14 + index * 6 + int(side > 0.0))
	# Infill behind the lots defines the back of the playable corridor.
	for station: float in [5.0, 22.0, 39.0, 56.0, 73.0, 90.0, 107.0, 124.0, 141.0, 155.0]:
		var here := _edge(station, 17.0 * side, 1.11)
		var size := Vector3(18.6 if station < 150.0 else 12.5, 2.5, 0.42)
		add_box(here, size, "brick_wall", true, _facade_yaw(station, side))


func _edge(station: float, offset: float, lift: float) -> Vector3:
	return Layout.position_at(station, offset, lift)


func _facade_yaw(station: float, side: float) -> float:
	var inward := Layout.right(station) * -side
	return atan2(inward.x, inward.y)


func _install_plant_meshes() -> void:
	var builder := TreeMesh.new()
	for index in 3:
		var mesh := builder.build_street_tree(index)
		meshes["bark_%d" % index] = mesh.bark
		meshes["crown_%d" % index] = mesh.leaves
		meshes["distant_crown_%d" % index] = mesh.distant_leaves
	meshes["shrub"] = builder.build_shrub()
	meshes["ipe_blossoms"] = FlowerMesh.build()


func _plants() -> void:
	for tree: Vector4 in [
		Vector4(11.3, -1.0, 7.9, 0), Vector4(30.5, 1.0, 7.3, 1), Vector4(37.7, -1.0, 6.7, 2),
		Vector4(50.3, 1.0, 7.8, 0), Vector4(61.7, -1.0, 7.5, 0), Vector4(72.2, 1.0, 6.5, 2),
		Vector4(81.0, -1.0, 7.1, 1), Vector4(95.5, 1.0, 8.3, 0), Vector4(106.3, -1.0, 7.1, 2),
		Vector4(120.4, 1.0, 7.4, 0), Vector4(136.2, -1.0, 7.5, 1), Vector4(150.0, 1.0, 7.0, 2),
	]:
		var offset := (Layout.half_width(tree.x) + 0.72) * tree.y
		var site := _surface_position(tree.x, offset)
		_tree(site, tree.z, int(tree.w), true)
		var yaw := _facade_yaw(tree.x, tree.y)
		add_box(site + Vector3.UP * 0.011, Vector3(0.84, 0.026, 1.12), "soil", false, yaw, false)
		for edge: float in [-1.0, 1.0]:
			add_part(site, Vector3(edge * 0.43, 0.027, 0.0), Vector3(0.065, 0.048, 1.17), "window_sill", yaw)
			add_part(site, Vector3(0.0, 0.027, edge * 0.55), Vector3(0.81, 0.048, 0.066), "window_sill", yaw)
	for side: float in [-1.0, 1.0]:
		for index in 16:
			var station := _random.randf_range(-13.0, Layout.LENGTH + 14.0)
			var offset := side * _random.randf_range(13.2, 36.0)
			_tree(_surface_position(station, offset), _random.randf_range(8.7, 14.2), index % 3, false)
	for tree: Vector3 in [Vector3(-13, -7, 11), Vector3(-9, 2, 9), Vector3(-12, 5.7, 10),
			Vector3(162, 5.7, 10), Vector3(168.4, -8.5, 11), Vector3(171, 0, 13),
			Vector3(172, 8.2, 7.0), Vector3(174.5, -5.8, 6.3), Vector3(177, -11.6, 11), Vector3(179, 4.8, 10)]:
		_tree(_surface_position(tree.x, tree.y), tree.z, int(tree.z) % 3, false)
	_flowering_ipe(_surface_position(159.8, -5.5))
	for plant: Vector3 in [Vector3(17.8, 1, 0.70), Vector3(18.7, 1, 0.42), Vector3(35.1, 1, 1.0),
			Vector3(58.5, -1, 0.80), Vector3(65.0, 1, 1.1), Vector3(98.7, 1, 0.95), Vector3(121.1, -1, 1.3)]:
		var site := _surface_position(plant.x, plant.y * (Layout.half_width(plant.x) + 1.65))
		planter(site, plant.z, plant.x)
	for yard: Vector2 in [Vector2(56.9, -1.0), Vector2(66.9, 1.0), Vector2(116.6, 1.0)]:
		var setback := Layout.half_width(yard.x) + Layout.SIDEWALK_WIDTH + 0.46
		var site := _surface_position(yard.x, yard.y * setback)
		var yaw := _facade_yaw(yard.x, yard.y)
		var frame := Basis(Vector3.UP, yaw)
		add_part(site, Vector3(0.0, 0.15, 0.0), Vector3(1.83, 0.34, 0.65), "basalt_wall", yaw, true)
		add_part(site, Vector3(0.0, 0.33, 0.0), Vector3(1.79, 0.055, 0.60), "soil", yaw)
		for x: float in [-0.61, 0.0, 0.56]:
			add_instance("shrub", "tree_leaves", site + frame * Vector3(x, 0.55 + absf(x) * 0.23, 0.0),
				Vector3(0.84, 0.73, 0.78), yaw + x, false)


func _flowering_ipe(site: Vector3) -> void:
	var yaw := 1.4
	var scale := Vector3(8.3, 6.9, 7.5)
	add_instance("bark_0", "tree_bark", site, scale, yaw, false)
	add_instance("distant_crown_0", "tree_leaves", site, scale, yaw, false)
	for bunch in 30:
		var angle := bunch * 2.399963
		var altitude := float(bunch) / 29.0
		var spread := lerpf(1.93, 0.67, altitude * altitude)
		var point := site + Vector3(cos(angle) * spread, 4.36 + altitude * 1.89, sin(angle) * spread * 0.84)
		var size := 0.69 + 0.23 * sin(bunch * 1.8)
		add_instance("ipe_blossoms", "ipe_gold" if bunch % 3 else "ipe_light", point,
			Vector3(size, size * 0.90, size), angle, false)


func planter(site: Vector3, size: float, yaw: float) -> void:
	add_instance("planter", "planter", site + Vector3.UP * size * 0.23, Vector3(0.64, 0.44, 0.64) * size, yaw)
	add_instance("planter", "soil", site + Vector3.UP * size * 0.43, Vector3(0.55, 0.05, 0.55) * size, yaw, false)
	add_instance("shrub", "tree_leaves", site + Vector3.UP * size * 0.67, Vector3.ONE * size, yaw, false)


func _surface_position(station: float, offset: float) -> Vector3:
	return _edge(station, offset, Ground.surface_lift(station, offset) - 0.018)


func _parked_car() -> void:
	var station := 30.8
	var offset := Layout.half_width(station) + 3.58
	var origin := _surface_position(station, offset) + Vector3.UP * 0.35
	var across := Layout.right(station)
	var yaw := -atan2(across.y, across.x)
	meshes["bakery_customer"] = ParkedCar.build_traffic(Color("50626e"), 0, true)
	add_instance("bakery_customer", "parked_car", origin, Vector3.ONE, yaw)
	add_collision(origin + Vector3.UP * 0.32, Vector3(1.72, 1.13, 4.13), yaw)


func _tree(site: Vector3, size: float, species: int, solid: bool) -> void:
	var turn := _random.randf_range(0.0, TAU)
	var scale := Vector3(_random.randf_range(0.86, 1.13), 1.0, _random.randf_range(0.85, 1.08)) * size
	add_instance("bark_%d" % species, "tree_bark", site, scale, turn, solid)
	var canopy := "crown_%d" if solid else "distant_crown_%d"
	add_instance(canopy % species, "tree_leaves", site, scale, turn, solid)
	if solid:
		_shade_trees.append(Vector4(site.x, site.y, site.z, size))
		add_collision(site + Vector3.UP * 0.88, Vector3(size * 0.038, 1.84, size * 0.038))


func _utilities() -> void:
	var previous := Vector3.INF
	for station: float in [4.8, 27.9, 50.4, 73.8, 98.8, 124.2, 150.1]:
		var site := _edge(station, -Layout.half_width(station) - 0.51, 0.11)
		var height := 7.65 + 0.32 * sin(station * 0.19)
		var cap := site + Vector3.UP * (height - 0.39)
		add_instance("pole", "armature", site + Vector3.UP * (height * 0.5), Vector3(0.16, height, 0.16), PI * 0.25)
		add_collision(site + Vector3.UP, Vector3(0.26, 2.2, 0.26))
		var crossbar := Vector3(Layout.right(station).x, 0.0, Layout.right(station).y)
		beam(cap - crossbar * 0.75, cap + crossbar * 0.75, 0.041, "zinc")
		for run: float in [-0.59, -0.08, 0.51]:
			var connector := cap + crossbar * run + Vector3.UP * 0.125
			add_instance("pole", "lens", connector - Vector3.UP * 0.045, Vector3(0.065, 0.19, 0.065), 0.0, false)
			if previous.is_finite():
				_span(previous + crossbar * run + Vector3.UP * 0.125, connector, 0.68 + absf(run) * 0.28)
		previous = cap
		var arm := cap - Vector3.UP * 1.67
		var light := arm + crossbar * 1.32 + Vector3.UP * 0.27
		beam(arm, light, 0.033, "zinc")
		add_box(light + crossbar * 0.10, Vector3(0.46, 0.12, 0.20), "zinc", false, rotation_for_cross(station))
		add_box(light + crossbar * 0.10 - Vector3.UP * 0.061, Vector3(0.39, 0.028, 0.16), "lens", false, rotation_for_cross(station), false)
		for side: float in [-1.0, 1.0]:
			var connection := _edge(station - 1.7, side * (Layout.half_width(station) + 2.76), 4.82)
			_span(cap + Vector3.UP * 0.17, connection, 0.26)


func rotation_for_cross(station: float) -> float:
	var across := Layout.right(station)
	return -atan2(across.y, across.x)


func _span(first: Vector3, last: Vector3, sag: float) -> void:
	var span := last - first
	var axis := Basis.looking_at(-span.normalized()).scaled_local(Vector3(1.72, sag, span.length()))
	add_transformed_instance("sagging_wire", "cable", Transform3D(axis, (first + last) * 0.5), false)


func beam(first: Vector3, last: Vector3, radius: float, material: String) -> void:
	var run := last - first
	var axis := Basis(Quaternion(Vector3.UP, run.normalized())).scaled_local(Vector3(radius, run.length(), radius))
	add_transformed_instance("beam", material, Transform3D(axis, (first + last) * 0.5), false)


func _street_furniture() -> void:
	for inlet: Vector2 in [Vector2(19.1, 1), Vector2(27.6, -1), Vector2(35.1, 1), Vector2(66.5, -1),
			Vector2(83.5, 1), Vector2(115.2, -1), Vector2(135.7, 1)]:
		var yaw := rotation_for_cross(inlet.x)
		var site := _edge(inlet.x, inlet.y * (Layout.half_width(inlet.x) - 0.225), -0.009)
		add_box(site, Vector3(0.39, 0.022, 0.63), "grate", false, yaw, false)
		for bar in 9:
			add_part(site, Vector3(0.0, 0.015, (bar - 4) * 0.058), Vector3(0.36, 0.010, 0.016), "zinc", yaw)
	for cover: Vector2 in [Vector2(23.5, -0.68), Vector2(79.2, 1.03), Vector2(122.6, -0.63)]:
		var site := _edge(cover.x, cover.y, 0.011)
		add_instance("tank", "grate", site, Vector3(0.64, 0.023, 0.64), 0.0, false)
		for ring in 5:
			var length := 0.44 - absf(float(ring - 2)) * 0.06
			add_box(site + Vector3(0.0, 0.013, (ring - 2) * 0.071), Vector3(length, 0.012, 0.024), "dark_iron", false, 0.0, false)
	var street_sign := _edge(34.8, -Layout.half_width(34.8) - 0.52, 0.10)
	var facing := rotation_for_cross(34.8) - PI * 0.18
	add_instance("beam", "zinc", street_sign + Vector3.UP * 1.24, Vector3(0.044, 2.48, 0.044), 0.0)
	add_box(street_sign + Vector3.UP * 2.34, Vector3(1.06, 0.243, 0.059), "sign_green", false, facing)
	var normal := Basis(Vector3.UP, facing).z
	lettering("R. DAS JABUTICABEIRAS", street_sign + Vector3.UP * 2.345 + normal * 0.033, facing, 0.00186, Color("e0ddd0"))
	var bakery := _edge(13.6, Layout.half_width(13.6) + 1.52, 0.16)
	var yaw := _facade_yaw(13.6, 1.0)
	var frame := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		for depth: float in [-1.0, 1.0]:
			var foot := bakery + frame * Vector3(side * 0.226, 0.015, depth * 0.17)
			var top := bakery + frame * Vector3(side * 0.226, 0.71, 0.0)
			beam(foot, top, 0.018, "wood")
	add_part(bakery, Vector3(0.0, 0.39, 0.13), Vector3(0.49, 0.48, 0.042), "wood", yaw)
	add_part(bakery, Vector3(0.0, 0.39, 0.161), Vector3(0.43, 0.42, 0.029), "dark_iron", yaw)
	lettering("PÃO\nQUENTE", bakery + frame.z * 0.181 + Vector3.UP * 0.408, yaw, 0.00217, Color("efdbab"))


func lettering(message: String, position: Vector3, yaw: float, pixel_size: float, ink: Color) -> void:
	add_label(message, position, yaw, pixel_size)
	var label := scene_root.get_child(-1) as Label3D
	label.modulate = ink
	label.outline_size = 0
	label.shaded = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = clampf(pixel_size * 6800.0, 15.0, 70.0)
	label.visibility_range_end_margin = 3.0
