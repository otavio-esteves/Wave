extends "res://scripts/corridor/corridor_builder.gd"

const Layout = preload("res://scripts/world/intercity_layout.gd")
const Cells = preload("res://scripts/world/corridor_cells_builder.gd")
var route_palette: Dictionary[String, StandardMaterial3D] = {}
var route_meshes: Dictionary[String, Mesh] = {}


func build_route(output: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(output + "/shared")
	if error != OK:
		return error
	var helper := Cells.new()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/world/cells/vale/manifest.json"))
	# Borrow the first authored urban cell unchanged; keep every old map intact.
	var urban: Node3D = load(original.cells[0].scene).instantiate()
	var roots: Array[Node3D] = [urban]
	var origins: Array[Vector3] = [Vector3.ZERO]
	var records: Array = [original.cells[0].duplicate(true)]
	records[0].neighbors = ["link-1"]
	records[0].region = Layout.REGIONS[0]
	var shared: Dictionary = {}
	for index in range(1, 4):
		var origin_z := Layout.START_Z - (index - 1) * Layout.CELL_LENGTH
		var cell := _build_cell(index, origin_z)
		roots.append(cell)
		origins.append(Vector3(0, 0, origin_z))
		for child in cell.get_children():
			if child is GeometryInstance3D:
				helper._share(child.material_override, output, "material", shared)
				if child is MultiMeshInstance3D:
					helper._share(child.multimesh.mesh, output, "mesh", shared)
		var path := "%s/cell-%d.tscn" % [output, index]
		error = helper._save(cell, path)
		if error != OK:
			break
		var neighbors: Array[String] = ["vale-0" if index == 1 else "link-%d" % (index - 1)]
		if index < 3:
			neighbors.append("link-%d" % (index + 1))
		records.append({"id": "link-%d" % index, "scene": path, "origin": [0, 0, origin_z], "bounds": [-130, -1, origin_z - Layout.CELL_LENGTH, 260, 50, Layout.CELL_LENGTH], "neighbors": neighbors, "region": Layout.REGIONS[index]})
	if error == OK:
		var distant := preload("res://scripts/world/corridor_hlod_builder.gd").new().build(roots, origins)
		for index in range(1, 4):
			distant.get_child(index).name = "link-%d" % index
		error = helper._save(distant, output + "/distant.tscn")
		distant.free()
	if error == OK:
		begin("SerraHorizon", "Colliders")
		_palette()
		for z in [-400.0, -800.0, -1200.0, -1600.0]:
			for side in [-1.0, 1.0]:
				add_instance("horizon_hill", "hill", Vector3(side * 240, -30, z), Vector3(115, 65, 180), 0, false)
		var horizon := finish()
		error = helper._save(horizon, output + "/horizon.tscn")
		horizon.free()
	if error == OK:
		var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_string(JSON.stringify({"version": 1, "generator_version": 3, "region": "sol-serra-proof", "seed": SEED, "cells": records, "road": {"start": [0, 0, 24], "end": [0, 0, -1360], "width_m": 12, "surface": "asphalt", "flat_support": true}}, "\t") + "\n")
	for cell in roots:
		cell.free()
	return error


func _build_cell(index: int, origin_z: float) -> Node3D:
	begin("LinkCell%d" % index, "Colliders")
	if route_palette.is_empty():
		_palette()
		route_palette = materials.duplicate()
		route_meshes = meshes.duplicate()
	else:
		materials = route_palette.duplicate()
		meshes = route_meshes.duplicate()
	rng.seed = SEED + index
	add_collision(Vector3(0, -0.3, -200), Vector3(260, 0.6, 400))
	_colliders.get_child(0).name = "Floor"
	_surface("Ground", Vector2(0, -200), Vector2(260, 400), 0, "grass", 0.16)
	_road(origin_z)
	if index < 3:
		_landscape(index, origin_z)
	for step in range(24, 390, 30) if index < 3 else []:
		var z := -float(step)
		var center := Layout.center_x(origin_z + z)
		for side in [-1.0, 1.0]:
			if not Layout.roadside_open(index, side, z):
				add_box(Vector3(center + side * 16, 0.8, z), Vector3(0.12, 1.6, 0.12), "wood", true)
			if not Layout.roadside_open(index, side, z - 14, 14):
				add_box(Vector3(center + side * 16, 1.1, z - 14), Vector3(0.09, 0.10, 28), "wood", false, 0, false)
	if index == 1:
		_building(Vector3(-38, 0, -100), 13, 3.8, 10, PI / 2, 0)
		_surface("RuralForecourt", Vector2(-21, -100), Vector2(34, 24), 0.025, "sidewalk", 0.18)
		_marker("RuralStop", Vector3(-18, 0, -100))
		_sign("RuralTownDirection", Vector3(Layout.center_x(origin_z - 340) + 10, 0, -340), 0, 0)
		_sign("RuralReturnDirection", Vector3(Layout.center_x(origin_z - 38) - 10, 0, -38), PI, 2)
	elif index == 2:
		# Roadside refuge: open vehicle access, no event or garage manager yet.
		var road_edge := Layout.center_x(Layout.HIGHWAY_STOP_Z) + 5
		_surface("HighwayForecourt", Vector2((road_edge + 34) / 2, -210), Vector2(34 - road_edge, 44), 0.025, "asphalt", 0.25)
		_building(Vector3(38, 0, -210), 16, 4.2, 10, -PI / 2, 3)
		_marker("RoadsideStop", Vector3(20, 0, -210))
		for z in [-222.0, -217.0, -202.0, -197.0]:
			add_box(Vector3(24, 0.037, z), Vector3(8, 0.008, 0.12), "white", false, 0, false)
		add_box(Vector3(29, 3.7, -210), Vector3(8, 0.18, 18), "metal", false)
		add_box(Vector3(24.95, 3.56, -210), Vector3(0.12, 0.68, 17.5), "metal", false)
		add_instance("facade", "route_sign1", Vector3(24.87, 3.56, -210), Vector3(13, 0.62, 1), -PI / 2, false)
		for z in [-217.5, -202.5]:
			add_box(Vector3(25.5, 1.8, z), Vector3(0.18, 3.6, 0.18), "plaster", true)
		_sign("HighwayStopAdvance", Vector3(Layout.center_x(origin_z - 142) + 10, 0, -142), 0, 1)
		_sign("HighwayReturnDirection", Vector3(Layout.center_x(origin_z - 290) - 10, 0, -290), PI, 2)
	else:
		_town()
		add_box(Vector3(0, 0.45, -385), Vector3(19, 0.9, 0.5), "sidewalk", true)
	var cell := finish()
	if index >= 1:
		for child in cell.get_children():
			if child is MultiMeshInstance3D and child.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
				child.multimesh.billboard_radius = 6.0
	return cell


func _palette() -> void:
	super._palette()
	for index in 4:
		var sign: StandardMaterial3D = materials["sign%d" % index].duplicate()
		sign.resource_name = "route_sign%d" % index
		sign.albedo_texture = load("res://assets/textures/intercity/wayfinding.png")
		materials[sign.resource_name] = sign


func _landscape(index: int, origin_z: float) -> void:
	# Deliberate open views alternate with groves; road and stop footprints stay clear.
	for side in [-1.0, 1.0]:
		_surface("Ground", Vector2(side * 72, -120 if index == 1 else -280), Vector2(68, 170), 0.005, "grass", 0.16, Color(0.88, 0.86, 0.73) if side < 0 else Color(0.85, 0.94, 0.85))
	var groves := [{"z": -42.0, "side": -1.0, "offset": 35.0, "count": 3},
		{"z": -155.0, "side": 1.0, "offset": 24.0, "count": 4},
		{"z": -286.0, "side": -1.0, "offset": 31.0, "count": 3},
		{"z": -360.0, "side": 1.0, "offset": 26.0, "count": 3}]
	if index == 2:
		groves = [{"z": -52.0, "side": 1.0, "offset": 32.0, "count": 3},
			{"z": -162.0, "side": -1.0, "offset": 25.0, "count": 3},
			{"z": -298.0, "side": 1.0, "offset": 34.0, "count": 3},
			{"z": -365.0, "side": -1.0, "offset": 22.0, "count": 2}]
	for grove in groves:
		for tree in int(grove.count):
			var z: float = grove.z + rng.randf_range(-10, 10)
			var x: float = Layout.center_x(origin_z + z) + grove.side * (grove.offset + rng.randf_range(-3, 6))
			_tree(Vector3(x, 0, z), rng.randf_range(7, 10))


func _sign(label: String, origin: Vector3, yaw: float, tile: int) -> void:
	add_box(origin + Vector3.UP * 2.75, Vector3(4.8, 1.4, 0.12), "metal", false, yaw)
	for x in [-1.8, 1.8]:
		add_box(origin + Vector3(x, 1.2, 0), Vector3(0.12, 2.4, 0.12), "metal", true)
	add_instance("facade", "route_sign%d" % tile, origin + Vector3.UP * 2.75 + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.075), Vector3(4.7, 1.3, 1), yaw, false)
	_marker(label, origin)


