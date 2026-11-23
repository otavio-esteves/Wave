extends "res://scripts/city/offline_scene_builder.gd"

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const Ground = preload("res://scripts/city/figueiras_ground.gd")
const ScenicBuilder = preload("res://scripts/city/figueiras_scenic_builder.gd")
const HortoBuilder = preload("res://scripts/city/figueiras_horto_builder.gd")
const MarketBuilder = preload("res://scripts/city/figueiras_market_builder.gd")
const CivicBuilder = preload("res://scripts/city/figueiras_civic_builder.gd")
const PlazaBuilder = preload("res://scripts/city/figueiras_plaza_builder.gd")
const BuildingParts = preload("res://scripts/city/figueiras_building_parts.gd")
const StationBuilder = preload("res://scripts/city/figueiras_station_builder.gd")
const DepotBuilder = preload("res://scripts/city/figueiras_depot_builder.gd")
const ValeBuilder = preload("res://scripts/city/figueiras_vale_builder.gd")
const BaixadaBuilder = preload("res://scripts/city/figueiras_baixada_builder.gd")
const UrbanBuilder = preload("res://scripts/city/figueiras_urban_builder.gd")
const Frontages = preload("res://scripts/city/figueiras_frontages.gd")
const Openings = preload("res://scripts/city/figueiras_openings.gd")
const ArchitectureBake = preload("res://scripts/city/figueiras_architecture_bake.gd")
const FoliageBake = preload("res://scripts/city/figueiras_foliage_bake.gd")
const TreeMesh = preload("res://scripts/city/neighborhood_tree_mesh.gd")
const STREET_FINISH = preload("res://assets/shaders/figueiras/street_finish.gdshader")
const UTILITY_COVER = preload("res://assets/shaders/figueiras/utility_cover.gdshader")
const WALL_ATLAS := "res://assets/textures/figueiras/rebocos-da-vila.png"
const WALL_TILES := {"cream": 0, "sage": 2, "terracotta": 1, "plaster": 3, "blue": 2, "retaining_oxide": 3}
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
const Signals = preload("res://scripts/city/figueiras_signals.gd")
const WALLS := ["cream", "sage", "terracotta", "plaster", "blue", "brick"]
const SHOPS := ["PADARIA IPÊ", "CAFÉ DA PRAÇA", "FLORICULTURA", "MERCEARIA", "OFICINA", "LIVRARIA", "ARMAZÉM DO BAIRRO", "FARMÁCIA IPÊ"]
const DETAIL_MATERIALS := ["trim", "metal", "awning", "awning_green", "bench", "flowers", "bush", "grass_blade", "cable", "awning_light", "door", "steel_plate", "signal_case"]
const MATTE_MATERIALS := ["trim", "parapet", "metal", "steel_plate", "signal_case", "ceramic", "terracotta_pot",
	"awning", "awning_green", "awning_light", "bollard", "fence", "sign_ink", "soil", "plaster_dark"]
const PARKED_COLORS := [Color("b8aca1"), Color("577585"), Color("905349"), Color("dedbcc"), Color("4e565a"), Color("bca269")]
const PLAZA_CROSSING_X := 8.75
const PLAZA_CROSSING_CLEARANCE := 3.2
var _ground: RefCounted
var _civic := CivicBuilder.new()
var _surface_finishes: Dictionary[String, ShaderMaterial] = {}
var _object_finishes: Dictionary[String, ShaderMaterial] = {}
var _random := RandomNumberGenerator.new()
var _lots := 0
var _trees := 0
var _parked_cars := 0
var _parked_vehicle_shapes := PackedInt32Array()
var _plantings := 0
var _terrace_houses := 0


