extends "res://scripts/city/offline_scene_builder.gd"

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Ground = preload("res://scripts/tools/build_jabuticabeiras_ground.gd")
const Facades = preload("res://scripts/tools/build_jabuticabeiras_facades.gd")
const Ends = preload("res://scripts/tools/build_jabuticabeiras_ends.gd")
const Stairs = preload("res://scripts/tools/build_jabuticabeiras_stairs.gd")
const ShadowBake = preload("res://scripts/tools/build_jabuticabeiras_shadows.gd")
const Backdrop = preload("res://scripts/tools/build_jabuticabeiras_backdrop.gd")
const Landscape = preload("res://scripts/tools/build_jabuticabeiras_landscape.gd")
const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const Streetscape = preload("res://scripts/tools/build_jabuticabeiras_streetscape.gd")
const StreetMeshes = preload("res://scripts/city/figueiras_street_meshes.gd")
const TreeMesh = preload("res://scripts/tools/build_jabuticabeiras_trees.gd")
const ParkedCar = preload("res://scripts/city/parked_car_mesh.gd")
const F = Facades.Facade

# Station, frontage, height, elevation, setback and tiled roof. Lots follow
# the curve individually, with a few yards breaking up the row of facades.
const LEFT := [
	[5.6, 8.8, 3.65, F.IVORY, 0.66, true], [15.7, 7.8, 5.8, F.GARAGE, 0.46, true],
	[25.0, 8.7, 5.33, F.WORKSHOP, 0.41, false], [36.8, 6.8, 6.7, F.BLUE, 1.12, false],
	[45.9, 8.2, 6.15, F.BRICK, 0.20, true], [56.7, 7.0, 3.25, F.OLIVE, 2.75, true],
	[68.8, 8.1, 5.30, F.IVORY, 0.72, true], [78.1, 7.2, 6.7, F.OLIVE, 0.06, false],
	[89.7, 8.9, 6.0, F.GARAGE, 0.37, false], [101.0, 7.4, 5.8, F.BRICK, 0.48, true],
	[112.7, 8.3, 3.4, F.OLIVE, 0.73, true], [122.0, 7.7, 6.35, F.BLUE, 0.28, false],
	[129.7, 7.2, 5.6, F.IVORY, 0.30, false], [142.4, 8.6, 5.2, F.GARAGE, 0.18, false],
]
const RIGHT := [
	[5.4, 8.6, 4.8, F.BRICK, 0.82, true], [15.9, 8.0, 6.52, F.BAKERY, 0.26, true],
	[24.5, 7.1, 5.19, F.HARDWARE, 0.61, true], [39.7, 8.2, 5.7, F.OLIVE, 1.26, true],
	[48.6, 7.3, 6.4, F.BLUE, 0.65, false], [56.3, 7.8, 4.15, F.IVORY, 1.68, true],
	[66.7, 7.9, 3.35, F.BRICK, 1.01, true], [77.7, 8.7, 5.7, F.GARAGE, 0.02, false],
	[88.4, 8.4, 6.65, F.OLIVE, 0.35, false], [97.9, 7.9, 5.32, F.BRICK, 0.92, true],
	[105.1, 6.8, 6.1, F.IVORY, 0.04, false], [115.8, 7.8, 5.35, F.BLUE, 1.19, true],
	[127.9, 8.4, 3.55, F.OLIVE, 0.65, true], [143.0, 9.4, 5.9, F.BRICK, 0.43, false],
]
const STUCCO = preload("res://assets/textures/neighborhood/stucco-albedo.res")
const STONE = preload("res://assets/textures/neighborhood/limestone-albedo.res")
const STONE_NORMAL = preload("res://assets/textures/neighborhood/limestone-normal.res")
const BASALT = preload("res://assets/textures/jabuticabeiras/basalto-assentado.png")
const ROOF = preload("res://assets/textures/jabuticabeiras/telha-colonial.png")
const LEAVES = preload("res://assets/textures/jabuticabeiras/jabuticaba-spray.png")
const IPE = preload("res://assets/textures/jabuticabeiras/ipe-amarelo.png")
const HYDRANGEA = preload("res://assets/textures/jabuticabeiras/hortensia-serra.png")
const FERN = preload("res://assets/textures/jabuticabeiras/samambaia.png")
const FOLIAGE = preload("res://assets/shaders/jabuticabeiras/leaves.gdshader")
const HALO = preload("res://assets/shaders/jabuticabeiras/lamp_halo.gdshader")
const BARK = preload("res://assets/textures/jabuticabeiras/casca-jabuticabeira.png")
const IPE_BARK = preload("res://assets/textures/rally/bark.png")

