extends SceneTree

const Layout = preload("res://scripts/race/circuit_layout.gd")
const Props = preload("res://scripts/city/neighborhood_builder.gd")
const Materials = preload("res://scripts/race/race_materials.gd")
const OUTPUT := "res://scenes/race/race_map.tscn"
var props: RefCounted
var points: PackedVector3Array
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 2005
	props = Props.new()
	props._root = Node3D.new()
	props._root.name = "RaceMap"
	props._colliders = StaticBody3D.new()
	props._colliders.name = "TrackColliders"
	props._root.add_child(props._colliders)
	props._setup_palette()
	props._setup_meshes()
	Materials.apply(props)
	props._box(Vector3(0, -0.3, 0), Vector3(1200, 0.6, 1060), "grass", true, 0.0, false)
	points = Layout.route()
	props._root.set_meta("route", points)
	props._root.set_meta("length_m", Layout.length_m(points))
	props._root.set_meta("finish", Layout.FINISH)
	_road()
	_pits_and_grid()
	_districts()
	_landmarks()
	props._flush_batches()
	for geometry in props._root.get_children():
		if geometry is MultiMeshInstance3D and geometry.visibility_range_end > 0:
			if geometry.material_override.resource_name in ["cream", "sage", "roof", "glass"]:
				geometry.visibility_range_end = 420
			elif geometry.material_override.resource_name == "foliage":
				geometry.visibility_range_end = 320
	props._assign_owner(props._root)
	var packed := PackedScene.new()
	var error := packed.pack(props._root)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	print("Circuit: %.0f m, %d route samples; saved %s" % [Layout.length_m(points), points.size(), error_string(error)])
	props._root.free()
	quit(0 if error == OK else 1)

func _road() -> void:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	road.set_material(props._materials["asphalt"])
	var runoff := SurfaceTool.new()
	runoff.begin(Mesh.PRIMITIVE_TRIANGLES)
	runoff.set_material(props._materials["sidewalk"])
	for index in points.size():
		var next := (index + 1) % points.size()
		var right := Layout.tangent(points, index).cross(Vector3.UP)
		var next_right := Layout.tangent(points, next).cross(Vector3.UP)
		_ribbon(road, points[index], points[next], right, next_right, -Layout.HALF_WIDTH, Layout.HALF_WIDTH, 0.025)
		var segment := points[next] - points[index]
		var middle := (points[next] + points[index]) * 0.5
		var yaw := atan2(segment.x, segment.z)
		if index % 2 == 0:
			props._box(middle + Vector3.UP * 0.043, Vector3(0.12, 0.008, 2.6), "yellow", false, yaw, false)
		for side in [-1.0, 1.0]:
			_ribbon(runoff, points[index], points[next], right, next_right, side * 8.5, side * 13.0, 0.012)
			props._box(middle + right * side * 8.6 + Vector3.UP * 0.04, Vector3(0.35, 0.08, segment.length() + 0.06), "white" if index % 2 == 0 else "terracotta", false, yaw, false)
			props._box(middle + right * side * 8.15 + Vector3.UP * 0.044, Vector3(0.12, 0.008, segment.length() + 0.05), "white", false, yaw, false)
			var pit_opening: bool = side > 0.0 and middle.z > 380 and ((middle.x > -340 and middle.x < -270) or (middle.x > 160 and middle.x < 230))
			if not pit_opening:
				# Concrete footing, steel double rail, regularly spaced posts.
				props._box(middle + right * side * 16.0 + Vector3.UP * 0.18, Vector3(0.45, 0.36, segment.length() + 0.08), "sidewalk", true, yaw, false)
				for height in [0.7, 1.0]:
					props._box(middle + right * side * 16.0 + Vector3.UP * height, Vector3(0.16, 0.2, segment.length() + 0.15), "metal", false, yaw, false)
				props._box(middle + right * side * 16.0 + Vector3.UP * 0.55, Vector3(0.16, 1.1, 0.16), "metal", true, yaw, false)
		if index % 20 == 0:
			_lamp(middle + right * 24.0, yaw)
		if index % 45 == 0 and middle.z < 350:
			# High contrast direction boards readable before entering each sector.
			var position := middle - right * 19.0
			props._box(position + Vector3.UP * 2.5, Vector3(3.5, 1.4, 0.18), "yellow", false, yaw)
			props._label("› › ›", position + Vector3.UP * 2.5 - Layout.tangent(points, index) * 0.13, yaw + PI, 0.025)
	for entry in [["CircuitAsphalt", road], ["Runoff", runoff]]:
		var surface := MeshInstance3D.new()
		surface.name = entry[0]
		var tool: SurfaceTool = entry[1]
		tool.index()
		tool.generate_tangents()
		surface.mesh = tool.commit()
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props._root.add_child(surface)

