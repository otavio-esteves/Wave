extends "res://scripts/city/neighborhood_tree_mesh.gd"

const FoliageLOD = preload("res://scripts/city/foliage_mesh_lod.gd")
const GOLDEN_ANGLE := 2.39996323
const OUTLINES := [
	Vector3(0.32, 0.63, 0.31), Vector3(0.25, 0.69, 0.27), Vector3(0.35, 0.59, 0.30),
]


func build_street_tree(variant: int, flowering := false) -> Dictionary:
	random.seed = 38311 + variant * 159 + int(flowering) * 643
	bark = SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spread: Vector3 = OUTLINES[variant]
	var drift := Vector3(variant * 0.022 - 0.030, 0.0, 0.014)
	var trunk := PackedVector3Array([
		Vector3.DOWN * 0.026, Vector3(0.002, 0.035, -0.004), -drift * 0.52 + Vector3.UP * 0.14,
		drift + Vector3.UP * 0.30, drift * 1.8 + Vector3.UP * 0.45,
		drift * 2.02 + Vector3.UP * 0.58, drift * 1.23 + Vector3.UP * 0.76,
	])
	_stem(trunk, PackedFloat32Array([0.042, 0.028, 0.021, 0.018, 0.012, 0.008, 0.0022]), 12)
	for index in 6:
		var outward := Vector3(cos(index * 1.094 + variant), 0, sin(index * 1.094 + variant))
		_stem(PackedVector3Array([trunk[1] + Vector3.UP * 0.067, outward * 0.039 + Vector3.UP * 0.012,
			outward * random.randf_range(0.067, 0.099) - Vector3.UP * 0.012]),
			PackedFloat32Array([0.014, 0.010, 0.002]), 6)
	for branch in 11:
		var level := float(branch) / 10.0
		var angle := branch * GOLDEN_ANGLE + random.randf_range(-0.21, 0.21)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var width := direction * Vector3(spread.x, 0, spread.z)
		var reach := lerpf(1.05, 0.34, pow(level, 1.5)) * random.randf_range(0.77, 1.19)
		var start := trunk[2].lerp(trunk[5], 0.10 + level * 0.88)
		var tip := width * reach + Vector3.UP * (spread.y + level * 0.25 + random.randf_range(-0.055, 0.055))
		tip += drift * 1.24
		var elbow := start.lerp(tip, 0.58) - Vector3.UP * 0.080
		var wrist := elbow.lerp(tip, 0.58) - width * 0.072
		_stem(PackedVector3Array([start, start.lerp(elbow, 0.45) + direction * 0.018, elbow, wrist, tip]),
			PackedFloat32Array([lerpf(0.012, 0.0044, level), lerpf(0.0091, 0.0035, level), 0.0047, 0.0028, 0.0011]), 7)
		for spray in 3:
			var side := Vector3.UP.cross(direction) * (1.0 if (branch + spray) % 2 == 0 else -1.0)
			var base := elbow.lerp(wrist, spray * 0.43)
			var bud := base + direction * random.randf_range(0.055, 0.100) + side * random.randf_range(0.040, 0.090)
			bud.y += random.randf_range(0.051, 0.124)
			var joint := base.lerp(bud, 0.54) - Vector3.UP * 0.016
			_stem(PackedVector3Array([base, joint, bud]), PackedFloat32Array([0.0031, 0.0019, 0.00065]), 5)
			_sprays(joint, bud, angle, spread.y, flowering)
		_sprays(wrist, tip, angle, spread.y, flowering)
	bark.generate_tangents()
	bark.index()
	leaves.index()
	var crown := FoliageLOD.bake(leaves.commit().surface_get_arrays(0))
	return {"bark": bark.commit(), "leaves": crown}


func build_distant_bark(variant: int) -> ArrayMesh:
	bark = SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drift := Vector3(variant * 0.037 - 0.039, 0.0, 0.021)
	_stem(PackedVector3Array([Vector3.DOWN * 0.017, Vector3.UP * 0.12, drift + Vector3.UP * 0.34,
		drift * 2.0 + Vector3.UP * 0.63, drift * 1.8 + Vector3.UP * 0.84]),
		PackedFloat32Array([0.036, 0.021, 0.014, 0.007, 0.001]), 7)
	for index in 7:
		var bearing := index * GOLDEN_ANGLE - 0.21 * variant
		var level := float(index) / 6.0
		var reach := 0.27 - 0.14 * level
		var first := drift + Vector3.UP * (0.28 + 0.34 * level)
		var tip := Vector3(cos(bearing) * reach, 0.65 + 0.26 * level, sin(bearing) * reach)
		var elbow := first.lerp(tip, 0.58) - Vector3.UP * 0.035
		_stem(PackedVector3Array([first, elbow, tip]), PackedFloat32Array([0.011, 0.0048, 0.0018]), 5)
	bark.index()
	return bark.commit()