func build() -> Node3D:
	_random.seed = 7741
	_lots = 0
	_trees = 0
	_parked_cars = 0
	_parked_vehicle_shapes.clear()
	_plantings = 0
	_terrace_houses = 0
	batch_size = 96.0
	center_batches_vertically = true
	begin("VilaDasFigueiras", "SolidObjects")
	for name: String in ["canopy", "ipe", "bark"]:
		batch_sizes[name] = FoliageBake.SIZE
	meshes["hip_roof"] = _hip_roof()
	meshes["shutter_grooves"] = _shutter_grooves()
	meshes["masonry_arch"] = BuildingParts.arch_mesh()
	var shed_roof := PrismMesh.new()
	shed_roof.left_to_right = StationBuilder.SHED_SHIFT
	shed_roof.size = Vector3.ONE
	meshes["shed_roof"] = shed_roof
	var bandstand_roof := CylinderMesh.new()
	bandstand_roof.top_radius = 0.06
	bandstand_roof.bottom_radius = 0.50
	bandstand_roof.height = 1.0
	bandstand_roof.radial_segments = 8
	bandstand_roof.rings = 1
	meshes["bandstand_roof"] = bandstand_roof
	var bandstand_base := bandstand_roof.duplicate() as CylinderMesh
	bandstand_base.top_radius = 0.50
	meshes["bandstand_base"] = bandstand_base
	_setup_district_materials()
	_ground = Ground.new()
	_ground.build()
	_mark_streets()
	_plaza_crossing()
	_street_wear()
	for row in Layout.ROWS.size() - 1:
		for column in Layout.COLUMNS.size() - 1:
			if row == 1 and column == 1:
				PlazaBuilder.new().build(self, _ground)
			else:
				_build_block(column, row)
	_streetscape()
	DepotBuilder.new().build(self, _ground)
	_avenue_wayfinding()
	_plaza_edges()
	_perimeter()
	_landscape()
	_reservoir()
	UrbanBuilder.new().build(self, _ground)
	HortoBuilder.new().build(self, _ground)
	MarketBuilder.new().build(self, _ground)
	StationBuilder.new().build(self, _ground)
	ScenicBuilder.new().build(self, _ground)
	ValeBuilder.new().build(self, _ground)
	BaixadaBuilder.new().build(self, _ground)
	_ground.save_into(scene_root, materials, _surface_finishes)
	finish()
	for node in scene_root.find_children("*", "MultiMeshInstance3D", false, false):
		var material: String = node.material_override.resource_name
		if _object_finishes.has(material):
			node.material_override = _object_finishes[material]
		if material in DETAIL_MATERIALS:
			node.visibility_range_end = 126.0
			node.visibility_range_end_margin = 15.0
		elif material in ["glass", "residential_glass_lit", "facade_frame", "terracotta_pot", "soil"] or material.begins_with("shop_"):
			node.visibility_range_end = 154.0 if material.begins_with("shop_") else 173.0
			node.visibility_range_end_margin = 20.0
		else:
			node.visibility_range_end = 0.0
		if material in ["bark", "canopy", "ipe", "distant_canopy", "forest"]:
			node.lod_bias = 0.45
		# Keep durable silhouettes in the sun map. Fine cards and wires shimmer
		# at sub-texel widths, and distant impostors only frame the skyline.
		if material.begins_with("shop_") or material in ["grass_blade", "flowers", "cable", "glass", "residential_glass_lit", "water", "distant_canopy", "forest", "mural_ipe"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_merge_material_batches()
	ArchitectureBake.new().bake(scene_root)
	FoliageBake.new().bake(scene_root)
	scene_root.set_meta("blocks", (Layout.ROWS.size() - 1) * (Layout.COLUMNS.size() - 1))
	scene_root.set_meta("buildings", _lots)
	scene_root.set_meta("trees", _trees)
	scene_root.set_meta("parked_cars", _parked_cars)
	_colliders.set_meta("parked_vehicle_shapes", _parked_vehicle_shapes)
	scene_root.set_meta("plantings", _plantings)
	scene_root.set_meta("terrace_houses", _terrace_houses)
	var road_length := 0.0
	for road in Layout.scenic_routes():
		road_length += road.length
	scene_root.set_meta("scenic_road_length", road_length)
	return scene_root


func _merge_material_batches() -> void:
	# Texture, geometry and shadow policy still match inside each combined batch.
	var groups: Dictionary = {}
	for instance: MultiMeshInstance3D in scene_root.find_children("*", "MultiMeshInstance3D", false, false):
		var material_name := instance.material_override.resource_name
		var stucco := material_name.begins_with("figueiras_wall_") and not material_name.begins_with("figueiras_wall_brick")
		if not stucco and material_name not in MATTE_MATERIALS:
			continue
		var key := [stucco, instance.multimesh.mesh.get_instance_id(), instance.position.x, instance.position.z,
			instance.cast_shadow, instance.visibility_range_end]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(instance)
	var palette := StandardMaterial3D.new()
	palette.resource_name = "figueiras_matte"
	palette.vertex_color_use_as_albedo = true
	palette.roughness = 0.86
	var stucco_palette: ShaderMaterial = _object_finishes["cream"].duplicate()
	stucco_palette.resource_name = "figueiras_wall_palette"
	stucco_palette.set_shader_parameter("instance_tint", true)
	var saved := 0
	var batch_index := 0
	for key: Array in groups:
		var members: Array = groups[key]
		if members.size() < 2 and not key[0]:
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
			var paint: Color = member.material_override.get_shader_parameter("wall_color") if key[0] else member.material_override.albedo_color
			if key[0]:
				var wall := str(member.material_override.resource_name).trim_prefix("figueiras_wall_")
				paint.a = (float(WALL_TILES.get(wall, 0)) + 0.5) * 0.25
			for transform: Transform3D in member.multimesh.instance_transforms:
				transform.origin += member.position - center
				transforms.append(transform)
				tints.append(paint)
		var multimesh := BakedMultiMesh.new()
		multimesh.mesh = first.multimesh.mesh
		multimesh.set_instances(transforms, tints)
		var merged := MultiMeshInstance3D.new()
		merged.name = "PaintedObjects_%d" % batch_index
		merged.position = center
		merged.multimesh = multimesh
		merged.material_override = stucco_palette if key[0] else palette
		merged.cast_shadow = first.cast_shadow
		merged.visibility_range_end = first.visibility_range_end
		merged.visibility_range_end_margin = first.visibility_range_end_margin
		scene_root.add_child(merged)
		merged.owner = scene_root
		for member: MultiMeshInstance3D in members:
			member.free()
		saved += members.size() - 1
		batch_index += 1
	scene_root.set_meta("merged_draw_batches", saved)


func _setup_district_materials() -> void:
	var palette := {
		"grass": "a4b17b", "asphalt": "9b9fa0", "sidewalk": "b9b1a4", "paving": "b9ac99", "retaining_oxide": "ae8f72",
		"curb": "b6aba0", "cobbles": "a79881", "mulch": "62513c", "brick": "b89074",
		"utility_cover": "5f615d", "storm_drain": "696660", "asphalt_repair": "96918a",
		"plaster_dark": "877862", "ceramic": "578182", "terracotta_pot": "a55d42", "parapet": "bcb099",
		"cream": "c9b594", "plaster": "b7ad99", "sage": "959d88", "terracotta": "a97862", "blue": "829399",
		"roof": "975f4a", "roof_gray": "656967", "stone": "a39885", "trim": "b8ae9e", "metal": "414948",
		"awning": "975b4b", "awning_green": "37554a", "awning_light": "c5b197", "sign_ink": "2e3933",
		"door": "765348", "cable": "383636", "fence": "68594d", "tactile": "c18839",
		"glass": "a4b5b8", "residential_glass_lit": "abac97", "bench": "76513f", "bollard": "54594f",
		"bark": "b8a68b", "canopy": "d8e5c5", "ipe": "ebd077", "distant_canopy": "465b40",
		"forest": "3b5246", "bush": "607747", "flowers": "d07a66", "grass_blade": "9f9d5f",
		"water": "7d9e9c", "white": "ede2c7", "yellow": "e3ad4f", "soil": "75644f",
		"light": "f3e6c2", "parked_car": "ffffff", "signal_case": "323b39", "signal_amber": "f6b93e",
		"reservoir_blue": "5d868a", "steel_plate": "536460", "mural_ipe": "ffffff", "median_pavers": "99836e",
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
	materials["asphalt"].albedo_texture = preload("res://assets/textures/figueiras/asfalto-alameda.png")
	materials["asphalt"].normal_texture = preload("res://assets/textures/pilot/finish-asphalt-normal.res")
	materials["asphalt"].normal_scale = 0.13
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
	materials["brick"].uv1_scale = Vector3(1.7, 2.0, 1.0)
	materials["door"].albedo_texture = preload("res://assets/textures/neighborhood/timber-albedo.res")
	materials["bench"].albedo_texture = materials["door"].albedo_texture
	materials["glass"].albedo_texture = preload("res://assets/textures/pilot/finish-window-interior-albedo.res")
	materials["glass"].albedo_color = Color("8c9c9b")
	materials["residential_glass_lit"].albedo_texture = preload("res://assets/textures/pilot/finish-window-interior-albedo.res")
	for key in ["glass", "residential_glass_lit", "water"]:
		materials[key].roughness = 0.29
	for key in ["canopy", "ipe", "bush"]:
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
	materials["flowers"].cull_mode = BaseMaterial3D.CULL_DISABLED
	materials["flowers"].vertex_color_use_as_albedo = true
	var window := QuadMesh.new()
	window.size = Vector2.ONE
	meshes["pane"] = window
	Openings.install(meshes, materials)
	for variant in 4:
		var tree := TreeMesh.new().build([0, 3, 1, 5][variant])
		meshes["bark%d" % variant] = tree.bark
		meshes["canopy%d" % variant] = tree.leaves
	var araucaria := TreeMesh.new().build_araucaria()
	meshes["araucaria_trunk"] = araucaria.bark
	meshes["araucaria_crown"] = araucaria.leaves
	for index in PARKED_COLORS.size():
		meshes["parked%d" % index] = ParkedCar.build_traffic(PARKED_COLORS[index], index % 3, true)
	meshes["tuft"] = _grass_mesh()
	materials["bush"].albedo_color = Color("d4dfbc")
	meshes["shrub"] = TreeMesh.new().build_shrub()
	meshes["flower_heads"] = make_flowers()
	meshes["horizon_tree"] = QuadMesh.new()
	_setup_surface_finishes()
	MarketBuilder.install_materials(materials)


func _setup_surface_finishes() -> void:
	_surface_finishes.clear()
	_object_finishes.clear()
	for name: String in ["asphalt", "asphalt_repair", "sidewalk", "curb", "paving", "cobbles", "white", "utility_cover", "storm_drain", "grass"]:
		var finish := ShaderMaterial.new()
		finish.shader = UTILITY_COVER if name == "utility_cover" else STREET_FINISH
		finish.resource_name = "figueiras_surface_" + name
		var material := materials[name]
		var mode := 0 if name.begins_with("asphalt") else 1
		if name == "white":
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
		finish.set_shader_parameter("vertex_paint", mode == 2)
		finish.set_shader_parameter("avenue_section", Vector3(Layout.AVENUE_MEDIAN_HALF, Layout.AVENUE_LANE, Layout.AVENUE_TRAVEL_HALF))
		if mode < 2 or mode == 5:
			finish.set_shader_parameter("base_color", material.albedo_texture)
			finish.set_shader_parameter("aggregate_normal", material.normal_texture)
		if mode == 5:
			finish.set_shader_parameter("rock_albedo", preload("res://assets/textures/figueiras/basalto-do-passo.png"))
		_surface_finishes[name] = finish
	var atlas: Texture2D = load(WALL_ATLAS)
	materials["retaining_oxide"].albedo_texture = materials["plaster"].albedo_texture
	for wall: String in WALLS + ["retaining_oxide"]:
		var material := materials[wall]
		var finish := ShaderMaterial.new()
		finish.shader = PLASTER
		finish.resource_name = "figueiras_wall_" + wall
		finish.set_shader_parameter("wall_color", material.albedo_color)
		finish.set_shader_parameter("color_texture", material.albedo_texture)
		finish.set_shader_parameter("normal_texture", preload("res://assets/textures/neighborhood/stucco-normal.res") if wall != "brick" else material.normal_texture)
		finish.set_shader_parameter("tiling", Vector2(material.uv1_scale.x, material.uv1_scale.y))
		finish.set_shader_parameter("masonry", wall == "brick")
		if wall != "brick":
			finish.set_shader_parameter("plaster_atlas", atlas)
			finish.set_shader_parameter("atlas_tile", WALL_TILES.get(wall, 0))
			finish.set_shader_parameter("pattern_atlas", true)
		_object_finishes[wall] = finish
	for room: String in SHOP_REGIONS:
		var region: Rect2 = SHOP_REGIONS[room]
		for side: int in [0, 1]:
			var name := "shop_%s_%s" % [room, "left" if side == 0 else "right"]
			var finish := ShaderMaterial.new()
			finish.shader = SHOP_GLASS
			finish.resource_name = "figueiras_" + name
			finish.set_shader_parameter("interior", BAKERY if room == "bakery" else SHOP_ATLAS)
			finish.set_shader_parameter("room_depth", 0.64 if room in ["workshop", "market"] else 0.36)
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
		var market_front := row == 2 and column == 0 and front == 2
		var schedule: Array = Frontages.AVENUE_PLOTS.get(Vector2i(column, row), []) if commercial else []
		var corner_clearance := 4.6 if not schedule.is_empty() else (7.0 if front % 2 == 0 else 25.0)
		var lots := schedule.size() if not schedule.is_empty() else floori((length - 2.0 * corner_clearance) / (16.5 if commercial else 13.9))
		if market_front and lots % 2 == 0:
			lots -= 1
		var widths := Frontages.plot_widths(schedule, lots, length - 2.0 * corner_clearance, column * 13 + row * 7 + front, market_front)
		var start := corner_clearance - length * 0.5
		for index in lots:
			var lot_width := widths[index]
			var frontage := edge + across * (start + lot_width * 0.5)
			start += lot_width
			var walls: Array = Frontages.WALLS[column]
			var wall: String = walls[posmod(index + row * 3 + front * 5, walls.size())]
			var house_type := posmod(index * 3 + row * 7 + column * 2 + front, 5)
			var floors := 2 if house_type in [1, 3, 4] else 1
			var width := lot_width * _random.randf_range(0.77, 0.91)
			var setback := _random.randf_range(1.9, 4.2) if house_type in [1, 3] else _random.randf_range(3.1, 6.0)
			var building_depth := _random.randf_range(8.3, 13.2)
			var name := ""
			if not schedule.is_empty():
				var plot: Array = schedule[index]
				name = plot[1]
				wall = plot[2]
				floors = plot[3]
				setback = plot[4]
				width = lot_width - (0.75 if name == "OFICINA" else 0.43)
				building_depth += 2.0 if floors >= 3 else 0.4
			elif market_front and (index + column) % 5 != 4:
				name = SHOPS[(index + column * 2 + front) % SHOPS.size()]
				setback = 2.5
			var site := frontage - forward * (setback + building_depth * 0.5)
			if market_front and index == floori(lots * 0.5):
				site = Layout.MARKET + Vector2(0, 2.1)
				frontage.x = site.x
				MarketBuilder.build_hall(self, _ground, site, frontage, clampf(lot_width * 0.97, 21.6, 23.8), 19.8, yaw)
				continue
			if column == 2 and row == 2:
				var footprint := across.abs() * width + forward.abs() * building_depth
				if StationBuilder.PROPERTY.intersects(Rect2(site - footprint * 0.5, footprint).grow(1.3)):
					continue
			if column == 0 and row == 0 and front % 2 == 0 and absf(site.x - Layout.DEPOT_AXIS) < 17.0 + width * 0.5:
				continue
			if not _lot_has_access(site, frontage, across, forward, width, building_depth):
				continue
			if column == 0 and row == 0 and front == 2 and index == 2:
				_overlook(frontage, yaw)
			elif name.is_empty() and index == lots - 1 and front == 1 and (column + row) % 2 == 0:
				_garden(frontage - forward * 8.0, 4.0, 13)
			else:
				var return_side := signf(float(index) - float(lots - 1) * 0.5) if commercial and index in [0, lots - 1] else 0.0
				_facade(site, frontage, yaw, width, floors, building_depth, wall, name, house_type, return_side)
	# Backyards form a canopy through each block and break the view between roofs.
	var center := block.get_center()
	for index in 20:
		var site := center + Vector2(_random.randf_range(-0.27, 0.27) * block.size.x, _random.randf_range(-0.24, 0.24) * block.size.y)
		if StationBuilder.PROPERTY.has_point(site):
			continue
		if site.distance_squared_to(MarketBuilder.TOWER) < 8.0 * 8.0 or Layout.DEPOT.grow(3.1).has_point(site) or Layout.urban_edge(Layout.urban_sample(site)) < 16.0:
			continue
		_tree(site, _random.randf_range(4.6, 10.6), index % 4, false)
		if index % 3 == 0:
			_garden(site, 4.5, 14)


func _lot_has_access(site: Vector2, frontage: Vector2, across: Vector2, forward: Vector2, width: float, depth: float) -> bool:
	for x: float in [-0.54, 0.0, 0.54]:
		var side := across * width * x
		if Layout.urban_edge(Layout.urban_sample(frontage + side)) < 2.4:
			return false
		for z: float in [-0.55, 0.0, 0.55]:
			if Layout.urban_edge(Layout.urban_sample(site + side + forward * depth * z)) < 3.1:
				return false
	return true


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


func _facade(site: Vector2, frontage: Vector2, yaw: float, width: float, floors: int, depth: float, wall: String, shop: String, house_type := -1, return_side := 0.0) -> void:
	_lots += 1
	if house_type < 0:
		house_type = posmod(_lots, 5)
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
			var ground_y: float = _ground.surface_point(site + across * x * width * 0.5 + forward * z * front).y
			bottom_y = minf(bottom_y, ground_y)
			if z == 1.0:
				facade_y = maxf(facade_y, ground_y)
	facade_y += 0.13
	var origin := Vector3(site.x, facade_y, site.y)
	var foundation := maxf(0.35, facade_y - bottom_y + 0.55)
	var garage_x := width * 0.28
	var garage_width := minf(width * 0.38, 3.27)
	var driveway := PackedVector3Array()
	if shop.is_empty() and house_type in [1, 4]:
		var garage_offset := across * garage_x
		driveway = _driveway_grade(frontage + garage_offset, entrance + garage_offset, facade_y, garage_width)
		if driveway.is_empty():
			house_type = 3 if house_type == 1 else 2
	var shade_size := across.abs() * width + forward.abs() * depth + Vector2.ONE * 4.0
	_ground.patch(Rect2(site - shade_size * 0.5, shade_size), "shade_building", 0.020)
	add_part(origin, Vector3(0, -foundation * 0.5, 0), Vector3(width, foundation, depth), "stone", yaw, true)
	var terrace := shop.is_empty() and floors == 2 and house_type in [1, 3]
	var upper_width := width * 0.68 if terrace else width
	var upper_depth := depth - 2.7 if terrace else depth
	var upper_position := Vector3(width * 0.135, 0.0, -1.05) if terrace else Vector3.ZERO
	var upper_origin := origin + basis * upper_position
	if terrace:
		_terrace_houses += 1
		add_part(origin, Vector3(0, 1.56, 0), Vector3(width, 3.12, depth), wall, yaw, true)
		add_part(upper_origin, Vector3(0, 4.68, 0), Vector3(upper_width, 3.12, upper_depth), wall, yaw, true)
		_residential_terrace(origin, width, depth, yaw)
	else:
		add_part(origin, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), wall, yaw, true)
	add_part(origin, Vector3(0, 0.22, 0), Vector3(width + 0.15, 0.44, depth + 0.12), "stone", yaw)
	var terrace_depth := 1.80 if shop.begins_with("CAFÉ") else 0.0
	_access(frontage, entrance + forward * terrace_depth, facade_y, yaw, width * 0.94 if not shop.is_empty() else 1.50)
	if terrace_depth > 0.0:
		var deck_floor := facade_y
		for side: float in [-1.0, 1.0]:
			var edge := entrance + forward * terrace_depth + across * (side * width * 0.47)
			deck_floor = minf(deck_floor, _ground.surface_point(edge).y)
		var deck_height := maxf(0.19, facade_y - deck_floor + 0.14)
		add_part(origin, Vector3(0, -deck_height * 0.5 + 0.022, front + terrace_depth * 0.5),
			Vector3(width * 0.94, deck_height, terrace_depth + 0.05), "stone", yaw, true)
	if shop.is_empty() and house_type not in [1, 4]:
		var roof_height := upper_depth * (0.13 if house_type == 0 else 0.21)
		var hipped := terrace or house_type == 2
		var roof_finish := "roof_gray" if house_type == 2 else "roof"
		add_part(upper_origin, Vector3(0, height + roof_height * 0.5, 0), Vector3(upper_depth + 0.78, roof_height, upper_width + 0.72), roof_finish, yaw + PI * 0.5, false, "hip_roof" if hipped else "roof")
		add_part(upper_origin, Vector3(0, height - 0.02, 0), Vector3(upper_width + 0.80, 0.19, upper_depth + 0.82), "wood", yaw)
		var ridge_width := (upper_width + 0.72) * 0.54 if hipped else upper_width + 0.66
		add_part(upper_origin, Vector3(0, height + roof_height + 0.04, 0), Vector3(ridge_width, 0.11, 0.23), roof_finish, yaw)
		for side: float in [-1, 1]:
			add_part(upper_origin, Vector3(0, height - 0.11, side * (upper_depth * 0.5 + 0.4)), Vector3(upper_width + 0.75, 0.13, 0.13), "plaster_dark", yaw)
	else:
		var roof_origin := upper_origin if terrace else origin
		add_part(roof_origin, Vector3(0, height - 0.04, 0), Vector3(upper_width + 0.26, 0.21, upper_depth + 0.27), "trim", yaw)
		add_part(roof_origin, Vector3(0, height + 0.22, upper_depth * 0.5 - 0.08), Vector3(upper_width, 0.46, 0.22), wall, yaw)
		if shop.is_empty() and _lots % 3 == 0:
			add_part(roof_origin, Vector3(upper_width * 0.24, height + 0.42, -upper_depth * 0.21), Vector3(1.31, 0.84, 1.31), "reservoir_blue", yaw, false, "cylinder")
	for floor_index in floors:
		var y := 1.77 + floor_index * 3.12
		if floor_index == 0 and not shop.is_empty():
			_shopfront(origin, width, front, yaw, shop)
			continue
		if not shop.is_empty():
			_retail_upper(origin, width, front, yaw, shop, floor_index)
			continue
		var top_floor := floor_index > 0
		var room := upper_origin if top_floor else origin
		var face := upper_depth * 0.5 if top_floor else front
		var span := upper_width if top_floor else width
		var balcony_floor := top_floor and house_type == 4
		if balcony_floor:
			y = 1.05 + floor_index * 3.12
		for side: float in [-1, 1]:
			var x := side * span * (0.245 if house_type == 2 else 0.28)
			var glass := "residential_glass_lit" if posmod(_lots + int(side) + floor_index, 3) == 0 else "glass"
			var profile := "timber" if house_type in [0, 2] else ("aluminium" if house_type == 4 else "iron")
			var size := Vector2(clampf(span * (0.15 if profile == "timber" else 0.24), 0.83, 1.98), 1.17 if house_type in [0, 1] else 1.45)
			if balcony_floor:
				size = Vector2(minf(1.96, span * 0.22), 2.03)
			var garage_bay := not top_floor and house_type in [1, 4] and side > 0.0
			if not garage_bay:
				_window(room, Vector3(x, y, face), size, yaw, glass, profile)
			if not garage_bay and house_type == 2:
				_shutters(room, Vector3(x, y, face + 0.18), size, yaw)
			elif not garage_bay and house_type == 3 and top_floor:
				_window_planter(room, Vector3(x, y - 0.90, face + 0.29), size.x, yaw)
			_window(room, Vector3(x, 1.72 + floor_index * 3.12, face), Vector2(1.12, 1.06), yaw + PI, glass, profile)
			if side > 0.0 or top_floor:
				_window(room, Vector3(side * face * 0.36, 1.80 + floor_index * 3.12, span * 0.5), Vector2(0.89, 1.03), yaw + side * PI * 0.5, glass)
		if balcony_floor:
			_balcony(origin, width * 0.79, y - 1.05, front, yaw)
	if shop.is_empty():
		_entry_door(origin, Vector3(0, 1.08, front), 0.96, yaw, false)
		var has_garage := not driveway.is_empty()
		_house_front(frontage, across, forward, width, yaw, house_type, has_garage)
		if has_garage:
			_install_driveway(driveway, garage_width)
			_garage_shutter(origin, Vector3(garage_x, 1.11, front), garage_width, yaw)
		elif floors > 1 and not terrace:
			_residential_front(origin, width, front, yaw)
		elif house_type == 0:
			add_part(origin, Vector3(0.66, 2.50, front + 0.36), Vector3(width * 0.52, 0.17, 0.91), "roof_gray", yaw)
			add_part(origin, Vector3(width * 0.28, 1.22, front + 0.74), Vector3(0.19, 2.38, 0.20), "stone", yaw)
			add_part(origin, Vector3(-width * 0.31, 0.23, front + 0.34), Vector3(width * 0.23, 0.45, 0.72), "brick", yaw)
	elif shop == "CINE FIGUEIRAS":
		_cinema(origin, width, front, yaw, height)
	if return_side != 0.0 and not shop.is_empty():
		_commercial_return(origin, width, depth, yaw, return_side, shop)
	_civic.decorate(self, yaw, origin, width, depth, height, shop)
	if floors >= 4 and shop != "GALERIA DO RELÓGIO":
		# Top-floor setback, service core and cornice give the east end
		# an identifiable silhouette from the start of the avenue.
		add_part(origin, Vector3(-width * 0.24, height + 1.22, -depth * 0.18), Vector3(width * 0.43, 2.44, depth * 0.51), wall, yaw)
		add_part(origin, Vector3(-width * 0.24, height + 2.45, -depth * 0.18), Vector3(width * 0.46, 0.20, depth * 0.55), "trim", yaw)
		for side: float in [-1.0, 1.0]:
			add_part(origin, Vector3(side * width * 0.456, height * 0.57, front + 0.09), Vector3(0.21, height * 0.84, 0.29), "stone", yaw)


func _garage_shutter(origin: Vector3, offset: Vector3, width: float, yaw: float) -> void:
	add_part(origin, offset + Vector3.BACK * 0.12, Vector3(width + 0.27, 2.24, 0.19), "stone", yaw)
	add_part(origin, offset + Vector3.BACK * 0.228, Vector3(width, 2.0, 0.08), "steel_plate", yaw)
	add_part(origin, offset + Vector3.BACK * 0.274, Vector3(width * 0.98, 2.0, 1.0), "metal", yaw, false, "shutter_grooves")


func _driveway_grade(approach: Vector2, door: Vector2, floor: float, width: float) -> PackedVector3Array:
	# Follow the sidewalk at the front. Plots too steep or irregular for a
	# continuous driveway use a pedestrian entrance and a different facade.
	var axis := door - approach
	var side := axis.normalized().orthogonal() * (width * 0.5 + 0.05)
	var left: float = _ground.surface_point(approach - side).y
	var right: float = _ground.surface_point(approach + side).y
	var start: Vector3 = _ground.surface_point(approach)
	if maxf(maxf(left, right), start.y) - minf(minf(left, right), start.y) > 0.17:
		return PackedVector3Array()
	start.y = maxf(maxf(left, right), start.y) + 0.014
	if absf(floor - start.y) > axis.length() * 0.23:
		return PackedVector3Array()
	var finish := Vector3(door.x, floor, door.y)
	for station: float in [0.20, 0.40, 0.60, 0.80]:
		var point := start.lerp(finish, station)
		var base := Vector2(point.x, point.z)
		for offset in [-side, Vector2.ZERO, side]:
			if _ground.surface_point(base + offset).y > point.y + 0.034:
				return PackedVector3Array()
	return PackedVector3Array([start, finish])


func _install_driveway(grade: PackedVector3Array, width: float) -> void:
	var chord := grade[1] - grade[0]
	var basis := Basis.looking_at(chord.normalized())
	const THICKNESS := 0.27
	var center := (grade[0] + grade[1]) * 0.5 - basis.y * (THICKNESS * 0.5)
	_add_tilted_box(center, basis, Vector3(width + 0.10, THICKNESS, chord.length()), "stone", true)
	_colliders.get_child(-1).name = "Driveway_%03d" % _colliders.get_child_count()


func _shutter_grooves() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slat in 8:
		var y := (slat - 3.5) * 0.115
		var a := Vector3(-0.5, y, 0.0)
		var b := Vector3(-0.5, y + 0.013, 0.0)
		var c := Vector3(0.5, y, 0.0)
		var d := Vector3(0.5, y + 0.013, 0.0)
		for vertex: Vector3 in [a, b, c, b, d, c]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(vertex)
	surface.index()
	return surface.commit()


func _commercial_return(origin: Vector3, width: float, depth: float, yaw: float, side: float, shop: String) -> void:
	# On a corner the shop addresses both streets. Shorter bays on the return
	# preserve the structure and leave room for a separate service entrance.
	var rotation := yaw + side * PI * 0.5
	var face := width * 0.5
	add_part(origin, Vector3(0.0, 0.39, face + 0.045), Vector3(depth, 0.78, 0.12), "brick", rotation)
	for bay in 2:
		var x := -side * (0.11 + 0.26 * bay) * depth
		_window(origin, Vector3(x, 1.63, face + 0.014), Vector2(minf(depth * 0.21, 2.3), 1.60), rotation, "glass")
	add_part(origin, Vector3(0.0, 2.77, face + 0.17), Vector3(depth * 0.91, 0.145, 0.39), "trim", rotation)
	var sign_position := Vector3(-side * depth * 0.25, 3.27, face + 0.162)
	var sign_width := minf(depth * 0.30, 0.18 * shop.length() + 0.28)
	add_part(origin, sign_position, Vector3(sign_width + 0.24, 0.31, 0.07), "sign_ink", rotation)
	Openings.lettering(self, shop, origin + Basis(Vector3.UP, rotation) * (sign_position + Vector3.BACK * 0.038),
		rotation, sign_width, 0.25, Color("dfd6c4"))
	_entry_door(origin, Vector3(side * depth * 0.34, 1.06, face), 0.87, rotation, false)


func _residential_terrace(origin: Vector3, width: float, depth: float, yaw: float) -> void:
	var face := depth * 0.5
	add_part(origin, Vector3(0.0, 3.12, 0.0), Vector3(width + 0.32, 0.19, depth + 0.32), "stone", yaw)
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(side * width * 0.48, 3.46, 0.0), Vector3(0.16, 0.66, depth), "parapet", yaw)
	var slab := Vector3(-width * 0.34, 3.42, face + 0.03)
	add_part(origin, slab, Vector3(width * 0.34, 0.63, 0.19), "parapet", yaw)
	add_part(origin, Vector3(width * 0.16, 3.59, face + 0.02), Vector3(width * 0.66, 0.08, 0.13), "steel_plate", yaw)
	for post in 6:
		var x := width * (-0.15 + 0.127 * post)
		add_part(origin, Vector3(x, 3.40, face + 0.02), Vector3(0.06, 0.51, 0.10), "metal", yaw)
	var pot := Vector3(-width * 0.37, 3.38, face - 0.81)
	add_part(origin, pot, Vector3(0.43, 0.51, 0.43), "terracotta_pot", yaw, false, "cylinder")
	add_part(origin, pot + Vector3.UP * 0.42, Vector3(0.66, 0.73, 0.68), "bush", yaw, false, "shrub")


