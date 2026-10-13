extends "res://scripts/city/pilot_city_scenery.gd"

# Authored neighbourhood composition, built offline into the existing city.
# Every new solid is either inside a checked parcel or beyond the sidewalk.

func _window(origin: Vector3, offset: Vector3, size: Vector2, yaw: float, side: bool = false, commercial: bool = false) -> void:
	# Opaque inset glazing avoids transparent facade sorting and fill-rate cost.
	var extent := Vector3(0.16, size.y + 0.22, size.x + 0.22) if side else Vector3(size.x + 0.22, size.y + 0.22, 0.16)
	add_part(origin, offset, extent, "charcoal", yaw)
	var seed_value := absi(roundi(origin.x * 3 + origin.z * 7 + offset.x * 11 + offset.y * 17))
	var pane_material := "commercial_glass" if commercial else ("residential_glass_lit" if seed_value % 4 == 0 else "residential_glass")
	var outward := Vector3(signf(offset.x), 0, 0) if side else Vector3(0, 0, signf(offset.z))
	var pane_yaw := yaw + (signf(offset.x) * PI / 2 if side else (PI if offset.z < 0 else 0.0))
	var pane_origin := origin + Basis(Vector3.UP, yaw) * (offset + outward * 0.095)
	# A dedicated quad maps the complete interior image; cube atlases crop it.
	add_instance("window_pane", pane_material, pane_origin, Vector3(size.x, size.y, 1), pane_yaw)
	if not side:
		add_part(origin, offset + outward * 0.11, Vector3(0.065, size.y, 0.04), "charcoal", yaw)
		add_part(origin, offset + Vector3(0, size.y * 0.30, outward.z * 0.12), Vector3(size.x, 0.04, 0.03), "ivory", yaw)
		add_part(origin, offset + Vector3(0, -size.y / 2 - 0.08, outward.z * 0.06), Vector3(size.x + 0.26, 0.085, 0.30), "stone", yaw)
	else:
		var sign_value := signf(offset.x)
		add_part(origin, offset + Vector3(sign_value * 0.10, 0, 0), Vector3(0.04, size.y, 0.065), "charcoal", yaw)
		add_part(origin, offset + Vector3(sign_value * 0.05, -size.y / 2 - 0.08, 0), Vector3(0.30, 0.085, size.x + 0.26), "stone", yaw)


func _detail_palette() -> void:
	for entry in [["oxidized_metal", "737e79", 0.83], ["court_paint", "757d68", 0.97], ["court_red", "a27863", 0.97], ["sign_green", "345a53", 0.76], ["sign_red", "964e40", 0.85], ["aged_plaster", "bab29f", 0.96], ["water_tank", "667a86", 0.85]]:
		var material := StandardMaterial3D.new()
		material.resource_name = entry[0]
		material.albedo_color = Color(entry[1])
		material.roughness = entry[2]
		materials[entry[0]] = material
	for key in ["aged_plaster", "court_paint", "court_red"]:
		var material: StandardMaterial3D = materials[key]
		material.albedo_texture = load("res://assets/textures/neighborhood/stucco-albedo.res")
		material.normal_texture = load("res://assets/textures/neighborhood/stucco-normal.res")
		material.normal_enabled = true
		material.normal_scale = 0.18
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.8