var _random := RandomNumberGenerator.new()
var _shade_trees: Array[Vector4] = []
var _lamps: Array[Vector4] = []


func build() -> Node3D:
	_random.seed = 982733
	_shade_trees.clear()
	_lamps.clear()
	batch_size = 38.0
	center_batches_vertically = true
	begin("RuaDasJabuticabeiras", "StreetObjects")
	StreetMeshes.install(meshes)
	_setup_finishes()
	_install_plant_meshes()
	var ground := Ground.new()
	ground.build(scene_root)
	var masonry := Masonry.new()
	var facades := Facades.new(self, masonry)
	_frontage(facades, LEFT, -1.0)
	_frontage(facades, RIGHT, 1.0)
	Ends.new(self).build(facades, masonry)
	Stairs.new(self, masonry).build(facades)
	Landscape.new(masonry).build(scene_root)
	Streetscape.new(self, masonry).build()
	facades.finish(scene_root)
	Backdrop.new().build(scene_root)
	_plants()
	_verge_detail()
	_utilities()
	_street_furniture()
	_parked_car()
	ground.set_surface_bake(ShadowBake.new().bake(_colliders, _shade_trees, _lamps), ShadowBake.BOUNDS)
	finish()
	_finish_foliage()
	_finish_lights()
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
		"awning_metal": "354749", "shop_reveal": "686854", "drain_recess": "222423",
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
	materials["drain_recess"].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials["steel_gate"].metallic = 0.32
	materials["steel_gate"].roughness = 0.65
	materials["awning_metal"].metallic = 0.27
	materials["awning_metal"].roughness = 0.67
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
	roof.albedo_color = Color("a59b92")
	roof.albedo_texture = ROOF
	roof.roughness = 0.94
	roof.uv1_scale = Vector3(5.4, 5.0, 1.0)
	roof.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["roof_tile"] = roof
	var bark := StandardMaterial3D.new()
	bark.resource_name = "casca-jabuticabeira"
	bark.roughness = 0.96
	bark.albedo_color = Color("b1a8a0")
	bark.albedo_texture = BARK
	bark.vertex_color_use_as_albedo = true
	bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["tree_bark"] = bark
	var ipe_bark := bark.duplicate() as StandardMaterial3D
	ipe_bark.resource_name = "casca-ipe"
	ipe_bark.albedo_texture = IPE_BARK
	ipe_bark.albedo_color = Color("b6aca1")
	materials["ipe_bark"] = ipe_bark
	# The shared builder batches by a standard material palette. Replace this
	# entry after batching so the generated canopy can use its own shader.
	materials["tree_leaves"] = StandardMaterial3D.new()
	materials["ipe_flowers"] = StandardMaterial3D.new()
	materials["hydrangea"] = StandardMaterial3D.new()
	materials["fern"] = StandardMaterial3D.new()
	materials["street_halo"] = StandardMaterial3D.new()
	var lamp := StandardMaterial3D.new()
	lamp.resource_name = "amber_light"
	lamp.albedo_color = Color("efd4a1")
	lamp.emission_enabled = true
	lamp.emission = Color("ffd28a")
	lamp.emission_energy_multiplier = 1.8
	materials["amber_light"] = lamp
	var halo := QuadMesh.new()
	halo.size = Vector2.ONE
	meshes["lamp_halo"] = halo
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
	var finishes := {
		materials["tree_leaves"]: _foliage_material("street_leaves", LEAVES),
		materials["ipe_flowers"]: _foliage_material("ipe_flowers", IPE, true),
		materials["hydrangea"]: _foliage_material("hydrangea", HYDRANGEA, true, Color("e8f3ff")),
		materials["fern"]: _foliage_material("fern", FERN),
	}
	for instance in scene_root.get_children():
		if instance is MultiMeshInstance3D and finishes.has(instance.material_override):
			instance.material_override = finishes[instance.material_override]
			var mesh_name := str(instance.name)
			if mesh_name.begins_with("fern_") or mesh_name.begins_with("hydrangea_"):
				instance.visibility_range_end = 89.0


