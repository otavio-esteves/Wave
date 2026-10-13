extends "res://scripts/city/pilot_city_surfaces.gd"

# Landscape, planting, street furniture and shared visual materials.
var composition_counts := {"shops": 0, "courts": 0, "playgrounds": 0, "utility_poles": 0, "street_trees": 0, "planted_gaps": 0, "benches": 0}

func _boundary() -> void:
	for side in [-1.0, 1.0]:
		for x in range(-int(Layout.HALF_WIDTH) + 8, int(Layout.HALF_WIDTH) - 7, 8):
			var z: float = side * (Layout.HALF_DEPTH - 8)
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(8, 1.2, 0.35), "hedge", true)
		for z in range(-int(Layout.HALF_DEPTH) + 8, int(Layout.HALF_DEPTH) - 7, 8):
			var x: float = side * (Layout.HALF_WIDTH - 8)
			add_box(Vector3(x, Layout.height_at(x, z) + 0.6, z), Vector3(0.35, 1.2, 8), "hedge", true)


func _premium_palette() -> void:
	meshes["flower_cluster"] = preload("res://scripts/city/neighborhood_flower_mesh.gd").build()
	for item in [["blossom_gold", "e6bd50", 0.95], ["blossom_violet", "b77cbb", 0.95], ["ivory", "cbcbbf", 0.8], ["stone", "bcb9ad", 0.9], ["charcoal", "333e43", 0.65], ["timber", "8b6850", 0.8], ["hedge", "4b6750", 0.95], ["flower", "baa17c", 0.95], ["pool", "50888c", 0.2], ["skyline", "a0a5a1", 0.95], ["skyline_roof", "68757a", 0.95], ["skyline_glass", "607884", 0.8]]:
		var material := StandardMaterial3D.new()
		material.resource_name = item[0]
		material.albedo_color = Color(item[1])
		material.roughness = item[2]
		if item[0] in ["ivory", "stone", "timber", "hedge", "flower"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		if str(item[0]).begins_with("blossom_"):
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[item[0]] = material
	materials["street_tree"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["grass"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	materials["glass"].albedo_color = Color("3d5964")
	materials["glass"].roughness = 0.16
	materials["glass"].metallic = 0.38
	materials["grass"].albedo_color = Color("dad8c8")
	var soil := StandardMaterial3D.new()
	soil.resource_name = "garden_soil"
	soil.albedo_color = Color("8b806b")
	soil.albedo_texture = load("res://assets/textures/rally/gravel.png")
	soil.roughness = 1.0
	soil.vertex_color_use_as_albedo = true
	materials["garden_soil"] = soil
	materials["grass"].albedo_texture = load("res://assets/textures/neighborhood/turf-albedo.res")
	materials["grass"].normal_texture = load("res://assets/textures/neighborhood/turf-normal.res")
	materials["grass"].normal_enabled = true
	materials["grass"].normal_scale = 0.22
	materials["grass"].shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	materials["grass"].uv1_triplanar = true
	materials["grass"].uv1_world_triplanar = true
	materials["grass"].uv1_scale = Vector3.ONE * 0.22
	materials["grass"].texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["asphalt"].albedo_color = Color("a6afb5")
	materials["white"].albedo_color = Color("e1e1d3")
	materials["sidewalk"].albedo_color = Color("b8b7aa")
	var paving: StandardMaterial3D = materials["sidewalk"].duplicate()
	paving.resource_name = "paving"
	paving.albedo_color = Color("c2c7c2")
	materials["paving"] = paving
	materials["hill"].albedo_color = Color("6b7c75")
	# World-meter projection avoids stretched textures on differently sized buildings.
	for entry in [["sage", "stucco", 0.8], ["cream", "stucco", 0.8], ["rose", "stucco", 0.8], ["ivory", "stucco", 0.8], ["stone", "limestone", 0.5], ["timber", "timber", 0.65], ["sidewalk", "paving", 0.75], ["paving", "pavers", 0.75], ["roof", "roof_tiles", 0.55]]:
		var surface: StandardMaterial3D = materials[entry[0]]
		surface.albedo_texture = load("res://assets/textures/neighborhood/%s-albedo.res" % entry[1])
		surface.normal_texture = load("res://assets/textures/neighborhood/%s-normal.res" % entry[1])
		surface.normal_enabled = true
		surface.normal_scale = 0.3
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		surface.uv1_triplanar = true
		surface.uv1_world_triplanar = true
		surface.uv1_scale = Vector3.ONE * float(entry[2])
		surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials["roof"].albedo_color = Color("b98b73")
	materials["asphalt"].albedo_texture = load("res://assets/textures/neighborhood/asphalt-albedo.res")
	materials["asphalt"].normal_texture = load("res://assets/textures/neighborhood/asphalt-normal.res")
	materials["asphalt"].normal_enabled = true
	materials["asphalt"].normal_scale = 0.25
	materials["asphalt"].albedo_color = Color("bcc2c2")
	materials["asphalt"].uv1_scale = Vector3.ONE * 0.65
	materials["asphalt"].roughness = 0.92
	var window_pane := QuadMesh.new()
	window_pane.size = Vector2.ONE
	meshes["window_pane"] = window_pane
	for label in ["residential_glass", "residential_glass_lit", "commercial_glass"]:
		var pane := StandardMaterial3D.new()
		pane.resource_name = label
		pane.albedo_texture = load("res://assets/textures/neighborhood/%s-albedo.res" % ("shop_window" if label == "commercial_glass" else "window"))
		pane.albedo_color = Color("d0d9d8")
		pane.roughness = 0.23
		pane.metallic = 0.12
		materials[label] = pane
	var curb: StandardMaterial3D = materials["sidewalk"].duplicate()
	curb.resource_name = "curb_concrete"
	curb.albedo_color = Color("abaeaa")
	materials["curb_concrete"] = curb


func _address(number: String, position: Vector3, yaw: float) -> void:
	position.y = Layout.height_at(position.x, position.z) + 1.04
	var basis := Basis(Vector3.UP, yaw)
	for index in number.length():
		var offset := Vector3((index - (number.length() - 1) * 0.5) * 0.105, 0.0, 0.008)
		add_instance("address_" + number[index], "address_plate", position + basis * offset, Vector3.ONE, yaw, false)
	var transform := Transform3D(basis, position)
	var marker := Node3D.new()
	marker.name = "Address%d" % scene_root.get_child_count()
	marker.transform = transform
	marker.set_meta("number", number)
	scene_root.add_child(marker)


func _address_palette() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "address_plate"
	material.albedo_texture = load("res://assets/textures/pilot/address-atlas.png")
	material.roughness = 0.9
	materials["address_plate"] = material
	batch_sizes["address_plate"] = 64.0
	for digit in 10:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector3(-0.05, 0.09, 0), Vector3(0.05, 0.09, 0), Vector3(0.05, -0.09, 0), Vector3(-0.05, -0.09, 0)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for corner in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.BACK)
			tool.set_uv(Vector2((digit + 0.04 + uvs[corner].x * 0.92) / 10.0, 0.04 + uvs[corner].y * 0.92))
			tool.add_vertex(corners[corner])
		tool.index()
		meshes["address_" + str(digit)] = tool.commit()
		meshes["address_" + str(digit)].resource_name = "AddressDigit_" + str(digit)


func _tree_palette() -> void:
	for item in ["tree_bark", "tree_leaves"]:
		var material := StandardMaterial3D.new()
		material.resource_name = item
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		if item == "tree_leaves":
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.albedo_texture = load("res://assets/textures/neighborhood/leaf-cluster-v1.png")
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.45
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[item] = material
	for variant in 6:
		var tree: Dictionary = preload("res://scripts/city/neighborhood_tree_mesh.gd").new().build(variant)
		meshes["tree_bark%d" % variant] = tree.bark
		meshes["tree_leaves%d" % variant] = tree.leaves


	# Leaf clusters give shrubs irregular silhouettes rather than solid green balls.
	var shrub_arrays: Array = meshes["tree_leaves0"].surface_get_arrays(0)
	var vertices: PackedVector3Array = shrub_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = shrub_arrays[Mesh.ARRAY_NORMAL]
	for index in vertices.size():
		vertices[index] = (vertices[index] - Vector3(0, 0.64, 0)) * Vector3(4.0, 3.0, 4.0)
		normals[index] = (normals[index] / Vector3(4.0, 3.0, 4.0)).normalized()
	shrub_arrays[Mesh.ARRAY_VERTEX] = vertices
	shrub_arrays[Mesh.ARRAY_NORMAL] = normals
	var shrub := ArrayMesh.new()
	shrub.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shrub_arrays)
	meshes["shrub"] = shrub


func _garden_tree(position: Vector3, height: float, solid: bool = true) -> void:
	if solid:
		_projected_patch("TreeShade", position, Vector2(height * 0.50, height * 0.50), "grass", 0.008, true)
	var variant := int(absf(position.x * 1.17 + position.z * 0.79)) % 6
	var shape_variation := int(absf(position.z * 0.43)) % 5
	var yaw := fposmod(position.x * 1.73 + position.z * 0.81, TAU)
	var scale := Vector3(height * (0.82 + 0.07 * shape_variation), height, height * (1.13 - 0.06 * shape_variation))
	add_instance("tree_bark%d" % variant, "tree_bark", position, scale, yaw)
	add_instance("tree_leaves%d" % variant, "tree_leaves", position, scale, yaw)
	if variant in [3, 4]:
		var flower_mat := "blossom_gold" if variant == 3 else "blossom_violet"
		for bunch in 7:
			var angle := bunch * 2.4 + yaw
			var offset := Vector3(cos(angle) * height * 0.17, height * (0.69 + 0.06 * sin(bunch)), sin(angle) * height * 0.17)
			add_instance("flower_cluster", flower_mat, position + offset, Vector3.ONE * height * 0.045)
	# Preserve the prior trunk's physical envelope; leaves do not obstruct driving.
	if solid:
		add_collision(position + Vector3.UP * 1.2, Vector3(0.4, 2.4, 0.4))
	tree_count += 1


func _street_life() -> void:
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		_street_details(edge, points)
		_curb_details(edge, points)
		for fraction: float in [0.18, 0.67]:
			var index := floori((points.size() - 1) * fraction)
			var p := points[index]
			var normal := (points[index + 1] - points[index - 1]).cross(Vector3.UP).normalized()
			for side: float in [-1.0, 1.0]:
				var origin := p + normal * side * (float(edge.width) / 2 + 4.2)
				origin.y = Layout.height_at(origin.x, origin.z)
				if fraction < 0.2:
					_garden_tree(origin, 7.5)
				else:
					var drain := p + normal * side * (float(edge.width) / 2 - 0.35)
					drain.y = Layout.height_at(drain.x, drain.z) + 0.034
					var yaw := atan2(-normal.z, normal.x)
					add_box(drain, Vector3(0.55, 0.012, 0.85), "charcoal", false, yaw, false)
					for rib in 6:
						add_part(drain, Vector3(0, 0.010, -0.33 + rib * 0.13), Vector3(0.52, 0.012, 0.025), "metal", yaw)
					add_instance("cylinder", "charcoal", origin + Vector3.UP * 3.5, Vector3(0.09, 7, 0.09))
					add_box(origin + Vector3.UP * 6.9 - normal * side * 0.8, Vector3(1.8, 0.08, 0.18), "charcoal")
					add_box(origin + Vector3.UP * 6.84 - normal * side * 1.5, Vector3(0.45, 0.05, 0.22), "light", false, 0, false)
					var lamp := Marker3D.new()
					lamp.name = "StreetLamp%d" % scene_root.get_child_count()
					lamp.position = origin + Vector3.UP * 6.75 - normal * side * 1.5
					scene_root.add_child(lamp)
					add_collision(origin + Vector3.UP, Vector3(0.18, 2, 0.18))


func _landscape() -> void:
	var faces := PackedVector3Array()
	for z in range(-1488, 1488, 16):
		for x in range(-1792, 1792, 16):
			if x >= -Layout.HALF_WIDTH and x + 16 <= Layout.HALF_WIDTH and z >= -Layout.HALF_DEPTH and z + 16 <= Layout.HALF_DEPTH:
				continue
			var a := Vector3(x, _land_height(x, z), z)
			var b := Vector3(x + 16, _land_height(x + 16, z), z)
			var c := Vector3(x, _land_height(x, z + 16), z + 16)
			var d := Vector3(x + 16, _land_height(x + 16, z + 16), z + 16)
			_background_triangle(faces, [a, c, b])
			_background_triangle(faces, [b, c, d])
	_mesh("BackgroundLandscape", faces, "grass", 0.045)
	for side: float in [-1.0, 1.0]:
		for index in 53:
			var p := Vector3(-Layout.HALF_WIDTH + 70 + index * 56.0, 0, side * (Layout.HALF_DEPTH - 55 + 8 * sin(index)))
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 10.0 + (index % 3))
		for index in 41:
			var p := Vector3(side * (Layout.HALF_WIDTH - 55), 0, -Layout.HALF_DEPTH + 70 + index * 57.0)
			p.y = Layout.height_at(p.x, p.z)
			_garden_tree(p, 9.0 + (index % 3))

	for group in 12:
		var angle := TAU * group / 12.0
		var center := Vector3(cos(angle) * 1710, 0, sin(angle) * 1430)
		for index in 7:
			var offset := Vector3(cos(index * 2.4 + group) * (9 + index * 2.8), 0, sin(index * 2.4 + group) * (8 + index * 2.1))
			var point := center + offset
			point.y = _land_height(point.x, point.z)
			_garden_tree(point, 12.0 + (index + group) % 5, false)
	# A low-detail neighboring skyline sits beyond the playable boundary.
	for index in 22:
		var x := -1400.0 + index * 132.0
		var z := -1340.0 - 38.0 * sin(index * 1.73)
		var position := Vector3(x, _land_height(x, z), z)
		var width := 12.0 + index % 4 * 3.0
		var height := 7.0 + index % 5 * 3.3
		add_box(position + Vector3.UP * height / 2, Vector3(width, height, 13), "skyline", false)
		add_box(position + Vector3.UP * (height + 0.2), Vector3(width + 0.7, 0.4, 14), "skyline_roof", false)
		for floor_index in int(height / 3):
			for window in 4:
				add_box(position + Vector3(-width * 0.35 + window * width * 0.23, 1.9 + floor_index * 3, 6.55), Vector3(1.6, 1.6, 0.1), "skyline_glass", false, 0, false)