func _town() -> void:
	# A short authored main street: staggered plots and an open square replace
	# evenly spaced houses/trees. All entrances retain the existing flat support.
	_surface("TownSideStreet", Vector2(0, Layout.TOWN_CROSSROAD_Z), Vector2(130, 10), 0.022, "asphalt", 0.25)
	for side in [-1.0, 1.0]:
		var run_start := 0.0
		var run_end := 0.0
		var in_run := false
		for step in range(40, 360, 4):
			var z := -float(step + 2)
			if Layout.town_sidewalk_open(z, side):
				if in_run:
					_town_sidewalk_collision(side, run_start, run_end)
					in_run = false
				continue
			if not in_run:
				run_start = z + 2
				in_run = true
			run_end = z - 2
			add_box(Vector3(side * 7.7, 0.055, z), Vector3(3.0, 0.11, 4), "sidewalk", false, 0, false)
			add_box(Vector3(side * 6.12, 0.10, z), Vector3(0.20, 0.20, 4), "plaster", false, 0, false)
		if in_run:
			_town_sidewalk_collision(side, run_start, run_end)
	# Short side-street pavements frame the intersection without blocking it.
	for side in [-1.0, 1.0]:
		for x in [-35.0, 35.0]:
			add_box(Vector3(x, 0.055, Layout.TOWN_CROSSROAD_Z + side * 6.5), Vector3(50, 0.11, 3), "sidewalk", true, 0, false)
	for index in Layout.TOWN_LOTS.size():
		var lot: Dictionary = Layout.TOWN_LOTS[index]
		var side := signf(float(lot.x))
		var origin := Vector3(lot.x, 0, lot.z)
		_building(origin, lot.width, lot.height, lot.depth, PI / 2 if side < 0 else -PI / 2, lot.facade)
		_surface("TownYard", Vector2(side * 14.0, lot.z), Vector2(10, lot.width + 4), 0.024, "sidewalk", 0.18, Color(0.86, 0.84, 0.79))
		# Leave the middle of every frontage open; walls define the plot edges.
		for offset in [-1.0, 1.0]:
			add_box(Vector3(side * 10.2, 0.55, lot.z + offset * (lot.width / 2 - 1.3)), Vector3(0.20, 1.1, 2.6), "plaster", true)
		add_box(Vector3(side * 16, 0.6, lot.z - lot.width / 2 - 2), Vector3(12, 1.2, 0.20), "brick", true)
		_marker("TownLot%d" % index, origin)
	_square()
	for position in [Vector3(-11, 0, -50), Vector3(12, 0, -126), Vector3(12, 0, -204), Vector3(-11, 0, -340)]:
		_tree(position, 8.0)
	for position in [Vector3(-10.5, 0, -95), Vector3(10.5, 0, -212), Vector3(-10.5, 0, -290)]:
		var side := signf(position.x)
		add_box(position + Vector3.UP * 3.1, Vector3(0.20, 6.2, 0.20), "plaster", true)
		add_box(position + Vector3(-side * 0.7, 6.0, 0), Vector3(1.5, 0.12, 0.12), "metal", false)
		add_box(position + Vector3(-side * 1.35, 5.9, 0), Vector3(0.65, 0.20, 0.4), "metal", false)
		add_box(position + Vector3(-side * 1.35, 5.79, 0), Vector3(0.50, 0.025, 0.30), "white", false, 0, false)
	# Zebra markings give the crossroad a different rhythm from the highway.
	for z in [Layout.TOWN_CROSSROAD_Z - 10, Layout.TOWN_CROSSROAD_Z + 10]:
		for stripe in 10:
			add_box(Vector3(-4.8 + stripe * 1.06, 0.041, z), Vector3(0.65, 0.008, 2.8), "white", false, 0, false)
	_marker("TownArrival", Vector3(16, 0, -45))
	_sign("TownWelcome", Vector3(11, 0, -22), 0, 0)
	_sign("TownReturnDirection", Vector3(-11, 0, -25), PI, 2)
	_sign("TownSquareDirection", Vector3(-11, 0, -204), 0, 3)