func _retail_upper(origin: Vector3, width: float, front: float, yaw: float, shop: String, floor_index: int) -> void:
	var y := 1.74 + floor_index * 3.12
	var form := Frontages.retail_treatment(shop, _shop_room(shop))
	var bay_count := 3 if width < 14.2 or form == Frontages.Retail.CIVIC else 4
	var spacing := width * 0.84 / bay_count
	var modern := form in [Frontages.Retail.GLAZED, Frontages.Retail.SERVICE]
	var window_width := minf(2.65 if modern else 1.27, spacing * (0.83 if modern else 0.60))
	var window_height := 1.30 if modern else 1.72
	var profile := "aluminium" if modern else ("iron" if form == Frontages.Retail.CIVIC else "timber")
	for bay in bay_count:
		var x := (float(bay) - (bay_count - 1) * 0.5) * spacing
		var pane := "residential_glass_lit" if posmod(_lots + floor_index + bay, 3) == 0 else "glass"
		_window(origin, Vector3(x, y, front), Vector2(window_width, window_height), yaw, pane, profile)
		if form == Frontages.Retail.GROCERY and posmod(_lots + bay, 3) == 0:
			add_part(origin, Vector3(x + 0.24, y - 1.01, front + 0.15), Vector3(0.58, 0.37, 0.29), "parapet", yaw)
	if modern:
		add_part(origin, Vector3(0, y - 0.74, front + 0.035), Vector3(width - 0.35, 0.13, 0.15), "ceramic", yaw)
		return
	if floor_index == 1 and form == Frontages.Retail.NEIGHBORHOOD and _lots % 2 == 0:
		_balcony(origin, width * 0.39, y - 0.92, front, yaw)
	elif form == Frontages.Retail.CIVIC:
		add_part(origin, Vector3(0, y + 1.02, front + 0.10), Vector3(width * 0.88, 0.11, 0.25), "parapet", yaw)