func _lot_finish(origin: Vector3, yaw: float, size: Vector2, variant: int) -> void:
	# Paths, planting and parked cars remain within each parcel's safety envelope.
	var basis := Basis(Vector3.UP, yaw)
	for side: float in [-1, 1]:
		for index in 3:
			var position := origin + basis * Vector3(side * (size.x / 2 - 1.1), 0, -size.y / 2 + 2.5 + index * 3.0)
			position.y = Layout.height_at(position.x, position.z)
			add_instance("shrub", "tree_leaves", position + Vector3.UP * 0.55, Vector3(0.8, 0.6, 1.1), yaw)
			add_instance("tree_leaves%d" % ((variant + index) % 6), "tree_leaves", position - Vector3.UP * 0.25, Vector3(2.7, 1.3, 3.0), yaw)
	if size.x > 18:
		var parking := origin + basis * Vector3(4.2, 0, -9.4)
		_projected_patch("GardenTerrace", parking, Vector2(8.0, 4.0), "paving", 0.04)
		if variant % 2 == 0:
			_parked_car(parking, yaw + PI / 2, variant)
	else:
		var parking := origin + basis * Vector3(3.5, 0, 6.4)
		if variant % 3 == 0:
			_parked_car(parking, yaw, variant)


func _parked_palette() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "parked_car"
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.18
	material.roughness = 0.48
	materials["parked_car"] = material
	batch_sizes["parked_car"] = 64.0
	for variant in 3:
		meshes["parked_car_" + str(variant)] = preload("res://scripts/city/parked_car_mesh.gd").build([Color("b8c0c3"), Color("79383b"), Color("d9d3c0")][variant])
		meshes["parked_car_" + str(variant)].resource_name = "ParkedCar_" + str(variant)


