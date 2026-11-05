extends SceneTree

const Layout = preload("res://scripts/city/pilot_city_layout.gd")

func _initialize() -> void:
	var output := "user://terrain-profile.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var heights: Array = []
	var minimum := INF
	var maximum := -INF
	for row in int(Layout.HALF_DEPTH * 2 / 32) + 1:
		var line: Array = []
		for column in int(Layout.HALF_WIDTH * 2 / 32) + 1:
			var x := -Layout.HALF_WIDTH + column * 32
			var z := -Layout.HALF_DEPTH + row * 32
			var height := Layout.height_at(x, z)
			minimum = minf(minimum, height)
			maximum = maxf(maximum, height)
			line.append(height)
		heights.append(line)
	var streets: Array = []
	var road_min := INF
	var road_max := -INF
	var max_grade := 0.0
	var max_crossfall := 0.0
	var district_ranges := [{"min": INF, "max": -INF}, {"min": INF, "max": -INF}, {"min": INF, "max": -INF}]
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		var line: Array = []
		for index in points.size():
			var p := points[index]
			line.append([p.x, p.y, p.z])
			road_min = minf(road_min, p.y)
			road_max = maxf(road_max, p.y)
			var district := 0 if p.x < -424 else (1 if p.x < 676 else 2)
			district_ranges[district].min = minf(district_ranges[district].min, p.y)
			district_ranges[district].max = maxf(district_ranges[district].max, p.y)
			if index + 1 < points.size():
				var delta := points[index + 1] - p
				max_grade = maxf(max_grade, absf(delta.y) / Vector2(delta.x, delta.z).length())
				var right: Vector2 = Vector2(delta.z, -delta.x).normalized() * edge.width / 2
				var left_y := Layout.height_at(p.x - right.x, p.z - right.y)
				var right_y := Layout.height_at(p.x + right.x, p.z + right.y)
				max_crossfall = maxf(max_crossfall, absf(left_y - right_y) / edge.width)
		streets.append({"a": edge.a, "b": edge.b, "points": line})
	var report := {"scope": "headless authored heightfield and street geometry; no rendered appearance or FPS approval", "grid_step_m": 32, "half_width": Layout.HALF_WIDTH, "half_depth": Layout.HALF_DEPTH, "min_height_m": minimum, "max_height_m": maximum, "street_min_height_m": road_min, "street_max_height_m": road_max, "max_street_grade": max_grade, "max_street_crossfall": max_crossfall, "district_ranges": district_ranges, "height_grid": heights, "streets": streets}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report) + "\n")
	print("Terrain: streets %.2f–%.2f m; max grade %.2f%%; crossfall %.2f%%; %s" % [road_min, road_max, max_grade * 100, max_crossfall * 100, output])
	quit()
