extends SceneTree

# Wave hatch inspired by the early Gol 1000; original geometry. Build offline; gameplay loads only these saved meshes.
const OUTPUT := "res://assets/models/hatch_1000"
const PAINT := Color("7098ac")
const ROOF := Color("7098ac")
const CHROME := Color("919a9d")
const DARK := Color("252b30")
const GLASS := Color("7198ab")
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_material("paint", 0.32, 0.38)
	_material("chrome", 0.24, 0.72)
	_material("dark", 0.88, 0.0)
	_material("glass", 0.10, 0.05)
	_material("lens", 0.24, 0.0)
	_material("headlight_glass", 0.15, 0.05)
	_material("rubber", 0.96, 0.0)
	_build_body()
	if not _save_mesh("body.tres"):
		quit(1)
		return
	_build_wheel()
	quit(0 if _save_mesh("wheel.tres") else 1)

func _material(label: String, roughness: float, metallic: float) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "Hatch1000_" + label
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.metallic = metallic
	if label == "paint":
		material.clearcoat_enabled = true
		material.clearcoat = 0.55
		material.clearcoat_roughness = 0.24
	if label in ["glass", "headlight_glass"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[label] = material

func _surface(label: String) -> SurfaceTool:
	if not surfaces.has(label):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(materials[label])
		surfaces[label] = surface
	return surfaces[label]

func _triangle(a: Vector3, b: Vector3, c: Vector3, label: String, color: Color, outward: Vector3) -> void:
	# Godot front faces use clockwise winding and explicit outward normals.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	if (c - a).cross(b - a).length_squared() < 0.0000000001:
		return
	var normal := (c - a).cross(b - a).normalized()
	var surface := _surface(label)
	for point in [a, b, c]:
		var shading_normal := normal
		if label == "rubber" and absf(normal.y) < 0.3:
			shading_normal = Vector3(point.x, 0, point.z).normalized()
		surface.set_normal(shading_normal)
		surface.set_color(Color(color, 0.35 if label in ["glass", "headlight_glass"] else color.a).srgb_to_linear())
		surface.add_vertex(point)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, label: String, color: Color, outward: Vector3) -> void:
	_triangle(a, b, c, label, color, outward)
	_triangle(a, c, d, label, color, outward)

func _box(center: Vector3, size: Vector3, label: String, color: Color) -> void:
	var half := size * 0.5
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := center
				point[axis] += sign_value * half[axis]
				point[u] += corner.x * half[u]
				point[v] += corner.y * half[v]
				points.append(point)
			_quad(points[0], points[1], points[2], points[3], label, color, normal)

func _line(a: Vector3, b: Vector3, width: float, label: String, color: Color) -> void:
	var direction := (b - a).normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * width * 0.5
	var up := direction.cross(side).normalized() * width * 0.5
	_quad(a - side - up, b - side - up, b + side - up, a + side - up, label, color, -up)
	_quad(a - side + up, b - side + up, b + side + up, a + side + up, label, color, up)
	_quad(a - side - up, b - side - up, b - side + up, a - side + up, label, color, -side)
	_quad(a + side - up, b + side - up, b + side + up, a + side + up, label, color, side)

func _round_face(center: Vector3, radius: float, outward: Vector3, label: String, color: Color, segments: int = 20) -> void:
	var right := outward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(outward).normalized()
	for index in segments:
		var a := TAU * index / segments
		var b := TAU * (index + 1) / segments
		_triangle(center, center + radius * (right * cos(a) + up * sin(a)), center + radius * (right * cos(b) + up * sin(b)), label, color, outward)

func _body_width(z: float) -> float:
	return lerpf(0.72, 0.80, clampf((1.86 - absf(z)) / 0.3, 0.0, 1.0))

func _body_height(z: float) -> float:
	return lerpf(0.31, 0.47, clampf((1.86 - absf(z)) / 0.25, 0.0, 1.0))