func _parked_car(position: Vector3, yaw: float, variant: int) -> void:
	parked_count += 1
	var vehicle := Node3D.new()
	vehicle.name = "ParkedVehicle%d" % parked_count
	vehicle.position = Vector3(position.x, Layout.height_at(position.x, position.z) + 0.38, position.z)
	vehicle.rotation.y = yaw
	scene_root.add_child(vehicle)
	add_instance("parked_car_" + str(variant % 3), "parked_car", vehicle.position, Vector3.ONE, yaw, false)
	add_collision(vehicle.position + Vector3.UP * 0.3, Vector3(1.8, 1.2, 4.0), yaw)


func _block_gardens(u: float, v: float, id: int) -> void:
	if Layout.district(id) == 2 or id in Layout.PARK_BLOCKS or id == Layout.WORKSHOP_BLOCK or (Layout.district(id) == 1 and id % 3 == 0):
		return
	# Small shared gardens fill the interior; they do not close the street approaches.
	var center := Layout.position(u, v)
	_projected_patch("GardenWalk", center, Vector2(36, 3), "paving", 0.038)
	for side: float in [-1, 1]:
		var bed := Layout.position(u + side * 13, v + 9)
		_projected_patch("PlantingBed", bed, Vector2(12, 11), "garden_soil", 0.018)
		for step in 7:
			var plant := Layout.position(u + side * (8 + step % 3 * 3.2), v + 5 + (step / 3) * 3)
			add_instance("flower_cluster", "blossom_gold" if id % 2 == 0 else "blossom_violet", plant + Vector3.UP * 0.25, Vector3(0.65, 0.55, 0.65), step * 0.8, false)
	for side: float in [-1, 1]:
		for step in 3:
			var point := Layout.position(u + side * (9 + step * 3 + 3 * sin(id)), v + (6 + id % 5) * sin(step * 1.4 + id))
			add_instance("shrub", "tree_leaves", point + Vector3.UP * 0.5, Vector3(1.2 + id % 3 * 0.3, 0.45 + id % 4 * 0.1, 1.2), step * 0.7)
			if step == 1:
				_garden_tree(point, 6.5 + id % 4)
		var bench := Layout.position(u + side * 7, v + 2.2)
		_bench(bench, 0 if side < 0 else PI)


