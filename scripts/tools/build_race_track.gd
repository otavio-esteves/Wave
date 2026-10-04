extends SceneTree

const Layout = preload("res://scripts/race/circuit_layout.gd")
const Props = preload("res://scripts/city/neighborhood_builder.gd")
const OUTPUT := "res://scenes/race/race_map.tscn"

func _initialize() -> void:
	var props := Props.new()
	props._root = Node3D.new()
	props._root.name = "RaceMap"
	props._colliders = StaticBody3D.new()
	props._colliders.name = "TrackColliders"
	props._root.add_child(props._colliders)
	props._setup_palette()
	props._setup_meshes()
	props._box(Vector3(0, -0.3, 0), Vector3(560, 0.6, 460), "grass", true, 0.0, false)
	var points := Layout.route()
	props._root.set_meta("route", points)
	props._root.set_meta("length_m", Layout.length_m(points))
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
		_ribbon(road, points[index], points[next], right, next_right, -7.0, 7.0, 0.025)
		for side in [-1.0, 1.0]:
			_ribbon(runoff, points[index], points[next], right, next_right, side * 7.0, side * 18.0, 0.012)
			var segment := points[next] - points[index]
			var middle := (points[next] + points[index]) * 0.5
			var yaw := atan2(segment.x, segment.z)
			# Low painted rumble strips, then generous escape area and solid rails.
			props._box(middle + right * side * 7.35 + Vector3.UP * 0.025, Vector3(0.7, 0.05, segment.length() + 0.05), "white" if index % 2 == 0 else "terracotta", false, yaw, false)
			props._box(middle + right * side * 7.0 + Vector3.UP * 0.045, Vector3(0.12, 0.008, segment.length() + 0.05), "white", false, yaw, false)
			# Open the outer rail for pit entry and exit on the main straight.
			var pit_opening: bool = side > 0.0 and middle.z > 144.0 and ((middle.x > -118.0 and middle.x < -80.0) or (middle.x > 82.0 and middle.x < 120.0))
			if not pit_opening:
				props._box(middle + right * side * 20.0 + Vector3.UP * 0.6, Vector3(0.35, 1.2, segment.length() + 0.15), "metal", true, yaw)
	var surface := MeshInstance3D.new()
	surface.name = "CircuitAsphalt"
	road.index()
	surface.mesh = road.commit()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props._root.add_child(surface)
	var shoulders := MeshInstance3D.new()
	shoulders.name = "Runoff"
	runoff.index()
	shoulders.mesh = runoff.commit()
	shoulders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props._root.add_child(shoulders)
	# Connected pit lane with its own outer rail and simple garages.
	props._box(Vector3(0, 0.027, 178), Vector3(242, 0.02, 9), "asphalt", false, 0.0, false)
	for x in [-103.0, 103.0]:
		props._box(Vector3(x, 0.029, 164), Vector3(9, 0.02, 36), "asphalt", false, -0.5 if x < 0.0 else 0.5, false)
	props._box(Vector3(0, 0.6, 191), Vector3(246, 1.2, 0.35), "metal", true)
	for x in range(-65, 70, 27):
		props._box(Vector3(x, 2.5, 198), Vector3(22, 5, 10), "cream", true)
		props._box(Vector3(x, 2.1, 192.9), Vector3(17, 4.2, 0.1), "metal")
		props._box(Vector3(x, 5.1, 198), Vector3(23, 0.3, 11), "terracotta")
	props._label("BOXES · 30 km/h", Vector3(0, 5.9, 191.9), PI, 0.02)
	# Start/finish on the straight, with an overhead gantry and grid slots.
	for stripe in 14:
		for row in 2:
			props._box(Vector3(-80.0 + row * 0.6, 0.049, 143.5 + stripe), Vector3(0.6, 0.008, 1), "white" if (stripe + row) % 2 == 0 else "metal", false, 0.0, false)
	for z in [140.0, 160.0]:
		props._box(Vector3(-80, 3.0, z), Vector3(0.5, 6, 0.5), "metal", true)
	props._box(Vector3(-80, 6, 150), Vector3(0.5, 0.8, 20), "metal")
	props._label("WAVE · AUTÓDROMO DO SOL", Vector3(-80.31, 6, 150), -PI * 0.5, 0.015)
	for slot in 8:
		props._box(Vector3(-90 - slot * 5, 0.049, 147 if slot % 2 == 0 else 153), Vector3(0.12, 0.008, 2.5), "white", false, 0.0, false)
	# Grandstand beside the final sector, with a clear view of the straight.
	for tier in 4:
		props._box(Vector3(-150, 0.5 + tier * 0.7, 190 + tier * 2.5), Vector3(40, 1.0 + tier * 1.4, 2.4), "cream", true)
		props._box(Vector3(-150, 1.03 + tier * 1.4, 190 + tier * 2.5), Vector3(40, 0.08, 1.4), "blue")
	for x in [-250.0, 250.0]:
		for z in [-170.0, -100.0, 0.0, 90.0]:
			props._tree(Vector3(x, 0, z), 1.4)
	for side in [-1.0, 1.0]:
		props._box(Vector3(side * 275, 0.6, 0), Vector3(0.4, 1.2, 450), "wood", true)
		props._box(Vector3(0, 0.6, side * 225), Vector3(550, 1.2, 0.4), "wood", true)
	props._flush_batches()
	props._assign_owner(props._root)
	var packed := PackedScene.new()
	var error := packed.pack(props._root)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	print("Circuit: %.0f m, %d route samples; saved %s" % [Layout.length_m(points), points.size(), error_string(error)])
	props._root.free()
	quit(0 if error == OK else 1)

func _ribbon(surface: SurfaceTool, a: Vector3, b: Vector3, right_a: Vector3, right_b: Vector3, inner: float, outer: float, height: float) -> void:
	var vertices: Array[Vector3] = [a + right_a * inner, b + right_b * inner, b + right_b * outer, a + right_a * outer]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		var p: Vector3 = vertices[triangle[0]]
		var q: Vector3 = vertices[triangle[1]]
		var r: Vector3 = vertices[triangle[2]]
		if (q - p).cross(r - p).y > 0.0:
			var swap := q
			q = r
			r = swap
		for vertex: Vector3 in [p, q, r]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex + Vector3.UP * height)