func _pits_and_grid() -> void:
	props._box(Vector3(-55, 0.027, 422), Vector3(550, 0.02, 10), "pit_asphalt", false, 0.0, false)
	for x in [-305.0, 195.0]:
		props._box(Vector3(x, 0.029, 407), Vector3(10, 0.02, 62), "pit_asphalt", false, -0.65 if x < 0 else 0.65, false)
	props._box(Vector3(-55, 0.6, 432), Vector3(550, 1.2, 0.35), "sidewalk", true)
	for x in range(-240, 170, 36):
		_building(Vector3(x, 0, 456), Vector3(30, 7, 32), 0, true)
	props._label("BOXES · CIRCUITO DO SOL", Vector3(-55, 9, 439.8), PI, 0.032)
	for stripe in 17:
		for row in 2:
			props._box(Layout.FINISH + Vector3(row * 0.6, 0.049, -8 + stripe), Vector3(0.6, 0.008, 1), "white" if (stripe + row) % 2 == 0 else "metal", false, 0.0, false)
	for z in [379.0, 401.0]:
		props._box(Vector3(-280, 3.5, z), Vector3(0.5, 7, 0.5), "metal", true)
	props._box(Vector3(-280, 7, 390), Vector3(0.7, 1, 22), "metal")
	props._label("WAVE · CIRCUITO DO SOL", Vector3(-280.4, 7, 390), -PI * 0.5, 0.025)
	for slot in 12:
		props._box(Vector3(-290 - slot * 5, 0.049, 386 if slot % 2 == 0 else 394), Vector3(0.12, 0.008, 2.5), "white", false, 0.0, false)
	for tier in 6:
		props._box(Vector3(-365, 0.5 + tier * 0.7, 430 + tier * 2.5), Vector3(56, 1 + tier * 1.4, 2.4), "sidewalk", true)
		props._box(Vector3(-365, 1.03 + tier * 1.4, 430 + tier * 2.5), Vector3(54, 0.08, 1.4), "blue")
	props._box(Vector3(-365, 11.5, 438), Vector3(60, 0.35, 22), "roof")
	for x in [-394, -336]:
		props._box(Vector3(x, 5.75, 438), Vector3(0.4, 11.5, 0.4), "metal", true)

func _districts() -> void:
	for index in range(0, points.size(), 17):
		var middle := points[index]
		var forward := Layout.tangent(points, index)
		var right := forward.cross(Vector3.UP)
		for side in [-1.0, 1.0]:
			# The western and northern sections are wooded; eastern sector industrial.
			var wooded := middle.x < -380 or middle.z < -180
			var center: Vector3 = middle + right * side * rng.randf_range(49, 65)
			if middle.z > 370 and side > 0:
				continue
			if wooded:
				for offset in [-20.0, 0.0, 20.0]:
					var tree: Vector3 = center + forward * offset
					if _clearance(tree) > 27:
						props._tree(tree, rng.randf_range(1.5, 2.7))
			elif _clearance(center) > 40:
				var toward: Vector3 = (middle - center).normalized()
				var yaw := atan2(-toward.x, -toward.z)
				_building(center, Vector3(rng.randf_range(25, 40), rng.randf_range(9, 19), rng.randf_range(22, 33)), yaw, false)
		# More roadside vegetation, far enough from the barriers.
		if index % 34 == 0:
			var tree := middle - right * 27
			if _clearance(tree) > 24:
				props._tree(tree, rng.randf_range(1.2, 1.8))
	# Interior warehouse yards form a skyline through the infield.
	for x in [-270.0, -150.0, -30.0, 90.0, 210.0, 330.0]:
		for z in [-55.0, 75.0, 205.0]:
			var center := Vector3(x, 0, z)
			if _clearance(center) > 65:
				_building(center, Vector3(55, rng.randf_range(12, 25), 45), PI, false)
				props._box(center + Vector3(-33, 1.3, 5), Vector3(5, 2.6, 12), "roof", true)
				props._box(center + Vector3(-33, 1.3, -12), Vector3(5, 2.6, 12), "terracotta", true)

