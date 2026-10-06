extends "res://scripts/city/offline_scene_builder.gd"

const STREET_CENTERS: Array[float] = [-490.0, -420.0, -350.0, -280.0, -210.0, -140.0, -70.0, 0.0, 70.0, 140.0, 210.0, 280.0, 350.0, 420.0, 490.0]
const AREA_SCALE := 2.2360679775 # sqrt(5): five times the previous footprint.
const LIMIT: float = 252.0 * AREA_SCALE
const GROUND_SIZE: float = 536.0 * AREA_SCALE

func build() -> Node3D:
	begin("NeighborhoodMap", "CityColliders")
	_roads_and_sidewalks()
	_residential_blocks()
	_shops()
	_park()
	_service_station()
	_street_furniture()
	_boundary()
	return finish()


func _roads_and_sidewalks() -> void:
	add_box(Vector3(0, -0.3, 0), Vector3(GROUND_SIZE, 0.6, GROUND_SIZE), "grass", true)
	for center in STREET_CENTERS:
		var width := _road_width(center)
		for segment in 18:
			var length := LIMIT * 2.0 / 18.0
			var middle := -LIMIT + (segment + 0.5) * length
			add_box(Vector3(center, 0.012, middle), Vector3(width, 0.02, length), "asphalt", false, 0.0, false)
			add_box(Vector3(middle, 0.013, center), Vector3(length, 0.02, width), "asphalt", false, 0.0, false)
		for side in [-1.0, 1.0]:
			var edge: float = center + side * (width * 0.5 + 1.4)
			_sidewalk_segments(center, edge, true)
			_sidewalk_segments(center, edge, false)
		for step in range(-int(LIMIT / 5.0) + 1, int(LIMIT / 5.0)):
			var along := float(step) * 5.0
			if _inside_crossing(along, 10.0):
				continue
			add_box(Vector3(center, 0.027, along), Vector3(0.14, 0.008, 2.4), "yellow", false, 0.0, false)
			add_box(Vector3(along, 0.028, center), Vector3(2.4, 0.008, 0.14), "yellow", false, 0.0, false)
			if is_zero_approx(center):
				for offset in [-4.0, 4.0]:
					add_box(Vector3(offset, 0.027, along), Vector3(0.1, 0.008, 2.4), "white", false, 0.0, false)
					add_box(Vector3(along, 0.028, offset), Vector3(2.4, 0.008, 0.1), "white", false, 0.0, false)
	for x in STREET_CENTERS:
		for z in STREET_CENTERS:
			_crosswalks(x, z)


func _road_width(center: float) -> float:
	if absf(center) >= 490.0:
		return 24.0
	return 16.0 if is_zero_approx(center) else 12.0


func _inside_crossing(position: float, margin: float) -> bool:
	for center in STREET_CENTERS:
		if absf(position - center) < margin:
			return true
	return false


func _sidewalk_segments(street: float, edge: float, vertical: bool) -> void:
	var endpoints: Array[float] = [-LIMIT]
	endpoints.append_array(STREET_CENTERS)
	endpoints.append(LIMIT)
	for index in range(endpoints.size() - 1):
		var start := endpoints[index]
		var end := endpoints[index + 1]
		if index > 0:
			start += _road_width(start) * 0.5
		if index < endpoints.size() - 2:
			end -= _road_width(end) * 0.5
		# Open two driveways into the service station, including the curbs.
		var driveway := (vertical and is_zero_approx(street) and edge > 0.0)
		driveway = driveway or (not vertical and is_equal_approx(street, 70.0) and edge < 70.0)
		if driveway and start < 48.0 and end > 22.0:
			_sidewalk_piece(edge, start, minf(end, 22.0), vertical)
			_sidewalk_piece(edge, maxf(start, 48.0), end, vertical)
		else:
			_sidewalk_piece(edge, start, end, vertical)


func _sidewalk_piece(edge: float, start: float, end: float, vertical: bool) -> void:
	if end <= start:
		return
	var length := end - start
	var middle := (start + end) * 0.5
	var center := Vector3(edge, 0.06, middle) if vertical else Vector3(middle, 0.06, edge)
	var size := Vector3(2.8, 0.12, length) if vertical else Vector3(length, 0.12, 2.8)
	add_box(center, size, "sidewalk", true)


