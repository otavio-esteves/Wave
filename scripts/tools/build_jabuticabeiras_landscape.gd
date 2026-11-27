extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Ground = preload("res://scripts/tools/build_jabuticabeiras_ground.gd")
const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const TreeMesh = preload("res://scripts/tools/build_jabuticabeiras_trees.gd")
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const M = Masonry.Finish
const Slope = preload("res://assets/shaders/jabuticabeiras/foothills.gdshader")
const Woods = preload("res://assets/textures/figueiras/mata-da-serra.png")
const Meadow = preload("res://assets/textures/jabuticabeiras/grama-do-largo.png")
const LEAVES = preload("res://assets/textures/jabuticabeiras/jabuticaba-spray.png")
const FOLIAGE = preload("res://assets/shaders/jabuticabeiras/leaves.gdshader")
const NORTH_EDGE := Layout.LENGTH + 24.0
const SOUTH_EDGE := -24.0
const LATERAL_EDGE := 49.0
const GOLDEN_ANGLE := 2.39996323

# The shelf behind the overlook falls away before the hills rise again. The
# hills are asymmetric in plan, which keeps the center view open to the valley.
const NORTH_HILLS := [
	Vector4(190.0, -25.0, 3.1, 11.0), Vector4(197.0, 22.0, 5.8, 12.0),
	Vector4(212.0, -36.0, 12.9, 18.0), Vector4(230.0, 35.0, 16.7, 20.0),
	Vector4(238.0, -17.0, 9.6, 16.0), Vector4(268.0, -51.0, 19.8, 22.0),
	Vector4(266.0, 67.0, 25.0, 14.0), Vector4(281.0, -2.0, 14.5, 22.0),
]
const SOUTH_HILLS := [
	Vector4(-46.0, 19.0, 7.9, 11.0), Vector4(-54.0, -25.0, 9.5, 14.0),
	Vector4(-73.0, -47.0, 18.5, 22.0), Vector4(-86.0, 43.0, 17.8, 19.0),
	Vector4(-105.0, -5.0, 10.3, 22.0), Vector4(-136.0, 8.0, 18.8, 26.0),
]
const GROVES := [
	Vector4(190, -31, 11, 26), Vector4(198, 30, 11, 28),
	Vector4(211, -44, 19, 37), Vector4(219, 38, 19, 30),
	Vector4(238, -17, 17, 36), Vector4(245, 45, 18, 30),
	Vector4(260, -50, 20, 36), Vector4(266, 56, 22, 29),
	Vector4(-47, -27, 10, 28), Vector4(-46, 22, 15, 42),
	Vector4(-69, -43, 16, 30), Vector4(-95, 40, 17, 32),
	Vector4(-110, -9, 19, 27),
	Vector4(44, -62, 17, 24), Vector4(111, -61, 21, 27),
	Vector4(24, 64, 14, 22), Vector4(109, 58, 12, 28),
]

var _masonry: Masonry
var _random := RandomNumberGenerator.new()
var _terrain := ShaderMaterial.new()
var _canopy_material: ShaderMaterial
var _canopy_meshes: Array[ArrayMesh] = []


func _init(masonry: Masonry) -> void:
	_masonry = masonry


func build(parent: Node3D) -> void:
	_random.seed = 617493
	_terrain.resource_name = "CapimEMataDaEncosta"
	_terrain.shader = Slope
	_terrain.set_shader_parameter("meadow_map", Meadow)
	_terrain.set_shader_parameter("woodland_map", Woods)
	for side: float in [-1.0, 1.0]:
		var start := -130.0 if side < 0.0 else LATERAL_EDGE - 0.7
		var end := -LATERAL_EDGE + 0.7 if side < 0.0 else 130.0
		_patch(parent, Rect2(Vector2(start, SOUTH_EDGE), Vector2(end - start, NORTH_EDGE - SOUTH_EDGE)), 2.6)
	for rect: Rect2 in [
		Rect2(-131.0, NORTH_EDGE - 0.7, 131.0, 124.0),
		Rect2(0.0, NORTH_EDGE - 0.7, 131.0, 124.0),
		Rect2(-131.0, -150.0, 131.0, 127.0),
		Rect2(0.0, -150.0, 131.0, 127.0),
	]:
		_patch(parent, rect, 2.2)
	_install_canopy_meshes()
	_forest(parent)
	_hillside_houses()


