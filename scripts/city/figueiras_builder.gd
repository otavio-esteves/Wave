extends "res://scripts/city/offline_scene_builder.gd"

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Ground = preload("res://scripts/city/figueiras_ground.gd")
const ScenicBuilder = preload("res://scripts/city/figueiras_scenic_builder.gd")
const TreeMesh = preload("res://scripts/city/neighborhood_tree_mesh.gd")
const STREET_FINISH = preload("res://assets/shaders/figueiras/street_finish.gdshader")
const PLASTER = preload("res://assets/shaders/figueiras/plaster.gdshader")
const SHOP_GLASS = preload("res://assets/shaders/figueiras/shop_glass.gdshader")
const FOUNTAIN = preload("res://assets/shaders/figueiras/fountain.gdshader")
const BAKERY = preload("res://assets/textures/figueiras/bakery-interior.png")
const LOOKOUT_MURAL = preload("res://assets/textures/figueiras/azulejo-mirante.png")
const SHOP_ATLAS = preload("res://assets/textures/figueiras/lojas-interiores.png")
const SHOP_REGIONS := {
	"bakery": Rect2(0.009, 0.009, 0.982, 0.982),
	"cafe": Rect2(0.009, 0.012, 0.482, 0.478),
	"market": Rect2(0.509, 0.012, 0.482, 0.478),
	"workshop": Rect2(0.009, 0.512, 0.482, 0.478),
	"pharmacy": Rect2(0.509, 0.512, 0.482, 0.478),
}
const ParkedCar = preload("res://scripts/city/parked_car_mesh.gd")
const WALLS := ["cream", "sage", "terracotta", "plaster", "blue", "brick"]
const SHOPS := ["PADARIA IPÊ", "CAFÉ DA PRAÇA", "FLORICULTURA", "MERCEARIA", "OFICINA", "LIVRARIA", "ARMAZÉM DO BAIRRO", "FARMÁCIA IPÊ"]
const DETAIL_MATERIALS := ["trim", "metal", "awning", "awning_green", "bench", "flowers", "bush", "grass_blade", "cable", "awning_light", "door", "steel_plate", "signal_case"]
const MATTE_MATERIALS := ["trim", "parapet", "metal", "steel_plate", "signal_case", "ceramic", "terracotta_pot",
	"awning", "awning_green", "awning_light", "bollard", "fence", "sign_ink", "bush", "flowers", "soil", "plaster_dark", "forest", "distant_canopy"]
const PARKED_COLORS := [Color("b8aca1"), Color("577585"), Color("905349"), Color("dedbcc"), Color("4e565a"), Color("bca269")]
const PLAZA_CROSSING_X := 8.75
const PLAZA_CROSSING_CLEARANCE := 3.2
var _ground: RefCounted
var _surface_finishes: Dictionary[String, ShaderMaterial] = {}
var _object_finishes: Dictionary[String, ShaderMaterial] = {}
var _random := RandomNumberGenerator.new()
var _lots := 0
var _trees := 0
var _parked_cars := 0
var _plantings := 0


