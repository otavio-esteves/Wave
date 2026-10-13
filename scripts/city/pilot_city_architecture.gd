extends "res://scripts/city/pilot_city_details.gd"

# District parcels, buildings and their entrances.

func _blocks() -> void:
	for row in Layout.ROW_COUNT - 1:
		for column in Layout.COLUMN_COUNT - 1:
			var id := row * (Layout.COLUMN_COUNT - 1) + column
			var u: float = (Layout.COLUMNS[column] + Layout.COLUMNS[column + 1]) / 2
			var v: float = (Layout.ROWS[row] + Layout.ROWS[row + 1]) / 2
			var district := Layout.district(id)
			var previous_parcels := parcel_count
			var block := Node3D.new()
			block.name = "Block%d" % id
			block.position = Layout.position(u, v)
			block.set_meta("label", Layout.block_name(id))
			block.set_meta("district", district)
			scene_root.add_child(block)
			if id in Layout.PARK_BLOCKS:
				_square(u, v)
				_park_amenities(u, v, id)
			elif id == Layout.WORKSHOP_BLOCK:
				_service(u + 18, v)
				_projected_patch("WorkshopYard", Layout.position(u + 33, v), Vector2(28, 26), "paving", 0.032)
				for offset: float in [-24.0, 24.0]:
					var yaw := 0.0 if offset > 0 else PI
					var lot := _safe_site(Vector2(u - 3, v + offset), Vector2(u - 20, v + offset * 1.2), yaw, Vector2(21.5, 24))
					if lot.is_finite():
						_villa(lot.x, lot.y, yaw, 2)
			else:
				if district != 2 and not (district == 1 and id % 3 == 0):
					var garden := Layout.position(u, v)
					_register_parcel({"center": Vector2(garden.x, garden.z), "yaw": 0.0, "size": Vector2(58, 40), "kind": "garden"})
				for side: float in [-1.0, 1.0]:
					var street_row := row if side < 0 else row + 1
					var start_id: int = street_row * Layout.COLUMN_COUNT + column
					_populate_frontage(start_id, start_id + 1, -side, Vector2(u, v), id, false)
			if id not in Layout.PARK_BLOCKS and id != Layout.WORKSHOP_BLOCK:
				_side_frontages(row, column, id)
			if district == 2 and id not in Layout.PARK_BLOCKS and id != Layout.WORKSHOP_BLOCK:
				_compact_commerce(row, column, id, maxi(0, 8 - (parcel_count - previous_parcels)))
			if district == 1 and id not in Layout.PARK_BLOCKS:
				_neighborhood_shop(u, v, id)
			block.set_meta("building_count", parcel_count - previous_parcels)
			district_parcels[district] += parcel_count - previous_parcels
			_block_gardens(u, v, id)
			# Compact centre blocks use their dedicated public parks, leaving room for buildings.
			if district != 2:
				for side: float in [-1.0, 1.0]:
					_garden_tree(Layout.position(u + side * 22, v + (10 if id == 3 else 0)), 9.0)


func _house(u: float, v: float, width: float, height: float, depth: float, yaw: float, facade: int) -> void:
	var origin := Layout.position(u, v)
	var base := origin.y
	var low := origin.y
	for dx in [-width / 2, width / 2]:
		for dz in [-depth / 2, depth / 2]:
			var corner := origin + Basis(Vector3.UP, yaw) * Vector3(dx, 0, dz)
			base = maxf(base, Layout.height_at(corner.x, corner.z))
			low = minf(low, Layout.height_at(corner.x, corner.z))
	# A visible plinth levels the house, instead of tilting its walls with the hill.
	base += 0.12
	add_box(Vector3(origin.x, (base + low - 0.2) / 2, origin.z), Vector3(width + 0.3, base - low + 0.2, depth + 0.3), "brick", true, yaw)
	origin.y = base
	_building(origin, width, height, depth, yaw, facade)


func _square(u: float, v: float) -> void:
	var center := Layout.position(u, v)
	_register_parcel({"center": Vector2(center.x, center.z), "yaw": 0.0, "size": Vector2(52, 44), "kind": "park"})
	_projected_patch("Square", center, Vector2(40, 36), "paving", 0.035)
	if Vector2(u, v).distance_to(Layout.block_uv(Layout.SQUARE_BLOCK)) < 1.0:
		# Mark the existing activity destination without narrowing its approach.
		for side: float in [-1, 1]:
			var bay := Layout.position(u + side * 4.5, v)
			for edge: float in [-1, 1]:
				_projected_patch("SquareParking", bay + Vector3(edge * 1.4, 0, 0), Vector2(0.10, 5.4), "white", 0.045)
			_projected_patch("SquareParking", bay + Vector3(0, 0, -2.65), Vector2(2.8, 0.10), "white", 0.045)
		var sign := Layout.position(u + 9, v + 3)
		add_box(sign + Vector3.UP * 1.8, Vector3(0.10, 3.6, 0.10), "charcoal")
		add_box(sign + Vector3.UP * 3.0, Vector3(4.6, 1.05, 0.12), "sage")
		add_label("PRAÇA DOS IPÊS", sign + Vector3(0, 3.0, 0.08), 0, 0.009)
	# Planting beds leave the central approach open for vehicle manoeuvres.
	for side: float in [-1.0, 1.0]:
		for offset: float in [-11.0, 11.0]:
			var bed := Layout.position(u + side * 14, v + offset)
			add_box(bed + Vector3.UP * 0.22, Vector3(7.0, 0.44, 5.0), "stone", true)
			add_box(bed + Vector3.UP * 0.46, Vector3(6.6, 0.12, 4.6), "hedge")
			_garden_tree(bed + Vector3.UP * 0.5, 8.0)
		for offset: float in [-5.0, 5.0]:
			var bench := Layout.position(u + side * 12, v + offset, 0.045)
			_bench(bench, PI / 2 * side)
		_litter_bin(Layout.position(u + side * 17, v, 0.045), 0)
	for step in 9:
		var offset := -70.0 + step * 17.5
		if absf(offset) < 30:
			continue
		var bend := 9 * sin(step * 0.8 + u * 0.01)
		_projected_patch("ParkWalk", Layout.position(u + bend, v + offset), Vector2(4, 19), "paving", 0.034)
		for side: float in [-1, 1]:
			_garden_tree(Layout.position(u + bend + side * 15, v + offset), 7 + step % 4)
	for side: float in [-1, 1]:
		var bed := Layout.position(u + side * 9, v + 12)
		add_box(bed + Vector3.UP * 0.22, Vector3(5, 0.44, 3), "stone", true)
		for blossom in 9:
			var flower := bed + Vector3(-2 + blossom % 5, 0.6, -0.7 + floori(blossom / 5) * 1.2)
			add_instance("flower_cluster", "blossom_gold" if side < 0 else "blossom_violet", flower, Vector3(0.45, 0.35, 0.45))
	var pavilion := _foundation(u, v - 11, 11, 7, 0)
	for dx: float in [-4.6, 4.6]:
		add_part(pavilion, Vector3(dx, 1.8, 0), Vector3(0.18, 3.6, 6), "charcoal", 0, true)
	for slat in 15:
		add_part(pavilion, Vector3(-5.0 + slat * 0.72, 3.5, 0), Vector3(0.18, 0.26, 7.0), "timber", 0)