func _meadow_grass() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "wild_grass"
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 1.0
	materials["wild_grass"] = material
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 3:
		var basis := Basis(Vector3.UP, blade * PI / 3)
		for point: Vector3 in [Vector3(-0.12, 0, 0), Vector3(0.08, 0.9, 0.05), Vector3(0.12, 0, 0)]:
			tool.set_normal(basis * Vector3.FORWARD)
			tool.set_color(Color("687148") if point.y < 0.1 else Color("a0a077"))
			tool.add_vertex(basis * point)
	tool.index()
	meshes["grass_blades"] = tool.commit()
	var random := RandomNumberGenerator.new()
	random.seed = 90418
	for cluster in 10500:
		var center := Vector2(random.randf_range(-Layout.HALF_WIDTH + 20, Layout.HALF_WIDTH - 20), random.randf_range(-Layout.HALF_DEPTH + 20, Layout.HALF_DEPTH - 20))
		if _road_distance(center) < 5.0:
			continue
		var occupied := false
		for parcel in _nearby_parcels(center):
			var local := Vector2(cos(parcel.yaw), -sin(parcel.yaw))
			var across := Vector2(sin(parcel.yaw), cos(parcel.yaw))
			var offset: Vector2 = center - parcel.center
			if absf(offset.dot(local)) < parcel.size.x / 2 + 4 and absf(offset.dot(across)) < parcel.size.y / 2 + 4:
				occupied = true
				break
		if occupied:
			continue
		if cluster % 13 == 0:
			var rock := Vector3(center.x, Layout.height_at(center.x, center.y), center.y)
			add_instance("foliage", "stone", rock + Vector3.UP * 0.14, Vector3(0.7, 0.23, 0.45), random.randf_range(0, TAU), false)
		if cluster % 7 == 0:
			for flower in 5:
				var spot := center + Vector2(random.randf_range(-1, 1), random.randf_range(-1, 1))
				var foot := Vector3(spot.x, Layout.height_at(spot.x, spot.y), spot.y)
				add_instance("foliage", "flower", foot + Vector3.UP * 0.23, Vector3(0.12, 0.1, 0.12), 0, false)
		for tuft in 22:
			var point := center + Vector2(random.randf_range(-3, 3), random.randf_range(-3, 3))
			if _road_distance(point) < 3.5 or _parcel_overlaps(Vector3(point.x, 0, point.y), 0, Vector2(0.1, 0.1)):
				continue
			var position := Vector3(point.x, Layout.height_at(point.x, point.y), point.y)
			var size := random.randf_range(0.18, 0.38)
			add_instance("grass_blades", "wild_grass", position, Vector3.ONE * size, random.randf_range(0, TAU), false)
			grass_count += 1