func build() -> Node3D:
	_random.seed = 7741
	_lots = 0
	_trees = 0
	_parked_cars = 0
	_plantings = 0
	batch_size = 96.0
	center_batches_vertically = true
	begin("VilaDasFigueiras", "SolidObjects")
	meshes["hip_roof"] = _hip_roof()
	_setup_district_materials()
	_ground = Ground.new()
	_ground.build()
	_mark_streets()
	_plaza_crossing()
	_street_wear()
	for row in Layout.ROWS.size() - 1:
		for column in Layout.COLUMNS.size() - 1:
			if row == 1 and column == 1:
				_build_plaza()
			else:
				_build_block(column, row)
	_streetscape()
	_avenue_wayfinding()
	_plaza_edges()
	_perimeter()
	_landscape()
	_reservoir()
	ScenicBuilder.new().build(self, _ground)
	_ground.save_into(scene_root, materials, _surface_finishes)
	finish()
	for node in scene_root.find_children("*", "MultiMeshInstance3D", false, false):
		var material: String = node.material_override.resource_name
		if _object_finishes.has(material):
			node.material_override = _object_finishes[material]
		if material in DETAIL_MATERIALS:
			node.visibility_range_end = 126.0
			node.visibility_range_end_margin = 15.0
		else:
			node.visibility_range_end = 0.0
		if material in ["bark", "canopy", "ipe", "distant_canopy", "forest"]:
			node.lod_bias = 0.45
		# Keep durable silhouettes in the sun map. Fine cards and wires shimmer
		# at sub-texel widths, and distant impostors only frame the skyline.
		if material.begins_with("shop_") or material in ["grass_blade", "flowers", "cable", "glass", "residential_glass_lit", "water", "distant_canopy", "forest", "mural_ipe"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_merge_matte_batches()
	scene_root.set_meta("blocks", (Layout.ROWS.size() - 1) * (Layout.COLUMNS.size() - 1))
	scene_root.set_meta("buildings", _lots)
	scene_root.set_meta("trees", _trees)
	scene_root.set_meta("parked_cars", _parked_cars)
	scene_root.set_meta("plantings", _plantings)
	scene_root.set_meta("scenic_road_length", Layout.scenic_routes()[0].length + Layout.scenic_routes()[1].length)
	return scene_root


func _merge_matte_batches() -> void:
	# Matte paints have identical shader state. Keep each shape, tint and shadow policy.
	var groups: Dictionary = {}
	for instance: MultiMeshInstance3D in scene_root.find_children("*", "MultiMeshInstance3D", false, false):
		if instance.material_override.resource_name not in MATTE_MATERIALS:
			continue
		var key := [instance.multimesh.mesh.get_instance_id(), instance.position.x, instance.position.z,
			instance.cast_shadow, instance.visibility_range_end]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(instance)
	var palette := StandardMaterial3D.new()
	palette.resource_name = "figueiras_matte"
	palette.vertex_color_use_as_albedo = true
	palette.roughness = 0.86
	var saved := 0
	for members: Array in groups.values():
		if members.size() < 2:
			continue
		var first: MultiMeshInstance3D = members[0]
		var bounds: AABB = first.multimesh.custom_aabb
		bounds.position += first.position
		for member: MultiMeshInstance3D in members:
			var local: AABB = member.multimesh.custom_aabb
			local.position += member.position
			bounds = bounds.merge(local)
		var center := bounds.get_center()
		var transforms: Array[Transform3D] = []
		var tints := PackedColorArray()
		for member: MultiMeshInstance3D in members:
			for transform: Transform3D in member.multimesh.instance_transforms:
				transform.origin += member.position - center
				transforms.append(transform)
				tints.append(member.material_override.albedo_color)
		var multimesh := BakedMultiMesh.new()
		multimesh.mesh = first.multimesh.mesh
		multimesh.set_instances(transforms, tints)
		var merged := MultiMeshInstance3D.new()
		merged.name = "PaintedObjects_%d" % saved
		merged.position = center
		merged.multimesh = multimesh
		merged.material_override = palette
		merged.cast_shadow = first.cast_shadow
		merged.visibility_range_end = first.visibility_range_end
		merged.visibility_range_end_margin = first.visibility_range_end_margin
		scene_root.add_child(merged)
		merged.owner = scene_root
		for member: MultiMeshInstance3D in members:
			member.free()
		saved += members.size() - 1
	scene_root.set_meta("merged_draw_batches", saved)


func _setup_district_materials() -> void:
	var palette := {
		"grass": "abb97e", "asphalt": "afada8", "sidewalk": "c4b9a6", "paving": "b9ac99",
		"curb": "b6aba0", "cobbles": "a79881", "mulch": "62513c", "brick": "b89074",
		"utility_cover": "5f615d", "storm_drain": "696660", "asphalt_repair": "96918a",
		"scenic_gutter": "8a836e", "scenic_shoulder": "91917c",
		"plaster_dark": "877862", "ceramic": "578182", "terracotta_pot": "a55d42", "parapet": "bcb099",
		"cream": "d9bd90", "plaster": "d3c9b6", "sage": "9fb098", "terracotta": "be7159", "blue": "7796a8",
		"roof": "ae6b4c", "roof_gray": "5a6465", "stone": "b0a28b", "trim": "d6c9b1", "metal": "414948",
		"awning": "bb5f48", "awning_green": "2f6154", "awning_light": "eee1c5", "sign_ink": "2e3d36",
		"door": "765348", "cable": "383636", "fence": "68594d", "tactile": "c18839",
		"glass": "a4b5b8", "residential_glass_lit": "abac97", "bench": "76513f", "bollard": "54594f",
		"bark": "b8a68b", "canopy": "d8e5c5", "ipe": "ebd077", "distant_canopy": "465b40",
		"forest": "354c3f", "bush": "607747", "flowers": "d07a66", "grass_blade": "9f9d5f",
		"water": "7d9e9c", "white": "ede2c7", "yellow": "e3ad4f", "soil": "75644f",
		"light": "f3e6c2", "parked_car": "ffffff", "signal_case": "323b39", "signal_amber": "f6b93e",
		"reservoir_blue": "5d868a", "steel_plate": "536460", "mural_ipe": "ffffff",
	}
	for room: String in SHOP_REGIONS:
		for side: String in ["left", "right"]:
			palette["shop_%s_%s" % [room, side]] = "ffffff"
	for key: String in palette:
		var material := StandardMaterial3D.new()
		material.resource_name = key
		material.albedo_color = Color(palette[key])
		material.roughness = 0.86
		materials[key] = material
	materials["signal_amber"].emission_enabled = true
	materials["signal_amber"].emission = Color("f5aa20")
	materials["signal_amber"].emission_energy_multiplier = 0.45
	materials["mural_ipe"].albedo_texture = LOOKOUT_MURAL
	materials["mural_ipe"].roughness = 0.58
	materials["mural_ipe"].texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for key in ["grass", "asphalt", "sidewalk", "paving", "bark", "parked_car"]:
		materials[key].vertex_color_use_as_albedo = true
		materials[key].vertex_color_is_srgb = key != "bark"
	materials["asphalt"].albedo_texture = preload("res://assets/textures/pilot/finish-asphalt-albedo.res")
	materials["asphalt"].normal_texture = preload("res://assets/textures/pilot/finish-asphalt-normal.res")
	materials["asphalt"].normal_scale = 0.13
	for key in ["scenic_gutter", "scenic_shoulder"]:
		materials[key].albedo_texture = materials["asphalt"].albedo_texture
		materials[key].normal_texture = materials["asphalt"].normal_texture
	materials["grass"].albedo_texture = preload("res://assets/textures/pilot/finish-grass-albedo.res")
	materials["grass"].normal_texture = preload("res://assets/textures/pilot/finish-grass-normal.res")
	materials["grass"].normal_scale = 0.23
	materials["sidewalk"].albedo_texture = preload("res://assets/textures/neighborhood/paving-albedo.res")
	materials["sidewalk"].normal_texture = preload("res://assets/textures/neighborhood/paving-normal.res")
	materials["sidewalk"].normal_scale = 0.28
	materials["curb"].albedo_texture = preload("res://assets/textures/neighborhood/limestone-albedo.res")
	materials["cobbles"].albedo_texture = preload("res://assets/textures/neighborhood/pavers-albedo.res")
	materials["cobbles"].normal_texture = preload("res://assets/textures/neighborhood/pavers-normal.res")
	materials["cobbles"].normal_scale = 0.48
	materials["mulch"].albedo_texture = preload("res://assets/textures/pilot/finish-grass-albedo.res")
	materials["paving"].albedo_texture = preload("res://assets/textures/neighborhood/pavers-albedo.res")
	materials["paving"].normal_texture = preload("res://assets/textures/neighborhood/pavers-normal.res")
	materials["asphalt_repair"].albedo_texture = materials["asphalt"].albedo_texture
	materials["asphalt_repair"].normal_texture = materials["asphalt"].normal_texture
	materials["curb"].normal_texture = preload("res://assets/textures/neighborhood/limestone-normal.res")
	materials["roof"].albedo_texture = preload("res://assets/textures/neighborhood/roof_tiles-albedo.res")
	materials["roof_gray"].albedo_texture = materials["roof"].albedo_texture
	for key in ["roof", "roof_gray"]:
		materials[key].uv1_scale = Vector3(3.0, 3.0, 1.0)
		materials[key].normal_texture = preload("res://assets/textures/neighborhood/roof_tiles-normal.res")
		materials[key].normal_scale = 0.32
	materials["stone"].albedo_texture = preload("res://assets/textures/neighborhood/limestone-albedo.res")
	for key in WALLS:
		materials[key].albedo_texture = preload("res://assets/textures/neighborhood/stucco-albedo.res")
		materials[key].uv1_scale = Vector3(3, 2, 1)
	materials["brick"].albedo_texture = preload("res://assets/textures/neighborhood/brickwork-albedo.res")
	materials["brick"].normal_texture = preload("res://assets/textures/neighborhood/brickwork-normal.res")
	materials["brick"].normal_scale = 0.46
	materials["brick"].uv1_scale = Vector3(7, 4, 1)
	materials["door"].albedo_texture = preload("res://assets/textures/neighborhood/timber-albedo.res")
	materials["bench"].albedo_texture = materials["door"].albedo_texture
	materials["glass"].albedo_texture = preload("res://assets/textures/pilot/finish-window-interior-albedo.res")
	materials["glass"].albedo_color = Color("8c9c9b")
	materials["residential_glass_lit"].albedo_texture = preload("res://assets/textures/pilot/finish-window-interior-albedo.res")
	for key in ["glass", "residential_glass_lit", "water"]:
		materials[key].roughness = 0.29
	for key in ["canopy", "ipe"]:
		var leaves := materials[key]
		leaves.albedo_texture = preload("res://assets/textures/neighborhood/leaf-cluster-v1.png")
		leaves.vertex_color_use_as_albedo = true
		leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		leaves.alpha_scissor_threshold = 0.42
		leaves.alpha_antialiasing_edge = 0.28
		leaves.roughness = 0.89
		leaves.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["grass_blade"].cull_mode = BaseMaterial3D.CULL_DISABLED
	var window := QuadMesh.new()
	window.size = Vector2.ONE
	meshes["pane"] = window
	for variant in 4:
		var tree := TreeMesh.new().build([0, 3, 1, 5][variant])
		meshes["bark%d" % variant] = tree.bark
		meshes["canopy%d" % variant] = tree.leaves
	for index in PARKED_COLORS.size():
		meshes["parked%d" % index] = ParkedCar.build(PARKED_COLORS[index], true)
	meshes["tuft"] = _grass_mesh()
	meshes["shrub"] = _shrub_mesh()
	_setup_surface_finishes()


func _setup_surface_finishes() -> void:
	_surface_finishes.clear()
	_object_finishes.clear()
	for name: String in ["asphalt", "asphalt_repair", "sidewalk", "curb", "paving", "cobbles", "white", "yellow", "utility_cover", "storm_drain", "grass", "scenic_gutter", "scenic_shoulder"]:
		var finish := ShaderMaterial.new()
		finish.shader = STREET_FINISH
		finish.resource_name = "figueiras_surface_" + name
		var material := materials[name]
		var mode := 0 if name.begins_with("asphalt") else 1
		if name in ["white", "yellow"]:
			mode = 2
		elif name == "utility_cover":
			mode = 3
		elif name == "storm_drain":
			mode = 4
		elif name == "grass":
			mode = 5
		finish.set_shader_parameter("surface_kind", mode)
		finish.set_shader_parameter("tint", material.albedo_color)
		finish.set_shader_parameter("repaved", name == "asphalt_repair")
		if mode < 2 or mode == 5:
			finish.set_shader_parameter("base_color", material.albedo_texture)
			finish.set_shader_parameter("aggregate_normal", material.normal_texture)
		_surface_finishes[name] = finish
	for wall: String in WALLS:
		var material := materials[wall]
		var finish := ShaderMaterial.new()
		finish.shader = PLASTER
		finish.resource_name = "figueiras_wall_" + wall
		finish.set_shader_parameter("wall_color", material.albedo_color)
		finish.set_shader_parameter("color_texture", material.albedo_texture)
		finish.set_shader_parameter("normal_texture", preload("res://assets/textures/neighborhood/stucco-normal.res") if wall != "brick" else material.normal_texture)
		finish.set_shader_parameter("tiling", Vector2(material.uv1_scale.x, material.uv1_scale.y))
		_object_finishes[wall] = finish
	for room: String in SHOP_REGIONS:
		var region: Rect2 = SHOP_REGIONS[room]
		for side: int in [0, 1]:
			var name := "shop_%s_%s" % [room, "left" if side == 0 else "right"]
			var finish := ShaderMaterial.new()
			finish.shader = SHOP_GLASS
			finish.resource_name = "figueiras_" + name
			finish.set_shader_parameter("interior", BAKERY if room == "bakery" else SHOP_ATLAS)
			var start := region.position.x + region.size.x * side * 0.44
			finish.set_shader_parameter("crop", Vector4(start, region.position.y, region.size.x * 0.56, region.size.y))
			_object_finishes[name] = finish
	var water := ShaderMaterial.new()
	water.shader = FOUNTAIN
	water.resource_name = "figueiras_water"
	_object_finishes["water"] = water


func _build_block(column: int, row: int) -> void:
	var block := Layout.block(column, row)
	for front in 4:
		var yaw := front * PI * 0.5
		var forward := Vector2(sin(yaw), cos(yaw))
		var across := Vector2(cos(yaw), -sin(yaw))
		var depth := block.size.y if front % 2 == 0 else block.size.x
		var length := block.size.x if front % 2 == 0 else block.size.y
		var edge := block.get_center() + forward * depth * 0.5
		var commercial := (front == 0 and row == 1) or (front == 2 and row == 2)
		var corner_clearance := 7.0 if front % 2 == 0 else 25.0
		var lots := floori((length - 2.0 * corner_clearance) / (16.5 if commercial else 13.9))
		var market_front := row == 2 and column == 0 and front == 2
		if market_front and lots % 2 == 0:
			lots -= 1
		var lot_width := (length - 2.0 * corner_clearance) / lots
		for index in lots:
			var frontage := edge + across * ((index + 0.5) * lot_width - lot_width * lots * 0.5)
			var shop := commercial and (index + column) % 5 != 4
			var variant := (index + column * 3 + row * 2 + front) % WALLS.size()
			var floors := 3 if shop and index % 3 == 0 else (2 if (index + row + front) % 3 != 0 else 1)
			if commercial and ((column == 0 and index == 1) or (column == 2 and index == 3)):
				floors += 1
			var width := lot_width * _random.randf_range(0.71, 0.94)
			var setback := _random.randf_range(1.0, 3.0) if shop else _random.randf_range(3.9, 6.8)
			var building_depth := _random.randf_range(9.0, 14.5)
			var site := frontage - forward * (setback + building_depth * 0.5)
			var name: String = SHOPS[(index + column * 2 + front) % SHOPS.size()] if shop else ""
			if market_front and index == floori(lots * 0.5):
				site = Layout.MARKET
				frontage.x = site.x
				name = "MERCADO DAS FIGUEIRAS"
				width = lot_width * 0.94
				floors = 2
				building_depth = 16.0
			if column == 0 and row == 0 and front == 2 and index == 2:
				_overlook(frontage, yaw)
			elif not shop and index == lots - 1 and front == 1 and (column + row) % 2 == 0:
				_garden(frontage - forward * 8.0, 4.0, 13)
			else:
				_facade(site, frontage, yaw, width, floors, building_depth, WALLS[variant], name)
	# Backyards form a canopy through each block and break the view between roofs.
	var center := block.get_center()
	for index in 20:
		var site := center + Vector2(_random.randf_range(-0.27, 0.27) * block.size.x, _random.randf_range(-0.24, 0.24) * block.size.y)
		_tree(site, _random.randf_range(4.6, 10.6), index % 4, false)
		if index % 3 == 0:
			_garden(site, 4.5, 14)


func _overlook(frontage: Vector2, yaw: float) -> void:
	var site := frontage + Vector2(0, 6)
	_ground.patch(Rect2(site - Vector2(10.9, 5.9), Vector2(21.8, 12.0)), "cobbles", 0.039)
	for x: float in [-7.5, -2.9, 2.9, 7.5]:
		_bench(site + Vector2(x, 2.1), yaw)
		_garden(site + Vector2(x, 5.5), 2.0, 14)
	for side: float in [-1, 1]:
		_tree(site + Vector2(side * 10.2, 4.9), 6.8, 1, false)
		_park_lantern(site + Vector2(side * 8.0, -3.1))
	var sign_site := Layout.surface_point(site + Vector2(0, -3.1))
	for x: float in [-1.32, 1.32]:
		add_box(sign_site + Vector3(x, 0.95, 0), Vector3(0.10, 1.94, 0.10), "wood", true)
	add_box(sign_site + Vector3(0, 1.82, 0), Vector3(3.35, 0.70, 0.14), "sign_ink")
	add_label("MIRANTE DO IPÊ", sign_site + Vector3(0, 1.82, -0.087), yaw, 0.013)
	_rail(site + Vector2(-10.3, 5.7), site + Vector2(10.3, 5.7), 0.38, 0.72, "stone", true)
	_rail(site + Vector2(-10.3, 5.7), site + Vector2(10.3, 5.7), 0.89, 0.095, "steel_plate")
	for x: float in [-10.3, -7.0, -3.5, 0.0, 3.5, 7.0, 10.3]:
		var post := Layout.surface_point(site + Vector2(x, 5.7), 0.62)
		add_box(post, Vector3(0.13, 0.61, 0.14), "steel_plate")


func _facade(site: Vector2, frontage: Vector2, yaw: float, width: float, floors: int, depth: float, wall: String, shop: String) -> void:
	_lots += 1
	var height := 3.12 * floors
	var front := depth * 0.5
	var basis := Basis(Vector3.UP, yaw)
	var forward := Vector2(basis.z.x, basis.z.z)
	var across := Vector2(basis.x.x, basis.x.z)
	var entrance := site + forward * front
	var facade_y := -INF
	var bottom_y := INF
	for x: float in [-1, 0, 1]:
		for z: float in [-1, 0, 1]:
			var ground_y := Layout.height_at(site + across * x * width * 0.5 + forward * z * front)
			bottom_y = minf(bottom_y, ground_y)
			if z == 1.0:
				facade_y = maxf(facade_y, ground_y)
	facade_y += 0.13
	var origin := Vector3(site.x, facade_y, site.y)
	var foundation := maxf(0.35, facade_y - bottom_y + 0.55)
	add_part(origin, Vector3(0, -foundation * 0.5, 0), Vector3(width, foundation, depth), "stone", yaw, true)
	add_part(origin, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), wall, yaw, true)
	add_part(origin, Vector3(0, 0.22, 0), Vector3(width + 0.15, 0.44, depth + 0.12), "stone", yaw)
	_access(frontage, entrance, facade_y, yaw, width * 0.88 if not shop.is_empty() else 1.75)
	if shop.is_empty() and _lots % 4 != 0:
		var roof_height := depth * 0.20
		var hipped := _lots % 5 in [1, 3]
		var roof_finish := "roof" if _lots % 3 != 0 else "roof_gray"
		add_part(origin, Vector3(0, height + roof_height * 0.5, 0), Vector3(depth + 0.78, roof_height, width + 0.72), roof_finish, yaw + PI * 0.5, false, "hip_roof" if hipped else "roof")
		add_part(origin, Vector3(0, height - 0.02, 0), Vector3(width + 0.80, 0.19, depth + 0.82), "wood", yaw)
		var ridge_width := (width + 0.72) * 0.54 if hipped else width + 0.66
		add_part(origin, Vector3(0, height + roof_height + 0.04, 0), Vector3(ridge_width, 0.11, 0.23), roof_finish, yaw)
		for side: float in [-1, 1]:
			add_part(origin, Vector3(0, height - 0.11, side * (front + 0.4)), Vector3(width + 0.75, 0.13, 0.13), "plaster_dark", yaw)
		if _lots % 3 != 1 and not hipped:
			add_part(origin, Vector3(width * 0.25, height + roof_height * 0.91, -front * 0.44), Vector3(0.63, 1.17, 0.57), "brick", yaw)
			add_part(origin, Vector3(width * 0.25, height + roof_height * 0.91 + 0.58, -front * 0.44), Vector3(0.78, 0.12, 0.71), "stone", yaw)
	else:
		add_part(origin, Vector3(0, height - 0.04, 0), Vector3(width + 0.34, 0.29, depth + 0.32), "trim", yaw)
		add_part(origin, Vector3(0, height + 0.27, front - 0.08), Vector3(width, 0.50, 0.23), wall, yaw)
		add_part(origin, Vector3(width * 0.24, height + 0.53, -depth * 0.21), Vector3(1.4, 1.04, 1.4), "metal", yaw, false, "cylinder")
	for floor_index in floors:
		var y := 1.77 + floor_index * 3.12
		if floor_index == 0 and not shop.is_empty():
			_shopfront(origin, width, front, yaw, shop)
			continue
		for side: float in [-1, 1]:
			var x := side * width * 0.26
			var glass := "residential_glass_lit" if posmod(_lots + int(side) + floor_index, 3) == 0 else "glass"
			var size := Vector2(width * 0.23, 1.47)
			_window(origin, Vector3(x, y, front), size, yaw, glass)
			if (_lots + floor_index) % 3 == 0:
				_shutters(origin, Vector3(x, y, front + 0.18), size, yaw)
			elif (_lots + floor_index) % 4 == 1:
				_window_planter(origin, Vector3(x, y - 0.90, front + 0.29), size.x, yaw)
			_window(origin, Vector3(x, y, front), Vector2(1.55, 1.31), yaw + PI, glass)
			_window(origin, Vector3(0, y, width * 0.5), Vector2(1.55, 1.3), yaw + side * PI * 0.5, glass)
		if floor_index == 1 and _lots % 3 == 0:
			_balcony(origin, width * 0.66, y - 0.86, front, yaw)
	add_part(origin, Vector3(0, 1.1, front + 0.055), Vector3(1.25 if shop.is_empty() else 1.72, 2.20, 0.13), "door" if shop.is_empty() else "glass", yaw)
	add_part(origin, Vector3(0.44, 1.05, front + 0.15), Vector3(0.08, 0.19, 0.07), "trim", yaw)
	if shop.is_empty():
		_house_front(frontage, across, forward, width, yaw)
		if floors > 1:
			_residential_front(origin, width, front, yaw)
		elif _lots % 3 == 1:
			add_part(origin, Vector3(0.66, 2.50, front + 0.36), Vector3(width * 0.52, 0.17, 0.91), "roof_gray", yaw)
			add_part(origin, Vector3(width * 0.28, 1.22, front + 0.74), Vector3(0.19, 2.38, 0.20), "stone", yaw)
			add_part(origin, Vector3(-width * 0.31, 0.23, front + 0.34), Vector3(width * 0.23, 0.45, 0.72), "brick", yaw)