func _foundation(u: float, v: float, width: float, depth: float, yaw: float) -> Vector3:
	var origin := Layout.position(u, v)
	var footprint := Vector2(absf(cos(yaw)) * width + absf(sin(yaw)) * depth, absf(sin(yaw)) * width + absf(cos(yaw)) * depth)
	_projected_patch("FoundationShade", origin, footprint + Vector2(6, 6), "grass", 0.011, true)
	var high := origin.y
	var low := origin.y
	for x_step in ceili(width / 2) + 1:
		for z_step in ceili(depth / 2) + 1:
			var dx := lerpf(-width / 2, width / 2, x_step / float(ceili(width / 2)))
			var dz := lerpf(-depth / 2, depth / 2, z_step / float(ceili(depth / 2)))
			var corner := origin + Basis(Vector3.UP, yaw) * Vector3(dx, 0, dz)
			high = maxf(high, Layout.height_at(corner.x, corner.z))
			low = minf(low, Layout.height_at(corner.x, corner.z))

	high += 0.12
	add_box(Vector3(origin.x, (high + low - 0.2) / 2, origin.z), Vector3(width + 0.4, high - low + 0.2, depth + 0.4), "stone", true, yaw)
	origin.y = high
	return origin


func _villa(u: float, v: float, yaw: float, variant: int) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 17, 13, yaw)
	var wall: String = ["ivory", "sage", "cream", "rose", "ivory", "stone", "cream", "sage", "ivory"][variant % 9]
	var upper_x: float = [-3.0, 3.0, 0.0][variant % 3]
	add_part(origin, Vector3(0, 1.65, 0), Vector3(16, 3.3, 12), wall, yaw, true)
	add_part(origin, Vector3(upper_x, 4.9, -1.0), Vector3(10.5, 3.2, 9.5), "stone" if variant % 3 == 1 else wall, yaw, true)
	add_part(origin, Vector3(0, 3.35, 0.4), Vector3(17.4, 0.28, 13.2), "ivory", yaw)
	add_part(origin, Vector3(upper_x, 6.6, -1.0), Vector3(11.5, 0.3, 10.5), "charcoal", yaw)
	if variant in [3, 6, 8]:
		# Roof terraces and pergolas vary the silhouette without enlarging the lot.
		for x: float in [-4, 4]:
			for z: float in [-3.3, 1.3]:
				add_part(origin, Vector3(upper_x + x, 7.4, z), Vector3(0.12, 1.6, 0.12), "timber", yaw)
		for z: float in [-3.3, 1.3]:
			add_part(origin, Vector3(upper_x, 8.12, z), Vector3(8.6, 0.18, 0.16), "timber", yaw)
		for slat in 9:
			add_part(origin, Vector3(upper_x - 4.2 + slat * 1.05, 8.25, -1.0), Vector3(0.14, 0.15, 5.0), "timber", yaw)
	if variant in [1, 4]:
		# Two tiled roof forms break up the repeated flat-roof silhouette.
		add_part(origin, Vector3(upper_x, 7.22, -1), Vector3(11.7, 1.15, 10.7), "roof", yaw, false, "roof")
	elif variant in [2, 5]:
		for strip in 8:
			add_part(origin, Vector3(upper_x - 4.8 + strip * 1.35, 4.9, 3.86), Vector3(0.17, 2.8, 0.16), "timber", yaw)
	# Roof coping, solar panels and rainwater pipes add believable scale.
	for side: float in [-1, 1]:
		add_part(origin, Vector3(upper_x + side * 5.5, 6.87, -1), Vector3(0.16, 0.36, 10.5), "ivory", yaw)
		add_part(origin, Vector3(side * 7.85, 1.62, -5.7), Vector3(0.09, 3.2, 0.09), "charcoal", yaw)
	for panel in (0 if variant in [1, 4] else 3):
		add_part(origin, Vector3(upper_x - 2.7 + panel * 2.5, 6.82, -1.8), Vector3(2.15, 0.08, 3.2), "glass", yaw)
	for x: float in [-4.5, 0.0, 4.5]:
		_window(origin, Vector3(x, 1.65, 6.10), Vector2(3.6, 2.3), yaw)
	for x: float in [-2.5, 2.5]:
		_window(origin, Vector3(upper_x + x, 4.9, 3.84), Vector2(3.8, 2.3), yaw)
	for side: float in [-1.0, 1.0]:
		for z: float in [-3.5, 1.5]:
			_window(origin, Vector3(side * 8.10, 1.75, z), Vector2(2.3, 1.65), yaw, true)
	# Recessed entrance, vertical stone feature and parapet caps give facade scale.
	add_part(origin, Vector3(6.6, 1.55, 6.15), Vector3(1.25, 2.9, 0.24), "timber", yaw)
	add_part(origin, Vector3(6.94, 1.45, 6.29), Vector3(0.045, 0.48, 0.035), "metal", yaw)
	add_part(origin, Vector3(-7.5, 1.65, 6.13), Vector3(0.65, 3.3, 0.30), "stone", yaw)
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(side * 7.9, 3.08, 0), Vector3(0.16, 0.08, 12.1), "charcoal", yaw)
	for x: float in [-4.5, 0.0, 4.5]:
		add_part(origin, Vector3(x, 0.42, 6.20), Vector3(3.85, 0.12, 0.40), "stone", yaw)
	# Timber screen and cantilevered balcony provide depth in the driving view.
	for slat in 10:
		add_part(origin, Vector3(upper_x - 4.5 + slat * 0.21, 4.95, 4.02), Vector3(0.09, 2.9, 0.20), "timber", yaw)
	add_part(origin, Vector3(upper_x, 3.45, 5.20), Vector3(11.1, 0.22, 3.2), "ivory", yaw)
	add_part(origin, Vector3(upper_x, 4.04, 6.70), Vector3(10.7, 1.0, 0.12), "glass", yaw)
	add_part(origin, Vector3(upper_x, 4.57, 6.70), Vector3(11.0, 0.06, 0.08), "charcoal", yaw)
	for x: float in [-5.3, 0.0, 5.3]:
		add_part(origin, Vector3(upper_x + x, 4.02, 6.75), Vector3(0.07, 1.1, 0.08), "charcoal", yaw)
	# Low garden walls begin behind the sidewalk safety strip; entrance stays open.
	for x: float in [-10.3, 10.3]:
		_ground_part(origin, Vector3(x, 0.48, 1.0), Vector3(0.3, 0.96, 17), "stone", yaw, true)
		_ground_part(origin, Vector3(x, 1.00, 1.0), Vector3(0.8, 0.55, 15.5), "hedge", yaw)
	_ground_part(origin, Vector3(5.8, 0.22, 9.0), Vector3(4.3, 0.44, 1.7), "stone", yaw, true)
	_ground_part(origin, Vector3(5.8, 0.50, 9.0), Vector3(4.0, 0.30, 1.5), "hedge", yaw)
	_domestic_details(origin, yaw, variant, 6.7, true)
	_front_garden(origin, yaw, variant, false)
	_lot_finish(origin, yaw, Vector2(21, 24), variant)
	var tree := origin + Basis(Vector3.UP, yaw) * Vector3(-7.0, 0, 9.0)
	tree.y = Layout.height_at(tree.x, tree.z)
	_garden_tree(tree, 6.5)
	if variant % 3 == 2:
		add_part(origin, Vector3(0, 0.03, -9.0), Vector3(8.5, 0.12, 4.2), "pool", yaw)
		for x: float in [-4.4, 4.4]:
			add_part(origin, Vector3(x, 0.08, -9), Vector3(0.4, 0.15, 4.8), "ivory", yaw)