func _street_details(edge: Dictionary, points: PackedVector3Array) -> void:
	var index := floori(points.size() * 0.47)
	var tangent := (points[index + 1] - points[index - 1]).normalized()
	var outward := tangent.cross(Vector3.UP).normalized()
	var site := points[index] + outward * (float(edge.width) / 2 + 2)
	site.y = _sidewalk_point(Vector3(site.x, _road_distance(Vector2(site.x, site.z)), site.z)).y
	var yaw := atan2(-tangent.z, tangent.x)
	if _parcel_overlaps(site, yaw, Vector2(5.5, 2.2)):
		return
	_register_parcel({"center": Vector2(site.x, site.z), "yaw": yaw, "size": Vector2(5.5, 2.2), "kind": "street_furniture"})
	street_detail_count += 1
	_bench(site, yaw)
	_litter_bin(site + Basis(Vector3.UP, yaw) * Vector3(2, 0, 0), yaw)
	if review_benches.size() < 12:
		review_benches.append({"position": site, "yaw": yaw})
	if (int(edge.a) + int(edge.b)) % 7 == 0:
		for x: float in [-1.8, 1.8]:
			add_part(site, Vector3(x, 1.5, -0.65), Vector3(0.1, 3, 0.1), "charcoal", yaw, true)
		add_part(site, Vector3(0, 3, 0), Vector3(4.4, 0.18, 1.8), "metal", yaw)
		add_part(site, Vector3(0, 1.75, -0.76), Vector3(3.6, 2.1, 0.08), "glass", yaw)
		add_part(site, Vector3(-2.25, 1.9, 0), Vector3(0.09, 3.8, 0.09), "charcoal", yaw)
		add_part(site, Vector3(-2.25, 3.4, 0), Vector3(0.55, 0.6, 0.1), "blue", yaw)
		add_label("ÔNIBUS", site + Basis(Vector3.UP, yaw) * Vector3(-2.25, 3.4, 0.07), yaw, 0.0025)
		add_part(site, Vector3(1.45, 1.55, -0.69), Vector3(0.6, 0.8, 0.025), "ivory", yaw)
		for line in 5:
			add_part(site, Vector3(1.45, 1.76 - line * 0.105, -0.668), Vector3(0.43, 0.02, 0.01), "charcoal", yaw)