func _residential_front(origin: Vector3, width: float, front: float, yaw: float) -> void:
	if _lots % 3 == 0:
		add_part(origin, Vector3(0, 3.13, front + 0.025), Vector3(width, 0.19, 0.23), "parapet", yaw)
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * width * 0.48, 3.11, front + 0.035), Vector3(0.34, 6.19, 0.18), "parapet", yaw)
	elif _lots % 3 == 1:
		add_part(origin, Vector3(width * 0.407, 3.32, front + 0.02), Vector3(width * 0.165, 5.59, 0.16), "brick", yaw)
		add_part(origin, Vector3(width * 0.407, 2.60, front + 0.14), Vector3(width * 0.165, 0.11, 0.19), "stone", yaw)
		add_part(origin, Vector3(0, 2.48, front + 0.43), Vector3(2.65, 0.16, 1.02), "roof", yaw)
	else:
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * width * 0.41, 1.48, front + 0.015), Vector3(0.16, 3.05, 0.16), "stone", yaw)
		add_part(origin, Vector3(0, 3.1, front + 0.29), Vector3(width * 0.86, 0.13, 0.69), "parapet", yaw)


func _access(frontage: Vector2, entrance: Vector2, floor: float, yaw: float, width: float) -> void:
	var forward := (entrance - frontage).normalized()
	var center := (entrance + frontage) * 0.5
	var depth := frontage.distance_to(entrance) + 0.2
	var size := Vector2(width, depth) if absf(forward.y) > absf(forward.x) else Vector2(depth, width)
	_ground.patch(Rect2(center - size * 0.5, size), "paving", 0.022)
	var rise := floor - Layout.height_at(entrance)
	var steps := clampi(ceili(rise / 0.18), 1, 7)
	for index in steps:
		var distance := (index + 0.55) * 0.31
		var site := entrance - forward * distance
		var top := floor - float(index) * minf(0.22, rise / steps)
		var ground_y := Layout.height_at(site)
		if top > ground_y:
			var base := ground_y - 0.22
			add_box(Vector3(site.x, (top + base) * 0.5, site.y), Vector3(width, top - base, 0.34), "stone", true, yaw)