func _tower(u: float, v: float, yaw: float, floors: int) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 19, 15, yaw)
	var height := 3.1 * floors + 3.6
	var wall: String = ["ivory", "cream", "sage"][floors % 3]
	add_part(origin, Vector3(0, height / 2, 0), Vector3(17, height, 13), wall, yaw, true)
	add_part(origin, Vector3(-6.5, height / 2, 0.08), Vector3(3.7, height, 13.3), "stone", yaw)
	add_part(origin, Vector3(6.5, height / 2, 0.08), Vector3(1.1, height, 13.3), "charcoal", yaw)
	for floor_index in floors:
		var y := 4.8 + floor_index * 3.1
		for side: float in [-1.0, 1.0]:
			for x: float in [-3.0, 2.1]:
				_window(origin, Vector3(x, y, side * 6.61), Vector2(4.1, 2.1), yaw)
			add_part(origin, Vector3(0, y - 1.35, side * 7.0), Vector3(18.3, 0.20, 2.0), "ivory", yaw)
			add_part(origin, Vector3(0, y - 0.79, side * 7.9), Vector3(16.8, 0.95, 0.12), "glass", yaw)
			add_part(origin, Vector3(0, y - 0.27, side * 7.91), Vector3(17.0, 0.06, 0.08), "charcoal", yaw)
			for x: float in [-7.7, -4.0, 0.0, 4.0, 7.7]:
				add_part(origin, Vector3(x, y - 0.8, side * 7.95), Vector3(0.06, 1.05, 0.08), "charcoal", yaw)
		for side: float in [-1.0, 1.0]:
			for z: float in [-3.6, 2.0]:
				_window(origin, Vector3(side * 8.61, y, z), Vector2(2.7, 1.9), yaw, true)
		add_part(origin, Vector3(0, y + 1.1, 0), Vector3(17.3, 0.14, 13.3), "stone", yaw)
	_window(origin, Vector3(1.5, 1.6, 6.65), Vector2(6.3, 2.9), yaw)
	add_part(origin, Vector3(0, 3.15, 8.4), Vector3(18, 0.35, 4.2), "stone", yaw)
	add_part(origin, Vector3(0, height + 0.22, 0), Vector3(18.4, 0.44, 14.4), "ivory", yaw)
	add_part(origin, Vector3(-3, height + 1.0, -2), Vector3(7, 1.6, 7), "charcoal", yaw)
	for x: float in [-6.5, 6.5]:
		add_part(origin, Vector3(x, height + 0.5, 4.5), Vector3(4.1, 0.65, 2), "hedge", yaw)
	_apartment_details(origin, yaw, floors, height)
	_front_garden(origin, yaw, floors, true)
	_lot_finish(origin, yaw, Vector2(21, 23), floors)