func _build_body() -> void:
	# Dense longitudinal rings and an actual curved shoulder replace flat panels.
	var stations: Array[float] = []
	for index in 25:
		stations.append(lerpf(-1.86, 1.86, index / 24.0))
	for wheel_z in [-1.13, 1.13]:
		for segment in 33:
			stations.append(wheel_z + 0.365 * cos(PI * segment / 32.0))
	stations.sort()
	for index in range(stations.size() - 1):
		var z0 := stations[index]
		var z1 := stations[index + 1]
		if z1 - z0 < 0.00001:
			continue
		for section in 16:
			var t0 := -1.0 + section / 8.0
			var t1 := t0 + 0.125
			_smooth_quad([_hood_point(z0, t0), _hood_point(z1, t0), _hood_point(z1, t1), _hood_point(z0, t1)], [_hood_normal(z0, t0), _hood_normal(z1, t0), _hood_normal(z1, t1), _hood_normal(z0, t1)], "paint", PAINT)
		for side in [-1.0, 1.0]:
			for row in 6:
				var r0 := row / 6.0
				var r1 := (row + 1) / 6.0
				var points: Array[Vector3] = [_side_point(z0, r0, side), _side_point(z1, r0, side), _side_point(z1, r1, side), _side_point(z0, r1, side)]
				var normals: Array[Vector3] = []
				for point in points:
					normals.append(_side_normal(point, side))
				_smooth_quad(points, normals, "paint", PAINT)
	for side in [-1.0, 1.0]:
		for wheel_z in [-1.13, 1.13]:
			# Dark wheel-well liners block the view through the gap above each tire.
			for segment in 16:
				var a := PI * segment / 16.0
				var b := PI * (segment + 1) / 16.0
				_quad(Vector3(side * 0.67, -0.04 + 0.31 * sin(a), wheel_z + 0.31 * cos(a)), Vector3(side * 0.67, -0.04 + 0.362 * sin(a), wheel_z + 0.362 * cos(a)), Vector3(side * 0.67, -0.04 + 0.362 * sin(b), wheel_z + 0.362 * cos(b)), Vector3(side * 0.67, -0.04 + 0.31 * sin(b), wheel_z + 0.31 * cos(b)), "dark", Color("171b1e"), Vector3.RIGHT * side)
			for segment in 16:
				var a := PI * segment / 16.0
				var b := PI * (segment + 1) / 16.0
				_line(Vector3(side * 0.807, -0.04 + 0.373 * sin(a), wheel_z + 0.373 * cos(a)), Vector3(side * 0.807, -0.04 + 0.373 * sin(b), wheel_z + 0.373 * cos(b)), 0.014, "dark", DARK)
		_line(Vector3(side * 0.81, 0.365, -1.35), Vector3(side * 0.81, 0.365, 1.35), 0.018, "dark", DARK)
		for z in [-0.57, 0.57]:
			_panel_seam(side, Vector2(z, -0.12), Vector2(z, 0.4))
		_panel_seam(side, Vector2(-0.57, -0.12), Vector2(0.57, -0.12))
		_box(Vector3(side * 0.817, 0.34, 0.37), Vector3(0.028, 0.028, 0.14), "dark", DARK)
		_box(Vector3(side * 0.82, 0.335, -0.82), Vector3(0.025, 0.05, 0.09), "lens", Color("e5a546"))
	_box(Vector3(0, -0.18, 0), Vector3(1.35, 0.07, 3.15), "dark", DARK)
	_build_interior()
	_build_cabin()
	_build_ends()
	_panel_details()