func _hip_roof() -> ArrayMesh:
	var northwest := Vector3(-0.5, -0.5, -0.5)
	var northeast := Vector3(0.5, -0.5, -0.5)
	var southeast := Vector3(0.5, -0.5, 0.5)
	var southwest := Vector3(-0.5, -0.5, 0.5)
	var north := Vector3(0, 0.5, -0.27)
	var south := Vector3(0, 0.5, 0.27)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for face in [[northwest, northeast, north], [northeast, southeast, south], [northeast, south, north],
		[southeast, southwest, south], [southwest, northwest, north], [southwest, north, south]]:
		for vertex: Vector3 in face:
			surface.set_uv(Vector2(vertex.x + 0.5, vertex.z + 0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


func _shopfront(origin: Vector3, width: float, front: float, yaw: float, shop: String) -> void:
	var room := _shop_room(shop)
	for side: float in [-1, 1]:
		var x := side * (width * 0.24 + 0.25)
		var pane := "glass" if room.is_empty() else "shop_%s_%s" % [room, "left" if side < 0.0 else "right"]
		_window(origin, Vector3(x, 1.48, front), Vector2(width * 0.39, 2.21), yaw, pane)
		add_part(origin, Vector3(x, 2.37, front + 0.16), Vector3(width * 0.39, 0.072, 0.08), "metal", yaw)
		add_part(origin, Vector3(x, 0.29, front + 0.05), Vector3(width * 0.39, 0.54, 0.17), "brick", yaw)
		add_part(origin, Vector3(side * width * 0.49, 1.5, front + 0.11), Vector3(0.25, 3.0, 0.25), "trim", yaw)
	var awning := "awning_green" if _lots % 2 == 0 else "awning"
	if room == "workshop":
		awning = "steel_plate"
	elif room == "market":
		awning = "roof"
	var sign_width := minf(width * 0.86, shop.length() * 0.39 + 0.85)
	var sign_face := front + (2.27 if room == "cafe" else 0.27)
	add_part(origin, Vector3(0, 3.42, sign_face - 0.12), Vector3(sign_width + 0.18, 0.87, 0.20), "trim", yaw)
	add_part(origin, Vector3(0, 3.42, sign_face), Vector3(sign_width, 0.72, 0.08), "sign_ink", yaw)
	add_label(shop, origin + Basis(Vector3.UP, yaw) * Vector3(0, 3.42, sign_face + 0.05), yaw, minf(0.020, sign_width / (shop.length() * 26.0)))
	if room == "cafe":
		_commercial_canopy(origin, width, front, yaw, "awning_green", "brick", 2.14)
		_cafe_terrace(origin, width, front, yaw)
	elif room == "pharmacy":
		_commercial_canopy(origin, width, front, yaw, "ceramic", "trim", 1.35)
		var cross := Vector3(width * 0.39, 3.88, front + 0.30)
		add_part(origin, cross, Vector3(0.94, 0.24, 0.21), "ceramic", yaw)
		add_part(origin, cross, Vector3(0.24, 0.94, 0.22), "ceramic", yaw)
	else:
		_shop_awning(origin, width, front, yaw, awning, room)
	if room == "bakery":
		_cafe_terrace(origin, width, front, yaw)
	elif shop.begins_with("MERCADO"):
		_market_display(origin, width, front, yaw)
		_market_front(origin, width, front, yaw)
	elif room == "workshop":
		for offset in [-0.55, 0.55]:
			add_part(origin, Vector3(offset, 1.29, front + 0.36), Vector3(0.08, 2.58, 0.09), "steel_plate", yaw)
		add_part(origin, Vector3(0, 2.68, front + 0.30), Vector3(2.14, 0.24, 0.27), "metal", yaw)


func _commercial_canopy(origin: Vector3, width: float, front: float, yaw: float, finish: String, frame: String, depth: float) -> void:
	add_part(origin, Vector3(0, 2.89, front + depth * 0.5), Vector3(width + 0.30, 0.18, depth), frame, yaw)
	add_part(origin, Vector3(0, 3.02, front + depth * 0.5), Vector3(width + 0.44, 0.10, depth + 0.17), finish, yaw)
	add_part(origin, Vector3(0, 2.79, front + depth), Vector3(width + 0.41, 0.19, 0.12), finish, yaw)
	for side: float in [-1, 1]:
		var x := side * width * 0.48
		add_part(origin, Vector3(x, 2.84, front + depth * 0.54), Vector3(0.26, 0.31, depth), frame, yaw)
		add_part(origin, Vector3(x, 1.38, front + depth - 0.13), Vector3(0.23, 2.76, 0.23), frame, yaw)


func _shop_awning(origin: Vector3, width: float, front: float, yaw: float, awning: String, room: String) -> void:
	var awning_width := width + 0.12
	var awning_root := origin + Basis(Vector3.UP, yaw) * Vector3(0, 2.91, front + 0.82)
	var tilt := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.16)
	add_transformed_instance("box", awning, Transform3D(tilt.scaled_local(Vector3(awning_width, 0.085, 1.56)), awning_root))
	add_part(origin, Vector3(0, 2.72, front + 1.60), Vector3(awning_width, 0.21, 0.07), awning, yaw)
	for slot in 9:
		var x := (slot - 4) * awning_width / 9.0
		if _lots % 3 == 0 or room in ["workshop", "market"]:
			continue
		var stripe_position := awning_root + tilt * Vector3(x, 0.048, 0.0)
		add_transformed_instance("box", "awning_light", Transform3D(tilt.scaled_local(Vector3(width / 21.0, 0.009, 1.54)), stripe_position))
		add_part(origin, Vector3(x, 2.72, front + 1.64), Vector3(width / 21.0, 0.21, 0.012), "awning_light", yaw)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * width * 0.42, 2.77, front + 0.84), Vector3(0.045, 0.051, 1.49), "metal", yaw)
		add_part(origin, Vector3(side * width * 0.45, 0.21, front + 0.53), Vector3(0.27, 0.42, 0.27), "terracotta_pot", yaw, false, "cylinder")
		add_part(origin, Vector3(side * width * 0.45, 0.66, front + 0.53), Vector3(0.44, 0.48, 0.42), "bush", yaw, false, "shrub")


func _shop_room(shop: String) -> String:
	if shop.begins_with("PADARIA"):
		return "bakery"
	if shop.begins_with("CAFÉ"):
		return "cafe"
	if shop.begins_with("MERCADO") or shop.begins_with("MERCEARIA") or shop.begins_with("ARMAZÉM"):
		return "market"
	if shop.begins_with("OFICINA"):
		return "workshop"
	if shop.begins_with("FARMÁCIA"):
		return "pharmacy"
	return ""


func _market_front(origin: Vector3, width: float, front: float, yaw: float) -> void:
	add_part(origin, Vector3(0, 4.19, front + 0.18), Vector3(width * 1.035, 0.29, 0.55), "ceramic", yaw)
	add_part(origin, Vector3(0, 4.46, front + 0.10), Vector3(width * 0.72, 0.37, 0.37), "trim", yaw)
	add_part(origin, Vector3(0, 4.72, front + 0.09), Vector3(width * 0.40, 0.24, 0.33), "ceramic", yaw)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * width * 0.475, 1.40, front + 1.53), Vector3(0.27, 2.78, 0.29), "brick", yaw, true)
		add_part(origin, Vector3(side * width * 0.475, 0.16, front + 1.53), Vector3(0.49, 0.34, 0.46), "stone", yaw)
		add_part(origin, Vector3(side * width * 0.42, 2.57, front + 1.61), Vector3(0.86, 0.15, 0.15), "light", yaw)


func _cafe_terrace(origin: Vector3, width: float, front: float, yaw: float) -> void:
	for side: float in [-1, 1]:
		var center := Vector3(side * width * 0.305, 0.0, front + 1.11)
		add_part(origin, center + Vector3.UP * 0.38, Vector3(0.068, 0.72, 0.068), "metal", yaw)
		add_part(origin, center + Vector3.UP * 0.74, Vector3(0.39, 0.07, 0.39), "bench", yaw, false, "cylinder")
		for x: float in [-0.69, 0.69]:
			add_part(origin, center + Vector3(x, 0.42, 0), Vector3(0.36, 0.065, 0.38), "bench", yaw)
			add_part(origin, center + Vector3(x * 1.22, 0.60, 0), Vector3(0.04, 0.36, 0.38), "metal", yaw)
			for z: float in [-0.13, 0.13]:
				add_part(origin, center + Vector3(x, 0.21, z), Vector3(0.065, 0.4, 0.052), "metal", yaw)


func _market_display(origin: Vector3, width: float, front: float, yaw: float) -> void:
	for side: float in [-1, 1]:
		var base := Vector3(side * width * 0.32, 0.38, front + 0.54)
		add_part(origin, base, Vector3(2.39, 0.58, 0.82), "bench", yaw)
		for crate in 3:
			var x := (crate - 1) * 0.77
			add_part(origin, base + Vector3(x, 0.34, 0), Vector3(0.67, 0.14, 0.67), "terracotta_pot", yaw)
			add_part(origin, base + Vector3(x, 0.47, 0), Vector3(0.27, 0.12, 0.25), "flowers" if crate == 1 else "bush", yaw, false, "shrub")