func _downtown_palette() -> void:
	var colors := {"downtown_stone": Color("bdb5a3"), "downtown_brick": Color("856451"), "downtown_frame": Color("384750"), "downtown_glass": Color("698d9c"), "downtown_glass_dark": Color("3d606e"), "downtown_window": Color("9faeac"), "downtown_copper": Color("638a81")}
	for key: String in colors:
		var material := StandardMaterial3D.new()
		material.resource_name = key
		material.albedo_color = colors[key]
		material.roughness = 0.32 if "glass" in key else 0.8
		material.metallic = 0.28 if "glass" in key else 0.0
		materials[key] = material
	for entry in [["downtown_stone", "limestone", 0.5], ["downtown_brick", "brickwork", 0.6]]:
		var material: StandardMaterial3D = materials[entry[0]]
		material.albedo_texture = load("res://assets/textures/neighborhood/%s-albedo.res" % entry[1])
		material.normal_texture = load("res://assets/textures/neighborhood/%s-normal.res" % entry[1])
		material.normal_enabled = true
		material.normal_scale = 0.25
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * float(entry[2])


	for key in ["downtown_glass", "downtown_glass_dark"]:
		var material: StandardMaterial3D = materials[key]
		material.albedo_texture = load("res://assets/textures/neighborhood/curtain_wall-albedo.res")
		material.normal_texture = load("res://assets/textures/neighborhood/curtain_wall-normal.res")
		material.normal_enabled = true
		material.normal_scale = 0.18
		material.albedo_color = Color("cfdbdc") if key == "downtown_glass" else Color("9cafb5")
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * (1.0 / 13.2)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _skyscraper(u: float, v: float, yaw: float, seed_value: int) -> void:
	parcel_count += 1
	skyscraper_count += 1
	var variant := seed_value % 6
	var origin := _foundation(u, v, 26, 24, yaw)
	var central := exp(-pow((u - 1090) / 300, 2) - pow(v / 600, 2))
	var floors := 9 + seed_value % 12 + int(central * 17)
	var height := 3.3 * floors
	var stone := "downtown_brick" if variant in [1, 4] else "downtown_stone"
	var facade := "downtown_glass_dark" if variant % 2 == 0 else "downtown_glass"
	add_part(origin, Vector3(0, 3.2, 0), Vector3(25, 6.4, 22), stone, yaw, true)
	add_part(origin, Vector3(0, 6.5, 0), Vector3(26, 0.3, 23), "downtown_frame", yaw)
	# Separate solid setbacks make a skyline rather than tall copies of a house.
	var tiers := 3 if variant in [0, 1, 4] else 2
	var bottom := 6.6
	for tier in tiers:
		var top := 6.6 + height * float(tier + 1) / tiers
		var width := 23.0 - tier * (3.0 if variant < 3 else 1.5)
		var depth := 19.0 - tier * 2.0
		add_part(origin, Vector3(0, (bottom + top) / 2, 0), Vector3(width, top - bottom, depth), facade, yaw, true)
		for side: float in [-1.0, 1.0]:
			for column in 6:
				var x := lerpf(-width / 2, width / 2, float(column) / 5)
				add_part(origin, Vector3(x, (bottom + top) / 2, side * (depth / 2 + 0.05)), Vector3(0.27 if variant % 2 == 0 else 0.6, top - bottom, 0.16), "downtown_frame" if variant % 2 == 0 else stone, yaw)
			for column in 4:
				var z := lerpf(-depth / 2, depth / 2, float(column) / 3)
				add_part(origin, Vector3(side * (width / 2 + 0.05), (bottom + top) / 2, z), Vector3(0.16, top - bottom, 0.4), stone, yaw)
		for floor_index in range(ceili(bottom / 3.3), floori(top / 3.3)):
			var y := floor_index * 3.3
			add_part(origin, Vector3(0, y, 0), Vector3(width + 0.15, 0.18 if variant % 2 == 0 else 0.5, depth + 0.15), "downtown_frame" if variant % 2 == 0 else stone, yaw)
			# Selective occupied windows avoid illuminating the entire glass curtain.
			if (floor_index + seed_value) % 3 == 0:
				for side: float in [-1, 1]:
					add_part(origin, Vector3(width * (0.18 if floor_index % 2 == 0 else -0.18), y + 1.4, side * (depth / 2 + 0.13)), Vector3(2.7, 1.8, 0.06), "downtown_window", yaw)
		add_part(origin, Vector3(0, top + 0.15, 0), Vector3(width + 1, 0.3, depth + 1), stone, yaw)
		bottom = top
	if variant in [1, 4]:
		add_part(origin, Vector3(0, bottom + 3, 0), Vector3(6, 6, 6), "downtown_copper", yaw)
		add_part(origin, Vector3(0, bottom + 9, 0), Vector3(0.65, 12, 0.65), "downtown_copper", yaw)
	else:
		add_part(origin, Vector3(-3, bottom + 1.2, -3), Vector3(6, 2.4, 5), "downtown_frame", yaw)
	for side: float in [-1.0, 1.0]:
		for x: float in [-8, -3, 3, 8]:
			add_part(origin, Vector3(x, 2.7, side * 11.06), Vector3(3.2, 4.2, 0.1), "downtown_glass_dark", yaw)
		add_part(origin, Vector3(0, 4.8, side * 12.3), Vector3(11, 0.3, 3), stone, yaw)
	# Local entrance paving conforms to the hill; no decorative object enters the road.
	_city_shopfront(origin, yaw, seed_value, 11.1, 21.0)
	var entrance := origin + Basis(Vector3.UP, yaw) * Vector3(0, 0, 14)
	_projected_patch("TowerEntrance", entrance, Vector2(15, 5), "paving", 0.035)