func _cinema(origin: Vector3, width: float, front: float, yaw: float, height: float) -> void:
	for level in 3:
		var cap_width := width * (0.95 - level * 0.18)
		var y := height + 0.37 + level * 0.43
		add_part(origin, Vector3(0, y, front + 0.06), Vector3(cap_width, 0.46, 0.62), "ceramic", yaw)
		add_part(origin, Vector3(0, y + 0.25, front + 0.12), Vector3(cap_width + 0.20, 0.14, 0.66), "trim", yaw)
	for side: float in [-1, 1]:
		var x := side * width * 0.43
		add_part(origin, Vector3(x, height * 0.61, front + 0.34), Vector3(0.26, height * 0.79, 0.37), "trim", yaw)
		add_part(origin, Vector3(x, 0.86, front + 0.33), Vector3(0.64, 1.71, 0.45), "stone", yaw)


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
	var edge := Vector2(-forward.y, forward.x) * width * 0.5
	_ground.patch_polygon(PackedVector2Array([frontage + edge, frontage - edge, entrance - edge, entrance + edge]), "paving", 0.022)
	var rise: float = floor - _ground.surface_point(entrance).y
	var steps := clampi(ceili(rise / 0.18), 1, 7)
	for index in steps:
		var distance := (index + 0.55) * 0.31
		var site := entrance - forward * distance
		var top := floor - float(index) * minf(0.22, rise / steps)
		var ground_y: float = _ground.surface_point(site).y
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
	var form := Frontages.retail_treatment(shop, room)
	if form == Frontages.Retail.SERVICE:
		_service_front(origin, width, front, yaw, shop)
		return
	var cinema := shop == "CINE FIGUEIRAS"
	var cafe := room == "cafe"
	var modern := form == Frontages.Retail.GLAZED
	var door_width := 1.73 if cinema else (1.46 if modern or cafe else 1.13)
	var entrance_x := 0.0 if cafe or form in [Frontages.Retail.CIVIC, Frontages.Retail.GROCERY] else width * 0.116
	var glass_height := 2.24 if modern else (1.95 if form == Frontages.Retail.GROCERY else 1.76)
	var glass_y := 2.46 - glass_height * 0.5
	var profile := "aluminium" if modern else ("iron" if form in [Frontages.Retail.CIVIC, Frontages.Retail.GROCERY] else "timber")
	for side: float in [-1, 1]:
		var jamb := entrance_x + side * (door_width * 0.5 + 0.29)
		var edge := side * (width * 0.5 - 0.37)
		var x := (edge + jamb) * 0.5
		var glass_width := absf(edge - jamb)
		var pane := "glass" if room.is_empty() else "shop_%s_%s" % [room, "left" if side < 0.0 else "right"]
		if cinema:
			_window(origin, Vector3(x, 1.64, front + 0.01), Vector2(minf(glass_width, 1.67), 0.70), yaw, pane, profile)
			continue
		_window(origin, Vector3(x, glass_y, front + 0.009), Vector2(glass_width, glass_height), yaw, pane, profile)
		var apron := 2.46 - glass_height
		if apron > 0.28:
			add_part(origin, Vector3(x, apron * 0.48, front + 0.044), Vector3(glass_width + 0.07, apron, 0.09), "plaster_dark" if cafe else "brick", yaw)
	_entry_door(origin, Vector3(entrance_x, 1.085, front), door_width, yaw, modern or cafe or form == Frontages.Retail.GROCERY)
	var awning := "roof" if room == "market" else ("awning_green" if _lots % 2 == 0 else "awning")
	var sign_width := minf(width * 0.68, shop.length() * 0.213 + 0.40)
	var sign_depth := front + (2.26 if cafe else (2.22 if cinema else 0.025))
	var label_y := 3.17 if cafe or cinema else 2.78
	var dark_card := cinema or cafe or form == Frontages.Retail.GROCERY
	if dark_card or modern:
		var card := "sign_ink" if cinema else ("awning_green" if dark_card else "parapet")
		add_part(origin, Vector3(0, label_y, sign_depth), Vector3(sign_width + 0.36, 0.44, 0.07), card, yaw)
	var label := origin + Basis(Vector3.UP, yaw) * Vector3(0, label_y, sign_depth + 0.041)
	Openings.lettering(self, shop, label, yaw, sign_width, 0.40 if cinema else 0.31, Color("ece1c5") if dark_card else Color("373a34"))
	if cinema:
		_commercial_canopy(origin, width, front, yaw, "ceramic", "parapet", 2.10)
		for side: float in [-1, 1]:
			var x := side * width * 0.31
			var poster := Vector3(x, 1.22, front + 0.13)
			add_part(origin, poster, Vector3(0.77, 1.02, 0.07), "sign_ink", yaw)
			Openings.lettering(self, "SESSÃO DA TARDE", origin + Basis(Vector3.UP, yaw) * (poster + Vector3.BACK * 0.040),
				yaw, 0.67, 0.12, Color("e1cab0"))
	elif cafe:
		_commercial_canopy(origin, width, front, yaw, "awning_green", "wood", 2.14)
		_cafe_terrace(origin, width, front, yaw)
	elif room == "pharmacy":
		_commercial_canopy(origin, width, front, yaw, "ceramic", "trim", 1.25)
		var cross := Vector3(width * 0.44, 2.76, front + 0.16)
		add_part(origin, cross, Vector3(0.38, 0.12, 0.16), "awning_green", yaw)
		add_part(origin, cross, Vector3(0.12, 0.38, 0.17), "awning_green", yaw)
	elif form in [Frontages.Retail.NEIGHBORHOOD, Frontages.Retail.GROCERY]:
		_shop_awning(origin, width, front, yaw, awning, room, room == "bakery" or shop == "FLORICULTURA")