func _foliage_material(label: String, texture: Texture2D, flowers := false, flower_tint := Color("fff2d6")) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = label
	material.shader = FOLIAGE
	material.set_shader_parameter("leaf_spray", texture)
	material.set_shader_parameter("flowers", flowers)
	material.set_shader_parameter("flower_tint", flower_tint)
	return material


func _finish_lights() -> void:
	var glow := ShaderMaterial.new()
	glow.shader = HALO
	for instance in scene_root.get_children():
		if instance is MultiMeshInstance3D and instance.material_override == materials["street_halo"]:
			instance.material_override = glow
			instance.visibility_range_end = 105.0


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
		meshes["distant_bark_%d" % index] = builder.build_distant_bark(index)
		meshes["distant_crown_%d" % index] = builder.build_forest_crown(index)
	var ipe := builder.build_street_tree(2, true)
	meshes["ipe_boughs"] = ipe.bark
	meshes["ipe_crown"] = ipe.leaves
	meshes["shrub"] = builder.build_shrub()
	meshes["fern"] = builder.build_understory(true)
	meshes["hydrangea"] = builder.build_understory(false)


func _plants() -> void:
	for tree: Vector4 in [
		Vector4(11.3, -1.0, 7.9, 0), Vector4(36.6, 1.0, 7.3, 1), Vector4(37.7, -1.0, 6.7, 2),
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
			Vector3(162, 8.7, 10), Vector3(168.4, -13.5, 11), Vector3(173, 12.0, 10),
			Vector3(172, 8.2, 7.0), Vector3(174.5, -8.8, 6.3), Vector3(177, -11.6, 11), Vector3(179, 8.8, 10)]:
		_tree(_surface_position(tree.x, tree.y), tree.z, int(tree.z) % 3, false)
	_flowering_ipe(_surface_position(159.8, -4.7))
	_terminal_banks()
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
		for x: float in [-0.58, 0.0, 0.54]:
			understory(site + frame * Vector3(x, 0.34, -0.014), 0.84 + absf(x) * 0.21, yaw + x, yard.x == 66.9 or x == 0.0)
	for bed: Vector3 in [Vector3(10.73, -1, 0.63), Vector3(11.70, -1, 0.54), Vector3(50.74, 1, 0.57),
			Vector3(61.45, -1, 0.69), Vector3(81.28, -1, 0.57), Vector3(136.60, -1, 0.71)]:
		var offset := bed.y * (Layout.half_width(bed.x) + 0.80)
		understory(_surface_position(bed.x, offset), bed.z, bed.x, true)


func understory(site: Vector3, size: float, yaw: float, fern: bool) -> void:
	var plant := "fern" if fern else "hydrangea"
	add_instance(plant, plant, site, Vector3.ONE * size, yaw, false)


func _terminal_banks() -> void:
	var bank_patches := [
		Vector4(160.2, -12.7, 1.1, 4.0), Vector4(165.3, 9.18, 1.35, 6.0),
		Vector4(170.5, 4.83, 1.41, 7.0), Vector4(167.18, -3.24, 1.03, 5.0),
		Vector4(174.20, -12.1, 1.91, 6.0), Vector4(151.9, 13.6, 1.9, 5.0),
		Vector4(-3.3, -9.38, 1.25, 5.0), Vector4(-8.1, 8.87, 1.40, 7.0),
		Vector4(-12.8, -8.82, 1.73, 6.0),
	]
	var natural := RandomNumberGenerator.new()
	natural.seed = 214293
	for row: Vector4 in bank_patches:
		for index in int(row.w):
			var azimuth := float(index) * 2.399963
			var shift := Vector2.from_angle(azimuth) * row.z * sqrt((index + 0.35) / row.w)
			var site := _surface_position(row.x + shift.x, row.y + shift.y)
			var scale := natural.randf_range(0.65, 1.16)
			if index % 3 == 0:
				understory(site, scale, azimuth, true)
			elif index % 4 == 1:
				understory(site, scale, azimuth, false)
			else:
				add_instance("shrub", "tree_leaves", site + Vector3.UP * scale * 0.38,
					Vector3(1.18, 0.71, 1.078) * scale, azimuth, false)