func _shutters(origin: Vector3, offset: Vector3, size: Vector2, yaw: float) -> void:
	for side: float in [-1, 1]:
		var x := side * (size.x * 0.5 + 0.18)
		add_part(origin, offset + Vector3(x, 0, 0), Vector3(0.31, size.y * 0.93, 0.075), "door", yaw)
		for slat in 5:
			var y := (slat - 2) * size.y / 6.0
			add_part(origin, offset + Vector3(x, y, 0.044), Vector3(0.28, 0.021, 0.023), "plaster_dark", yaw)


func _window_planter(origin: Vector3, offset: Vector3, width: float, yaw: float) -> void:
	add_part(origin, offset, Vector3(width * 0.75, 0.20, 0.31), "terracotta_pot", yaw)
	for section in 4:
		var x := (section - 1.5) * width * 0.17
		add_part(origin, offset + Vector3(x, 0.20, 0.02), Vector3(0.28, 0.25, 0.25), "bush", yaw, false, "shrub")


func _window(origin: Vector3, offset: Vector3, size: Vector2, yaw: float, glass: String) -> void:
	add_part(origin, offset + Vector3(0, 0, 0.035), Vector3(size.x + 0.20, size.y + 0.20, 0.17), "trim", yaw)
	add_part(origin, offset + Vector3(0, 0, 0.14), Vector3(size.x, size.y, 1), glass, yaw, false, "pane")
	add_part(origin, offset + Vector3(0, 0, 0.16), Vector3(0.058, size.y, 0.06), "metal", yaw)
	add_part(origin, offset + Vector3(0, -size.y * 0.5 - 0.095, 0.14), Vector3(size.x + 0.38, 0.14, 0.31), "stone", yaw)


func _balcony(origin: Vector3, width: float, height: float, front: float, yaw: float) -> void:
	add_part(origin, Vector3(0, height, front + 0.63), Vector3(width, 0.21, 1.35), "stone", yaw)
	add_part(origin, Vector3(0, height + 0.96, front + 1.26), Vector3(width, 0.065, 0.065), "metal", yaw)
	for index in 8:
		var x := (index / 7.0 - 0.5) * (width - 0.14)
		add_part(origin, Vector3(x, height + 0.51, front + 1.26), Vector3(0.043, 0.90, 0.055), "metal", yaw)


func _house_front(frontage: Vector2, across: Vector2, forward: Vector2, width: float, yaw: float) -> void:
	for side: float in [-1, 1]:
		var garden := frontage + across * side * width * 0.31 - forward * 1.65
		_garden(garden, minf(2.5, width * 0.23), 8)
		var length := width * 0.39
		var center := frontage + across * side * (width * 0.27 + 0.55) - forward * 0.45
		for index in 4:
			var post := Layout.surface_point(center + across * (index / 3.0 - 0.5) * length)
			add_box(post + Vector3.UP * 0.58, Vector3(0.19, 1.28, 0.19), "stone")
		_rail(center - across * length * 0.5, center + across * length * 0.5, 0.27, 0.44, "brick", true)
		_rail(center - across * length * 0.5, center + across * length * 0.5, 1.02, 0.09, "fence")
	if _lots % 4 == 0:
		var tree := frontage - forward * 3.0 + across * width * 0.28
		_tree(tree, _random.randf_range(3.7, 5.4), _lots % 3, false)
	if _lots % 3 == 0:
		var box := Layout.surface_point(frontage - forward * 0.48 + across * 1.20)
		add_box(box + Vector3.UP * 1.11, Vector3(0.31, 0.21, 0.34), "metal", false, yaw)


func _rail(start: Vector2, end: Vector2, height: float, thickness: float, material: String, solid := false) -> void:
	var a := Layout.surface_point(start, height)
	var b := Layout.surface_point(end, height)
	var direction := b - a
	var basis := Basis.looking_at(direction.normalized())
	var size := Vector3(0.21 if solid else thickness, thickness, direction.length())
	# This part needs pitch as well as yaw to follow the slope between posts.
	_add_tilted_box((a + b) * 0.5, basis, size, material, solid)


func _add_tilted_box(center: Vector3, basis: Basis, size: Vector3, material: String, solid: bool) -> void:
	add_transformed_instance("box", material, Transform3D(basis.scaled_local(size), center))
	if solid:
		add_collision(center, size)
		_colliders.get_child(-1).basis = basis


func _build_plaza() -> void:
	var center := Layout.PLAZA.get_center()
	_ground.patch(Rect2(center.x - 28, center.y - 9, 56, 21), "paving", 0.035)
	_ground.patch(Rect2(center.x - 4.2, Layout.PLAZA.position.y, 8.4, Layout.AVENUE - Layout.AVENUE_HALF - Layout.PLAZA.position.y), "cobbles", 0.046)
	_ground.patch(Rect2(-48, 19.8, 96, 5.0), "cobbles", 0.044)
	for x: float in [-4.2, 3.75]:
		_ground.patch(Rect2(x, -35.0, 0.45, 76.0), "curb", 0.052)
	for side: float in [-1, 1]:
		for z: float in [-22.0, 3.2, 31.0]:
			_park_lantern(Vector2(side * 6.15, z))
	_ground.patch(Rect2(-51, -29, 102, 4.5), "paving", 0.035)
	for x: float in [-47, 43]:
		_ground.patch(Rect2(x, -29, 4.0, 66.0), "paving", 0.035)
	_ground.patch(Rect2(-34, 19, 68, 4.2), "paving", 0.037)
	var fig := Layout.surface_point(center + Vector2(0, -12))
	_tree(Vector2(fig.x, fig.z), 14.0, 0)
	add_instance("cylinder", "stone", fig + Vector3.UP * 0.20, Vector3(6.2, 0.50, 6.2))
	add_collision(fig + Vector3.UP * 0.19, Vector3(8.0, 0.45, 8.0))
	add_instance("cylinder", "soil", fig + Vector3.UP * 0.456, Vector3(5.93, 0.03, 5.93))
	var basin := Layout.surface_point(center + Vector2(0, 15.0))
	add_instance("cylinder", "stone", basin + Vector3.UP * 0.27, Vector3(5.8, 0.65, 5.8))
	add_collision(basin + Vector3.UP * 0.25, Vector3(5.8, 0.6, 5.8))
	add_instance("cylinder", "ceramic", basin + Vector3.UP * 0.58, Vector3(5.77, 0.12, 5.77))
	add_instance("cylinder", "water", basin + Vector3.UP * 0.66, Vector3(5.43, 0.04, 5.43))
	add_instance("cylinder", "stone", basin + Vector3.UP * 0.79, Vector3(0.51, 1.56, 0.51))
	add_instance("cylinder", "ceramic", basin + Vector3.UP * 1.47, Vector3(1.70, 0.16, 1.70))
	add_instance("cylinder", "water", basin + Vector3.UP * 1.56, Vector3(1.52, 0.025, 1.52))
	for side: float in [-1, 1]:
		for offset: float in [-28, -16, 19, 30]:
			_tree(center + Vector2(side * 27.0, offset), 7.8, 1 if offset in [-28.0, 19.0] else 0)
		for offset: float in [-4, 7]:
			var bench := Layout.surface_point(center + Vector2(side * 16, offset))
			add_part(bench, Vector3(0, 0.45, 0), Vector3(2.35, 0.12, 0.63), "bench", side * PI * 0.5, true)
			add_part(bench, Vector3(0, 0.80, -0.30), Vector3(2.35, 0.48, 0.09), "bench", side * PI * 0.5)
			for x: float in [-0.87, 0.87]:
				add_part(bench, Vector3(x, 0.20, 0), Vector3(0.13, 0.4, 0.46), "metal", side * PI * 0.5)
	var sign_site := Layout.surface_point(Vector2(12.5, 37.0))
	add_box(sign_site + Vector3.UP * 1.72, Vector3(10.0, 1.15, 0.23), "metal", true)
	for x: float in [-4.2, 4.2]:
		add_box(sign_site + Vector3(x, 0.87, 0), Vector3(0.19, 1.8, 0.19), "metal")
	add_label("PRAÇA DA FIGUEIRA", sign_site + Vector3(0, 1.72, 0.127), 0.0, 0.021)
	var kiosk := Layout.surface_point(Vector2(-31, 11.5), 0.25)
	add_part(kiosk, Vector3(0, 1.85, 0), Vector3(9.6, 4.2, 6.3), "sage", 0, true)
	add_part(kiosk, Vector3(0, 4.04, 0), Vector3(10.5, 0.37, 7.2), "roof", 0)
	_window(kiosk, Vector3(0, 1.86, 3.15), Vector2(5.8, 1.9), 0, "glass")
	add_part(kiosk, Vector3(0, 3.2, 3.86), Vector3(8.5, 0.17, 1.81), "awning", 0)
	add_label("BANCA DA PRAÇA", kiosk + Vector3(0, 3.62, 3.26), 0.0, 0.017)
	_plaza_shelter(Vector2(34, -13))
	_plaza_pergola(Vector2(-22, 24))
	for x: float in [-20.5, 18.5]:
		var bed := Layout.surface_point(Vector2(x, 27.0))
		add_box(bed + Vector3.UP * 0.17, Vector3(8.0, 0.42, 3.05), "stone", true)
		for offset: float in [-2.5, 0, 2.5]:
			add_instance("shrub", "bush", bed + Vector3(offset, 0.57, 0), Vector3(1.34, 0.54, 1.2), 0.0, false)
	for x: float in [-38, -27, -17, 14, 27, 39]:
		for z: float in [-35, -19, -12, 32]:
			var site := Vector2(x, z)
			if x > 24.0 and z in [-19.0, -12.0]:
				continue
			_garden(site, 3.8, 22)
			if z == -35.0 or z == 32.0:
				_tree(site, _random.randf_range(5.8, 8.6), posmod(int(x), 4), false)
	for x: float in [-39, -20, 19, 39]:
		_bench(Vector2(x, 25.5), PI)
		_bench(Vector2(x, -23.2), 0.0)