func _entry_door(origin: Vector3, offset: Vector3, width: float, yaw: float, glazed: bool) -> void:
	var jamb := "iron" if glazed else "timber"
	_window(origin, offset, Vector2(width, 2.14), yaw, "glass" if glazed else "door", jamb)
	var handle := offset + Vector3(width * 0.41, -0.046, 0.091)
	add_part(origin, handle, Vector3(0.034, 0.16, 0.032), "steel_plate", yaw)


func _service_front(origin: Vector3, width: float, front: float, yaw: float, shop: String) -> void:
	var entry := width * 0.23
	_garage_shutter(origin, Vector3(-width * 0.22, 1.23, front), minf(4.1, width * 0.45), yaw)
	var window_width := minf(2.62, width * 0.30)
	if shop == "OFICINA":
		_window(origin, Vector3(entry - window_width * 0.25, 1.52, front), Vector2(window_width * 0.49, 1.18), yaw, "shop_workshop_left")
		_window(origin, Vector3(entry + window_width * 0.25, 1.52, front), Vector2(window_width * 0.49, 1.18), yaw, "shop_workshop_right")
	else:
		_window(origin, Vector3(entry, 1.52, front), Vector2(window_width, 1.18), yaw, "glass")
	var door_x := width * 0.42
	_entry_door(origin, Vector3(door_x, 1.085, front), 0.96, yaw, false)
	add_part(origin, Vector3(0, 2.67, front + 0.37), Vector3(width * 0.97, 0.15, 0.87), "steel_plate", yaw)
	var nameplate := Vector3(-width * 0.17, 3.02, front + 0.064)
	var sign_width := minf(width * 0.53, shop.length() * 0.19 + 0.35)
	add_part(origin, nameplate, Vector3(sign_width + 0.23, 0.34, 0.10), "parapet", yaw)
	Openings.lettering(self, shop, origin + Basis(Vector3.UP, yaw) * (nameplate + Vector3.BACK * 0.056),
		yaw, sign_width, 0.29, Color("424a44"))