func _patch(parent: Node3D, area: Rect2, spacing: float) -> void:
	var across_count := ceili(area.size.x / spacing)
	var lane_count := ceili(area.size.y / spacing)
	var vertices := PackedVector3Array()
	var local := PackedVector2Array()
	var shades := PackedColorArray()
	for lane in lane_count + 1:
		for column in across_count + 1:
			var offset := lerpf(area.position.x, area.end.x, float(column) / across_count)
			var station := lerpf(area.position.y, area.end.y, float(lane) / lane_count)
			var point := _ground(station, offset)
			if station >= SOUTH_EDGE and station <= NORTH_EDGE and absf(offset) <= LATERAL_EDGE:
				point.y -= 0.045
			vertices.append(point)
			local.append(Vector2(offset, station))
			shades.append(_biome(station, offset))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain)
	var width := across_count + 1
	for lane in lane_count:
		for column in across_count:
			var lower := lane * width + column
			var upper := lower + width
			for index in [lower, upper, upper + 1, lower, upper + 1, lower + 1]:
				surface.set_color(shades[index])
				surface.set_uv(local[index])
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertices[index])
	surface.index()
	var mesh := MeshInstance3D.new()
	mesh.name = "Encosta_%d_%d" % [roundi(area.position.x), roundi(area.position.y)]
	mesh.mesh = surface.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


func _ground(station: float, offset: float) -> Vector3:
	return Layout.position_at(station, offset, _height(station, offset))


func _height(station: float, offset: float) -> float:
	var inside := clampf(station, SOUTH_EDGE, NORTH_EDGE)
	var lateral := clampf(offset, -LATERAL_EDGE, LATERAL_EDGE)
	var street_lift := Ground.surface_lift(inside, lateral) + Layout.grade(inside) - Layout.grade(station)
	var reach := maxf(absf(offset) - LATERAL_EDGE, 0.0)
	var west_flank := (10.0 + 9.1 * cos(station * 0.042 - 0.55)) * smoothstep(0.0, 54.0, reach)
	var east_flank := (12.0 + 9.5 * sin(station * 0.038 + 1.28)) * smoothstep(0.0, 62.0, reach)
	var length := absf(inside - station)
	var bank := (west_flank if offset < 0.0 else east_flank) * (1.0 - smoothstep(15.0, 52.0, length))
	if is_equal_approx(inside, station):
		return street_lift + bank
	var floor_height := -6.0 - 0.044 * length
	var hills := 0.0
	for hill: Vector4 in (NORTH_HILLS if station > NORTH_EDGE else SOUTH_HILLS):
		var separation := Vector2((station - hill.x) * 1.14, offset - hill.y).length_squared()
		var h := hill.z * exp(-separation / (hill.w * hill.w * 1.47))
		hills = maxf(hills, h) + minf(hills, h) * 0.33
	var variation := sin(station * 0.128 + offset * 0.092) * 0.82 + cos(station * 0.191 - offset * 0.115) * 0.42
	return lerpf(street_lift + bank, floor_height + hills + variation, smoothstep(0.0, 15.0, length))


