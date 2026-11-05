extends "res://tests/pilot_city_smoke.gd"

const Terrain = preload("res://scripts/city/pilot_terrain.gd")


func _run() -> void:
	InputSetup.configure()
	FixtureInput.isolate()
	var low := INF
	var high := -INF
	var grade := 0.0
	var curvature := 0.0
	var climbs := 0
	var descents := 0
	var meaningful_edges := 0
	for edge in Layout.edges():
		var points := Layout.edge_points(edge.a, edge.b)
		var previous_grade := 0.0
		if absf(points[-1].y - points[0].y) >= 7.0:
			meaningful_edges += 1
		for index in points.size() - 1:
			var p := points[index]
			low = minf(low, p.y)
			high = maxf(high, p.y)
			var delta := points[index + 1] - p
			var slope := delta.y / Vector2(delta.x, delta.z).length()
			grade = maxf(grade, absf(slope))
			if index > 0:
				curvature = maxf(curvature, absf(atan(slope) - atan(previous_grade)))
			previous_grade = slope
			climbs += 1 if slope > 0.04 else 0
			descents += 1 if slope < -0.04 else 0
	_check(high - low > 45 and high - low < 65, "streets offer visible residential hills and a lower urban valley")
	_check(grade > 0.075 and grade < 0.10, "stronger hills retain an urban driving grade below ten percent")
	_check(curvature < 0.02, "vertical street curves remain progressive through sampled terrain seams")
	_check(climbs > 100 and descents > 100 and meaningful_edges >= 20, "multiple streets contain substantial climbs and descents rather than a single isolated mound")
	var centre_low := INF
	var centre_high := -INF
	for id in Layout.NODE_COUNT:
		var point := Layout.node(id)
		if point.x >= 676:
			centre_low = minf(centre_low, point.y)
			centre_high = maxf(centre_high, point.y)
	_check(centre_high - centre_low < 6, "downtown retains gentler relief than the residential hills")
	var faces := Layout.terrain_faces()
	_check(faces.size() == int(Layout.HALF_WIDTH * 2 / Layout.TERRAIN_STEP) * int(Layout.HALF_DEPTH * 2 / Layout.TERRAIN_STEP) * 6, "new relief preserves the existing terrain triangle budget")
	var matching := true
	for index in range(0, faces.size(), 711):
		var point := faces[index]
		matching = matching and absf(Layout.height_at(point.x, point.z) - point.y) < 0.00001
	_check(matching, "cached queries agree with the actual saved terrain vertices")
	var continuous := true
	for x: float in [-1536, -1024, -8, 0, 768, 1536]:
		for z: float in [-1232, -400, 0, 784, 1232]:
			continuous = continuous and absf(Layout.height_at(x - 0.0001, z) - Layout.height_at(x + 0.0001, z)) < 0.001
	_check(continuous, "negative coordinates, cell boundaries and outer landscape stay continuous")
	var builder := preload("res://scripts/city/pilot_city_builder.gd").new()
	builder.begin("SlopeBench", "Colliders")
	builder._palette()
	builder._premium_palette()
	var bench_site := Layout.node(63)
	bench_site.y += 0.3
	builder._bench(bench_site, 0.0)
	var bench := builder.finish()
	var bench_colliders := bench.get_node("Colliders").get_children()
	_check(bench_colliders.size() == 1, "level hillside bench support reuses its original single collider")
	var bench_shape := bench_colliders[0] as CollisionShape3D
	var supported := true
	for x: float in [-1.225, 1.225]:
		for z: float in [-0.39, 0.39]:
			var height := Layout.height_at(bench_site.x + x, bench_site.z + z) + 0.3
			supported = supported and bench_shape.position.y - bench_shape.shape.size.y / 2 <= height
			supported = supported and bench_shape.position.y + bench_shape.shape.size.y / 2 >= height + 0.85
	_check(supported and bench.find_children("box_stone_*", "MultiMeshInstance3D", true, false).size() == 1, "a level plinth and its collider span the slope beneath all bench feet")
	bench.free()
	var world := Node3D.new()
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.name = "Terrain"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collider.shape = shape
	ground.add_child(collider)
	world.add_child(ground)
	var car := preload("res://scenes/cars/player_car.tscn").instantiate() as PlayerCar
	car.position = Layout.node(63) + Vector3.UP * 0.4
	world.add_child(car)
	root.add_child(world)
	current_scene = world
	for ids: Array in [[63, 64], [64, 63], [89, 90], [90, 89]]:
		var route := Layout.route(ids, 1.8)
		_terrain_place(car, route[0], route[1] - route[0])
		await _frames(15)
		var result := await _drive(car, route, 30.0 / 3.6)
		_check(result.arrived and result.ground_ratio > 0.99 and result.max_offset < 2.5, "real inputs retain support through the new hillside in both directions: %s" % [ids])
	var slope_points := Layout.route([63, 64])
	_terrain_place(car, slope_points[slope_points.size() / 2], slope_points[-1] - slope_points[0])
	Input.action_press("handbrake")
	await _frames(60)
	var parked := car.position
	await _frames(120)
	_check(car.is_on_floor() and car.position.distance_to(parked) < 0.05, "parking brake holds the new residential incline without altering vehicle tuning")
	_release()
	world.queue_free()
	await _frames(3)
	print("Pilot relief: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _terrain_place(car: PlayerCar, point: Vector3, forward: Vector3) -> void:
	_release()
	car.reset_car()
	car.position = point
	car.rotation = Vector3(0, atan2(-forward.x, -forward.z), 0)