func _crosswalks(x: float, z: float) -> void:
	for side in [-1.0, 1.0]:
		var vertical_stripes := int(_road_width(x) / 1.3)
		for stripe in range(vertical_stripes):
			var offset := (float(stripe) - float(vertical_stripes - 1) * 0.5) * 1.3
			add_box(Vector3(x + offset, 0.03, z + side * (_road_width(z) * 0.5 + 2.0)), Vector3(0.7, 0.009, 2.5), "white", false, 0.0, false)
		var horizontal_stripes := int(_road_width(z) / 1.3)
		for stripe in range(horizontal_stripes):
			var offset := (float(stripe) - float(horizontal_stripes - 1) * 0.5) * 1.3
			add_box(Vector3(x + side * (_road_width(x) * 0.5 + 2.0), 0.031, z + offset), Vector3(2.5, 0.009, 0.7), "white", false, 0.0, false)


func _residential_blocks() -> void:
	var colors: Array[String] = ["cream", "sage", "blue", "rose"]
	var addresses: Array[float] = [-95.0, -46.0, -24.0, 24.0, 46.0, 95.0]
	for index in range(addresses.size()):
		_house(Vector3(addresses[index], 0, -97), colors[index % 4], 0.0)
		_house(Vector3(addresses[index], 0, 97), colors[(index + 1) % 4], PI)
	for index in range(4):
		var z: float = [-46.0, -24.0, 24.0, 46.0][index]
		_house(Vector3(-97, 0, z), colors[index], PI * 0.5)
		_house(Vector3(97, 0, z), colors[(index + 2) % 4], -PI * 0.5)
	_house(Vector3(-24, 0, 25), "cream", PI)
	_house(Vector3(-48, 0, 25), "sage", PI)
	_house(Vector3(-24, 0, 49), "rose", 0.0)
	_house(Vector3(-48, 0, 49), "blue", 0.0)

	# Populate the added blocks; keep the original center and landmarks intact.
	for x in [-238.0, -175.0, -105.0, -35.0, 35.0, 105.0, 175.0, 238.0]:
		for z in [-238.0, -175.0, -105.0, -35.0, 35.0, 105.0, 175.0, 238.0]:
			if absf(x) < 130.0 and absf(z) < 130.0:
				continue
			var color_index := posmod(int(x + z), 4)
			_house(Vector3(x, 0, z), colors[color_index], 0.0 if z < 0.0 else PI)
			if absf(x) < 220.0 and absf(z) < 220.0:
				_house(Vector3(x + 16, 0, z + 16), colors[(color_index + 1) % 4], PI * 0.5)

	# Larger outer district with long avenues; the original center is unchanged.
	for x in range(-455, 456, 70):
		for z in range(-455, 456, 70):
			if abs(x) < 260 and abs(z) < 260:
				continue
			_house(Vector3(x, 0, z), colors[posmod(x + z, 4)], 0.0 if z < 0 else PI)
			add_tree(Vector3(x + 14, 0, z - 14), 1.0)


func _house(center: Vector3, color: String, yaw: float) -> void:
	add_part(center, Vector3(0, 2.6, 0), Vector3(12, 5.2, 12), color, yaw, true)
	add_part(center, Vector3(0, 6.0, 0), Vector3(13, 2, 13), "roof", yaw, false, "roof")
	add_part(center, Vector3(0, 1.3, 6.04), Vector3(1.8, 2.6, 0.12), "wood", yaw)
	for offset in [-3.8, 3.8]:
		add_part(center, Vector3(offset, 2.9, 6.08), Vector3(2.4, 1.6, 0.12), "glass", yaw)
		add_part(center, Vector3(offset, 2.9, 6.16), Vector3(0.1, 1.6, 0.05), "cream", yaw)
		add_part(center, Vector3(6.08, 2.9, offset), Vector3(0.12, 1.6, 2.4), "light", yaw)
	add_part(center, Vector3(0, 0.016, 13), Vector3(2.0, 0.02, 14.0), "sidewalk", yaw)
	add_part(center, Vector3(0, 3.1, 6.6), Vector3(3, 0.18, 1.6), "roof", yaw)
	var tree_position := center + Basis(Vector3.UP, yaw) * Vector3(9.0, 0.0, 7.5)
	add_tree(tree_position, 0.8)


func _shops() -> void:
	_shop(Vector3(25, 0, -46), Vector3(16, 10, 17), "cream", -PI * 0.5, "MERCADO SOL")
	_shop(Vector3(25, 0, -24), Vector3(16, 8, 17), "sage", -PI * 0.5, "DISCOS & CAFÉ")
	_shop(Vector3(49, 0, -22), Vector3(18, 6, 16), "rose", 0.0, "CAFÉ DA ESQUINA")