func _neighborhood_shop(u: float, v: float, id: int) -> void:
	if id % 3 != 0 or id == Layout.WORKSHOP_BLOCK:
		return
	var lot := _safe_site(Vector2(u, v), Vector2(u, v), 0.0, Vector2(30, 24))
	if not lot.is_finite():
		return
	parcel_count += 1
	var origin := _foundation(lot.x, lot.y, 24, 16, 0)
	var wall: String = ["cream", "rose", "sage", "stone"][id % 4]
	add_part(origin, Vector3(0, 4, 0), Vector3(23, 8, 15), wall, 0, true)
	add_part(origin, Vector3(0, 8.2, 0), Vector3(24, 0.4, 16), "charcoal", 0)
	for x: float in [-8, -3, 3, 8]:
		_window(origin, Vector3(x, 2, 7.6), Vector2(3.7, 3.1), 0, false, true)
		_window(origin, Vector3(x, 6, 7.6), Vector2(2.8, 1.9), 0)
	add_part(origin, Vector3(0, 3.9, 9), Vector3(24, 0.3, 3.5), "terracotta" if id % 2 else "sage", 0)
	# Fabric valance, striped awning, open-air tables and planter pots animate the frontage.
	for stripe in 24:
		add_part(origin, Vector3(-11.5 + stripe, 4.07, 9), Vector3(0.46, 0.04, 3.4), "ivory", 0)
	add_part(origin, Vector3(0, 3.65, 10.7), Vector3(24, 0.35, 0.08), "terracotta" if id % 2 else "sage", 0)
	for side: float in [-1, 1]:
		var terrace := origin + Vector3(side * 9, 0, 10.0)
		terrace.y = Layout.height_at(terrace.x, terrace.z) + 0.045
		add_part(terrace, Vector3(0, 0.75, 0), Vector3(1.0, 0.07, 0.7), "timber", 0)
		add_part(terrace, Vector3(0, 0.36, 0), Vector3(0.07, 0.72, 0.07), "charcoal", 0)
		for x: float in [-0.78, 0.78]:
			add_part(terrace, Vector3(x, 0.45, 0), Vector3(0.42, 0.05, 0.42), "timber", 0)
			for z: float in [-0.16, 0.16]:
				add_part(terrace, Vector3(x, 0.22, z), Vector3(0.04, 0.44, 0.04), "charcoal", 0)
			add_part(terrace, Vector3(x, 0.67, -0.19), Vector3(0.42, 0.43, 0.035), "timber", 0)
	add_label(["PADARIA AURORA", "MERCADO DA VILA", "CAFÉ DA ESQUINA", "OFICINA DE BICICLETAS"][id % 4], origin + Vector3(0, 4.6, 7.65), 0, 0.014)
	_projected_patch("ShopForecourt", origin + Vector3(0, 0, 9.5), Vector2(28, 7), "paving", 0.035)


func _district_landmarks() -> void:
	for entry in [{"uv": Vector2(-700, 19), "text": "JARDINS DO VALE"}, {"uv": Vector2(130, 19), "text": "VILA AURORA"}, {"uv": Vector2(1000, 19), "text": "CENTRO HORIZONTE"}]:
		var site := _safe_site(Vector2(entry.uv.x, entry.uv.y + 45), Vector2(entry.uv.x, entry.uv.y + 75), 0, Vector2(11, 3))
		if not site.is_finite():
			continue
		var origin := Layout.position(site.x, site.y)
		add_box(origin + Vector3.UP * 1.2, Vector3(10, 2.4, 0.7), "stone", true)
		add_label(entry.text, origin + Vector3(0, 1.45, 0.4), 0, 0.018)
	# A planted civic sculpture provides a visible destination by the central park.
	var uv := Layout.block_uv(97)
	var origin := _foundation(uv.x, uv.y + 5, 7, 7, 0)
	add_part(origin, Vector3(0, 1, 0), Vector3(6, 2, 6), "stone", 0, true)
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * 1.6, 6, 0), Vector3(1, 10, 1.5), "downtown_copper", side * 0.3, true)
	add_label("PARQUE HORIZONTE", origin + Vector3(0, 2.5, 3.1), 0, 0.014)


func _service(u: float, v: float) -> void:
	var site := Layout.position(u, v)
	_register_parcel({"center": Vector2(site.x, site.z), "yaw": PI / 2, "size": Vector2(22, 28), "kind": "workshop"})
	parcel_count += 1
	var origin := _foundation(u, v, 20, 13, PI / 2)
	add_part(origin, Vector3(0, 2.3, 0), Vector3(19, 4.6, 12), "stone", PI / 2, true)
	for x: float in [-5.5, 0.0, 5.5]:
		_window(origin, Vector3(x, 2.0, 6.1), Vector2(4.7, 3.4), PI / 2)
	add_part(origin, Vector3(0, 4.4, 7), Vector3(21, 0.28, 4), "charcoal", PI / 2)
	add_part(origin, Vector3(0, 3.7, 6.25), Vector3(11, 0.85, 0.14), "blue", PI / 2)
	add_label("OFICINA ALVORADA", origin + Basis(Vector3.UP, PI / 2) * Vector3(0, 3.7, 6.35), PI / 2, 0.009)
	for side: float in [-1.0, 1.0]:
		add_part(origin, Vector3(side * 9, 2.0, 8.5), Vector3(0.15, 4, 0.15), "charcoal", PI / 2, true)