func _plaza_pergola(site: Vector2) -> void:
	_ground.patch(Rect2(site - Vector2(9.0, 3.0), Vector2(18.0, 6.0)), "cobbles", 0.053)
	var root := Layout.surface_point(site)
	var height := 3.60
	for side: float in [-1, 1]:
		for x: float in [-8.1, -2.7, 2.7, 8.1]:
			var post := Layout.surface_point(site + Vector2(x, side * 2.0))
			var length := root.y + height - post.y
			add_box(post + Vector3.UP * length * 0.5, Vector3(0.38, length, 0.38), "brick", true)
			add_box(post + Vector3.UP * 0.24, Vector3(0.56, 0.5, 0.55), "stone")
		add_box(root + Vector3(0, height, side * 2.0), Vector3(17.2, 0.39, 0.34), "wood")
	for index in 17:
		add_box(root + Vector3(index - 8.0, height + 0.24, 0), Vector3(0.14, 0.19, 4.58), "wood")


func _plaza_edges() -> void:
	# The east edge steps with the slope and opens twice onto the park paths.
	for pair: Vector2 in [Vector2(-33, -19), Vector2(-14, 7), Vector2(12, 28)]:
		_rail(Vector2(53.0, pair.x), Vector2(53.0, pair.y), 0.33, 0.62, "stone", true)
		_rail(Vector2(53.0, pair.x), Vector2(53.0, pair.y), 0.66, 0.12, "brick")
		for z in range(ceili(pair.x) + 2, floori(pair.y), 4):
			var site := Vector2(51, z)
			var base := Layout.surface_point(site)
			add_instance("shrub", "bush", base + Vector3.UP * 0.31, Vector3(1.40, 0.74, 1.62), 0.0, false)
			_garden(site + Vector2(-2.2, 0.25), 1.55, 8)
	for site: Vector2 in [Vector2(54.4, 37.1), Vector2(74.0, 36.7)]:
		var base := Layout.surface_point(site)
		_ground.patch(Rect2(site - Vector2(1.6, 1.0), Vector2(3.2, 2.0)), "mulch", 0.022)
		for x: float in [-0.94, 0.94]:
			add_instance("shrub", "bush", base + Vector3(x, 0.30, 0), Vector3(1.24, 0.66, 1.07), 0.0, false)
		_garden(site, 1.25, 13)


func _park_lantern(site: Vector2) -> void:
	var foot := Layout.surface_point(site)
	add_instance("cylinder", "metal", foot + Vector3.UP * 1.30, Vector3(0.064, 2.60, 0.064))
	add_box(foot + Vector3.UP * 2.60, Vector3(0.29, 0.23, 0.29), "light")
	add_instance("roof", "metal", foot + Vector3.UP * 2.83, Vector3(0.40, 0.19, 0.40))
	_lamp_marker(foot + Vector3.UP * 2.53)


func _plaza_shelter(site: Vector2) -> void:
	var point := Layout.surface_point(site, 0.68)
	var footprint := Vector2(17.0, 12.0)
	_ground.patch(Rect2(site - footprint * 0.63, footprint * 1.26), "cobbles", 0.036)
	var low := INF
	for x: float in [-8, 8]:
		for z: float in [-5.5, 5.5]:
			var corner := point + Vector3(x, 0, z)
			low = minf(low, Layout.height_at(Vector2(corner.x, corner.z)) - 0.35)
			add_box(corner + Vector3.UP * 1.77, Vector3(0.28, 3.65, 0.28), "wood", true)
	var support := point.y - low
	add_box(point - Vector3.UP * support * 0.5, Vector3(17.0, support, 12.0), "stone", true)
	add_instance("roof", "roof", point + Vector3.UP * 4.48, Vector3(17.9, 1.75, 12.9))
	add_box(point + Vector3(0, 3.56, 5.57), Vector3(16.7, 0.24, 0.32), "wood")
	for x: float in [-5.8, -2.9, 0, 2.9, 5.8]:
		add_part(point, Vector3(x, 0.46, 2.25), Vector3(2.12, 0.15, 0.65), "bench", 0.0)
		add_part(point, Vector3(x, 0.28, 2.25), Vector3(1.82, 0.42, 0.14), "metal", 0.0)
	add_label("CORETO DA VILA", point + Vector3(0, 3.28, 5.62), 0, 0.015)


func _mark_streets() -> void:
	for row in Layout.ROWS.size():
		var z: float = Layout.ROWS[row]
		var avenue := z == Layout.AVENUE
		for column in Layout.COLUMNS.size() - 1:
			var start: float = Layout.COLUMNS[column] + Layout.COLUMN_HALF_WIDTHS[column] + Layout.junction_radius(column, row) + 6.0
			var end: float = Layout.COLUMNS[column + 1] - Layout.COLUMN_HALF_WIDTHS[column + 1] - Layout.junction_radius(column + 1, row) - 6.0
			if avenue:
				var passes_plaza := column == 1
				var crossing_start := PLAZA_CROSSING_X - PLAZA_CROSSING_CLEARANCE
				var crossing_end := PLAZA_CROSSING_X + PLAZA_CROSSING_CLEARANCE
				var spans := [Vector2(start, crossing_start), Vector2(crossing_end, end)] if passes_plaza else [Vector2(start, end)]
				for side: float in [-1, 1]:
					for span: Vector2 in spans:
						_ground.patch(Rect2(span.x, z + side * 0.145 - 0.062, span.y - span.x, 0.124), "yellow", 0.027)
						_ground.patch(Rect2(span.x, z + side * Layout.AVENUE_TRAVEL_HALF - 0.06, span.y - span.x, 0.12), "white", 0.027)
					for x in range(ceili(start), floori(end) - 5, 9):
						if not passes_plaza or x + 5.1 < crossing_start or x > crossing_end:
							_ground.patch(Rect2(x, z + side * Layout.AVENUE_LANE - 0.067, 5.1, 0.134), "white", 0.026)
					for x in range(ceili(start) + 1, floori(end), 6):
						if not passes_plaza or x < crossing_start or x > crossing_end:
							_mark(Vector2(x, z + side * (Layout.AVENUE_TRAVEL_HALF + Layout.PARKING_WIDTH * 0.5)), Vector2(0.09, Layout.PARKING_WIDTH - 0.20), 0, "white", 0.026)
					var heading := Vector2(side, 0)
					var approach := end - 12.0 if side > 0.0 else start + 12.0
					_road_arrow(Vector2(approach, z + side * Layout.AVENUE_LANE * 0.5), heading)
					_road_arrow(Vector2(approach, z + side * Layout.AVENUE_LANE * 1.5), heading)
			elif row != 3:
				for x in range(ceili(start), floori(end) - 3, 13):
					_ground.patch(Rect2(x, z - 0.056, 3.9, 0.112), "yellow", 0.025)
	for row in Layout.ROWS.size() - 1:
		var from: float = Layout.ROWS[row] + Layout.ROW_HALF_WIDTHS[row] + Layout.junction_radius(2, row) + 6.0
		var to: float = Layout.ROWS[row + 1] - Layout.ROW_HALF_WIDTHS[row + 1] - Layout.junction_radius(2, row + 1) - 6.0
		for side: float in [-1, 1]:
			_ground.patch(Rect2(Layout.COLLECTOR + side * (Layout.COLLECTOR_HALF - 0.56) - 0.065, from, 0.13, to - from), "white", 0.025)
		for z in range(ceili(from), floori(to) - 5, 10):
			_ground.patch(Rect2(Layout.COLLECTOR - 0.063, z, 0.126, 4.8), "yellow", 0.025)
	for row in [1, 2, 3]:
		for column in Layout.COLUMNS.size():
			var center := Vector2(Layout.COLUMNS[column], Layout.ROWS[row])
			var arms: Array[int] = []
			if column < Layout.COLUMNS.size() - 1:
				arms.append(1)
			if column > 0:
				arms.append(3)
			if row < Layout.ROWS.size() - 1:
				arms.append(0)
			if row > 0:
				arms.append(2)
			for arm in arms:
				var heading := Vector2(sin(arm * PI * 0.5), cos(arm * PI * 0.5)).round()
				var across := heading.orthogonal()
				var outgoing: float = Layout.COLUMN_HALF_WIDTHS[column] if arm % 2 == 1 else Layout.ROW_HALF_WIDTHS[row]
				var cross_width: float = Layout.ROW_HALF_WIDTHS[row] if arm % 2 == 1 else Layout.COLUMN_HALF_WIDTHS[column]
				var radius := Layout.junction_radius(column, row)
				var crossing := outgoing + radius + 0.90
				if row == 2 or (column == 2 and row == 1):
					for stripe in range(-floori(cross_width - 0.45), floori(cross_width - 0.45) + 1):
						var point := center + heading * crossing + across * stripe
						_mark(point, Vector2(0.53, 2.55), arm, "white", 0.029)
					for side: float in [-1, 1]:
						var pad := center + heading * crossing + across * side * (cross_width + 0.70)
						_mark(pad, Vector2(0.55, 2.2), arm, "tactile", 0.028)
				if arm % 2 == 0 and row == 2:
					var stop := center + heading * (crossing + 2.15) + across * cross_width * 0.5
					_mark(stop, Vector2(cross_width - 0.42, 0.33), arm, "white", 0.026)
				if row == 2 and column == 2:
					var site := center + heading * (crossing + 1.8) + across * (cross_width + 1.04)
					_signal(site, -heading)


