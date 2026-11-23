extends RefCounted

# A parked vehicle needs the silhouette and optics, not the player's cabin,
# suspension and multi-material wheel assemblies. One opaque surface per car.
static func build(paint: Color, detailed := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	_box(tool, Vector3(0, 0.34, 0), Vector3(1.68, 0.58, 3.8), paint)
	_box(tool, Vector3(0, 0.19, -1.92), Vector3(1.72, 0.2, 0.15), Color("30393b"))
	_box(tool, Vector3(0, 0.19, 1.92), Vector3(1.72, 0.2, 0.15), Color("30393b"))
	var glass := Color("38505a")
	# Tapered upright cabin of the project's square hatch.
	var a := Vector3(-0.78, 0.63, -0.83)
	var b := Vector3(0.78, 0.63, -0.83)
	var c := Vector3(-0.65, 1.26, -0.42)
	var d := Vector3(0.65, 1.26, -0.42)
	var e := Vector3(-0.78, 0.63, 1.62)
	var f := Vector3(0.78, 0.63, 1.62)
	var g := Vector3(-0.65, 1.26, 1.27)
	var h := Vector3(0.65, 1.26, 1.27)
	_quad(tool, a, c, d, b, glass)
	_quad(tool, e, f, h, g, glass)
	_quad(tool, a, e, g, c, glass)
	_quad(tool, b, d, h, f, glass)
	_quad(tool, c, g, h, d, paint)
	for side: float in [-1, 1]:
		_box(tool, Vector3(side * 0.705, 0.96, 0.33), Vector3(0.06, 0.6, 0.075), paint)
		_box(tool, Vector3(side * 0.87, 0.74, -0.55), Vector3(0.18, 0.1, 0.14), Color("30393b"))
		_box(tool, Vector3(side * 0.54, 0.5, -1.907), Vector3(0.46, 0.22, 0.025), Color("d1d7c9"))
		_box(tool, Vector3(side * 0.6, 0.47, 1.907), Vector3(0.38, 0.22, 0.025), Color("9c302d"))
		for z: float in [-1.13, 1.13]:
			_wheel(tool, Vector3(side * 0.77, -0.04, z), detailed)
	if detailed:
		_trim(tool, paint)
	tool.generate_normals()
	tool.index()
	return tool.commit()

static func _trim(tool: SurfaceTool, paint: Color) -> void:
	var rubber := Color("252b2b")
	var alloy := Color("a7aaa1")
	_box(tool, Vector3(0, 0.49, -1.914), Vector3(0.60, 0.19, 0.035), rubber)
	for y: float in [0.43, 0.49, 0.55]:
		_box(tool, Vector3(0, y, -1.936), Vector3(0.57, 0.019, 0.015), Color("545755"))
	for direction: float in [-1, 1]:
		_box(tool, Vector3(0, 0.24, direction * 2.0), Vector3(0.35, 0.14, 0.035), rubber)
		_box(tool, Vector3(0, 0.24, direction * 2.022), Vector3(0.29, 0.105, 0.014), Color("e6e1cf"))
	for side: float in [-1, 1]:
		_box(tool, Vector3(side * 0.841, 0.34, 0), Vector3(0.026, 0.061, 3.75), rubber)
		_box(tool, Vector3(side * 0.849, 0.53, 0.28), Vector3(0.028, 0.051, 0.19), rubber)
		_box(tool, Vector3(side * 0.864, 0.534, 0.28), Vector3(0.012, 0.018, 0.138), alloy)
		_box(tool, Vector3(side * 0.66, 0.45, -1.926), Vector3(0.15, 0.09, 0.021), Color("ca8138"))
		_box(tool, Vector3(side * 0.53, 0.44, 1.927), Vector3(0.16, 0.064, 0.021), Color("d6b8a0"))
		var lo := side * 0.79
		var hi := side * 0.66
		_quad(tool, Vector3(lo, 0.63, -0.85), Vector3(hi, 1.26, -0.44), Vector3(hi, 1.257, -0.35), Vector3(lo, 0.63, -0.73), paint)
		_quad(tool, Vector3(lo, 0.63, 1.52), Vector3(hi, 1.26, 1.17), Vector3(hi, 1.26, 1.29), Vector3(lo, 0.63, 1.64), paint)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	for point in [a, c, b, a, d, c]:
		tool.add_vertex(point)


static func _box(tool: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var p := size / 2
	var corners := [centre + Vector3(-p.x, -p.y, -p.z), centre + Vector3(p.x, -p.y, -p.z), centre + Vector3(p.x, p.y, -p.z), centre + Vector3(-p.x, p.y, -p.z), centre + Vector3(-p.x, -p.y, p.z), centre + Vector3(p.x, -p.y, p.z), centre + Vector3(p.x, p.y, p.z), centre + Vector3(-p.x, p.y, p.z)]
	for face in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
		_quad(tool, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], color)


static func _wheel(tool: SurfaceTool, centre: Vector3, detailed: bool) -> void:
	var segments := 16 if detailed else 10
	for index in segments:
		var first := TAU * index / segments
		var last := TAU * (index + 1) / segments
		var a := centre + Vector3(-0.1, cos(first) * 0.31, sin(first) * 0.31)
		var b := centre + Vector3(0.1, cos(first) * 0.31, sin(first) * 0.31)
		var c := centre + Vector3(0.1, cos(last) * 0.31, sin(last) * 0.31)
		var d := centre + Vector3(-0.1, cos(last) * 0.31, sin(last) * 0.31)
		_quad(tool, a, d, c, b, Color("242b2c"))
		for side: float in [-1, 1]:
			var origin := centre + Vector3(side * 0.101, 0, 0)
			var first_point := origin + Vector3(0, cos(first) * 0.31, sin(first) * 0.31)
			var last_point := origin + Vector3(0, cos(last) * 0.31, sin(last) * 0.31)
			tool.set_color(Color("26292a") if detailed else Color("596266"))
			for point in ([origin, last_point, first_point] if side > 0 else [origin, first_point, last_point]):
				tool.add_vertex(point)
			if detailed:
				var hub := origin + Vector3.RIGHT * side * 0.002
				var rim_a := hub + (first_point - origin) * 0.65
				var rim_b := hub + (last_point - origin) * 0.65
				tool.set_color(Color("60666a") if index % 2 == 0 else Color("b3b5aa"))
				for point in ([hub, rim_b, rim_a] if side > 0 else [hub, rim_a, rim_b]):
					tool.add_vertex(point)


static func build_traffic(paint: Color, style: int, parked := false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var body_length: float = [4.05, 4.46, 4.32][style] * 0.5
	var stations := PackedFloat32Array([-body_length, -body_length + 0.13, -1.34, -0.72, 0.10, 0.70, 1.42, body_length - 0.14, body_length])
	var belt := PackedFloat32Array([0.30, 0.43, 0.53, 0.64, 0.65, 0.65, 0.62, 0.54, 0.39])
	if style == 2:
		belt[7] = 0.70
		belt[8] = 0.63
	var lower := Color("262b2c")
	var trim := Color("4f5753")
	var glass := Color("405558")
	var finish := paint.darkened(0.17)
	var skirt := _skirt_stations(stations, style, body_length)
	for index in stations.size() - 1:
		var z := stations[index]
		var next_z := stations[index + 1]
		var top := belt[index]
		var next_top := belt[index + 1]
		var width := _traffic_width(z, body_length)
		var next_width := _traffic_width(next_z, body_length)
		_traffic_face(tool, Vector3(-width + 0.1, top, z), Vector3(-next_width + 0.1, next_top, next_z), Vector3(next_width - 0.1, next_top, next_z), Vector3(width - 0.1, top, z), Vector3.UP, paint.lightened(0.02))
		for side: float in [-1, 1]:
			var a := Vector3(side * width, top - 0.10, z)
			var b := Vector3(side * next_width, next_top - 0.10, next_z)
			_traffic_face(tool, Vector3(side * (width - 0.10), top, z), a, b, Vector3(side * (next_width - 0.10), next_top, next_z), Vector3(side, 0.36, 0.0), paint)
			_traffic_face(tool, a, a - Vector3.UP * 0.13, b - Vector3.UP * 0.13, b, Vector3(side, 0, 0), paint)
	for side: float in [-1, 1]:
		for index in skirt.size() - 1:
			var z := skirt[index]
			var next_z := skirt[index + 1]
			var x := _traffic_width(z, body_length) * side
			var next_x := _traffic_width(next_z, body_length) * side
			var arch := _traffic_arch(z, style)
			var next_arch := _traffic_arch(next_z, style)
			_traffic_face(tool, Vector3(x, _traffic_belt(z, stations, belt) - 0.228, z),
				Vector3(x, arch, z), Vector3(next_x, next_arch, next_z),
				Vector3(next_x, _traffic_belt(next_z, stations, belt) - 0.228, next_z), Vector3(side, 0, 0), finish)
			if maxf(arch, next_arch) > -0.08:
				_traffic_face(tool, Vector3(x + side * 0.014, arch + 0.047, z), Vector3(x, arch, z),
					Vector3(next_x, next_arch, next_z), Vector3(next_x + side * 0.014, next_arch + 0.047, next_z), Vector3(side, 0, 0), trim)
		_box(tool, Vector3(side * 0.82, -0.079, 0.0), Vector3(0.084, 0.087, 1.50), lower)
		_box(tool, Vector3(side * 0.855, 0.48, 0.36), Vector3(0.028, 0.042, 0.19), trim)
		_box(tool, Vector3(side * 0.855, 0.48, -0.37), Vector3(0.028, 0.042, 0.19), trim)
		_box(tool, Vector3(side * 0.859, 0.67, -0.58), Vector3(0.24, 0.10, 0.157), finish)
		_box(tool, Vector3(side * 0.876, 0.67, -0.50), Vector3(0.15, 0.072, 0.008), glass)
	_traffic_cabin(tool, paint, style, glass)
	for direction: float in [-1, 1]:
		var face := body_length * direction
		_box(tool, Vector3(0, 0.217, face - direction * 0.018), Vector3(1.51, 0.29, 0.148), finish)
		_box(tool, Vector3(0, 0.078, face + direction * 0.014), Vector3(1.55, 0.165, 0.173), lower)
		_box(tool, Vector3(0, 0.146, face + direction * 0.097), Vector3(1.51, 0.041, 0.022), trim)
		_box(tool, Vector3(0, 0.276, face + direction * 0.059), Vector3(0.53, 0.14, 0.055), lower)
		for rib in 4:
			_box(tool, Vector3(0, 0.231 + rib * 0.031, face + direction * 0.087), Vector3(0.48, 0.012, 0.006), trim)
		_box(tool, Vector3(0, 0.098, face + direction * 0.112), Vector3(0.31, 0.091, 0.012), Color("b4b1a2"))
		for side: float in [-1, 1]:
			var lens := Color("dbcfb1") if direction < 0 else Color("982e27")
			_box(tool, Vector3(side * 0.572, 0.326, face + direction * 0.055), Vector3(0.39, 0.18, 0.027), lower)
			_box(tool, Vector3(side * 0.557, 0.332, face + direction * 0.071), Vector3(0.28, 0.136, 0.012), lens)
			_box(tool, Vector3(side * 0.717, 0.332, face + direction * 0.060), Vector3(0.079, 0.152, 0.012), Color("c77d39"))
	if parked:
		var axle := float([1.14, 1.28, 1.19][style])
		for side: float in [-1, 1]:
			for z: float in [-axle, axle]:
				_wheel(tool, Vector3(side * 0.755, -0.035, z), true)
	tool.generate_normals()
	tool.index()
	var mesh := tool.commit()
	if not parked:
		return mesh
	var lod := ImporterMesh.new()
	lod.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
	lod.generate_lods(36.0, 0.0, [])
	return lod.get_mesh()


static func build_traffic_wheel() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	_wheel(tool, Vector3.ZERO, true)
	tool.generate_normals()
	tool.index()
	return tool.commit()


static func _skirt_stations(stations: PackedFloat32Array, style: int, length: float) -> PackedFloat32Array:
	var cuts := stations.duplicate()
	var axle: float = [1.14, 1.28, 1.19][style]
	for wheel: float in [-axle, axle]:
		for corner in 11:
			var profile := wheel - 0.34 * cos(PI * corner / 10.0)
			cuts.append(profile)
	for side: float in [-1.0, 1.0]:
		cuts.append(side * (length - 0.34))
		cuts.append(side * (length - 0.25))
	cuts.sort()
	return cuts


static func _traffic_cabin(tool: SurfaceTool, paint: Color, style: int, glass: Color) -> void:
	var top: float = [1.22, 1.12, 1.57][style]
	var back: float = [1.53, 1.42, 1.92][style]
	var upper_back: float = [1.14, 0.77, 1.82][style]
	var upper_front: float = [-0.40, -0.36, -0.47][style]
	var shoulder := 0.74 if style == 2 else 0.66
	var tint := Color("3c4545")
	_traffic_face(tool, Vector3(-0.73, 0.63, -0.81), Vector3(-shoulder, top, upper_front), Vector3(shoulder, top, upper_front), Vector3(0.73, 0.63, -0.81), Vector3(0, 0.58, -1), glass.lightened(0.08))
	_traffic_face(tool, Vector3(-0.73, 0.60, back), Vector3(0.73, 0.60, back), Vector3(shoulder, top, upper_back), Vector3(-shoulder, top, upper_back), Vector3(0, 0.38, 1), glass)
	_traffic_face(tool, Vector3(-shoulder, top, upper_front), Vector3(-shoulder, top, upper_back), Vector3(shoulder, top, upper_back), Vector3(shoulder, top, upper_front), Vector3.UP, paint)
	for side: float in [-1, 1]:
		var a := Vector3(side * 0.734, 0.635, -0.812)
		var b := Vector3(side * shoulder, top - 0.032, upper_front)
		var c := Vector3(side * shoulder, top - 0.032, upper_back)
		var d := Vector3(side * 0.734, 0.627, back)
		_traffic_face(tool, a, b, c, d, Vector3(side, 0.2, 0), paint)
		var glass_side := Vector3(side * 0.008, 0.0, 0.0)
		for section: Vector2 in [Vector2(0.075, 0.455), Vector2(0.50, 0.92)]:
			var lower_start := a.lerp(d, section.x)
			var lower_end := a.lerp(d, section.y)
			var top_start := b.lerp(c, section.x)
			var top_end := b.lerp(c, section.y)
			if style == 2 and section.x > 0.45:
				_traffic_face(tool, lower_start.lerp(top_start, 0.10) + glass_side, top_start.lerp(lower_start, 0.11) + glass_side, top_end.lerp(lower_end, 0.11) + glass_side, lower_end.lerp(top_end, 0.10) + glass_side, Vector3(side, 0.2, 0), paint.darkened(0.13))
			else:
				_traffic_face(tool, lower_start.lerp(top_start, 0.10) + glass_side, top_start.lerp(lower_start, 0.10) + glass_side, top_end.lerp(lower_end, 0.10) + glass_side, lower_end.lerp(top_end, 0.10) + glass_side, Vector3(side, 0.2, 0), glass)
		_box(tool, Vector3(side * 0.738, 0.644, (back - 0.78) * 0.5), Vector3(0.026, 0.045, back + 0.78), tint)


static func _traffic_face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, side: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(side) > 0.0:
		_quad(tool, a, b, c, d, color)
	else:
		_quad(tool, a, d, c, b, color)


static func _traffic_width(z: float, half_length: float) -> float:
	return 0.845 - 0.075 * smoothstep(half_length - 0.34, half_length, absf(z))


static func _traffic_arch(z: float, style: int) -> float:
	var distance := absf(absf(z) - [1.14, 1.28, 1.19][style])
	return -0.112 + sqrt(maxf(0.0, 0.34 * 0.34 - distance * distance)) * 1.15


static func _traffic_belt(z: float, stations: PackedFloat32Array, heights: PackedFloat32Array) -> float:
	var index := clampi(stations.bsearch(z), 1, stations.size() - 1)
	return lerpf(heights[index - 1], heights[index], inverse_lerp(stations[index - 1], stations[index], z))