func _building(center: Vector3, size: Vector3, yaw: float, garage: bool) -> void:
	var material := "cream" if garage or rng.randf() > 0.4 else "sage"
	props._part(center, Vector3(0, size.y * 0.5, 0), size, material, yaw, true)
	props._part(center, Vector3(0, size.y + 0.15, 0), Vector3(size.x + 0.8, 0.3, size.z + 0.8), "roof", yaw)
	props._part(center, Vector3(0, 0.5, -size.z * 0.5 - 0.06), Vector3(size.x, 1, 0.15), "sidewalk", yaw)
	# Recessed doors, lintels, window mullions, gutters and rooftop ventilation.
	props._part(center, Vector3(0, 2.5, -size.z * 0.5 - 0.12), Vector3(8, 5, 0.15), "metal", yaw)
	for x in [-size.x * 0.35, size.x * 0.35]:
		for y in range(6, int(size.y - 1), 4):
			props._part(center, Vector3(x, y, -size.z * 0.5 - 0.1), Vector3(6, 2.1, 0.1), "glass", yaw)
			props._part(center, Vector3(x, y, -size.z * 0.5 - 0.18), Vector3(0.1, 2.1, 0.1), "metal", yaw)
			props._part(center, Vector3(x, y - 1.1, -size.z * 0.5 - 0.2), Vector3(6.3, 0.18, 0.35), "sidewalk", yaw)
		props._part(center, Vector3(x, size.y + 0.6, 0), Vector3(3, 1.2, 2), "metal", yaw)
	for side in [-1.0, 1.0]:
		props._part(center, Vector3(side * (size.x * 0.5 - 0.2), size.y * 0.5, -size.z * 0.5 - 0.18), Vector3(0.15, size.y, 0.15), "metal", yaw)
	props._part(center, Vector3(0, 5.4, -size.z * 0.5 - 0.7), Vector3(10, 0.15, 1.4), "roof", yaw)

func _lamp(position: Vector3, yaw: float) -> void:
	props._box(position + Vector3.UP * 5.5, Vector3(0.18, 11, 0.18), "metal", true)
	props._box(position + Vector3.UP * 10.8, Vector3(3.5, 0.16, 0.25), "metal", false, yaw)
	props._box(position + Vector3.UP * 10.65, Vector3(1.1, 0.12, 0.5), "light", false, yaw, false)

func _landmarks() -> void:
	for center in [Vector3(390, 0, 0), Vector3(370, 0, -95)]:
		props._instance("cylinder", "sage", center + Vector3.UP * 12, Vector3(16, 24, 16))
		props._collision(center + Vector3.UP * 12, Vector3(32, 24, 32))
		for height in [3.0, 21.0]:
			props._instance("cylinder", "metal", center + Vector3.UP * height, Vector3(16.3, 0.25, 16.3))
		props._box(center + Vector3(0, 32, 0), Vector3(2, 17, 2), "metal")
	# Distant low-poly landforms retain depth beyond the draw distance.
	var hill := SphereMesh.new()
	hill.radius = 1
	hill.height = 2
	hill.radial_segments = 16
	hill.rings = 8
	props._meshes["hill"] = hill
	for x in range(-900, 901, 180):
		props._instance("hill", "hill", Vector3(x, -30, -620 - rng.randf_range(0, 65)), Vector3(230, rng.randf_range(65, 105), 200), 0, false)
	for side in [-1.0, 1.0]:
		props._box(Vector3(side * 595, 0.7, 0), Vector3(0.4, 1.4, 1050), "sidewalk", true)
		props._box(Vector3(0, 0.7, side * 525), Vector3(1190, 1.4, 0.4), "sidewalk", true)

func _clearance(position: Vector3) -> float:
	var distance := INF
	for point in points:
		distance = minf(distance, point.distance_to(position))
	return distance

func _ribbon(surface: SurfaceTool, a: Vector3, b: Vector3, right_a: Vector3, right_b: Vector3, inner: float, outer: float, height: float) -> void:
	var vertices: Array[Vector3] = [a + right_a * inner, b + right_b * inner, b + right_b * outer, a + right_a * outer]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		var p: Vector3 = vertices[triangle[0]]
		var q: Vector3 = vertices[triangle[1]]
		var r: Vector3 = vertices[triangle[2]]
		if (q - p).cross(r - p).y > 0:
			var swap := q
			q = r
			r = swap
		for vertex: Vector3 in [p, q, r]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x, vertex.z) * 0.25)
			surface.add_vertex(vertex + Vector3.UP * height)