func _plaza_crossing() -> void:
	var center := Vector2(PLAZA_CROSSING_X, Layout.AVENUE)
	for stripe in range(-9, 10):
		_mark(center + Vector2(0, stripe), Vector2(3.55, 0.56), 0, "white", 0.032)
	for side: float in [-1, 1]:
		var approach := center + Vector2(-side * 2.62, side * Layout.AVENUE_TRAVEL_HALF * 0.5)
		_mark(approach, Vector2(0.31, Layout.AVENUE_TRAVEL_HALF - 0.34), 0, "white", 0.031)
		var landing := center + Vector2(0, side * (Layout.AVENUE_HALF + 1.25))
		_mark(landing, Vector2(4.25, 1.68), 0, "cobbles", 0.026)
		_mark(landing - Vector2(0, side * 0.63), Vector2(3.55, 0.42), 0, "tactile", 0.033)
		for edge: float in [-1, 1]:
			var foot := Layout.surface_point(landing + Vector2(edge * 2.31, 0))
			add_instance("cylinder", "bollard", foot + Vector3.UP * 0.48, Vector3(0.085, 0.96, 0.085))
			add_instance("cylinder", "tactile", foot + Vector3.UP * 0.82, Vector3(0.09, 0.09, 0.09))


func _road_arrow(center: Vector2, direction: Vector2) -> void:
	var half_width := direction.orthogonal() * 0.62
	_ground.patch_polygon(PackedVector2Array([center - half_width, center + half_width, center + direction * 1.55]), "white", 0.029)
	var tail := center - direction * 0.95
	_ground.patch(Rect2(tail - Vector2(1.05, 0.14), Vector2(2.10, 0.28)), "white", 0.028)


func _street_wear() -> void:
	for column in Layout.COLUMNS.size() - 1:
		var a: float = Layout.COLUMNS[column]
		var b: float = Layout.COLUMNS[column + 1]
		for row in Layout.ROWS.size():
			var z: float = Layout.ROWS[row]
			var x := lerpf(a, b, 0.34 + 0.11 * ((row + column) % 3))
			var width := 3.8 if z == Layout.AVENUE else 2.9
			var center := Vector2(x, z - width * 0.40)
			_ground.patch_polygon(PackedVector2Array([center + Vector2(-2.6, -width * 0.40), center + Vector2(2.5, -width * 0.48),
				center + Vector2(2.25, width * 0.29), center + Vector2(-1.9, width * 0.44)]), "asphalt_repair", 0.011)
			_ground.patch(Rect2(x + 5.1, z + 0.74, 0.85, 0.85), "utility_cover", 0.019)
			if z == Layout.AVENUE:
				for side: float in [-1, 1]:
					for placement in [0.22, 0.46, 0.76]:
						var drain := Vector2(lerpf(a, b, placement), z + side * (Layout.AVENUE_HALF - 0.28))
						_mark(drain, Vector2(1.0, 0.41), 0, "storm_drain", 0.021)


func _mark(point: Vector2, footprint: Vector2, arm: int, material: String, lift: float) -> void:
	var size := footprint if arm % 2 == 0 else Vector2(footprint.y, footprint.x)
	_ground.patch(Rect2(point - size * 0.5, size), material, lift)


func _streetscape() -> void:
	for column in Layout.COLUMNS.size() - 1:
		var start: float = Layout.COLUMNS[column]
		var end: float = Layout.COLUMNS[column + 1]
		for side: float in [-1, 1]:
			for index in 7:
				var x := lerpf(start + 15, end - 15, (index + 0.5) / 7.0)
				var verge := Vector2(x, Layout.AVENUE + side * (Layout.AVENUE_HALF + 1.03))
				if index % 3 == 0:
					_lamp(verge, Vector2(0, -side))
				else:
					_tree(verge, _random.randf_range(5.1, 8.6), (index + column) % 4)
					_mark(verge, Vector2(1.46, 1.43), 0, "mulch", 0.017)
				if index in [1, 2, 4, 5]:
					_park(Vector2(x + 2.4, Layout.AVENUE + side * (Layout.AVENUE_TRAVEL_HALF + Layout.PARKING_WIDTH * 0.5)), side)
			var stop_site := Vector2(lerpf(start, end, 0.46), Layout.AVENUE + side * (Layout.AVENUE_HALF + 2.66))
			if side == -1 or column == 2:
				_bus_stop(stop_site, side)
	for row in [0, 1, 3]:
		var z: float = Layout.ROWS[row]
		for column in Layout.COLUMNS.size() - 1:
			var start: float = Layout.COLUMNS[column]
			var end: float = Layout.COLUMNS[column + 1]
			var previous := Vector2.ZERO
			for t: float in [0.12, 0.38, 0.65, 0.88]:
				var x := lerpf(start, end, t)
				var pole := Vector2(x, z + Layout.LOCAL_HALF + 0.68)
				_lamp(pole, Vector2.UP)
				if previous != Vector2.ZERO:
					_rail(previous, pole, 6.12, 0.024, "cable")
				previous = pole
				_tree(Vector2(x + 3.6, z - Layout.LOCAL_HALF - 0.77), _random.randf_range(5.6, 8.2), (column + row) % 4)
	for column in Layout.COLUMNS.size():
		var street: float = Layout.COLUMNS[column]
		var verge: float = Layout.COLUMN_HALF_WIDTHS[column] + 0.66
		for row in Layout.ROWS.size() - 1:
			for t: float in [0.19, 0.40, 0.60, 0.81]:
				var z := lerpf(Layout.ROWS[row], Layout.ROWS[row + 1], t)
				_tree(Vector2(street + verge, z), _random.randf_range(4.8, 7.8), row % 4)
				_tree(Vector2(street - verge, z + 2.4), _random.randf_range(4.8, 7.8), (column + 2) % 4)
			var positions := [0.095, 0.30, 0.50, 0.71, 0.90]
			for index in positions.size():
				var z := lerpf(Layout.ROWS[row], Layout.ROWS[row + 1], positions[index])
				var side := 1.0 if (column + row + index) % 2 == 0 else -1.0
				_lamp(Vector2(street + side * verge, z), Vector2(-side, 0))


func _park(site: Vector2, side: float) -> void:
	var yaw := side * PI * 0.5
	var a := Layout.surface_point(site - Vector2(1.83, 0.0))
	var b := Layout.surface_point(site + Vector2(1.83, 0.0))
	var basis := Basis.looking_at((b - a).normalized() * side)
	var point := Layout.surface_point(site, 0.28)
	add_transformed_instance("parked%d" % (_parked_cars % PARKED_COLORS.size()), "parked_car", Transform3D(basis, point))
	_ground.patch(Rect2(site - Vector2(2.50, 1.11), Vector2(5.0, 2.22)), "shade_parked", 0.033)
	add_collision(point + Vector3.UP * 0.29, Vector3(1.74, 1.06, 3.94), yaw)
	_colliders.get_child(-1).basis = basis
	_parked_cars += 1


func _bus_stop(site: Vector2, side: float) -> void:
	var point := Layout.surface_point(site)
	_ground.patch(Rect2(site - Vector2(2.85, 0.91), Vector2(5.7, 1.82)), "paving", 0.043)
	for x: float in [-2.45, 2.45]:
		var foot := Layout.surface_point(site + Vector2(x, 0.47 * side))
		var height := point.y + 2.69 - foot.y
		add_box(foot + Vector3.UP * height * 0.5, Vector3(0.11, height, 0.11), "steel_plate", true)
	add_box(point + Vector3(0, 2.62, 0.0), Vector3(5.35, 0.14, 1.38), "awning_green")
	add_box(point + Vector3(0, 2.42, -0.62 * side), Vector3(5.19, 0.29, 0.13), "sign_ink")
	add_label("VILA DAS FIGUEIRAS", point + Vector3(0, 2.42, -0.70 * side), PI if side > 0.0 else 0.0, 0.011)
	for x: float in [-1.62, 0.0, 1.62]:
		add_box(point + Vector3(x, 1.46, 0.54 * side), Vector3(0.065, 1.90, 0.06), "steel_plate")
	add_box(point + Vector3(-1.63, 1.46, 0.55 * side), Vector3(1.54, 1.27, 0.058), "ceramic")
	add_label("PRAÇA  •  MERCADO", point + Vector3(-1.63, 1.56, 0.509 * side), PI if side > 0.0 else 0.0, 0.008)
	_bench(site, PI if side > 0.0 else 0.0)
	var bin := Layout.surface_point(site + Vector2(3.4, 0))
	add_instance("cylinder", "metal", bin + Vector3.UP * 0.42, Vector3(0.26, 0.86, 0.26))


func _bench(site: Vector2, yaw: float) -> void:
	var point := Layout.surface_point(site)
	add_part(point, Vector3(0, 0.46, 0), Vector3(2.0, 0.12, 0.58), "bench", yaw, true)
	for rail: float in [0.65, 0.81]:
		add_part(point, Vector3(0, rail, -0.27), Vector3(2.0, 0.11, 0.08), "bench", yaw)
	for x: float in [-0.73, 0.73]:
		add_part(point, Vector3(x, 0.21, 0), Vector3(0.12, 0.45, 0.39), "metal", yaw)


func _lamp(site: Vector2, inward: Vector2) -> void:
	var point := Layout.surface_point(site)
	var arm := Vector3(inward.x, 0.0, inward.y)
	var yaw := atan2(arm.x, arm.z)
	add_instance("cylinder", "metal", point + Vector3.UP * 3.3, Vector3(0.087, 6.65, 0.087))
	add_instance("box", "metal", point + Vector3.UP * 6.54 + arm * 0.82, Vector3(0.11, 0.12, 1.8), yaw)
	var head := point + Vector3.UP * 6.48 + arm * 1.63
	add_instance("box", "light", head, Vector3(0.38, 0.14, 0.65), yaw)
	_lamp_marker(head - Vector3.UP * 0.24, (Vector3.DOWN + arm * 0.14).normalized())