func _biome(station: float, offset: float) -> Color:
	var slope := Vector2(_height(station, offset + 1.6) - _height(station, offset - 1.6),
		_height(station + 1.6, offset) - _height(station - 1.6, offset)) / 3.2
	var steepness := slope.length()
	var tune := 0.50 + 0.24 * sin(station * 0.088 + offset * 0.21) + 0.19 * cos(station * 0.19 - offset * 0.06)
	var woods := smoothstep(0.25, 0.74, tune + 0.25 * steepness)
	for grove: Vector4 in GROVES:
		var gap := Vector2(station - grove.x, offset - grove.y)
		if absf(gap.x) < grove.z * 1.26 and absf(gap.y) < grove.z * 1.26:
			var reach := gap.length() / grove.z
			var closure := (1.0 - smoothstep(0.44, 1.26, reach)) * (0.81 + 0.16 * tune)
			woods = maxf(woods, closure)
	var sun := Vector3(-slope.x, 1.0, slope.y).normalized().dot(Layout.SUN_DIRECTION.normalized())
	var shade := 0.73 + 0.32 * smoothstep(-0.29, 0.65, sun)
	return Color(woods, shade, smoothstep(0.38, 0.85, steepness) * (1.0 - woods))


func _install_canopy_meshes() -> void:
	_canopy_material = ShaderMaterial.new()
	_canopy_material.resource_name = "CopasDaSerra"
	_canopy_material.shader = FOLIAGE
	_canopy_material.set_shader_parameter("leaf_spray", LEAVES)
	_canopy_material.set_shader_parameter("distant_grove", true)
	var builder := TreeMesh.new()
	for species in 3:
		_canopy_meshes.append(builder.build_forest_crown(species))


func _forest(parent: Node3D) -> void:
	# Groups follow crests and sheltered hollows. Houses occupy the gaps.
	for patch_index in GROVES.size():
		var patch: Vector4 = GROVES[patch_index]
		var placements: Array[Array] = [[], [], []]
		for index in int(patch.w):
			var angle := index * GOLDEN_ANGLE + _random.randf_range(-0.32, 0.32)
			var sample := Vector2.from_angle(angle) * patch.z * sqrt((index + 0.5) / patch.w)
			var station := patch.x + sample.x
			var offset := patch.y + sample.y
			var age := _random.randf_range(2.8, 6.0) * (1.28 if index % 11 == 0 else 1.0)
			var species := index % 3
			var tree := _ground(station, offset)
			var shape := Vector3(age * _random.randf_range(0.72, 1.13), age, age * _random.randf_range(0.68, 1.07))
			placements[species].append(Transform3D(Basis(Vector3.UP, angle).scaled_local(shape), tree))
		for species in 3:
			_grove(parent, patch_index, species, _ground(patch.x, patch.y), placements[species])


func _grove(parent: Node3D, patch: int, species: int, center: Vector3, placements: Array) -> void:
	var multimesh := BakedMultiMesh.new()
	multimesh.mesh = _canopy_meshes[species]
	var transforms: Array[Transform3D] = []
	for tree: Transform3D in placements:
		tree.origin -= center
		transforms.append(tree)
	multimesh.instance_transforms = transforms
	var grove := MultiMeshInstance3D.new()
	grove.name = "Mata_%d_%d" % [patch, species]
	grove.position = center
	grove.multimesh = multimesh
	grove.material_override = _canopy_material
	grove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grove.visibility_range_end = 224.0
	parent.add_child(grove)


func _hillside_houses() -> void:
	var lots := [
		Vector4(193, -14.4, 4.7, 0.38), Vector4(197, -20.7, 5.2, 0.12),
		Vector4(204, -14.1, 4.5, -0.29), Vector4(206, -24.8, 4.8, 0.27),
		Vector4(213, -16.1, 5.7, 0.10), Vector4(216, -27.5, 4.6, 0.38),
		Vector4(218, -9.3, 4.9, -0.25),
		Vector4(199, 16.0, 4.7, -0.33), Vector4(204, 23.5, 5.7, -0.41),
		Vector4(212, 13.2, 4.7, 0.26), Vector4(218, 22.0, 6.1, -0.06),
		Vector4(223, 28.5, 4.6, -0.39), Vector4(231, 29.8, 5.5, -0.21),
		Vector4(-41, 15.9, 5.4, PI + 0.29), Vector4(-48, 26.7, 4.9, PI - 0.31),
		Vector4(-58, 15.5, 4.6, PI + 0.18), Vector4(-62, 22.7, 5.2, PI - 0.29),
	]
	for index in lots.size():
		var lot: Vector4 = lots[index]
		_cottage(_ground(lot.x, lot.y), lot.z, lot.w, index)