func _build_cabin() -> void:
	var front_low := Vector3(0.74, 0.49, -0.70)
	var front_top := Vector3(0.64, 1.02, -0.16)
	var rear_low := Vector3(0.74, 0.49, 1.72)
	var rear_top := Vector3(0.64, 1.02, 0.90)
	for side in [-1.0, 1.0]:
		var fl := front_low * Vector3(side, 1, 1)
		var ft := front_top * Vector3(side, 1, 1)
		var rl := rear_low * Vector3(side, 1, 1)
		var rt := rear_top * Vector3(side, 1, 1)
		var window: Array[Vector3] = [Vector3(side * 0.735, 0.55, -0.53), Vector3(side * 0.655, 0.965, -0.17), Vector3(side * 0.655, 0.965, 0.81), Vector3(side * 0.735, 0.55, 1.58)]
		var perimeter: Array[Vector3] = [fl, ft, rt, rl]
		for index in 4:
			_quad(perimeter[index], perimeter[(index + 1) % 4], window[(index + 1) % 4], window[index], "paint", PAINT, Vector3.RIGHT * side)
		_glass_panel(window, Vector3.RIGHT * side)
		for index in 4:
			_line(window[index], window[(index + 1) % 4], 0.018, "dark", DARK)
		_line(Vector3(side * 0.739, 0.55, 0.48), Vector3(side * 0.655, 0.965, 0.48), 0.06, "dark", DARK)
		_line(Vector3(side * 0.739, 0.55, -0.35), Vector3(side * 0.65, 0.93, -0.15), 0.015, "dark", DARK)
		_line(Vector3(side * 0.78, 0.53, -0.57), Vector3(side * 1.00, 0.59, -0.57), 0.025, "dark", DARK)
		_ellipsoid(Vector3(side * 0.98, 0.61, -0.57), Vector3(0.105, 0.065, 0.105), "paint", PAINT)
		_box(Vector3(side * 1.013, 0.61, -0.488), Vector3(0.075, 0.08, 0.012), "glass", GLASS)
	for front in [true, false]:
		var lower := front_low if front else rear_low
		var upper := front_top if front else rear_top
		var normal := Vector3.FORWARD if front else Vector3.BACK
		var low := lower.lerp(upper, 0.075)
		var high := lower.lerp(upper, 0.91)
		var points: Array[Vector3] = [Vector3(-low.x + 0.045, low.y, low.z), Vector3(low.x - 0.045, low.y, low.z), Vector3(high.x - 0.045, high.y, high.z), Vector3(-high.x + 0.045, high.y, high.z)]
		for index in 4:
			points[index] += normal * 0.008
		var perimeter: Array[Vector3] = [Vector3(-lower.x, lower.y, lower.z), Vector3(lower.x, lower.y, lower.z), Vector3(upper.x, upper.y, upper.z), Vector3(-upper.x, upper.y, upper.z)]
		for index in 4:
			_quad(perimeter[index], perimeter[(index + 1) % 4], points[(index + 1) % 4], points[index], "paint", PAINT, normal)
		_glass_panel([points[0], points[3], points[2], points[1]], normal)
		for index in 4:
			_line(points[index], points[(index + 1) % 4], 0.025, "dark", DARK)
			_line(points[index] + normal * 0.006, points[(index + 1) % 4] + normal * 0.006, 0.012, "dark", DARK)
		if front:
			for side in [-1.0, 1.0]:
				_line(Vector3(side * 0.32, 0.555, -0.62), Vector3(side * 0.15, 0.62, -0.568), 0.012, "dark", DARK)
	for row in 12:
		for column in 20:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var x := -0.64 + 1.28 * (column + corner.x) / 20.0
				var z := -0.17 + 1.08 * (row + corner.y) / 12.0
				var y := 1.025 + 0.065 * (1.0 - pow(x / 0.64, 2)) + 0.018 * sin(PI * (z + 0.17) / 1.08)
				points.append(Vector3(x, y, z))
				normals.append(Vector3(0.13 * x / (0.64 * 0.64), 1, -0.018 * PI / 1.08 * cos(PI * (z + 0.17) / 1.08)).normalized())
			_smooth_quad(points, normals, "paint", ROOF)