func _bench(origin: Vector3, yaw: float) -> void:
	composition_counts["benches"] += 1
	# Adult-scale wooden slats, open steel supports, armrests and fixing bolts.
	for slat in 5:
		add_part(origin, Vector3(0, 0.46, -0.24 + slat * 0.115), Vector3(2.3, 0.055, 0.095), "timber", yaw)
	for slat in 4:
		add_part(origin, Vector3(0, 0.68 + slat * 0.095, -0.29 - slat * 0.024), Vector3(2.3, 0.072, 0.05), "timber", yaw)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * 0.86, 0.22, 0), Vector3(0.065, 0.44, 0.48), "charcoal", yaw)
		add_part(origin, Vector3(side * 0.86, 0.68, -0.31), Vector3(0.045, 0.65, 0.045), "charcoal", yaw)
		add_part(origin, Vector3(side * 1.02, 0.63, 0.01), Vector3(0.055, 0.34, 0.055), "charcoal", yaw)
		add_part(origin, Vector3(side * 1.02, 0.79, -0.07), Vector3(0.065, 0.045, 0.48), "charcoal", yaw)
		add_part(origin, Vector3(side * 0.86, 0.025, 0), Vector3(0.16, 0.05, 0.54), "metal", yaw)
		for z: float in [-0.18, 0.18]:
			add_part(origin, Vector3(side * 0.86, 0.058, z), Vector3(0.025, 0.012, 0.025), "metal", yaw)
	add_collision(origin + Vector3.UP * 0.43, Vector3(2.35, 0.86, 0.68), yaw)