func _shop(center: Vector3, size: Vector3, color: String, yaw: float, title: String) -> void:
	add_part(center, Vector3(0, size.y * 0.5, 0), size, color, yaw, true)
	add_part(center, Vector3(0, size.y + 0.25, 0), Vector3(size.x + 0.8, 0.5, size.z + 0.8), "roof", yaw)
	for x in [-size.x * 0.3, size.x * 0.3]:
		add_part(center, Vector3(x, 2.0, size.z * 0.5 + 0.06), Vector3(4.5, 2.8, 0.12), "glass", yaw)
		if size.y > 7.0:
			add_part(center, Vector3(x, 6.5, size.z * 0.5 + 0.06), Vector3(3.0, 1.8, 0.12), "light", yaw)
	add_part(center, Vector3(0, 3.9, size.z * 0.5 + 0.8), Vector3(size.x + 1.0, 0.25, 2.0), "terracotta", yaw)
	add_part(center, Vector3(0, 4.7, size.z * 0.5 + 0.09), Vector3(size.x - 1.0, 1.1, 0.15), "metal", yaw)
	add_label(title, center + Basis(Vector3.UP, yaw) * Vector3(0, 4.7, size.z * 0.5 + 0.2), yaw, 0.012)


func _park() -> void:
	add_box(Vector3(-36, 0.022, -36), Vector3(46, 0.025, 46), "grass", false, 0.0, false)
	add_box(Vector3(-36, 0.04, -36), Vector3(4, 0.025, 50), "sidewalk", false, 0.0, false)
	add_box(Vector3(-36, 0.041, -36), Vector3(50, 0.025, 4), "sidewalk", false, 0.0, false)
	add_instance("cylinder", "sidewalk", Vector3(-36, 0.25, -36), Vector3(4.0, 0.5, 4.0))
	add_instance("cylinder", "water", Vector3(-36, 0.51, -36), Vector3(3.4, 0.05, 3.4), 0.0, false)
	add_collision(Vector3(-36, 0.25, -36), Vector3(8, 0.5, 8))
	for position: Vector3 in [Vector3(-52, 0, -52), Vector3(-20, 0, -52), Vector3(-52, 0, -20), Vector3(-20, 0, -20), Vector3(-51, 0, -36), Vector3(-21, 0, -36)]:
		add_tree(position, 1.1)
	for position: Vector3 in [Vector3(-43, 0, -45), Vector3(-29, 0, -45), Vector3(-43, 0, -27), Vector3(-29, 0, -27)]:
		_bench(position)
	add_box(Vector3(-36, 1.5, -12), Vector3(7, 1.2, 0.25), "wood", true)
	add_label("PRAÇA DO SOL", Vector3(-36, 1.5, -11.84), 0.0, 0.015)


func _service_station() -> void:
	add_box(Vector3(36, 0.026, 37), Vector3(48, 0.025, 48), "sidewalk", false, 0.0, false)
	add_box(Vector3(9.5, 0.026, 35), Vector3(7, 0.025, 26), "sidewalk", false, 0.0, false)
	add_box(Vector3(35, 0.026, 63), Vector3(26, 0.025, 12), "sidewalk", false, 0.0, false)
	add_box(Vector3(47, 4, 19), Vector3(20, 8, 10), "cream", true)
	add_box(Vector3(47, 8.25, 19), Vector3(21, 0.5, 11), "terracotta")
	for x in [42.0, 51.0]:
		add_box(Vector3(x, 2, 24.07), Vector3(7, 4, 0.14), "metal")
		for stripe in range(5):
			add_box(Vector3(x, 0.5 + float(stripe) * 0.7, 24.17), Vector3(6.8, 0.06, 0.03), "glass")
	add_label("OFICINA HORIZONTE", Vector3(47, 6.5, 24.15), 0.0, 0.018)
	add_box(Vector3(29, 5.3, 42), Vector3(22, 0.65, 14), "terracotta")
	add_box(Vector3(29, 4.92, 42), Vector3(21, 0.15, 13), "cream")
	for x in [20.0, 38.0]:
		for z in [36.0, 48.0]:
			add_box(Vector3(x, 2.5, z), Vector3(0.4, 5, 0.4), "metal", true)
	for x in [25.0, 33.0]:
		add_box(Vector3(x, 0.15, 42), Vector3(2.5, 0.3, 2.5), "cream", true)
		add_box(Vector3(x, 1.3, 42), Vector3(1.0, 2.3, 0.8), "terracotta", true)
		add_box(Vector3(x, 1.8, 42.43), Vector3(0.7, 0.45, 0.06), "glass")
	add_label("POSTO SOL", Vector3(29, 5.35, 49.06), 0.0, 0.02)
	for x in [39.0, 44.0, 49.0, 54.0, 59.0]:
		add_box(Vector3(x, 0.048, 31), Vector3(0.12, 0.01, 9), "white", false, 0.0, false)
	add_box(Vector3(49, 0.048, 26.5), Vector3(20, 0.01, 0.12), "white", false, 0.0, false)
	add_tree(Vector3(57, 0, 55), 0.8)
	add_tree(Vector3(16, 0, 16), 0.8)