func _commercial_canopy(origin: Vector3, width: float, front: float, yaw: float, finish: String, frame: String, depth: float) -> void:
	add_part(origin, Vector3(0, 2.89, front + depth * 0.5), Vector3(width + 0.30, 0.18, depth), frame, yaw)
	add_part(origin, Vector3(0, 3.02, front + depth * 0.5), Vector3(width + 0.44, 0.10, depth + 0.17), finish, yaw)
	add_part(origin, Vector3(0, 2.79, front + depth), Vector3(width + 0.41, 0.19, 0.12), finish, yaw)
	for side: float in [-1, 1]:
		var x := side * width * 0.48
		add_part(origin, Vector3(x, 2.84, front + depth * 0.54), Vector3(0.26, 0.31, depth), frame, yaw)
		var support := origin + Basis(Vector3.UP, yaw) * Vector3(x, 0, front + depth - 0.13)
		var floor_height: float = _ground.surface_point(Vector2(support.x, support.z)).y
		var height := origin.y + 2.76 - floor_height
		add_box(Vector3(support.x, floor_height + height * 0.5, support.z), Vector3(0.21, height, 0.22), frame, false, yaw)


func _shop_awning(origin: Vector3, width: float, front: float, yaw: float, awning: String, room: String, striped: bool) -> void:
	var awning_width := width + 0.12
	var awning_root := origin + Basis(Vector3.UP, yaw) * Vector3(0, 2.57, front + 0.72)
	var tilt := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.16)
	add_transformed_instance("box", awning, Transform3D(tilt.scaled_local(Vector3(awning_width, 0.044, 1.42)), awning_root))
	add_part(origin, Vector3(0, 2.41, front + 1.43), Vector3(awning_width, 0.11, 0.04), awning, yaw)
	if striped:
		for slot in 7:
			var x := (slot - 3) * awning_width / 7.0
			var stripe_position := awning_root + tilt * Vector3(x, 0.023, 0.0)
			add_transformed_instance("box", "awning_light", Transform3D(tilt.scaled_local(Vector3(width / 17.0, 0.006, 1.40)), stripe_position), false)
			add_part(origin, Vector3(x, 2.41, front + 1.456), Vector3(width / 17.0, 0.11, 0.012), "awning_light", yaw)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * width * 0.45, 2.44, front + 0.73), Vector3(0.038, 0.048, 1.34), "metal", yaw)
	if room == "bakery":
		add_part(origin, Vector3(-width * 0.45, 0.21, front + 0.53), Vector3(0.34, 0.42, 0.34), "terracotta_pot", yaw, false, "cylinder")
		add_part(origin, Vector3(-width * 0.45, 0.62, front + 0.53), Vector3(0.44, 0.48, 0.42), "bush", yaw, false, "shrub")


func _shop_room(shop: String) -> String:
	if shop.begins_with("PADARIA"):
		return "bakery"
	if shop.begins_with("CAFÉ"):
		return "cafe"
	if shop.begins_with("MERCEARIA") or shop.begins_with("ARMAZÉM") or shop.begins_with("COOPERATIVA"):
		return "market"
	if shop.begins_with("OFICINA"):
		return "workshop"
	if shop.begins_with("FARMÁCIA") or shop.begins_with("DROGARIA"):
		return "pharmacy"
	return ""


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


func _window(origin: Vector3, offset: Vector3, size: Vector2, yaw: float, glass: String, profile := "iron") -> void:
	Openings.add_window(self, origin, offset, size, yaw, glass, profile)


func _balcony(origin: Vector3, width: float, height: float, front: float, yaw: float) -> void:
	add_part(origin, Vector3(0, height, front + 0.63), Vector3(width, 0.21, 1.35), "stone", yaw)
	add_part(origin, Vector3(0, height + 0.60, front + 1.25), Vector3(width, 1.04, 1.0), "facade_frame", yaw, false, "facade_ironwork")
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(-side * (front + 0.67), height + 0.60, width * 0.48),
			Vector3(1.13, 1.04, 1.0), "facade_frame", yaw + side * PI * 0.5, false, "facade_ironwork")


func _house_front(frontage: Vector2, across: Vector2, forward: Vector2, width: float, yaw: float, house_type: int, has_garage: bool) -> void:
	for side: float in [-1, 1]:
		if has_garage and side > 0.0:
			continue
		var garden := frontage + across * side * width * 0.31 - forward * 1.65
		_garden(garden, minf(2.5, width * 0.23), 8)
		var length := width * 0.39
		var center := frontage + across * side * (width * 0.27 + 0.55) - forward * 0.45
		var begin := center - across * length * 0.5
		var end := center + across * length * 0.5
		var tall := house_type == 4 and has_garage
		var masonry_height := 0.69 if tall else 0.46
		var masonry := "terracotta" if tall else ("stone" if house_type in [0, 2] else "brick")
		_rail(begin, end, masonry_height * 0.5 + 0.015, masonry_height, masonry, true)
		var a := Layout.surface_point(begin, masonry_height)
		var b := Layout.surface_point(end, masonry_height)
		if house_type != 3:
			var panel_height := 0.56 if tall else 0.66
			var axis := (b - a).normalized()
			var outward := axis.cross(Vector3.UP).normalized()
			var frame := Basis(axis, outward.cross(axis), outward)
			var center_panel := (a + b) * 0.5 + frame.y * (panel_height * 0.5)
			add_transformed_instance("facade_ironwork", "facade_frame",
				Transform3D(frame.scaled_local(Vector3(a.distance_to(b), panel_height, 1.0)), center_panel), false)
			for foot: Vector3 in [a, b]:
				add_box(foot - Vector3.UP * 0.21, Vector3(0.23, 0.65, 0.27), "stone", false, yaw)
		else:
			_rail(begin, end, masonry_height + 0.035, 0.11, "parapet")
	if not has_garage and _lots % 4 == 0:
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


func _mark_streets() -> void:
	for row in Layout.ROWS.size():
		var z: float = Layout.ROWS[row]
		var avenue := z == Layout.AVENUE
		for column in Layout.COLUMNS.size() - 1:
			var start: float = Layout.COLUMNS[column] + Layout.COLUMN_HALF_WIDTHS[column] + Layout.junction_radius(column, row) + 6.0
			var end: float = Layout.COLUMNS[column + 1] - Layout.COLUMN_HALF_WIDTHS[column + 1] - Layout.junction_radius(column + 1, row) - 6.0
			if avenue:
				var spans := _stripe_spans(z, start, end)
				for side: float in [-1, 1]:
					for span: Vector2 in spans:
						_ground.patch(Rect2(span.x, z + side * Layout.AVENUE_MEDIAN_HALF - 0.065, span.y - span.x, 0.130), "yellow", 0.027)
						_ground.patch(Rect2(span.x, z + side * Layout.AVENUE_TRAVEL_HALF - 0.06, span.y - span.x, 0.12), "white", 0.027)
						for x in range(ceili(span.x), floori(span.y) - 5, 9):
							_ground.patch(Rect2(x, z + side * (Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE) - 0.067, 5.1, 0.134), "white", 0.026)
						for x in range(ceili(span.x) + 1, floori(span.y), 6):
							_mark(Vector2(x, z + side * (Layout.AVENUE_TRAVEL_HALF + Layout.PARKING_WIDTH * 0.5)), Vector2(0.09, Layout.PARKING_WIDTH - 0.20), 0, "white", 0.026)
					var heading := Vector2(side, 0)
					var approach := end - 12.0 if side > 0.0 else start + 12.0
					for span: Vector2 in spans:
						if approach - 2.0 > span.x and approach + 2.0 < span.y:
							for lane: float in [0.5, 1.5]:
								_road_arrow(Vector2(approach, z + side * (Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE * lane)), heading)
				_mark_avenue_junction_guides(start, end, z)
			elif row != 3:
				for span: Vector2 in _stripe_spans(z, start, end):
					for x in range(ceili(span.x), floori(span.y) - 3, 13):
						_ground.patch(Rect2(x, z - 0.056, 3.9, 0.112), "yellow", 0.025)
	for row in Layout.ROWS.size() - 1:
		var from: float = Layout.ROWS[row] + Layout.ROW_HALF_WIDTHS[row] + Layout.junction_radius(2, row) + 6.0
		var to: float = Layout.ROWS[row + 1] - Layout.ROW_HALF_WIDTHS[row + 1] - Layout.junction_radius(2, row + 1) - 6.0
		for side: float in [-1, 1]:
			_ground.patch(Rect2(Layout.COLLECTOR + side * (Layout.COLLECTOR_HALF - 0.86) - 0.065, from, 0.13, to - from), "white", 0.025)
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
				if row == 2 or (column in [1, 2] and row == 1):
					for stripe in range(-floori(cross_width - 0.45), floori(cross_width - 0.45) + 1):
						var point := center + heading * crossing + across * stripe
						_mark(point, Vector2(0.53, 2.55), arm, "white", 0.029)
					for side: float in [-1, 1]:
						var pad := center + heading * crossing + across * side * (cross_width + 0.70)
						_mark(pad, Vector2(0.55, 2.2), arm, "tactile", 0.028)
				var controlled: bool = row in [1, 2] and column in [1, 2]
				if controlled or (arm % 2 == 0 and row == 2):
					var avenue_arm: bool = row == 2 and arm % 2 == 1
					var span := Layout.AVENUE_LANE * 2.0 if avenue_arm else cross_width
					var lane := span * 0.5 + (Layout.AVENUE_MEDIAN_HALF if avenue_arm else 0.0)
					var stop := center + heading * (crossing + Signals.STOP_SETBACK) + across * lane
					_mark(stop, Vector2(span - 0.42, 0.33), arm, "white", 0.026)
				if controlled:
					var site := center + heading * (crossing + 1.8) + across * (cross_width + 1.04)
					_signal(site, -heading)