func _lamp_marker(position: Vector3, aim := Vector3.DOWN) -> void:
	var marker := Marker3D.new()
	marker.name = "StreetLamp_%02d" % scene_root.get_child_count()
	marker.position = position
	marker.set_meta("lamp_aim", aim)
	scene_root.add_child(marker)


func _signal(site: Vector2, facing: Vector2) -> void:
	var origin := Layout.surface_point(site)
	var yaw := atan2(facing.x, facing.y)
	var arm := Vector2(-facing.y, facing.x)
	add_instance("cylinder", "steel_plate", origin + Vector3.UP * 2.32, Vector3(0.13, 4.7, 0.13))
	var head := origin + Vector3(arm.x, 2.0, arm.y) * 2.38
	add_instance("box", "steel_plate", origin.lerp(head, 0.5) + Vector3.UP * 2.38, Vector3(0.10, 0.11, 2.45), atan2(arm.x, arm.y))
	add_part(head, Vector3.ZERO, Vector3(0.36, 0.86, 0.27), "signal_case", yaw)
	for height: float in [-0.25, 0.0, 0.25]:
		add_part(head, Vector3(0, height + 0.099, 0.235), Vector3(0.27, 0.065, 0.22), "signal_case", yaw)
		add_part(head, Vector3(0, height, 0.146), Vector3(0.18, 0.18, 0.04), "signal_amber" if height == 0.0 else "steel_plate", yaw)


func _avenue_wayfinding() -> void:
	# The sign spans the eastbound lanes with road-height clearance measured below its footing.
	var site := Vector2(-88.0, Layout.AVENUE + Layout.AVENUE_HALF + 0.82)
	var origin := Layout.surface_point(site)
	var road_y := Layout.height_at(Vector2(site.x, Layout.AVENUE + Layout.AVENUE_LANE))
	var head := Vector3(origin.x, road_y + 6.45, Layout.AVENUE + Layout.AVENUE_LANE)
	var height := head.y - origin.y
	add_box(origin + Vector3.UP * 0.23, Vector3(0.69, 0.5, 0.71), "stone", true)
	add_instance("cylinder", "steel_plate", origin + Vector3.UP * height * 0.5, Vector3(0.18, height, 0.18))
	var arm_end := head.z - 3.40
	add_box(Vector3(head.x, head.y, (site.y + arm_end) * 0.5), Vector3(0.18, 0.17, site.y - arm_end), "steel_plate")
	for offset: float in [-1.70, 1.70]:
		var panel := head + Vector3(-0.22, 0.28, offset)
		add_box(panel, Vector3(0.11, 0.72, 3.25), "trim")
		add_box(panel + Vector3.LEFT * 0.062, Vector3(0.034, 0.64, 3.14), "awning_green")
		var destination := "PRAÇA  ↑" if offset < 0.0 else "MERCADO  ↗"
		add_label(destination, panel + Vector3.LEFT * 0.088, -PI * 0.5, 0.012)


func _reservoir() -> void:
	var site := Layout.RESERVOIR
	var base := Layout.surface_point(site)
	for x: float in [-2.35, 2.35]:
		for z: float in [-2.35, 2.35]:
			var foot := Layout.surface_point(site + Vector2(x, z), -0.22)
			var height := base.y + 12.8 - foot.y
			add_box(foot + Vector3.UP * height * 0.5, Vector3(0.49, height, 0.54), "stone", true)
	for y: float in [4.8, 8.7, 12.4]:
		for side: float in [-1, 1]:
			add_box(base + Vector3(side * 2.35, y, 0), Vector3(0.36, 0.40, 4.72), "stone")
			add_box(base + Vector3(0, y, side * 2.35), Vector3(4.73, 0.37, 0.36), "stone")
	add_instance("cylinder", "stone", base + Vector3.UP * 12.7, Vector3(7.0, 0.53, 7.0))
	add_instance("cylinder", "reservoir_blue", base + Vector3.UP * 15.0, Vector3(6.72, 4.75, 6.72))
	for y: float in [13.4, 16.5, 17.4]:
		add_instance("cylinder", "trim", base + Vector3.UP * y, Vector3(6.79, 0.13, 6.79))
	add_instance("cylinder", "steel_plate", base + Vector3.UP * 17.66, Vector3(5.39, 0.47, 5.39))
	add_instance("cylinder", "steel_plate", base + Vector3(0, 19.23, -0.77), Vector3(0.12, 3.45, 0.12))
	add_box(base + Vector3(0, 20.95, -0.77), Vector3(0.23, 0.24, 0.22), "signal_amber")
	add_label("FIGUEIRAS", base + Vector3(-3.40, 15.42, 0), -PI * 0.5, 0.034)


func _tree(site: Vector2, height: float, variant: int, solid := true) -> void:
	var point := Layout.surface_point(site, -0.06)
	var yaw := _random.randf() * TAU
	var scale := Vector3.ONE * height
	add_instance("bark%d" % variant, "bark", point, scale, yaw)
	add_instance("canopy%d" % variant, "ipe" if variant == 1 else "canopy", point, scale, yaw)
	if solid:
		add_collision(point + Vector3.UP * height * 0.17, Vector3(height * 0.062, height * 0.34, height * 0.062))
		var diameter := Vector2.ONE * height * 0.53
		_ground.patch(Rect2(site - diameter * 0.5, diameter), "shade_tree", 0.034)
	_trees += 1


func _garden(site: Vector2, radius: float, count: int) -> void:
	for index in count:
		var angle := TAU * index / count
		var offset := Vector2(cos(angle), sin(angle)) * sqrt(_random.randf()) * radius
		var location := site + offset
		var plant := Layout.surface_point(location)
		if index % 4 == 0:
			add_instance("shrub", "bush", plant + Vector3.UP * 0.31, Vector3(0.61, 0.54, 0.54), angle, false)
			add_instance("foliage", "flowers", plant + Vector3.UP * 0.64, Vector3(0.37, 0.19, 0.34), angle, false)
		else:
			var size := _random.randf_range(0.46, 0.86)
			add_instance("tuft", "grass_blade", plant, Vector3.ONE * size, angle, false)
		_plantings += 1


func _shrub_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobe := SphereMesh.new()
	lobe.radial_segments = 6
	lobe.rings = 3
	lobe.radius = 1.0
	lobe.height = 2.0
	for index in 7:
		var angle := index * 2.4
		var offset := Vector3(cos(angle) * 0.45, 0.15 + 0.25 * cos(index), sin(angle) * 0.45)
		var scale := Vector3(0.57, 0.51 + 0.12 * sin(index), 0.56)
		surface.append_from(lobe, 0, Transform3D(Basis.from_scale(scale), offset))
	return surface.commit()


func _grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 7:
		var axis := Vector3(cos(index * 2.4), 0.0, sin(index * 2.4))
		var base := axis * 0.20
		var width := axis.cross(Vector3.UP) * 0.10
		var tip := axis * 0.48 + Vector3.UP * (0.36 + 0.27 * sin(index * 0.94))
		for vertex in [base - width, base + width, tip]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	return surface.commit()


func _perimeter() -> void:
	# A second row of silhouettes frames the edge streets, with open road ends.
	for side: float in [-1, 1]:
		for index in 22:
			var x := -211.0 + index * 20.0
			if Layout.COLUMNS.any(func(street): return absf(x - street) < 15.0):
				continue
			var z := float(Layout.ROWS[0 if side < 0.0 else 3]) + side * _random.randf_range(13.0, 20.0)
			var site := Vector2(x, z)
			if Layout.scenic_edge(Layout.scenic_sample(site)) < 12.0:
				continue
			var yaw := 0.0 if side < 0.0 else PI
			_facade(site, Vector2(x, z - side * 8.0), yaw, _random.randf_range(8.4, 13.2), 1 + index % 2, 10.2, WALLS[index % WALLS.size()], "")
		for index in 15:
			var z := -174.0 + index * 25.0
			if Layout.ROWS.any(func(street): return absf(z - street) < 15.0):
				continue
			var x := float(Layout.COLUMNS[0 if side < 0.0 else 3]) + side * _random.randf_range(13.0, 20.0)
			var site := Vector2(x, z)
			if Layout.scenic_edge(Layout.scenic_sample(site)) < 12.0:
				continue
			_facade(site, Vector2(x - side * 8.0, z), -side * PI * 0.5, _random.randf_range(8.4, 13.2), 1 + index % 2, 10.2, WALLS[(index + 2) % WALLS.size()], "")


func _landscape() -> void:
	for cluster in 98:
		var center := Vector2(_random.randf_range(-400, 400), _random.randf_range(-385, 385))
		if Layout.STREET_BOUNDS.grow(29).has_point(center):
			continue
		for index in 13:
			var site := center + Vector2(_random.randf_range(-25, 25), _random.randf_range(-18, 18))
			if Layout.STREET_BOUNDS.grow(29).has_point(site) or not Layout.TERRAIN.has_point(site):
				continue
			if Layout.scenic_edge(Layout.scenic_sample(site)) < 37.0 or Layout.lake_distance(site) < 1.49:
				continue
			var height := _random.randf_range(5.0, 9.0)
			var point := Layout.surface_point(site)
			var yaw := _random.randf() * TAU
			add_instance("foliage", "distant_canopy" if index % 4 == 0 else "forest", point + Vector3.UP * height * 0.33, Vector3(height * 0.82, height * 0.51, height * 0.64), yaw, false)