func _build_ends() -> void:
	for side in [-1.0, 1.0]:
		var normal: Vector3 = Vector3.BACK * side
		_quad(Vector3(-0.72, -0.20, side * 1.86), Vector3(0.72, -0.20, side * 1.86), Vector3(0.72, 0.31, side * 1.86), Vector3(-0.72, 0.31, side * 1.86), "paint", PAINT, normal)
		_bevel_bumper(Vector3(0, -0.025, side * 1.89), normal)
		_box(Vector3(0, -0.028, side * 1.973), Vector3(0.32, 0.10, 0.012), "paint", ROOF)
		for x in [-0.74, 0.74]:
			_box(Vector3(x, -0.025, side * 1.79), Vector3(0.12, 0.20, 0.28), "dark", DARK)
	_box(Vector3(0, 0.19, -1.875), Vector3(0.52, 0.19, 0.022), "dark", DARK)
	for height in [0.12, 0.17, 0.22, 0.27]:
		_box(Vector3(0, height, -1.89), Vector3(0.51, 0.012, 0.012), "chrome", Color("555c5d"))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.49, 0.19, -1.877), Vector3(0.41, 0.19, 0.018), "dark", DARK)
		_box(Vector3(side * 0.48, 0.19, -1.89), Vector3(0.35, 0.155, 0.012), "chrome", Color("676e6e"))
		for bulb_x in [-0.078, 0.078]:
			_reflector(Vector3(side * 0.48 + bulb_x, 0.19, -1.907))
		_box(Vector3(side * 0.48, 0.19, -1.929), Vector3(0.35, 0.155, 0.008), "headlight_glass", Color("bbced1"))
		_box(Vector3(side * 0.70, 0.19, -1.887), Vector3(0.105, 0.155, 0.025), "lens", Color("de922a"))
		_box(Vector3(side * 0.50, 0.18, 1.875), Vector3(0.40, 0.19, 0.025), "dark", DARK)
		_box(Vector3(side * 0.45, 0.15, 1.891), Vector3(0.25, 0.085, 0.012), "lens", Color("b23229"))
		_box(Vector3(side * 0.63, 0.225, 1.891), Vector3(0.13, 0.065, 0.012), "lens", Color("e7a238"))
		_box(Vector3(side * 0.40, 0.225, 1.891), Vector3(0.13, 0.065, 0.012), "lens", Color("d8d8c7"))
	_box(Vector3(0, 0.33, 1.879), Vector3(0.13, 0.03, 0.015), "dark", DARK)
	_line(Vector3(-0.30, 0.66, 1.49), Vector3(0.20, 0.67, 1.48), 0.015, "dark", DARK)
	_box(Vector3(-0.52, -0.23, 1.73), Vector3(0.07, 0.07, 0.24), "dark", DARK)

func _glass_panel(points: Array, outward: Vector3) -> void:
	# Subdivided glazing has a subtle real bow, so reflections follow its surface.
	for row in 4:
		for column in 8:
			var vertices: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var u := (column + corner.x) / 8.0
				var v := (row + corner.y) / 4.0
				vertices.append(_glazing_point(points, u, v, outward))
				var du := _glazing_point(points, u + 0.001, v, outward) - _glazing_point(points, u - 0.001, v, outward)
				var dv := _glazing_point(points, u, v + 0.001, outward) - _glazing_point(points, u, v - 0.001, outward)
				var normal := du.cross(dv).normalized()
				normals.append(normal if normal.dot(outward) > 0 else -normal)
			_smooth_quad(vertices, normals, "glass", Color(Color("7e929a"), 0.40))

func _glazing_point(points: Array, u: float, v: float, outward: Vector3) -> Vector3:
	return points[0].lerp(points[3], u).lerp(points[1].lerp(points[2], u), v) + outward * (0.003 + 0.012 * sin(PI * u) * sin(PI * v))