func _mark_avenue_junction_guides(start: float, end: float, z: float) -> void:
	# Short dashed extensions separate the two through lanes while side streets open into the avenue.
	var between_lanes := Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE
	for link in Layout.urban_routes():
		for mouth: Vector2 in [link.points[0], link.points[-1]]:
			if not is_equal_approx(mouth.y, z) or mouth.x <= start or mouth.x >= end:
				continue
			for offset in range(-9, 10, 3):
				var x := mouth.x + offset
				if x < start or x + 1.35 > end or absf(x - PLAZA_CROSSING_X) < 5.6:
					continue
				for side in [-1.0, 1.0]:
					var strip := Rect2(x, z + side * between_lanes - 0.058, 1.35, 0.116)
					_ground.patch(strip, "white", 0.029)


func _stripe_spans(z: float, start: float, end: float) -> Array[Vector2]:
	var exclusions: Array[Vector2] = []
	for link in Layout.urban_routes():
		for mouth: Vector2 in [link.points[0], link.points[-1]]:
			if is_equal_approx(mouth.y, z):
				exclusions.append(Vector2(mouth.x - link.half_width - 6.1, mouth.x + link.half_width + 6.1))
	if z == Layout.AVENUE:
		exclusions.append(Vector2(PLAZA_CROSSING_X - PLAZA_CROSSING_CLEARANCE, PLAZA_CROSSING_X + PLAZA_CROSSING_CLEARANCE))
	exclusions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	for opening in exclusions:
		if opening.y <= start or opening.x >= end:
			continue
		if start < opening.x:
			spans.append(Vector2(start, opening.x))
		start = opening.y
	if start < end:
		spans.append(Vector2(start, end))
	return spans


func _plaza_crossing() -> void:
	var center := Vector2(PLAZA_CROSSING_X, Layout.AVENUE)
	for stripe in range(-floori(Layout.AVENUE_HALF - 0.28), floori(Layout.AVENUE_HALF - 0.28) + 1):
		if stripe != 0:
			_mark(center + Vector2(0, stripe), Vector2(3.55, 0.56), 0, "white", 0.032)
	for side: float in [-1, 1]:
		var approach := center + Vector2(-side * 2.62, side * (Layout.AVENUE_MEDIAN_HALF + Layout.AVENUE_LANE))
		_mark(approach, Vector2(0.31, Layout.AVENUE_LANE * 2.0 - 0.34), 0, "white", 0.031)
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
				if Layout.urban_edge(Layout.urban_sample(verge)) < 4.0:
					continue
				if index % 3 == 0:
					_lamp(verge, Vector2(0, -side))
				else:
					_tree(verge, _random.randf_range(5.1, 8.6), (index + column) % 4)
					_mark(verge, Vector2(1.46, 1.43), 0, "mulch", 0.017)
				var parking := Vector2(x + 2.4, Layout.AVENUE + side * (Layout.AVENUE_TRAVEL_HALF + Layout.PARKING_WIDTH * 0.5))
				if index in [1, 2, 4, 5, 6] and absf(parking.x - PLAZA_CROSSING_X) > 6.0 and Layout.urban_edge(Layout.urban_sample(parking)) > 4.0:
					_park(parking, side)
			var stop_site := Vector2(lerpf(start, end, 0.46), Layout.AVENUE + side * (Layout.AVENUE_HALF + 2.66))
			if (side == -1 or column == 2) and Layout.urban_edge(Layout.urban_sample(stop_site)) > 4.0:
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
				if (row in [0, 1] and absf(x - Layout.DEPOT_AXIS) < 7.0) or Layout.urban_edge(Layout.urban_sample(pole)) < 4.0:
					previous = Vector2.ZERO
					continue
				_lamp(pole, Vector2.UP)
				if previous != Vector2.ZERO:
					_rail(previous, pole, 6.12, 0.024, "cable")
				previous = pole
				var tree := Vector2(x + 3.6, z - Layout.LOCAL_HALF - 0.77)
				if not (row in [0, 1] and absf(tree.x - Layout.DEPOT_AXIS) < 7.0) and Layout.urban_edge(Layout.urban_sample(tree)) > 4.0:
					_tree(tree, _random.randf_range(5.6, 8.2), (column + row) % 4)
	for column in Layout.COLUMNS.size():
		var street: float = Layout.COLUMNS[column]
		var verge: float = Layout.COLUMN_HALF_WIDTHS[column] + 0.66
		for row in Layout.ROWS.size() - 1:
			for t: float in [0.19, 0.40, 0.60, 0.81]:
				var z := lerpf(Layout.ROWS[row], Layout.ROWS[row + 1], t)
				var right := Vector2(street + verge, z)
				var left := Vector2(street - verge, z + 2.4)
				if Layout.urban_edge(Layout.urban_sample(right)) > 3.4:
					_tree(right, _random.randf_range(4.8, 7.8), row % 4)
				if Layout.urban_edge(Layout.urban_sample(left)) > 3.4:
					_tree(left, _random.randf_range(4.8, 7.8), (column + 2) % 4)
			var positions := [0.095, 0.30, 0.50, 0.71, 0.90]
			for index in positions.size():
				var z := lerpf(Layout.ROWS[row], Layout.ROWS[row + 1], positions[index])
				var side := 1.0 if (column + row + index) % 2 == 0 else -1.0
				var site := Vector2(street + side * verge, z)
				if Layout.urban_edge(Layout.urban_sample(site)) > 3.4:
					_lamp(site, Vector2(-side, 0))


func _park(site: Vector2, side: float, axis := Vector2.RIGHT) -> void:
	var a := Layout.surface_point(site - axis * 1.83)
	var b := Layout.surface_point(site + axis * 1.83)
	var basis := Basis.looking_at((b - a).normalized() * side)
	var point := Layout.surface_point(site, 0.335)
	add_transformed_instance("parked%d" % (_parked_cars % PARKED_COLORS.size()), "parked_car", Transform3D(basis, point))
	var along := axis * 2.50
	var across := Vector2(-axis.y, axis.x) * 1.11
	var footprint := PackedVector2Array([site - along - across, site + along - across, site + along + across, site - along + across])
	_ground.patch_polygon(footprint, "shade_parked", 0.033)
	var style := _parked_cars % PARKED_COLORS.size() % 3
	add_collision(point + Vector3.UP * 0.36, Vector3(1.74, 1.12, float([4.05, 4.46, 4.32][style])))
	_colliders.get_child(-1).basis = basis
	_parked_vehicle_shapes.append(_colliders.get_child_count() - 1)
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
		add_part(head, Vector3(0, height, 0.146), Vector3(0.18, 0.18, 0.04), "steel_plate", yaw)


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


func _tree(site: Vector2, height: float, variant: int, solid := true, shadows := true) -> void:
	var point: Vector3 = _ground.surface_point(site, -0.06)
	var yaw := _random.randf() * TAU
	var scale := Vector3.ONE * height
	add_instance("bark%d" % variant, "bark", point, scale, yaw, shadows)
	add_instance("canopy%d" % variant, "ipe" if variant == 1 else "canopy", point, scale, yaw, shadows)
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
			add_instance("flower_heads", "flowers", plant + Vector3.UP * 0.57, Vector3(0.52, 0.29, 0.50), angle, false)
		else:
			var size := _random.randf_range(0.46, 0.86)
			add_instance("tuft", "grass_blade", plant, Vector3.ONE * size, angle, false)
		_plantings += 1