func _front_garden(origin: Vector3, yaw: float, variant: int, tower: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var entrance := origin + basis * Vector3(0, 0, 10.4)
	var nearest := Vector3.ZERO
	var distance := INF
	var road_width := 10.0
	for sample in _nearby_street_points(entrance):
		var p: Vector3 = sample.position
		var delta := p.distance_squared_to(entrance)
		if delta < distance:
			distance = delta
			nearest = p
			road_width = sample.width
	var direction := (nearest - entrance).normalized()
	var end := nearest - direction * (road_width / 2 + 0.4)
	var start := origin + basis * Vector3(0, 0, 6.8)
	_add_driveway(start, end, 2.1)
	# All new solid details stay inside the lot envelope checked by _safe_site.
	for side: float in [-1, 1]:
		_ground_part(origin, Vector3(side * 7.2, 0.48, 10.2), Vector3(5.5, 0.95, 0.25), "stone", yaw)
		for slat in 14:
			_ground_part(origin, Vector3(side * 7.2 - 2.5 + slat * 0.38, 1.02, 10.2), Vector3(0.05, 0.92, 0.07), "charcoal", yaw)
		_ground_part(origin, Vector3(side * 4.3, 1.0, 10.2), Vector3(0.38, 2.0, 0.38), "stone", yaw)
		_ground_part(origin, Vector3(side * 4.3, 1.65, 10.42), Vector3(0.18, 0.28, 0.06), "light", yaw, false)
	var address := origin + basis * Vector3(4.31, 1.02, 10.43)
	_address(str(140 + variant * 12 + int(absf(origin.x)) % 20), address, yaw)
	_ground_part(origin, Vector3(-4.3, 0.94, 10.48), Vector3(0.29, 0.18, 0.16), "charcoal", yaw)
	_ground_part(origin, Vector3(-4.3, 0.98, 10.57), Vector3(0.19, 0.022, 0.015), "metal", yaw)
	if not tower:
		for z: float in [-3.4, -1.4, 0.6]:
			add_part(origin, Vector3(8.14, 2.6, z), Vector3(0.26, 0.42, 0.78), "ivory", yaw)
			for rib in 5:
				add_part(origin, Vector3(8.29, 2.43 + rib * 0.072, z), Vector3(0.03, 0.025, 0.64), "charcoal", yaw)
		for side: float in [-1, 1]:
			_ground_part(origin, Vector3(side * 5.5, 0.32, 8.6), Vector3(0.75, 0.64, 0.75), "stone", yaw)
			var plant := origin + basis * Vector3(side * 5.5, 0, 8.6)
			plant.y = Layout.height_at(plant.x, plant.z) + 0.88
			add_instance("shrub", "tree_leaves", plant, Vector3(0.62, 0.6, 0.62), yaw)


func _outer_frontages() -> void:
	# Complete the opposite side of the existing streets without adding blocks.
	var frontages: Array[Dictionary] = []
	for row in [0, Layout.ROW_COUNT - 1]:
		for column in Layout.COLUMN_COUNT - 1:
			frontages.append({"a": row * Layout.COLUMN_COUNT + column, "b": row * Layout.COLUMN_COUNT + column + 1, "side": -1.0 if row == 0 else 1.0})
	for column in [0, Layout.COLUMN_COUNT - 1]:
		for row in Layout.ROW_COUNT - 1:
			frontages.append({"a": row * Layout.COLUMN_COUNT + column, "b": (row + 1) * Layout.COLUMN_COUNT + column, "side": 1.0 if column == 0 else -1.0})
	for frontage in frontages:
		var length := Layout.logical_node(frontage.a).distance_to(Layout.logical_node(frontage.b))
		var count := maxi(3, floori((length - 44) / 19.5))
		for step in count:
			var t := lerpf(24.0 / length, 1.0 - 24.0 / length, float(step) / (count - 1))
			var uv := Layout.street_uv(frontage.a, frontage.b, t)
			var tangent := (Layout.street_uv(frontage.a, frontage.b, t + 0.001) - Layout.street_uv(frontage.a, frontage.b, t - 0.001)).normalized()
			var outward := Vector2(-tangent.y, tangent.x) * float(frontage.side)
			var lot := uv + outward * (25.0 + 2.0 * sin(frontage.a + step * 2.4))
			var forward := Layout.position(uv.x + tangent.x, uv.y + tangent.y) - Layout.position(uv.x, uv.y)
			var yaw := atan2(-forward.z, forward.x) + (PI if float(frontage.side) > 0 else 0.0)
			lot = _safe_site(lot, lot + outward * 12, yaw, Vector2(15.5, 18.5))
			if not lot.is_finite():
				continue
			_cottage(lot.x, lot.y, yaw, (frontage.a + step) % 5)


func _local_shop(u: float, v: float, yaw: float, variant: int) -> void:
	_cottage(u, v, yaw, variant % 5, true)


func _cottage(u: float, v: float, yaw: float, variant: int, commercial: bool = false) -> void:
	parcel_count += 1
	var origin := _foundation(u, v, 12.0, 9.0, yaw)
	var wall: String = ["ivory", "sage", "cream", "stone", "rose"][variant]
	var height := 3.4 if variant % 2 == 0 else 6.4
	add_part(origin, Vector3(0, height / 2, 0), Vector3(11.5, height, 8.5), wall, yaw, true)
	add_part(origin, Vector3(0, height + 0.09, 0), Vector3(12.4, 0.18, 9.3), "ivory", yaw)
	if variant in [1, 2, 4]:
		add_part(origin, Vector3(0, height + 0.95, 0), Vector3(12.2, 1.8, 9.1), "roof", yaw, false, "roof")
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 6.05, height + 0.05, 0), Vector3(0.12, 0.12, 9.2), "charcoal", yaw)
	else:
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 5.9, height + 0.38, 0), Vector3(0.22, 0.6, 9.2), wall, yaw)
		add_part(origin, Vector3(0, height + 0.8, -2), Vector3(2.5, 1.4, 2.5), "stone", yaw)
	for floor_index in (2 if height > 4 else 1):
		for x: float in [-3.4, 1.2]:
			_window(origin, Vector3(x, 1.75 + floor_index * 3, 4.34), Vector2(2.4, 1.55), yaw)
			add_part(origin, Vector3(x, 0.89 + floor_index * 3, 4.48), Vector3(2.65, 0.1, 0.35), "stone", yaw)
		for side: float in [-1, 1]:
			_window(origin, Vector3(side * 5.84, 1.8 + floor_index * 3, -1.0), Vector2(2.1, 1.5), yaw, true)
	add_part(origin, Vector3(4.0, 1.4, 4.37), Vector3(1.2, 2.8, 0.18), "timber", yaw)
	add_part(origin, Vector3(4.0, 2.9, 5.0), Vector3(2.5, 0.16, 1.8), "charcoal", yaw)
	for side: float in [-1, 1]:
		_ground_part(origin, Vector3(side * 7.2, 0.55, 0), Vector3(0.25, 1.1, 17.5), "stone", yaw, true)
		_ground_part(origin, Vector3(side * 4.6, 0.5, 8.4), Vector3(4.4, 1.0, 0.25), wall, yaw, true)
		_ground_part(origin, Vector3(side * 2.4, 0.85, 8.4), Vector3(0.34, 1.7, 0.34), "stone", yaw)
	_address(str(200 + parcel_count * 2), origin + Basis(Vector3.UP, yaw) * Vector3(2.42, 1.0, 8.6), yaw)
	# A separate approach follows the same exact terrain as the larger homes.
	var entrance := origin + Basis(Vector3.UP, yaw) * Vector3(0, 0, 4.6)
	var closest := Vector3.ZERO
	var nearest := INF
	var width := 12.0
	for sample in _nearby_street_points(entrance):
		var point: Vector3 = sample.position
		if entrance.distance_squared_to(point) < nearest:
			nearest = entrance.distance_squared_to(point)
			closest = point
			width = sample.width
	var end := closest + (entrance - closest).normalized() * (width / 2 + 0.5)
	_add_driveway(entrance, end, 1.8)
	_lot_finish(origin, yaw, Vector2(14, 18), variant)
	_cottage_details(origin, yaw, variant, height, wall)
	if commercial:
		_city_shopfront(origin, yaw, variant, 4.36, 10.7)
	else:
		_domestic_details(origin, yaw, variant, height, false)
	var tree := origin + Basis(Vector3.UP, yaw) * Vector3(-5, 0, 6.3)
	tree.y = Layout.height_at(tree.x, tree.z)
	_garden_tree(tree, 5.8 + variant * 0.3)