func _build_interior() -> void:
	var fabric := Color("343a3d")
	_box(Vector3(0, 0.06, 0.40), Vector3(1.35, 0.10, 2.35), "dark", Color("171c20"))
	_box(Vector3(0, 0.43, -0.48), Vector3(1.34, 0.16, 0.38), "dark", DARK)
	_box(Vector3(0, 0.27, 0.18), Vector3(0.18, 0.25, 0.68), "dark", DARK)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.35, 0.28, 0.14), Vector3(0.23, 0.075, 0.235), "dark", fabric)
		_box(Vector3(side * 0.35, 0.51, 0.36), Vector3(0.46, 0.48, 0.12), "dark", fabric)
		_ellipsoid(Vector3(side * 0.35, 0.80, 0.38), Vector3(0.13, 0.065, 0.055), "dark", fabric)
		for rib in 5:
			_line(Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, -0.05), Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, 0.30), 0.005, "dark", Color("53595b"))
		_box(Vector3(side * 0.697, 0.33, 0.58), Vector3(0.025, 0.25, 1.3), "dark", fabric)
	_box(Vector3(0, 0.28, 1.08), Vector3(1.12, 0.15, 0.40), "dark", fabric)
	_box(Vector3(0, 0.48, 1.24), Vector3(1.12, 0.34, 0.12), "dark", fabric)
	_box(Vector3(0, 0.51, 1.44), Vector3(1.30, 0.04, 0.28), "dark", Color("20262b"))
	var steering := Vector3(-0.34, 0.57, -0.26)
	for segment in 24:
		var a := TAU * segment / 24
		var b := TAU * (segment + 1) / 24
		_line(steering + Vector3(cos(a) * 0.14, sin(a) * 0.11, 0), steering + Vector3(cos(b) * 0.14, sin(b) * 0.11, 0), 0.016, "dark", DARK)
	for side in [-1.0, 1.0]:
		_line(steering, steering + Vector3(side * 0.13, 0, 0), 0.02, "dark", DARK)
	_line(Vector3(0, 0.40, 0.02), Vector3(0, 0.51, 0.02), 0.018, "dark", DARK)
	_box(Vector3(0, 0.83, -0.09), Vector3(0.20, 0.07, 0.04), "dark", DARK)
	_box(Vector3(-0.34, 0.50, -0.27), Vector3(0.26, 0.09, 0.012), "dark", Color("161a1d"))


func _bevel_bumper(center: Vector3, outward: Vector3) -> void:
	var profile: Array[Vector2] = [Vector2(-0.815, -0.07), Vector2(-0.77, -0.10), Vector2(0.77, -0.10), Vector2(0.815, -0.07), Vector2(0.815, 0.07), Vector2(0.77, 0.10), Vector2(-0.77, 0.10), Vector2(-0.815, 0.07)]
	for index in profile.size():
		var a := profile[index]
		var b := profile[(index + 1) % profile.size()]
		_quad(center + Vector3(a.x, a.y, -0.06), center + Vector3(b.x, b.y, -0.06), center + Vector3(b.x, b.y, 0.06), center + Vector3(a.x, a.y, 0.06), "dark", DARK, Vector3(a.x, a.y, 0).normalized())
		_triangle(center + outward * 0.061, center + Vector3(a.x, a.y, outward.z * 0.061), center + Vector3(b.x, b.y, outward.z * 0.061), "dark", DARK, outward)
	_line(center + Vector3(-0.74, 0.05, outward.z * 0.064), center + Vector3(0.74, 0.05, outward.z * 0.064), 0.012, "chrome", Color("5c6770"))

func _panel_details() -> void:
	# Panel seams, hood crease, grille depth, lens ribs and inset plates.
	for side in [-1.0, 1.0]:
		for segment in 8:
			var z0 := lerpf(-0.75, -1.57, segment / 8.0)
			var z1 := lerpf(-0.75, -1.57, (segment + 1) / 8.0)
			var a := _hood_point(z0, side * 0.68 / (_body_width(z0) - 0.006)) + Vector3.UP * 0.002
			var b := _hood_point(z1, side * 0.68 / (_body_width(z1) - 0.006)) + Vector3.UP * 0.002
			_line(a, b, 0.004, "dark", Color("243542"))
		_line(Vector3(side * 0.79, 0.04, -0.49), Vector3(side * 0.79, 0.04, 0.50), 0.018, "paint", Color("416e91"))
		for rib in 9:
			_box(Vector3(side * 0.48 + (rib - 4) * 0.033, 0.19, -1.934), Vector3(0.004, 0.135, 0.004), "headlight_glass", Color("8a9da4"))
		_line(Vector3(side * 0.34, 0.195, 1.901), Vector3(side * 0.69, 0.195, 1.901), 0.009, "dark", DARK)
	for z in [-1.982, 1.982]:
		_box(Vector3(0, -0.025, z), Vector3(0.34, 0.115, 0.006), "dark", DARK)
		_box(Vector3(0, -0.025, z + signf(z) * 0.004), Vector3(0.30, 0.080, 0.004), "lens", Color("d4dcdb"))
		for letter in 6:
			_box(Vector3((letter - 2.5) * 0.035, -0.025, z + signf(z) * 0.008), Vector3(0.015, 0.037, 0.002), "dark", Color("354352"))
	_round_face(Vector3(0, 0.195, -1.913), 0.028, Vector3.FORWARD, "chrome", CHROME, 12)
	_box(Vector3(0, 0.43, 1.90), Vector3(0.38, 0.025, 0.09), "paint", PAINT)