func _flowering_ipe(site: Vector3) -> void:
	var yaw := 1.4
	var scale := Vector3(9.9, 8.3, 9.5)
	add_instance("ipe_boughs", "ipe_bark", site, scale, yaw)
	add_instance("ipe_crown", "ipe_flowers", site, scale, yaw)
	_shade_trees.append(Vector4(site.x, site.y, site.z, scale.y))


func _verge_detail() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 682590
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.roughness = 1.0
	for sector in 5:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		for group in 33:
			var station := sector * 32.0 + random.randf_range(0.3, 31.7)
			var side := -1.0 if group % 2 == 0 else 1.0
			var offset := side * (Layout.paving_edge(station) + random.randf_range(0.15, 0.96))
			var group_site := _surface_position(station, offset)
			for blade in 8:
				var angle := random.randf_range(0.0, TAU)
				var outward := Vector3(cos(angle), 0.0, sin(angle))
				var hinge := group_site + outward * random.randf_range(0.018, 0.12)
				var width := random.randf_range(0.008, 0.017)
				var height := random.randf_range(0.066, 0.26)
				var across := outward.cross(Vector3.UP) * width
				var tip := hinge + outward * height * 0.57 + Vector3.UP * height
				var color := Color("3b4b30").lerp(Color("a19358"), random.randf())
				_ground_triangle(surface, hinge - across, hinge + across, tip, color)
		for sprout in 17:
			var station := sector * 32.0 + random.randf_range(0.3, 31.7)
			if station > Layout.LENGTH - 1.0:
				continue
			var side := -1.0 if sprout % 2 else 1.0
			var offset := side * (Layout.half_width(station) + random.randf_range(0.12, 0.20))
			var site := _surface_position(station, offset) + Vector3.UP * 0.024
			for blade in (3 + sprout % 4):
				var angle := random.randf_range(0.0, TAU)
				var wide := Vector3(cos(angle), 0.0, sin(angle)) * random.randf_range(0.009, 0.016)
				var bow := Vector3(wide.z, 0.0, -wide.x) * 3.2
				var tip := site + bow + Vector3.UP * random.randf_range(0.031, 0.099)
				var knuckle := site.lerp(tip, 0.53) + Vector3.UP * 0.009
				var tint := Color("64744a").lerp(Color("a6a06b"), random.randf() * 0.72)
				_ground_triangle(surface, site - wide, site + wide, knuckle + wide * 0.49, tint.darkened(0.12))
				_ground_triangle(surface, site - wide, knuckle + wide * 0.49, knuckle - wide * 0.49, tint.darkened(0.08))
				_ground_triangle(surface, knuckle - wide * 0.49, knuckle + wide * 0.49, tip, tint)
		for tree: Vector4 in _shade_trees:
			var coordinates := Layout.coordinates(Vector2(tree.x, tree.z))
			if floori(coordinates.y / 32.0) != sector:
				continue
			for leaf in 40:
				var station := coordinates.y + random.randf_range(-2.4, 2.4)
				var offset := signf(coordinates.x) * (Layout.half_width(station) + random.randf_range(-0.26, 1.07))
				var center := _surface_position(station, offset) + Vector3.UP * 0.026
				var direction := Vector2.from_angle(random.randf_range(0.0, TAU))
				var long := Vector3(direction.x, 0, direction.y) * random.randf_range(0.015, 0.042)
				var wide := Vector3(-direction.y, 0, direction.x) * random.randf_range(0.011, 0.025)
				var color := Color("917044").lerp(Color("b1a17a"), random.randf())
				_ground_triangle(surface, center - long, center + wide, center + long, color)
				_ground_triangle(surface, center - long, center + long, center - wide, color.darkened(0.14))
		var edge := MeshInstance3D.new()
		edge.name = "VegetacaoRasteira_%d" % sector
		edge.mesh = surface.commit()
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		edge.visibility_range_end = 36.0
		scene_root.add_child(edge)