func _litter_bin(origin: Vector3, yaw: float) -> void:
	add_part(origin, Vector3(0, 0.46, 0), Vector3(0.36, 0.85, 0.36), "charcoal", yaw, true)
	for side: float in [-1, 1]:
		for slat in 5:
			add_part(origin, Vector3(-0.19 + slat * 0.095, 0.46, side * 0.195), Vector3(0.06, 0.78, 0.045), "timber", yaw)
			add_part(origin, Vector3(side * 0.195, 0.46, -0.19 + slat * 0.095), Vector3(0.045, 0.78, 0.06), "timber", yaw)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * 0.20, 0.90, 0), Vector3(0.08, 0.06, 0.48), "metal", yaw)
		add_part(origin, Vector3(0, 0.90, side * 0.20), Vector3(0.34, 0.06, 0.08), "metal", yaw)
	# Dark inner floor leaves a real visible opening instead of a solid lid.
	add_part(origin, Vector3(0, 0.72, 0), Vector3(0.32, 0.02, 0.32), "charcoal", yaw)

func _curb_details(edge: Dictionary, points: PackedVector3Array) -> void:
	var faces := PackedVector3Array()
	for index in range(3, points.size() - 4):
		var a := points[index]
		var b := points[index + 1]
		if minf(a.distance_to(points[0]), a.distance_to(points[-1])) < 18.0:
			continue
		var n0 := (points[index + 1] - points[index - 1]).cross(Vector3.UP).normalized()
		var n1 := (points[index + 2] - points[index]).cross(Vector3.UP).normalized()
		for side: float in [-1, 1]:
			var polygon: Array[Vector3] = [a + n0 * side * (edge.width / 2 + 0.07), a + n0 * side * (edge.width / 2 + 0.55), b + n1 * side * (edge.width / 2 + 0.07), b + n1 * side * (edge.width / 2 + 0.55)]
			for vertex in polygon.size():
				var p := polygon[vertex]
				polygon[vertex] = _sidewalk_point(Vector3(p.x, _road_distance(Vector2(p.x, p.z)), p.z)) + Vector3.UP * 0.003
			_triangle(faces, polygon[0], polygon[2], polygon[1])
			_triangle(faces, polygon[1], polygon[2], polygon[3])
	_mesh("CurbDetail", faces, "curb_concrete", 0.75)
	# Flush road covers and tactile crossing pads are visual details over existing support.
	if (int(edge.a) + int(edge.b)) % 3 == 0:
		var index := points.size() / 3
		var cover := points[index] + Vector3.UP * (Layout.ROAD_LIFT + 0.004)
		add_instance("cylinder", "metal", cover, Vector3(0.32, 0.008, 0.32), 0, false)
		for groove in 5:
			add_part(cover, Vector3(-0.22 + groove * 0.11, 0.006, 0), Vector3(0.018, 0.003, 0.42), "charcoal", 0)
	for index in [7, points.size() - 9]:
		var tangent := (points[index + 1] - points[index - 1]).normalized()
		var normal := tangent.cross(Vector3.UP).normalized()
		var yaw := atan2(-normal.z, normal.x)
		for side: float in [-1, 1]:
			var pad: Vector3 = points[index] + normal * side * (float(edge.width) / 2 + 1.3)
			pad.y = _sidewalk_point(Vector3(pad.x, _road_distance(Vector2(pad.x, pad.z)), pad.z)).y + 0.006
			add_part(pad, Vector3.ZERO, Vector3(0.72, 0.012, 1.20), "yellow", yaw)
			for rib in 6:
				add_part(pad, Vector3(-0.29 + rib * 0.115, 0.009, 0), Vector3(0.025, 0.006, 1.08), "terracotta", yaw)