func _street_furniture() -> void:
	var lamp_positions: Array[float] = [-525.0, -455.0, -385.0, -315.0, -238.0, -175.0, -105.0, -45.0, -20.0, 20.0, 50.0, 105.0, 175.0, 238.0, 315.0, 385.0, 455.0, 525.0]
	for x in STREET_CENTERS:
		for index in range(lamp_positions.size()):
			var z := lamp_positions[index]
			var side := -1.0 if index % 2 == 0 else 1.0
			_lamp(Vector3(x + side * (_road_width(x) * 0.5 + 1.4), 0.12, z), -side)
	for x in STREET_CENTERS:
		for z in STREET_CENTERS:
			var position := Vector3(x - _road_width(x) * 0.5 - 1.4, 0.12, z - _road_width(z) * 0.5 - 1.4)
			add_box(position + Vector3.UP * 1.8, Vector3(0.1, 3.6, 0.1), "metal", true)
			add_box(position + Vector3.UP * 3.2, Vector3(3.6, 0.5, 0.15), "sage")
			var street_name := "AV. HORIZONTE" if is_zero_approx(z) else ("RUA DAS FLORES" if z < 0 else "RUA DO SOL")
			add_label(street_name, position + Vector3(0, 3.2, 0.09), 0.0, 0.009)


func _lamp(position: Vector3, side: float) -> void:
	add_box(position + Vector3.UP * 3.3, Vector3(0.16, 6.6, 0.16), "metal", true)
	add_box(position + Vector3(side * 0.7, 6.5, 0), Vector3(1.6, 0.15, 0.2), "metal")
	add_box(position + Vector3(side * 1.4, 6.4, 0), Vector3(0.65, 0.16, 0.4), "light", false, 0.0, false)


func _bench(position: Vector3) -> void:
	add_box(position + Vector3.UP * 0.6, Vector3(3.5, 0.16, 0.8), "wood")
	add_box(position + Vector3(0, 1.1, -0.4), Vector3(3.5, 0.7, 0.12), "wood")
	for x in [-1.3, 1.3]:
		add_box(position + Vector3(x, 0.3, 0), Vector3(0.15, 0.6, 0.7), "metal")
	add_collision(position + Vector3.UP * 0.65, Vector3(3.5, 1.3, 1))


func _boundary() -> void:
	for side in [-1.0, 1.0]:
		add_box(Vector3(side * (GROUND_SIZE * 0.5 - 2.0), 0.65, 0), Vector3(0.4, 1.3, GROUND_SIZE - 4.0), "wood", true)
		add_box(Vector3(0, 0.65, side * (GROUND_SIZE * 0.5 - 2.0)), Vector3(GROUND_SIZE - 4.0, 1.3, 0.4), "wood", true)
		for center in STREET_CENTERS:
			add_box(Vector3(center, 0.5, side * (LIMIT - 2.0)), Vector3(_road_width(center), 1, 0.6), "terracotta", true)
			add_box(Vector3(side * (LIMIT - 2.0), 0.5, center), Vector3(0.6, 1, _road_width(center)), "terracotta", true)
			add_label("RETORNE", Vector3(center, 1.5, side * (LIMIT - 2.0) - side * 0.35), PI if side > 0 else 0.0, 0.013)
	for position: Vector3 in [Vector3(-720, 0, -680), Vector3(720, 0, -680), Vector3(-720, 0, 690), Vector3(720, 0, 690)]:
		add_instance("foliage", "hill", position - Vector3.UP * 12, Vector3(100, 35, 90), 0.0, false)