func _town_sidewalk_collision(side: float, start: float, end: float) -> void:
	# One shape per continuous strip, with the same extents as the visual tiles.
	var z := (start + end) / 2
	add_collision(Vector3(side * 7.7, 0.055, z), Vector3(3, 0.11, start - end))
	add_collision(Vector3(side * 6.12, 0.10, z), Vector3(0.20, 0.20, start - end))


func _square() -> void:
	var z := Layout.TOWN_SQUARE_Z
	_surface("TownSquareForecourt", Vector2(-28, z), Vector2(38, 58), 0.026, "sidewalk", 0.18, Color(0.95, 0.91, 0.82))
	_surface("TownSquareAccess", Vector2(-10, z), Vector2(10, 16), 0.028, "asphalt", 0.25)
	# Small covered meeting point, open toward the square and the avenue.
	var shelter := Vector3(-40, 0, z - 18)
	add_part(shelter, Vector3(0, 3.9, 0), Vector3(12, 1.2, 8), "roof", PI / 2, false, "roof")
	for dx in [-3.2, 3.2]:
		for dz in [-5.2, 5.2]:
			add_box(shelter + Vector3(dx, 1.7, dz), Vector3(0.3, 3.4, 0.3), "cream", true)
	for tree in [Vector3(-40, 0, z + 18), Vector3(-22, 0, z + 21), Vector3(-21, 0, z - 21)]:
		_tree(tree, 9.0)
	# Benches and low planting borders stay away from the drivable centre.
	for bench_z in [z - 18, z + 18]:
		add_box(Vector3(-30, 0.48, bench_z), Vector3(4, 0.18, 0.8), "wood", true)
		add_box(Vector3(-30, 0.83, bench_z - 0.4), Vector3(4, 0.55, 0.12), "wood", true)
		for x in [-31.6, -28.4]:
			add_box(Vector3(x, 0.2, bench_z), Vector3(0.16, 0.4, 0.6), "metal", false)
	for edge in [z - 28, z + 28]:
		add_box(Vector3(-28, 0.17, edge), Vector3(38, 0.34, 0.22), "brick", true)
	_marker("TownSquare", Vector3(-28, 0, z))
	_marker("TownSquareAccess", Vector3(-10, 0, z))


