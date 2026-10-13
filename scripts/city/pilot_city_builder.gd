extends "res://scripts/city/pilot_city_architecture.gd"

# Orchestrate offline domains; persistence commits one validated generation.

func build_city() -> Node3D:
	batch_size = 112.0
	begin("PilotCity", "Colliders")
	_palette()
	_premium_palette()
	_tree_palette()
	_downtown_palette()
	_detail_palette()
	composition_counts = {"shops": 0, "courts": 0, "playgrounds": 0, "utility_poles": 0, "street_trees": 0, "planted_gaps": 0, "benches": 0}
	skyscraper_count = 0
	district_parcels = [0, 0, 0]
	tree_count = 0
	parcel_count = 0
	parked_count = 0
	surface_batches.clear()
	_address_palette()
	_parked_palette()
	road_faces.clear()
	sidewalk_faces.clear()
	paint_faces.clear()
	driveway_faces.clear()
	sites_valid = true
	street_samples.clear()
	street_point_tiles.clear()
	parcels.clear()
	parcel_tiles.clear()
	driveway_connections.clear()
	road_tiles.clear()
	ramp_tiles.clear()
	grass_count = 0
	garden_frontages = 0
	street_detail_count = 0
	review_benches.clear()
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		street_samples.append({"points": points, "width": edge.width})
		for point in points:
			var key := Vector2i(floori(point.x / 64), floori(point.z / 64))
			if not street_point_tiles.has(key):
				street_point_tiles[key] = []
			street_point_tiles[key].append({"position": point, "width": edge.width})
	print("Pilot generation: terrain and streets")
	var ground := Layout.terrain_faces()
	_mesh("Terrain", ground, "grass", 0.075)
	_support("Terrain", ground)
	for edge in Layout.edges():
		_street(edge)
	for id in Layout.NODE_COUNT:
		_junction(Layout.node(id))
	print("Pilot generation: district parcels")
	_blocks()
	_outer_frontages()
	_prepare_distance_field()
	print("Pilot generation: continuous sidewalks")
	_joined_sidewalks()
	for access in [Layout.square_access(), Layout.workshop_access()]:
		for index in access.size() - 1:
			_ribbon(road_faces, access[index], access[index + 1], -3.5, 3.5, Layout.ROAD_LIFT)
	_mesh("Streets", road_faces, "asphalt", 0.25)
	_mesh("Sidewalks", sidewalk_faces, "sidewalk", 0.18)
	_mesh("SidewalksFar", _sample_sidewalks(8), "sidewalk", 0.18)
	_settle_markings()
	_mesh("RoadMarkings", paint_faces, "white", 1.0)
	_support("Streets", road_faces)
	_support("Sidewalks", sidewalk_faces)
	_mesh("LotDriveways", driveway_faces, "paving", 0.25)
	print("Pilot generation: street furniture and landscape")
	_street_life()
	_street_canopy()
	_infill_landscape()
	_boundary()
	_landscape()
	print("Pilot generation: grass and landmarks")
	_meadow_grass()
	_district_landmarks()
	_flush_surfaces()
	print("Pilot generation: packing batches")
	var city := finish()
	_finish_colours(city)
	for child in city.get_children():
		if child is MultiMeshInstance3D and child.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			child.multimesh.billboard_radius = 6.0
	for child in city.get_children():
		if child is MultiMeshInstance3D:
			var material_name: String = child.material_override.resource_name
			if material_name in ["ivory", "sage", "cream", "rose", "stone", "charcoal", "roof", "timber", "glass", "water_tank", "aged_plaster", "oxidized_metal", "residential_glass", "residential_glass_lit", "commercial_glass"]:
				child.visibility_range_end = 650.0
			if material_name in ["tree_bark", "tree_leaves"]:
				child.visibility_range_end = 850.0
		if child is MultiMeshInstance3D and child.material_override.resource_name == "parked_car":
			child.visibility_range_end = 155.0
		if child is MultiMeshInstance3D and child.material_override.resource_name == "address_plate":
			child.visibility_range_end = 55.0
		if child is MultiMeshInstance3D and child.material_override.resource_name == "wild_grass":
			child.visibility_range_end = 75.0
			child.visibility_range_end_margin = 12.0
		if child is MultiMeshInstance3D and child.material_override.resource_name.begins_with("downtown"):
			child.visibility_range_end = 1800.0
			child.visibility_range_end_margin = 100.0
		if child is MultiMeshInstance3D and child.material_override.resource_name.begins_with("skyline"):
			child.visibility_range_end = 650.0
	city.set_meta("block_count", Layout.BLOCK_COUNT)
	city.set_meta("planned_block_count", Layout.PLANNED_BLOCK_COUNT)
	city.set_meta("generator_version", 13)
	city.set_meta("review_benches", review_benches)
	city.set_meta("district_names", Layout.DISTRICT_NAMES)
	city.set_meta("district_parcels", district_parcels)
	city.set_meta("skyscraper_count", skyscraper_count)
	city.set_meta("area_m2", 4.0 * Layout.HALF_WIDTH * Layout.HALF_DEPTH)
	city.set_meta("street_detail_count", street_detail_count)
	city.set_meta("tree_species_count", 6)
	city.set_meta("composition_counts", composition_counts)
	city.set_meta("visual_revision", "2026-10-12-neighborhood-composition")
	city.set_meta("grass_tuft_count", grass_count)
	city.set_meta("garden_frontages", garden_frontages)
	city.set_meta("parcel_footprints", parcels)
	city.set_meta("volumetric_tree_count", tree_count)
	city.set_meta("parcel_count", parcel_count)
	city.set_meta("parked_vehicle_count", parked_count)
	return city


func _finish_colours(city: Node3D) -> void:
	# Variation uses instance colours, preserving the existing material batches.
	var palette := [Color(1, 0.94, 0.86), Color(0.88, 0.95, 1), Color(0.92, 0.96, 0.88), Color(0.96, 0.90, 0.88), Color(0.89, 0.91, 0.93), Color.WHITE]
	for node in city.get_children():
		if not node is MultiMeshInstance3D:
			continue
		var material: StandardMaterial3D = node.material_override
		if material.resource_name not in ["ivory", "sage", "cream", "rose", "stone", "timber", "downtown_stone", "downtown_brick", "downtown_glass", "downtown_glass_dark"]:
			continue
		material.vertex_color_use_as_albedo = true
		var colours := PackedColorArray()
		for transform: Transform3D in node.multimesh.instance_transforms:
			var point: Vector3 = node.transform * transform.origin
			var position := Vector2(point.x, point.z)
			var centre := position
			var nearest := INF
			for parcel in _nearby_parcels(position):
				var distance := position.distance_squared_to(parcel.center)
				if distance < nearest:
					nearest = distance
					centre = parcel.center
			var seed_value := absi(floori(centre.x) * 73856093 ^ floori(centre.y) * 19349663)
			colours.append(palette[seed_value % palette.size()])
		node.multimesh.instance_tints = colours


func save_city(output: String) -> Error:
	var city := build_city()
	if not sites_valid:
		city.free()
		return ERR_INVALID_DATA
	var error: Error = preload("res://scripts/city/pilot_city_generation.gd").save(city, output)
	city.free()
	return error