func _build_wheel() -> void:
	# Local Y is the axle, matching the existing controller's spin axis.
	var profile: Array[Vector2] = [Vector2(-0.088, 0.24), Vector2(-0.085, 0.28), Vector2(-0.065, 0.31), Vector2(0.065, 0.31), Vector2(0.085, 0.28), Vector2(0.088, 0.24)]
	for ring in range(profile.size() - 1):
		for segment in 48:
			var a := TAU * segment / 48.0
			var b := TAU * (segment + 1) / 48.0
			var p := profile[ring]
			var q := profile[ring + 1]
			_quad(Vector3(p.y * cos(a), p.x, p.y * sin(a)), Vector3(p.y * cos(b), p.x, p.y * sin(b)), Vector3(q.y * cos(b), q.x, q.y * sin(b)), Vector3(q.y * cos(a), q.x, q.y * sin(a)), "rubber", Color("202528"), Vector3(cos((a + b) / 2), 0, sin((a + b) / 2)))
	for segment in 40:
		var a := TAU * segment / 40
		for side in [-1.0, 1.0]:
			var b: float = a + side * 0.05
			_line(Vector3(0.311 * cos(a), 0, 0.311 * sin(a)), Vector3(0.311 * cos(b), side * 0.057, 0.311 * sin(b)), 0.0035, "rubber", Color("111619"))
	for side in [-1.0, 1.0]:
		_round_face(Vector3(0, side * 0.091, 0), 0.254, Vector3.UP * side, "rubber", Color("282d31"), 32)
		_round_face(Vector3(0, side * 0.094, 0), 0.205, Vector3.UP * side, "chrome", Color("9da7af"), 32)
		_round_face(Vector3(0, side * 0.097, 0), 0.176, Vector3.UP * side, "chrome", Color("6e777c"), 32)
		for hole in 16:
			var angle := TAU * hole / 16
			_round_face(Vector3(0.14 * cos(angle), side * 0.098, 0.14 * sin(angle)), 0.006, Vector3.UP * side, "dark", DARK, 6)
		for spoke in 5:
			var angle := TAU * spoke / 5.0
			_line(Vector3(0.06 * cos(angle), side * 0.104, 0.06 * sin(angle)), Vector3(0.19 * cos(angle + 0.10), side * 0.103, 0.19 * sin(angle + 0.10)), 0.038, "chrome", CHROME)
		_round_face(Vector3(0, side * 0.125, 0), 0.062, Vector3.UP * side, "chrome", Color("a9b2b7"), 16)
		for bolt in 5:
			var angle := TAU * bolt / 5.0
			_round_face(Vector3(0.037 * cos(angle), side * 0.128, 0.037 * sin(angle)), 0.008, Vector3.UP * side, "dark", DARK, 6)
		for ring in [0.225, 0.28]:
			for segment in 32:
				var angle := TAU * segment / 32.0
				_line(Vector3(ring * cos(angle), side * 0.092, ring * sin(angle)), Vector3(ring * cos(angle + TAU / 32), side * 0.092, ring * sin(angle + TAU / 32)), 0.006, "rubber", Color("3c4246"))

func _save_mesh(filename: String) -> bool:
	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in surfaces.values():
		surface.index()
		surface.commit(mesh)
	var error := ResourceSaver.save(mesh, OUTPUT.path_join(filename))
	if error != OK:
		push_error("Could not save Hatch 1000: %s" % error_string(error))
		return false
	print("Hatch 1000 saved: %s · %d surfaces · %d triangles" % [filename, mesh.get_surface_count(), mesh.get_faces().size() / 3])
	surfaces.clear()
	return true