func _ground_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)


func planter(site: Vector3, size: float, yaw: float) -> void:
	add_instance("planter", "planter", site + Vector3.UP * size * 0.23, Vector3(0.64, 0.44, 0.64) * size, yaw)
	add_instance("planter", "soil", site + Vector3.UP * size * 0.43, Vector3(0.55, 0.05, 0.55) * size, yaw, false)
	understory(site + Vector3.UP * size * 0.43, size, yaw, true)


func _surface_position(station: float, offset: float) -> Vector3:
	return _edge(station, offset, Ground.surface_lift(station, offset) - 0.018)


func _parked_car() -> void:
	var station := 62.2
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
	var trunk := "bark_%d" if solid else "distant_bark_%d"
	add_instance(trunk % species, "tree_bark", site, scale, turn, solid)
	var canopy := "crown_%d" if solid else "distant_crown_%d"
	add_instance(canopy % species, "tree_leaves", site, scale, turn, solid)
	if solid:
		_shade_trees.append(Vector4(site.x, site.y, site.z, size))
		add_collision(site + Vector3.UP * 0.88, Vector3(size * 0.038, 1.84, size * 0.038))


func _utilities() -> void:
	var previous := Vector3.INF
	for station: float in [4.8, 29.8, 50.4, 73.8, 98.8, 124.2, 150.1]:
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
		var emitter := light + crossbar * 0.10 - Vector3.UP * 0.061
		add_box(emitter, Vector3(0.39, 0.028, 0.16), "amber_light", false, rotation_for_cross(station), false)
		add_lamp(emitter - Vector3.UP * 0.11, 5.2, 0.85, 1.33)
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
		add_box(site, Vector3(0.39, 0.019, 0.66), "drain_recess", false, yaw, false)
		for side: float in [-1.0, 1.0]:
			add_part(site, Vector3(side * 0.182, 0.014, 0.0), Vector3(0.040, 0.019, 0.668), "grate", yaw)
			add_part(site, Vector3(0.0, 0.014, 0.319 * side), Vector3(0.385, 0.019, 0.035), "grate", yaw)
		for bar in 10:
			add_part(site, Vector3(0.0, 0.013, (bar - 4.5) * 0.058), Vector3(0.344, 0.016, 0.019), "grate", yaw)
		for side: float in [-1.0, 1.0]:
			add_part(site, Vector3(side * 0.119, 0.023, side * 0.267), Vector3(0.022, 0.008, 0.022), "zinc", yaw, false, "beam")
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


func add_lamp(site: Vector3, radius: float, power: float, halo := 0.77) -> void:
	_lamps.append(Vector4(site.x, site.z, radius, power))
	add_instance("lamp_halo", "street_halo", site - Vector3.UP * 0.022, Vector3.ONE * halo, 0.0, false)
	if power >= 0.72:
		var lamp := OmniLight3D.new()
		lamp.name = "LuzRua_%d" % _lamps.size()
		lamp.position = site - Vector3.UP * 0.19
		lamp.light_color = Color("ffc783")
		lamp.light_energy = power * 1.17
		lamp.light_specular = 0.38
		lamp.light_bake_mode = Light3D.BAKE_DISABLED
		lamp.omni_range = radius * 1.43
		lamp.omni_attenuation = 1.23
		lamp.visible = false
		scene_root.add_child(lamp)


func lettering(message: String, position: Vector3, yaw: float, pixel_size: float, ink: Color, lit := false) -> void:
	add_label(message, position, yaw, pixel_size)
	var label := scene_root.get_child(-1) as Label3D
	label.modulate = ink
	label.outline_size = 0
	label.shaded = not lit
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = clampf(pixel_size * 6800.0, 15.0, 70.0)
	label.visibility_range_end_margin = 3.0