func _side_frontages(row: int, column: int, id: int) -> void:
	var centre := Layout.block_uv(id)
	for side: float in [-1, 1]:
		var a := row * Layout.COLUMN_COUNT + column + (1 if side > 0 else 0)
		_populate_frontage(a, a + Layout.COLUMN_COUNT, side, centre, id, true)


func _populate_frontage(a: int, b: int, inward_sign: float, _centre: Vector2, id: int, lateral: bool) -> void:
	var district := Layout.district(id)
	var length := Layout.logical_node(a).distance_to(Layout.logical_node(b))
	# Cadence is measured in metres, with a protected corner and a shallow setback.
	# Houses frame the street instead of sitting in the middle of a broad lawn.
	var spacing := 33.0 if district == 2 else (24.0 if district == 0 else 19.5)
	var count := maxi(2, floori((length - 40.0) / spacing))
	for step in count:
		var along := lerpf(23.0, length - 23.0, float(step) / maxi(count - 1, 1))
		var t := along / length
		var uv := Layout.street_uv(a, b, t)
		var tangent := (Layout.street_uv(a, b, t + 0.001) - Layout.street_uv(a, b, t - 0.001)).normalized()
		var inward := Vector2(-tangent.y, tangent.x) * inward_sign
		var forward := Layout.position(uv.x + tangent.x, uv.y + tangent.y) - Layout.position(uv.x, uv.y)
		var yaw := atan2(-forward.z, forward.x) + (PI if inward_sign > 0 else 0.0)
		var seed_value := id * 17 + step * 7 + (3 if inward_sign > 0 else 0) + (5 if lateral else 0)
		var highrise := district == 2 and (not lateral or seed_value % 3 != 2)
		var block_column := id % (Layout.COLUMN_COUNT - 1)
		var block_width: float = Layout.COLUMNS[block_column + 1] - Layout.COLUMNS[block_column]
		var compact := highrise and (lateral or block_width < 100.0)
		var tower := district == 2 or (district == 1 and seed_value % 7 == 0) or (district == 0 and seed_value % 17 == 0)
		var villa := district == 0 and not tower
		var footprint := Vector2(15.5, 18.5)
		if highrise and not compact:
			footprint = Vector2(30, 34)
		elif tower:
			footprint = Vector2(23, 24) if district == 2 else Vector2(23, 27)
		elif villa:
			footprint = Vector2(21.5, 24)
		var width := 22.0 if a / Layout.COLUMN_COUNT == b / Layout.COLUMN_COUNT and a / Layout.COLUMN_COUNT in [4, 5, 8] else (24.0 if a % Layout.COLUMN_COUNT in [6, 13, 16, 19] and lateral else (16.0 if district == 2 else 12.0))
		var lot := uv + inward * (width / 2 + 6.2 + footprint.y / 2)
		lot = _safe_site(lot, lot + inward * 24, yaw, footprint)
		if not lot.is_finite():
			continue
		if compact:
			# Slender residential high-rises fit the smaller Brazilian centre blocks.
			_tower(lot.x, lot.y, yaw, 13 + seed_value % 10)
			skyscraper_count += 1
		elif highrise:
			_skyscraper(lot.x, lot.y, yaw, seed_value)
		elif tower:
			_tower(lot.x, lot.y, yaw, 3 + seed_value % 5)
		elif villa:
			_villa(lot.x, lot.y, yaw, seed_value % 9)
		elif seed_value % 4 == 0:
			_local_shop(lot.x, lot.y, yaw, seed_value)
		else:
			_cottage(lot.x, lot.y, yaw, seed_value % 5)