func _road(origin_z: float) -> void:
	# Four-metre samples create a continuous ribbon; world UVs meet at joins.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(0, 400, 4):
		var a := -float(step)
		var b := a - 4
		var xa := Layout.center_x(origin_z + a)
		var xb := Layout.center_x(origin_z + b)
		var points: Array[Vector3] = [Vector3(xb - 6, 0.018, b), Vector3(xb + 6, 0.018, b), Vector3(xa + 6, 0.018, a), Vector3(xa - 6, 0.018, a)]
		for corner in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.UP)
			tool.set_color(Color.WHITE)
			tool.set_uv(Vector2(points[corner].x, points[corner].z + origin_z) * 0.25)
			tool.add_vertex(points[corner])
		var center := Vector3((xa + xb) / 2, 0.034, (a + b) / 2)
		var yaw := atan2(xa - xb, 4.0)
		for x in [-5.7, 5.7]:
			if origin_z == Layout.TOWN_ORIGIN_Z and Layout.town_sidewalk_open(center.z, signf(x)):
				continue
			if Layout.roadside_open(1 if origin_z == Layout.START_Z else 2, signf(x), center.z) and origin_z != Layout.TOWN_ORIGIN_Z:
				continue
			add_box(center + Vector3(x, 0, 0), Vector3(0.09, 0.008, 4.05), "white", false, yaw, false)
		if step % 8 == 0 and not (origin_z == Layout.TOWN_ORIGIN_Z and absf(center.z - Layout.TOWN_CROSSROAD_Z) < 8):
			add_box(center, Vector3(0.13, 0.008, 3.4), "yellow", false, yaw, false)
	var road := MeshInstance3D.new()
	road.name = "Avenue_Link"
	road.mesh = tool.commit()
	road.material_override = materials["asphalt"]
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(road)