static func make_flowers(detailed := true) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flower in 15:
		var angle := flower * 2.39996
		var radius := sqrt(float(flower) / 15.0) * 0.59
		var center := Vector3(cos(angle) * radius, 0.21 + cos(flower * 1.42) * 0.32, sin(angle) * radius)
		var normal := (Vector3.UP * 0.58 + center * 0.89).normalized()
		var basis := Basis.looking_at(normal, Vector3.FORWARD)
		var size := 0.065 + 0.044 * absf(sin(flower * 1.82))
		for petal in 5:
			var phase := angle + TAU * petal / 5.0
			var corners: Array[Vector2]
			if detailed:
				var left := Vector2.from_angle(phase - 0.31)
				var right := Vector2.from_angle(phase + 0.31)
				var tip := (left + right).normalized()
				corners.assign([Vector2.ZERO, left * 0.78, tip, Vector2.ZERO, tip, right * 0.78])
			else:
				# Keep each flower's position and projected petal area at distance.
				corners.assign([Vector2.ZERO, Vector2.from_angle(phase) * 0.71, Vector2.from_angle(phase + TAU / 5.0) * 0.71])
			for corner: Vector2 in corners:
				surface.set_normal(normal)
				surface.set_color(Color("e3a460") if corner == Vector2.ZERO else Color("ffe3dc").lerp(Color("dad8ff"), absf(sin(flower * 13.0))))
				surface.add_vertex(center + basis.x * corner.x * size + basis.y * corner.y * size)
	surface.index()
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
			if Layout.urban_edge(Layout.urban_sample(site)) < 10.0 or Layout.scenic_edge(Layout.scenic_sample(site)) < 12.0:
				continue
			var yaw := 0.0 if side < 0.0 else PI
			_facade(site, Vector2(x, z - side * 8.0), yaw, _random.randf_range(8.4, 13.2), 1 + index % 2, 10.2, WALLS[index % WALLS.size()], "")
		for index in 15:
			var z := -174.0 + index * 25.0
			if Layout.ROWS.any(func(street): return absf(z - street) < 15.0):
				continue
			var x := float(Layout.COLUMNS[0 if side < 0.0 else 3]) + side * _random.randf_range(13.0, 20.0)
			var site := Vector2(x, z)
			if Layout.urban_edge(Layout.urban_sample(site)) < 10.0 or Layout.scenic_edge(Layout.scenic_sample(site)) < 12.0:
				continue
			_facade(site, Vector2(x - side * 8.0, z), -side * PI * 0.5, _random.randf_range(8.4, 13.2), 1 + index % 2, 10.2, WALLS[(index + 2) % WALLS.size()], "")


func _landscape() -> void:
	# The crests and drainage corridors carry continuous woodland. Between
	# them, the western pastures and east shore remain open from the car.
	var vegetation := RandomNumberGenerator.new()
	vegetation.seed = 73193
	var stands := [
		[Vector2(-279, -342), Vector2(136, 70), 65],
		[Vector2(-79, -369), Vector2(130, 45), 74],
		[Vector2(104, -363), Vector2(153, 54), 80],
		[Vector2(316, -335), Vector2(90, 63), 70],
		[Vector2(-365, -211), Vector2(60, 103), 64],
		[Vector2(-385, -16), Vector2(40, 78), 36],
		[Vector2(368, -141), Vector2(58, 98), 69],
		[Vector2(401, 54), Vector2(36, 97), 55],
		[Vector2(-296, 295), Vector2(114, 92), 57],
		[Vector2(-45, 339), Vector2(157, 53), 66],
		[Vector2(284, 371), Vector2(130, 58), 54],
	]
	for stand: Array in stands:
		for index: int in int(stand[2] * 1.3):
			var angle := vegetation.randf() * TAU
			var offset: Vector2 = Vector2.from_angle(angle) * stand[1] * sqrt(vegetation.randf())
			var site: Vector2 = stand[0] + offset
			if Layout.STREET_BOUNDS.grow(29).has_point(site) or not Layout.TERRAIN.has_point(site):
				continue
			if Layout.urban_edge(Layout.urban_sample(site)) < 12.0 or Layout.scenic_edge(Layout.scenic_sample(site)) < 37.0 or Layout.lake_distance(site) < 1.49 or Layout.Baixada.edge(Layout.district_sample(site)) < 12.0:
				continue
			var cover := Layout.canopy_cover(site)
			if vegetation.randf() > smoothstep(0.11, 0.57, cover):
				continue
			var height := vegetation.randf_range(4.9, 10.4) * lerpf(0.92, 1.22, cover)
			var point: Vector3 = _ground.surface_point(site)
			var yaw := vegetation.randf() * TAU
			add_instance("horizon_tree", "distant_canopy" if index % 4 == 0 else "forest", point,
				Vector3(height * 0.92, height * (0.79 + 0.22 * cos(index * 0.7)), height * 0.86), yaw, false)
	# Stands follow the terrain behind the roadside groves, breaking the
	# skyline with overlapping crowns and leaving the turnout views open.
	var park_roads: Array[Layout.Route] = Layout.scenic_routes().duplicate()
	park_roads.append(Layout.urban_routes()[Layout.HORTO_ROUTE])
	for route in park_roads:
		for station in range(35, floori(route.length) - 31, 9):
			if absf(station - route.stop_station) < 37.0:
				continue
			for side: float in [-1.0, 1.0]:
				for row in 2:
					var offset := side * (19.0 + row * 11.0 + 6.0 * sin(station * 0.061 + side))
					var site := route.offset_at(station + row * 4.5, offset)
					if not Layout.TERRAIN.has_point(site) or Layout.STREET_BOUNDS.grow(16.0).has_point(site):
						continue
					if Layout.road_distance(site) < 7.0 or Layout.lake_distance(site) < 1.16 or Layout.creek_weight(site) > 0.30:
						continue
					var height := 5.9 + 3.7 * absf(sin(station * 0.29 + side * 1.2 + row))
					if absf(offset) < 23.0:
						_tree(site, height, station % 2 * 2, false, false)
					else:
						add_instance("horizon_tree", "forest", _ground.surface_point(site, -0.10),
							Vector3(height * 0.84, height, height * 0.75), station * 0.73 + side, false)
	_plant_highland_edges(park_roads, vegetation)


func _plant_highland_edges(roads: Array[Layout.Route], vegetation: RandomNumberGenerator) -> void:
	var araucarias := 0
	var verges := 0
	for route in roads:
		for station in range(46, floori(route.length) - 42, 9):
			if route == Layout.scenic_routes()[0] and station > Layout.GALLERY_START - 12.0 and station < Layout.GALLERY_END + 12.0:
				continue
			for side: float in [-1.0, 1.0]:
				if side < 0.0 and absf(station - route.stop_station) < 35.0:
					continue
				var edge := route.edge_at(station, side)
				var site := route.offset_at(station, side * (edge + 4.3 + vegetation.randf() * 1.9))
				if not Layout.TERRAIN.has_point(site) or Layout.STREET_BOUNDS.grow(11.0).has_point(site) or Layout.road_distance(site) < 2.9 or Layout.lake_distance(site) < 1.02 or Layout.creek_weight(site) > 0.32:
					continue
				var cover := Layout.canopy_cover(site)
				var cut := route == Layout.scenic_routes()[Layout.PASSO_ROUTE]
				if (cover > 0.28 or cut) and vegetation.randf() < (0.82 if cut else 0.67):
					for stem in vegetation.randi_range(2, 5):
						var sprout := site + Vector2(vegetation.randf_range(-1.46, 1.46), vegetation.randf_range(-1.46, 1.46))
						var height := vegetation.randf_range(0.36, 0.85)
						add_instance("tuft", "grass_blade", _ground.surface_point(sprout), Vector3(height, height * 0.83, height), vegetation.randf() * TAU, false)
						verges += 1
				if station % 4 != 0 or cover < 0.44 or not route in [Layout.scenic_routes()[0], Layout.scenic_routes()[Layout.PASSO_ROUTE]]:
					continue
				var tree := route.offset_at(station, side * (edge + vegetation.randf_range(10.0, 16.5)))
				if not Layout.TERRAIN.has_point(tree) or Layout.road_distance(tree) < 8.0:
					continue
				var point: Vector3 = _ground.surface_point(tree, -0.12)
				var height := vegetation.randf_range(9.5, 14.8)
				var shape := Vector3(height * 0.88, height, height * 0.88)
				var yaw := vegetation.randf() * TAU
				add_instance("araucaria_trunk", "bark", point, shape, yaw, false)
				add_instance("araucaria_crown", "canopy", point, shape, yaw, false)
				araucarias += 1
	scene_root.set_meta("highland_plants", Vector2i(araucarias, verges))