func _compact_commerce(row: int, column: int, id: int, remaining: int) -> void:
	# Small shop lots complete irregular corners where a full tower cannot fit.
	# Each one goes through the same road clearance and parcel overlap checks.
	if remaining == 0:
		return
	var south := row * Layout.COLUMN_COUNT + column
	var north := south + Layout.COLUMN_COUNT
	var frontages := [{"a": south, "b": south + 1, "side": 1.0}, {"a": north, "b": north + 1, "side": -1.0}, {"a": south, "b": north, "side": -1.0}, {"a": south + 1, "b": north + 1, "side": 1.0}]
	for edge in frontages:
		var horizontal: bool = edge.b - edge.a == 1
		var width := 22.0 if horizontal and int(edge.a) / Layout.COLUMN_COUNT in [4, 5, 8] else (24.0 if not horizontal and int(edge.a) % Layout.COLUMN_COUNT in [13, 16, 19] else 16.0)
		for step in 9:
			var t := 0.12 + step * 0.095
			var uv := Layout.street_uv(edge.a, edge.b, t)
			var tangent := (Layout.street_uv(edge.a, edge.b, t + 0.001) - Layout.street_uv(edge.a, edge.b, t - 0.001)).normalized()
			var inward := Vector2(-tangent.y, tangent.x) * float(edge.side)
			var forward := Layout.position(uv.x + tangent.x, uv.y + tangent.y) - Layout.position(uv.x, uv.y)
			var yaw := atan2(-forward.z, forward.x) + (PI if edge.side > 0 else 0.0)
			var lot := uv + inward * (width / 2 + 6.2 + 9.25)
			lot = _safe_site(lot, lot + inward * 16, yaw, Vector2(15.5, 18.5))
			if not lot.is_finite():
				continue
			_local_shop(lot.x, lot.y, yaw, id * 5 + step)
			remaining -= 1
			if remaining == 0:
				return


func _cottage_details(origin: Vector3, yaw: float, variant: int, height: float, wall: String) -> void:
	# Domestic details remain within the already validated lot envelope.
	for side: float in [-1, 1]:
		add_part(origin, Vector3(side * 5.67, height / 2, 4.20), Vector3(0.12, height, 0.13), "ivory", yaw)
		add_part(origin, Vector3(side * 5.87, height / 2, -4.22), Vector3(0.085, height, 0.085), "charcoal", yaw)
		add_part(origin, Vector3(side * 4.60, 1.07, 8.4), Vector3(4.5, 0.07, 0.39), "stone", yaw)
		# Mailbox and utility cabinet are anchored to the front wall, clear of the entry.
		_ground_part(origin, Vector3(side * 3.2, 0.69, 8.57), Vector3(0.35, 0.37, 0.09), "charcoal" if side < 0 else "ivory", yaw)
		_ground_part(origin, Vector3(side * 3.2, 0.78, 8.63), Vector3(0.23, 0.025, 0.018), "metal", yaw)
	# Entry hardware and threshold make the door read at human scale.
	add_part(origin, Vector3(3.65, 1.35, 4.49), Vector3(0.03, 0.26, 0.045), "metal", yaw)
	add_part(origin, Vector3(4.0, 0.09, 4.6), Vector3(1.45, 0.12, 0.6), "stone", yaw)
	add_part(origin, Vector3(5.05, 2.23, 4.43), Vector3(0.18, 0.29, 0.11), "charcoal", yaw)
	add_part(origin, Vector3(5.05, 2.23, 4.50), Vector3(0.12, 0.18, 0.035), "light", yaw)
	for floor_index in (2 if height > 4 else 1):
		for x: float in [-3.4, 1.2]:
			if variant % 2 == 0:
				for side: float in [-1, 1]:
					add_part(origin, Vector3(x + side * 1.40, 1.75 + floor_index * 3, 4.43), Vector3(0.34, 1.65, 0.12), "timber", yaw)
					for rib in 7:
						add_part(origin, Vector3(x + side * 1.40, 1.12 + floor_index * 3 + rib * 0.20, 4.51), Vector3(0.34, 0.045, 0.025), "charcoal", yaw)
			if (variant + floor_index) % 3 == 0:
				add_part(origin, Vector3(x, 0.73 + floor_index * 3, 4.54), Vector3(2.0, 0.27, 0.34), "terracotta", yaw)
				for plant in 3:
					var position := origin + Basis(Vector3.UP, yaw) * Vector3(x - 0.6 + plant * 0.6, 0.97 + floor_index * 3, 4.57)
					add_instance("shrub", "tree_leaves", position, Vector3(0.24, 0.20, 0.23))
	if variant in [1, 2, 4]:
		# Rain gutters follow the eaves; a modest chimney breaks the tiled roof silhouette.
		for side: float in [-1, 1]:
			add_part(origin, Vector3(side * 6.06, height + 0.02, 0), Vector3(0.14, 0.10, 9.25), "charcoal", yaw)
		add_part(origin, Vector3(-3.4, height + 1.25, -2.4), Vector3(0.65, 1.45, 0.65), wall, yaw)
		add_part(origin, Vector3(-3.4, height + 1.98, -2.4), Vector3(0.83, 0.10, 0.83), "charcoal", yaw)