func _reflector(center: Vector3) -> void:
	for segment in 20:
		var a := TAU * segment / 20
		var b := TAU * (segment + 1) / 20
		var p := center + Vector3(cos(a) * 0.068, sin(a) * 0.063, -0.014)
		var q := center + Vector3(cos(b) * 0.068, sin(b) * 0.063, -0.014)
		_triangle(center + Vector3.BACK * 0.015, p, q, "chrome", CHROME, Vector3.FORWARD)
	_round_face(center + Vector3.FORWARD * 0.019, 0.013, Vector3.FORWARD, "lens", Color("dbd1af"), 12)

func _hood_point(z: float, t: float) -> Vector3:
	return Vector3((_body_width(z) - 0.006) * t, _body_height(z) - 0.055 + 0.08 * pow(maxf(0, 1 - t * t), 0.45), z)

func _hood_normal(z: float, t: float) -> Vector3:
	if absf(t) > 0.999:
		return Vector3(signf(t), 0, 0)
	var across := _hood_point(z, minf(t + 0.001, 1)) - _hood_point(z, maxf(t - 0.001, -1))
	var along := _hood_point(z + 0.001, t) - _hood_point(z - 0.001, t)
	return along.cross(across).normalized()

func _arch_bottom(z: float) -> float:
	var lower := -0.20
	for wheel_z in [-1.13, 1.13]:
		var distance := absf(z - wheel_z)
		if distance <= 0.365:
			lower = maxf(lower, -0.04 + sqrt(maxf(0, 0.365 * 0.365 - distance * distance)))
	return lower

func _side_width(z: float, y: float) -> float:
	return _body_width(z) - 0.006 + 0.015 * sin(PI * clampf((y + 0.20) / 0.615, 0, 1)) - 0.034 * pow(clampf((0.12 - y) / 0.32, 0, 1), 2)

func _side_point(z: float, fraction: float, side: float) -> Vector3:
	var y := lerpf(_arch_bottom(z), _body_height(z) - 0.055, fraction)
	return Vector3(side * _side_width(z, y), y, z)

func _side_normal(point: Vector3, side: float) -> Vector3:
	var dy := (_side_width(point.z, point.y + 0.001) - _side_width(point.z, point.y - 0.001)) / 0.002
	var dz := (_side_width(point.z + 0.001, point.y) - _side_width(point.z - 0.001, point.y)) / 0.002
	return Vector3(side, -dy, -dz).normalized()

func _smooth_quad(points: Array[Vector3], normals: Array[Vector3], label: String, color: Color) -> void:
	for ids in [[0, 1, 2], [0, 2, 3]]:
		if (points[ids[1]] - points[ids[0]]).cross(points[ids[2]] - points[ids[0]]).dot(normals[ids[0]]) > 0:
			ids.reverse()
		var surface := _surface(label)
		for index: int in ids:
			surface.set_normal(normals[index])
			surface.set_color(color.srgb_to_linear())
			surface.add_vertex(points[index])

func _ellipsoid(center: Vector3, radii: Vector3, label: String, color: Color) -> void:
	for ring in 8:
		for segment in 16:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var a := PI * (ring + corner.x) / 8
				var b := TAU * (segment + corner.y) / 16
				var direction := Vector3(sin(a) * cos(b), cos(a), sin(a) * sin(b))
				points.append(center + direction * radii)
				normals.append((direction / radii).normalized())
			_smooth_quad(points, normals, label, color)

func _panel_seam(side: float, start: Vector2, end: Vector2) -> void:
	for segment in 8:
		var a := start.lerp(end, segment / 8.0)
		var b := start.lerp(end, (segment + 1) / 8.0)
		_line(Vector3(side * (_side_width(a.x, a.y) + 0.003), a.y, a.x), Vector3(side * (_side_width(b.x, b.y) + 0.003), b.y, b.x), 0.005, "dark", DARK)