func _cottage(site: Vector3, width: float, yaw: float, index: int) -> void:
	var walls := [Color("c2b099"), Color("a78e7c"), Color("b5b8a5"), Color("aab4b2"), Color("c2b69c")]
	var wall: Color = walls[index % walls.size()]
	var roof := Color("c6a08e").lerp(Color("8d827d"), 0.24 * (index % 4))
	var joinery := Color("55594e").lerp(Color("6c7a77"), 0.24 * (index % 3))
	var height := 2.65 + (0.90 if index % 4 == 1 else 0.20 * (index % 3))
	var depth := 3.3 + 0.25 * (index % 3)
	var foundation := site + Vector3.UP * 0.29
	var half := width * 0.5
	var eaves := half + 0.24
	var peak := height + 0.88 + (index % 3) * 0.14
	_masonry.begin(Transform3D(Basis(Vector3.UP, yaw), foundation))
	_masonry.box(Vector3(0, -0.96, -depth * 0.5), Vector3(width + 0.17, 2.05, depth + 0.42), M.STONE, Color("8e8e7e"), 0.92)
	_masonry.box(Vector3(0, height * 0.5, -depth * 0.5), Vector3(width, height, depth), M.PLASTER, wall)
	_masonry.quad(Vector3(-eaves, height, 0.32), Vector3(eaves, height, 0.32),
		Vector3(eaves, peak, -depth * 0.56), Vector3(-eaves, peak, -depth * 0.56), M.TILE, roof)
	_masonry.quad(Vector3(eaves, height, -depth - 0.35), Vector3(-eaves, height, -depth - 0.35),
		Vector3(-eaves, peak, -depth * 0.56), Vector3(eaves, peak, -depth * 0.56), M.TILE, roof.darkened(0.12))
	for side: float in [-1.0, 1.0]:
		var left := Vector3(side * half, height - 0.008, -depth)
		var right := Vector3(side * half, height - 0.008, 0.0)
		var top := Vector3(side * half, peak, -depth * 0.56)
		if side < 0.0:
			_masonry.triangle(left, right, top, M.PLASTER, wall.darkened(0.10))
		else:
			_masonry.triangle(right, left, top, M.PLASTER, wall.darkened(0.10))
	_masonry.box(Vector3(0, peak + 0.015, -depth * 0.56), Vector3(eaves * 2.01, 0.13, 0.23), M.TILE, roof)
	_masonry.box(Vector3(0, height - 0.045, 0.273), Vector3(eaves * 2.02, 0.13, 0.075), M.WOOD, joinery)
	for side: float in [-1.0, 1.0]:
		var x := width * 0.27 * side
		var lit := (index + int(side > 0.0)) % 4 == 1
		var center := Vector3(x, height * 0.66, 0.025)
		var sash := M.LIGHT if lit else M.METAL
		var glass := Color("c88d45") if lit else joinery.darkened(0.34)
		_masonry.box(center, Vector3(0.96, 0.91, 0.085), M.WOOD, joinery)
		_masonry.box(center + Vector3.BACK * 0.055, Vector3(0.78, 0.73, 0.025), sash, glass, 0.90)
		_masonry.box(center + Vector3.BACK * 0.073, Vector3(0.045, 0.76, 0.028), M.WOOD, joinery)
		_masonry.box(center + Vector3(0, -0.43, 0.084), Vector3(1.03, 0.09, 0.17), M.STONE, wall)
	_masonry.box(Vector3(0, 0.93, 0.024), Vector3(0.75, 1.86, 0.09), M.WOOD, joinery)
	if index % 3 != 1:
		_masonry.box(Vector3(-width * 0.31, peak + 0.20, -depth * 0.74), Vector3(0.37, 0.94, 0.42), M.BRICK, roof)
		_masonry.box(Vector3(-width * 0.31, peak + 0.65, -depth * 0.74), Vector3(0.48, 0.10, 0.52), M.STONE, wall)