func _detail_segment(a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var delta := b - a
	if delta.length_squared() < 0.00001:
		return
	var centre := (a + b) / 2
	var sector_width := float(batch_sizes.get(material, batch_size))
	var key := "cylinder:%s:true:%d:%d" % [material, floori(centre.x / sector_width), floori(centre.z / sector_width)]
	if not _batches.has(key):
		_batches[key] = []
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.from_scale(Vector3(radius, delta.length(), radius))
	_batches[key].append(Transform3D(basis, centre))


func _domestic_details(origin: Vector3, yaw: float, variant: int, roof_height: float, premium: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var wall_width := 20.6 if premium else 14.4
	var back := -11.5 if premium else -8.8
	_ground_part(origin, Vector3(0, 0.65, back), Vector3(wall_width, 1.3, 0.20), "aged_plaster", yaw, true)
	for floor_index in (2 if premium or roof_height > 4 else 1):
		var upper_x: float = [-3.0, 3.0, 0.0][variant % 3] if premium and floor_index == 1 else 0.0
		var y := (1.65 + floor_index * 3.25) if premium else (1.75 + floor_index * 3.0)
		for x: float in [-3.0, 2.4]:
			_window(origin, Vector3(upper_x + x, y, -5.85 if premium and floor_index == 1 else (-6.1 if premium else -4.34)), Vector2(2.1, 1.5), yaw)
	var fence_z := 10.2 if premium else 8.4
	# A sliding gate stored to one side keeps the existing driveway open.
	var gate_x := -7.0 if premium else -4.6
	_ground_part(origin, Vector3(gate_x, 0.9, fence_z + 0.10), Vector3(4.3, 1.45, 0.13), "charcoal", yaw)
	for rib in 12:
		_ground_part(origin, Vector3(gate_x - 1.95 + rib * 0.35, 0.91, fence_z + 0.18), Vector3(0.10, 1.35, 0.03), "oxidized_metal", yaw)
	if not premium or variant % 3 == 0:
		var tank := origin + basis * Vector3(2.0, roof_height + (1.9 if variant in [1, 2, 4] and not premium else 0.5), -2.5)
		add_instance("cylinder", "water_tank", tank, Vector3(0.72, 0.92, 0.72), yaw)
		add_instance("cylinder", "charcoal", tank + Vector3.UP * 0.49, Vector3(0.79, 0.07, 0.79), yaw)
		add_part(tank, Vector3(0, -0.55, 0), Vector3(1.6, 0.22, 1.6), "aged_plaster", yaw)
	# Rooftop aerial with a recognisable horizontal silhouette.
	var antenna := origin + basis * Vector3(-3.5, roof_height + 2.2, -2.0)
	add_part(antenna, Vector3(0, -0.8, 0), Vector3(0.035, 2.4, 0.035), "oxidized_metal", yaw)
	add_part(antenna, Vector3(0, 0.35, 0), Vector3(1.65, 0.025, 0.025), "oxidized_metal", yaw)
	for rib in 5:
		add_part(antenna, Vector3(-0.68 + rib * 0.34, 0.35, 0), Vector3(0.018, 0.018, 0.42 + rib * 0.08), "oxidized_metal", yaw)
	# Side-yard laundry, a grill and pots suggest inhabited homes.
	if variant % 3 == 1:
		var clothes := origin + basis * Vector3(0, 0, -7.0 if not premium else -9.8)
		clothes.y = Layout.height_at(clothes.x, clothes.z)
		for x: float in [-3, 3]:
			add_part(clothes, Vector3(x, 1.15, 0), Vector3(0.055, 2.3, 0.055), "oxidized_metal", yaw)
		add_part(clothes, Vector3(0, 2.2, 0), Vector3(6, 0.025, 0.025), "charcoal", yaw)
		for sheet in 4:
			add_part(clothes, Vector3(-2.2 + sheet * 1.35, 1.62, 0), Vector3(0.8, 1.1, 0.02), "ivory" if sheet % 2 == 0 else "blue", yaw)
	for side: float in [-1, 1]:
		var pot := origin + basis * Vector3(side * (5.4 if not premium else 7.8), 0, 5.6 if not premium else 8.0)
		pot.y = Layout.height_at(pot.x, pot.z)
		add_instance("cylinder", "terracotta", pot + Vector3.UP * 0.25, Vector3(0.27, 0.5, 0.27))
		add_instance("tree_leaves2", "tree_leaves", pot + Vector3(0, 0.15, 0), Vector3(1.35, 1.05, 1.35), yaw)


func _apartment_details(origin: Vector3, yaw: float, floors: int, height: float) -> void:
	for floor_index in floors:
		var y := 4.8 + floor_index * 3.1
		for side: float in [-1, 1]:
			var ac := Vector3(side * 8.70, y - 0.25, -3.6)
			add_part(origin, ac, Vector3(0.40, 0.55, 0.95), "ivory", yaw)
			for rib in 5:
				add_part(origin, ac + Vector3(side * 0.22, -0.20 + rib * 0.10, 0), Vector3(0.035, 0.035, 0.78), "charcoal", yaw)
			var plant := origin + Basis(Vector3.UP, yaw) * Vector3(-5.0 + floor_index % 2 * 10.0, y - 1.08, side * 7.3)
			add_instance("cylinder", "terracotta", plant, Vector3(0.22, 0.36, 0.22), yaw)
			add_instance("tree_leaves2", "tree_leaves", plant - Vector3.UP * 0.05, Vector3(1.0, 0.8, 1.0), yaw)
	add_part(origin, Vector3(3, height + 0.9, -3), Vector3(3.5, 1.4, 3.5), "water_tank", yaw)
	_city_shopfront(origin, yaw, floors, 6.66, 15.5)


func _city_shopfront(origin: Vector3, yaw: float, variant: int, front: float, width: float) -> void:
	composition_counts["shops"] += 1
	var names := ["PADARIA DO VALE", "MERCEARIA AURORA", "CAFÉ & PÃO", "FARMÁCIA HORIZONTE", "FLORICULTURA IPÊ", "BARBEARIA DA VILA", "LIVRARIA DA PRAÇA", "MERCADO BOM DIA"]
	var trim := "sign_green" if variant % 3 else "terracotta"
	var window_width := width / 3.0 - 0.4
	for x: float in [-width / 3, 0, width / 3]:
		_window(origin, Vector3(x, 1.65, front + 0.12), Vector2(window_width, 2.65), yaw, false, true)
	add_part(origin, Vector3(0, 3.20, front + 0.12), Vector3(width, 0.70, 0.13), trim, yaw)
	add_label(names[posmod(variant, names.size())], origin + Basis(Vector3.UP, yaw) * Vector3(0, 3.2, front + 0.21), yaw, 0.008 if width < 17 else 0.010)
	add_part(origin, Vector3(0, 2.82, front + 0.70), Vector3(width + 0.3, 0.14, 1.6), trim, yaw)
	for stripe in ceili(width / 0.85):
		add_part(origin, Vector3(-width / 2 + 0.3 + stripe * 0.85, 2.9, front + 0.70), Vector3(0.22, 0.025, 1.55), "ivory", yaw)
	add_part(origin, Vector3(0, 2.69, front + 1.44), Vector3(width + 0.2, 0.24, 0.04), trim, yaw)


func _street_canopy() -> void:
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		var length := points[0].distance_to(points[-1])
		var count := maxi(2, floori(length / 24.0))
		var utility_sites: Array[Vector3] = []
		for step in count:
			var t := (step + 0.5) / float(count)
			var index := clampi(roundi(t * (points.size() - 1)), 2, points.size() - 3)
			var tangent := (points[index + 1] - points[index - 1]).normalized()
			var normal := tangent.cross(Vector3.UP).normalized()
			var yaw := atan2(-tangent.z, tangent.x)
			for side: float in [-1, 1]:
				var site := points[index] + normal * side * (float(edge.width) / 2 + 4.6)
				site.y = Layout.height_at(site.x, site.z)
				if _parcel_overlaps(site, 0, Vector2(2.4, 2.4)) or _road_distance(Vector2(site.x, site.z)) < 3.6 or _ramp_factor(Vector2(site.x, site.z)) < 0.98:
					continue
				_garden_tree(site, 7.0 + posmod(int(edge.a) + step * 3 + int(side), 5) * 0.7)
				composition_counts["street_trees"] += 1
				_projected_patch("TreeBed", site, Vector2(1.7, 1.7), "garden_soil", 0.016)
				for bush in 3:
					var plant := site + normal * side * 0.6 + tangent * (-0.5 + bush * 0.5)
					plant.y = Layout.height_at(plant.x, plant.z)
					add_instance("tree_leaves2", "tree_leaves", plant - Vector3.UP * 0.12, Vector3(1.5, 0.85, 1.5), yaw)
				if side < 0 and step % 2 == 0 and int(edge.a) % 3 == 0:
					var pole := site + tangent * 3.0
					pole.y = Layout.height_at(pole.x, pole.z)
					if not _parcel_overlaps(pole, 0, Vector2(1, 1)) and _ramp_factor(Vector2(pole.x, pole.z)) > 0.98:
						_utility_pole(pole, yaw)
						utility_sites.append(pole + Vector3.UP * 8.1)
			if step == 0:
				_street_identity(points[index], normal, yaw, edge)
		for index in utility_sites.size() - 1:
			var direction := utility_sites[index + 1] - utility_sites[index]
			var wire_yaw := atan2(-direction.z, direction.x)
			for wire in 3:
				var a := utility_sites[index] + normal_offset(wire_yaw, -0.5 + wire * 0.5)
				var b := utility_sites[index + 1] + normal_offset(wire_yaw, -0.5 + wire * 0.5)
				for segment in 8:
					var t0 := segment / 8.0
					var t1 := (segment + 1) / 8.0
					_detail_segment(a.lerp(b, t0) - Vector3.UP * sin(PI * t0) * 0.65, a.lerp(b, t1) - Vector3.UP * sin(PI * t1) * 0.65, 0.012, "charcoal")


func normal_offset(yaw: float, offset: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(0, 0, offset)


func _utility_pole(origin: Vector3, yaw: float) -> void:
	composition_counts["utility_poles"] += 1
	add_instance("cylinder", "aged_plaster", origin + Vector3.UP * 4.2, Vector3(0.16, 8.4, 0.16), yaw)
	add_collision(origin + Vector3.UP * 1.2, Vector3(0.32, 2.4, 0.32))
	add_part(origin, Vector3(0, 8.0, 0), Vector3(0.12, 0.13, 1.8), "oxidized_metal", yaw)
	for z: float in [-0.5, 0, 0.5]:
		add_part(origin, Vector3(0, 8.14, z), Vector3(0.14, 0.19, 0.14), "ivory", yaw)
	add_part(origin, Vector3(0.20, 5.8, 0), Vector3(0.38, 0.6, 0.42), "oxidized_metal", yaw)
	for rung in 4:
		add_part(origin, Vector3(0.18, 4.0 + rung * 0.4, 0), Vector3(0.12, 0.045, 0.30), "charcoal", yaw)


func _street_identity(point: Vector3, normal: Vector3, yaw: float, edge: Dictionary) -> void:
	var site := point + normal * (float(edge.width) / 2 + 3.9)
	site.y = Layout.height_at(site.x, site.z)
	if _parcel_overlaps(site, 0, Vector2(2, 2)) or _road_distance(Vector2(site.x, site.z)) < 3.3 or _ramp_factor(Vector2(site.x, site.z)) < 0.98:
		return
	add_part(site, Vector3(0, 1.7, 0), Vector3(0.06, 3.4, 0.06), "oxidized_metal", yaw)
	add_part(site, Vector3(0, 3.0, 0), Vector3(1.65, 0.32, 0.045), "sign_green", yaw)
	var names := ["RUA DOS IPÊS", "RUA DAS ACÁCIAS", "ALAMEDA DO VALE", "RUA AURORA", "RUA DOS CEDROS", "AV. HORIZONTE", "RUA DAS PALMEIRAS"]
	add_label(names[int(edge.a) % names.size()], site + Basis(Vector3.UP, yaw) * Vector3(0, 3.0, 0.045), yaw, 0.0017)
	if int(edge.a) % 4 == 0:
		# A worn community notice board, set behind the pedestrian strip.
		add_part(site, Vector3(1.0, 1.45, 0.2), Vector3(0.85, 1.3, 0.08), "timber", yaw)
		for poster in 3:
			add_part(site, Vector3(0.77 + poster % 2 * 0.42, 1.6 - poster / 2 * 0.55, 0.255), Vector3(0.34, 0.43, 0.02), "ivory" if poster % 2 == 0 else "cream", yaw)
		add_label("FEIRA DO BAIRRO", site + Basis(Vector3.UP, yaw) * Vector3(1, 2.18, 0.25), yaw, 0.0018)


func _park_amenities(u: float, v: float, id: int) -> void:
	var court_uv := _safe_site(Vector2(u + 34, v - 42), Vector2(u + 25, v - 54), 0, Vector2(20, 30))
	if court_uv.is_finite():
		var origin := Layout.position(court_uv.x, court_uv.y)
		_projected_patch("Court", origin, Vector2(18, 28), "court_red", 0.04)
		_projected_patch("CourtInfield", origin, Vector2(15, 24), "court_paint", 0.045)
		for side: float in [-1, 1]:
			_projected_patch("CourtLines", origin + Vector3(side * 7.2, 0, 0), Vector2(0.09, 23.2), "white", 0.055)
			_projected_patch("CourtLines", origin + Vector3(0, 0, side * 11.6), Vector2(14.5, 0.09), "white", 0.055)
			var post := origin + Vector3(0, 0, side * 12.6)
			post.y = Layout.height_at(post.x, post.z)
			add_part(post, Vector3(0, 1.6, 0), Vector3(0.13, 3.2, 0.13), "oxidized_metal", 0, true)
			add_part(post, Vector3(0, 3.2, -side * 0.6), Vector3(1.6, 1.0, 0.09), "ivory", 0)
			add_part(post, Vector3(0, 3.2, -side * 0.66), Vector3(0.52, 0.36, 0.025), "sign_red", 0)
			for x: float in [-0.25, 0.25]:
				add_part(post, Vector3(x, 2.88, -side * 0.95), Vector3(0.045, 0.045, 0.50), "terracotta", 0)
			add_part(post, Vector3(0, 2.88, -side * 1.19), Vector3(0.54, 0.045, 0.045), "terracotta", 0)
		_projected_patch("CourtCentre", origin, Vector2(14.5, 0.09), "white", 0.055)
		for side: float in [-1, 1]:
			for z: float in [-12, -6, 0, 6, 12]:
				var fence := origin + Vector3(side * 9.2, 0, z)
				fence.y = Layout.height_at(fence.x, fence.z)
				add_box(fence + Vector3.UP * 1.4, Vector3(0.07, 2.8, 0.07), "oxidized_metal", true)
			for y: float in [0.35, 1.1, 1.9, 2.75]:
				_ground_part(origin, Vector3(side * 9.2, y, 0), Vector3(0.025, 0.025, 28), "oxidized_metal", 0)
		composition_counts["courts"] += 1
	var play_uv := _safe_site(Vector2(u - 33, v - 34), Vector2(u - 26, v - 46), 0, Vector2(18, 22))
	if play_uv.is_finite():
		var origin := Layout.position(play_uv.x, play_uv.y)
		_projected_patch("Playground", origin, Vector2(16, 20), "garden_soil", 0.025)
		for x: float in [-2.4, 2.4]:
			for side: float in [-1, 1]:
				_detail_segment(origin + Vector3(x, 0, side * 1.1), origin + Vector3(x, 2.8, 0), 0.065, "sign_green")
		_detail_segment(origin + Vector3(-2.6, 2.8, 0), origin + Vector3(2.6, 2.8, 0), 0.065, "sign_green")
		for swing: float in [-1.1, 1.1]:
			for side: float in [-1, 1]:
				_detail_segment(origin + Vector3(swing + side * 0.3, 2.75, 0), origin + Vector3(swing + side * 0.3, 0.6, 0.18), 0.015, "oxidized_metal")
			add_part(origin, Vector3(swing, 0.58, 0.18), Vector3(0.75, 0.09, 0.40), "timber", 0)
		var sandbox := origin + Vector3(0, 0, -5)
		_projected_patch("Sandpit", sandbox, Vector2(5, 4), "garden_soil", 0.038)
		for side: float in [-1, 1]:
			_ground_part(sandbox, Vector3(side * 2.6, 0.15, 0), Vector3(0.18, 0.3, 4.3), "timber", 0)
			_ground_part(sandbox, Vector3(0, 0.15, side * 2.1), Vector3(5.4, 0.3, 0.18), "timber", 0)
		for side: float in [-1, 1]:
			var bench := origin + Vector3(side * 6, 0, 3)
			bench.y = Layout.height_at(bench.x, bench.z)
			_bench(bench, side * PI / 2)
			_litter_bin(bench + Vector3(0, 0, 2), 0)
		composition_counts["playgrounds"] += 1


func _infill_landscape() -> void:
	# Composed planting occupies the remaining gaps, including perimeter streets.
	# It never substitutes a grass patch for an unchecked building footprint.
	for id in Layout.BLOCK_COUNT:
		var row := id / (Layout.COLUMN_COUNT - 1)
		var column := id % (Layout.COLUMN_COUNT - 1)
		for u in range(int(Layout.COLUMNS[column]) + 24, int(Layout.COLUMNS[column + 1]) - 22, 18):
			for v in range(int(Layout.ROWS[row]) + 26, int(Layout.ROWS[row + 1]) - 24, 19):
				var seed_value := absi(id * 971 + u * 13 + v * 7)
				var position := Layout.position(u + sin(seed_value) * 4, v + cos(seed_value) * 4)
				var point := Vector2(position.x, position.z)
				if _parcel_overlaps(position, 0, Vector2(7, 7)) or _road_distance(point) < 8 or _ramp_factor(point) < 0.98:
					continue
				composition_counts["planted_gaps"] += 1
				_garden_tree(position, 6.5 + seed_value % 5)
				for bush in 5:
					var angle := bush * 2.4 + seed_value
					var plant := position + Vector3(cos(angle) * 2.8, 0, sin(angle) * 2.8)
					plant.y = Layout.height_at(plant.x, plant.z)
					add_instance("tree_leaves%d" % (seed_value % 3), "tree_leaves", plant - Vector3.UP * 0.2, Vector3(2.8, 1.5, 2.8), angle)
					if seed_value % 3 == 0:
						add_instance("flower_cluster", "blossom_gold" if id % 2 == 0 else "blossom_violet", plant + Vector3.UP * 0.8, Vector3.ONE * 0.65, angle)