func _sprays(start: Vector3, end: Vector3, bearing: float, crown_base: float, flowering: bool) -> void:
	for patch in 4:
		var point := start.lerp(end, 0.29 + patch * 0.28) + _direction() * random.randf_range(0.012, 0.054)
		var normal := (point - Vector3.UP * (crown_base - 0.11)).normalized()
		var tilt := Basis.from_euler(Vector3(random.randf_range(-1.20, 1.20), bearing + patch * 1.88,
			random.randf_range(-1.34, 1.34)))
		var tint := Color("829484").lerp(Color("e5dfbd"),
			0.28 + 0.46 * smoothstep(0.40, 0.93, point.y) + 0.24 * random.randf())
		var size := random.randf_range(0.063, 0.094) * (0.90 if flowering else 1.0)
		_cluster(point, tilt, size, tint, normal)


func _stem(path: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var azimuth := (path[1] - path[0]).normalized()
	var across := azimuth.cross(Vector3.FORWARD)
	if across.length_squared() < 0.1:
		across = azimuth.cross(Vector3.RIGHT)
	across = across.normalized()
	var distance := 0.0
	var repeats := maxf(1.0, roundf(radii[0] * TAU * 17.0))
	for row in path.size():
		var prior := maxi(row - 1, 0)
		var next := mini(row + 1, path.size() - 1)
		var axis := (path[next] - path[prior]).normalized()
		across = (across - axis * across.dot(axis)).normalized()
		var perpendicular := axis.cross(across).normalized()
		distance += path[row].distance_to(path[prior])
		for column in sides + 1:
			var angle := TAU * (column % sides) / sides
			var radial := across * cos(angle) + perpendicular * sin(angle)
			var lobe := 1.0 + 0.09 * sin(angle * 3.0 + row * 0.37) + 0.038 * cos(angle * 5.0)
			var darkness := lerpf(0.54, 1.0, smoothstep(-0.01, 0.27, path[row].y)) * (0.95 + 0.05 * cos(angle * 2.0))
			vertices.append(path[row] + radial * radii[row] * lobe)
			normals.append(radial)
			uv.append(Vector2(float(column) / sides * repeats + path[0].x * 9.0, distance * 17.0 + path[0].y * 17.0))
			colors.append(Color(darkness, darkness, darkness * lerpf(0.93, 1.0, darkness)))
	var width := sides + 1
	for row in path.size() - 1:
		for column in sides:
			var a := row * width + column
			var b := (row + 1) * width + column
			for index in [a, b, b + 1, a, b + 1, a + 1]:
				bark.set_normal(normals[index])
				bark.set_uv(uv[index])
				bark.set_color(colors[index])
				bark.add_vertex(vertices[index])


func build_understory(fern: bool) -> ArrayMesh:
	random.seed = 1764 if fern else 1566
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch in (10 if fern else 14):
		var angle := branch * GOLDEN_ANGLE
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var spread := random.randf_range(0.13, 0.38)
		var lift := 0.12 + pow(random.randf(), 1.45) * (0.29 if fern else 0.41)
		var slope := random.randf_range(-0.91, -0.27) if fern else random.randf_range(-1.30, -0.56)
		var hinge := radial * spread + Vector3.UP * lift
		var tilt := Basis.from_euler(Vector3(slope, PI * 0.5 - angle, random.randf_range(-0.78, 0.78)))
		var tint := Color("918d75").lerp(Color("e5ddca"), smoothstep(0.09, 0.55, lift))
		var size := random.randf_range(0.22, 0.38) if fern else random.randf_range(0.17, 0.34)
		_cluster(hinge, tilt, size, tint, (radial * 0.48 + Vector3.UP).normalized())
	leaves.index()
	return FoliageLOD.bake(leaves.commit().surface_get_arrays(0))


func build_forest_crown(species: int) -> ArrayMesh:
	random.seed = 10943 + species * 43
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := [0.34, 0.24, 0.40]
	for branch in 8:
		var angle := branch * GOLDEN_ANGLE + random.randf_range(-0.24, 0.16)
		var spread: float = radius[species] * (0.49 + 0.50 * random.randf())
		var axis := Vector3(cos(angle) * spread, 0, sin(angle) * spread)
		var lift := 0.63 + 0.026 * branch + random.randf_range(-0.049, 0.078)
		if branch > 5:
			axis *= 0.47
		for spray in 6:
			var point := axis + Vector3.UP * lift + _direction() * random.randf_range(0.051, 0.149)
			var inclination := Basis.from_euler(Vector3(random.randf_range(-1.44, 1.44), angle + spray * 1.57,
				random.randf_range(-1.46, 1.46)))
			var color := Color("91aa91").lerp(Color("ddd3a9"), 0.37 + random.randf() * 0.52)
			_cluster(point, inclination, random.randf_range(0.128, 0.205), color,
				(point - Vector3.UP * 0.46).normalized(), false)
	leaves.index()
	return FoliageLOD.apply(leaves.commit(), 6)
