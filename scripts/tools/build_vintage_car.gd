extends SceneTree

# Original Wave model. Build offline; gameplay loads only these saved meshes.
const OUTPUT := "res://assets/models/mare_68"
const PAINT := Color("bd5946")
const ROOF := Color("e9dcc0")
const CHROME := Color("b9c4c2")
const DARK := Color("252a2c")
const GLASS := Color("344b53")
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_material("paint", 0.48, 0.18)
	_material("chrome", 0.25, 0.8)
	_material("dark", 0.88, 0.0)
	_material("glass", 0.16, 0.4)
	_material("lens", 0.3, 0.1)
	_build_body()
	if not _save_mesh("body.tres"):
		quit(1)
		return
	_build_wheel()
	quit(0 if _save_mesh("wheel.tres") else 1)

func _material(label: String, roughness: float, metallic: float) -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "Mare68_" + label
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.metallic = metallic
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
		surface.set_normal(normal)
		surface.set_color(color.srgb_to_linear())
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
	return lerpf(0.68, 0.89, clampf((1.72 - absf(z)) / 0.3, 0.0, 1.0))

func _body_height(z: float) -> float:
	return lerpf(0.31, 0.47, clampf((1.72 - absf(z)) / 0.25, 0.0, 1.0))

func _build_body() -> void:
	var stations: Array[float] = [-1.72, -1.58, -1.42, -0.68, 0.72, 1.42, 1.58, 1.72]
	for index in range(stations.size() - 1):
		var rings: Array[Array] = []
		for z in [stations[index], stations[index + 1]]:
			var w := _body_width(z)
			var h := _body_height(z)
			rings.append([Vector3(-w, h - 0.03, z), Vector3(-w + 0.1, h, z), Vector3(0, h + 0.025, z), Vector3(w - 0.1, h, z), Vector3(w, h - 0.03, z)])
		for section in 4:
			_quad(rings[0][section], rings[1][section], rings[1][section + 1], rings[0][section + 1], "paint", PAINT, Vector3.UP)
	for side in [-1.0, 1.0]:
		var outline: Array[Vector2] = []
		for z in stations:
			outline.append(Vector2(z, _body_height(z) - 0.03))
		outline.append(Vector2(1.72, -0.20))
		for wheel_z in [1.1, -1.1]:
			outline.append(Vector2(wheel_z + 0.405, -0.20))
			for segment in 17:
				var angle := PI * segment / 16.0
				outline.append(Vector2(wheel_z + 0.405 * cos(angle), -0.01 + 0.405 * sin(angle)))
			outline.append(Vector2(wheel_z - 0.405, -0.20))
		outline.append(Vector2(-1.72, -0.20))
		var triangles := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
		assert(not triangles.is_empty(), "Wheel arch outline must triangulate")
		for index in range(0, triangles.size(), 3):
			var vertices: Array[Vector3] = []
			for corner in 3:
				var point := outline[triangles[index + corner]]
				vertices.append(Vector3(side * _body_width(point.x), point.y, point.x))
			_triangle(vertices[0], vertices[1], vertices[2], "paint", PAINT, Vector3.RIGHT * side)
		for wheel_z in [-1.1, 1.1]:
			for segment in 16:
				var a := PI * segment / 16.0
				var b := PI * (segment + 1) / 16.0
				_line(Vector3(side * 0.897, -0.01 + 0.413 * sin(a), wheel_z + 0.413 * cos(a)), Vector3(side * 0.897, -0.01 + 0.413 * sin(b), wheel_z + 0.413 * cos(b)), 0.014, "chrome", CHROME)
		_line(Vector3(side * 0.9, 0.405, -1.35), Vector3(side * 0.9, 0.405, 1.35), 0.018, "chrome", CHROME)
		for z in [-0.57, 0.57]:
			_line(Vector3(side * 0.896, -0.12, z), Vector3(side * 0.896, 0.4, z), 0.008, "dark", DARK)
		_line(Vector3(side * 0.897, -0.12, -0.57), Vector3(side * 0.897, -0.12, 0.57), 0.008, "dark", DARK)
		_box(Vector3(side * 0.917, 0.34, 0.37), Vector3(0.028, 0.028, 0.14), "chrome", CHROME)
		_box(Vector3(side * 0.92, 0.335, -0.82), Vector3(0.025, 0.05, 0.09), "lens", Color("e5a546"))
	_box(Vector3(0, -0.18, 0), Vector3(1.35, 0.07, 3.15), "dark", DARK)
	_build_cabin()
	_build_ends()

func _build_cabin() -> void:
	var front_low := Vector3(0.77, 0.49, -0.65)
	var front_top := Vector3(0.61, 1.02, -0.23)
	var rear_low := Vector3(0.77, 0.49, 0.94)
	var rear_top := Vector3(0.61, 1.02, 0.47)
	for side in [-1.0, 1.0]:
		var fl := front_low * Vector3(side, 1, 1)
		var ft := front_top * Vector3(side, 1, 1)
		var rl := rear_low * Vector3(side, 1, 1)
		var rt := rear_top * Vector3(side, 1, 1)
		_quad(fl, ft, rt, rl, "paint", PAINT, Vector3.RIGHT * side)
		var window: Array[Vector3] = [Vector3(side * 0.759, 0.55, -0.53), Vector3(side * 0.634, 0.965, -0.17), Vector3(side * 0.634, 0.965, 0.40), Vector3(side * 0.759, 0.55, 0.81)]
		_quad(window[0], window[1], window[2], window[3], "glass", GLASS, Vector3.RIGHT * side)
		for index in 4:
			_line(window[index], window[(index + 1) % 4], 0.018, "chrome", CHROME)
		_line(Vector3(side * 0.762, 0.55, 0.15), Vector3(side * 0.637, 0.965, 0.15), 0.032, "paint", PAINT)
		_line(Vector3(side * 0.762, 0.55, -0.35), Vector3(side * 0.65, 0.93, -0.15), 0.015, "chrome", CHROME)
		_line(Vector3(side * 0.78, 0.53, -0.57), Vector3(side * 1.00, 0.59, -0.57), 0.025, "chrome", CHROME)
		_box(Vector3(side * 1.01, 0.61, -0.57), Vector3(0.10, 0.11, 0.15), "chrome", CHROME)
		_box(Vector3(side * 1.013, 0.61, -0.488), Vector3(0.075, 0.08, 0.012), "glass", GLASS)
	for front in [true, false]:
		var lower := front_low if front else rear_low
		var upper := front_top if front else rear_top
		var normal := Vector3.FORWARD if front else Vector3.BACK
		_quad(Vector3(-lower.x, lower.y, lower.z), Vector3(lower.x, lower.y, lower.z), Vector3(upper.x, upper.y, upper.z), Vector3(-upper.x, upper.y, upper.z), "paint", PAINT, normal)
		var low := lower.lerp(upper, 0.075)
		var high := lower.lerp(upper, 0.91)
		var points: Array[Vector3] = [Vector3(-low.x + 0.045, low.y, low.z), Vector3(low.x - 0.045, low.y, low.z), Vector3(high.x - 0.045, high.y, high.z), Vector3(-high.x + 0.045, high.y, high.z)]
		for index in 4:
			points[index] += normal * 0.008
		_quad(points[0], points[1], points[2], points[3], "glass", GLASS, normal)
		for index in 4:
			_line(points[index], points[(index + 1) % 4], 0.025, "dark", DARK)
			_line(points[index] + normal * 0.006, points[(index + 1) % 4] + normal * 0.006, 0.012, "chrome", CHROME)
		if front:
			for side in [-1.0, 1.0]:
				_line(Vector3(side * 0.32, 0.555, -0.62), Vector3(side * 0.15, 0.62, -0.568), 0.012, "dark", DARK)
	for index in 8:
		var x0 := -0.62 + 1.24 * index / 8.0
		var x1 := -0.62 + 1.24 * (index + 1) / 8.0
		var h0 := 1.025 + 0.065 * (1.0 - pow(x0 / 0.62, 2))
		var h1 := 1.025 + 0.065 * (1.0 - pow(x1 / 0.62, 2))
		_quad(Vector3(x0, h0, -0.24), Vector3(x0, h0, 0.48), Vector3(x1, h1, 0.48), Vector3(x1, h1, -0.24), "paint", ROOF, Vector3.UP)
		for z in [-0.24, 0.48]:
			_quad(Vector3(x0, h0, z), Vector3(x1, h1, z), Vector3(x1, 1.015, z), Vector3(x0, 1.015, z), "paint", ROOF, Vector3.FORWARD if z < 0 else Vector3.BACK)

func _build_ends() -> void:
	for sign_value in [-1.0, 1.0]:
		var normal: Vector3 = Vector3.BACK * sign_value
		_quad(Vector3(-0.68, -0.20, sign_value * 1.72), Vector3(0.68, -0.20, sign_value * 1.72), Vector3(0.68, 0.28, sign_value * 1.72), Vector3(-0.68, 0.28, sign_value * 1.72), "paint", PAINT, normal)
		_box(Vector3(0, -0.035, sign_value * 1.78), Vector3(1.53, 0.11, 0.10), "chrome", CHROME)
		for side in [-1.0, 1.0]:
			_box(Vector3(side * 0.76, -0.035, sign_value * 1.69), Vector3(0.12, 0.11, 0.23), "chrome", CHROME)
			_box(Vector3(side * 0.48, -0.025, sign_value * 1.838), Vector3(0.07, 0.14, 0.012), "dark", DARK)
	_box(Vector3(0, 0.15, -1.733), Vector3(0.64, 0.19, 0.025), "dark", DARK)
	for height in [0.075, 0.125, 0.175, 0.225]:
		_box(Vector3(0, height, -1.751), Vector3(0.63, 0.012, 0.012), "chrome", CHROME)
	for side in [-1.0, 1.0]:
		_round_face(Vector3(side * 0.49, 0.18, -1.735), 0.139, Vector3.FORWARD, "chrome", CHROME)
		_round_face(Vector3(side * 0.49, 0.18, -1.744), 0.111, Vector3.FORWARD, "lens", Color("f3e6b5"))
		_box(Vector3(side * 0.49, 0.01, -1.739), Vector3(0.18, 0.045, 0.02), "lens", Color("dfa03e"))
		_box(Vector3(side * 0.47, 0.18, 1.733), Vector3(0.31, 0.125, 0.02), "chrome", CHROME)
		_box(Vector3(side * 0.445, 0.18, 1.749), Vector3(0.21, 0.089, 0.014), "lens", Color("a82827"))
		_box(Vector3(side * 0.565, 0.18, 1.749), Vector3(0.058, 0.089, 0.014), "lens", Color("dc9a36"))
	for z in [-1.845, 1.845]:
		_box(Vector3(0, -0.025, z), Vector3(0.29, 0.085, 0.012), "paint", ROOF)
	_box(Vector3(0, 0.23, 1.747), Vector3(0.13, 0.017, 0.015), "chrome", CHROME)
	_box(Vector3(0, 0.31, -1.736), Vector3(0.055, 0.045, 0.015), "chrome", CHROME)
	_box(Vector3(-0.56, -0.22, 1.65), Vector3(0.08, 0.07, 0.27), "dark", DARK)

func _build_wheel() -> void:
	# Local Y is the axle, matching the existing controller's spin axis.
	var profile: Array[Vector2] = [Vector2(-0.115, 0.255), Vector2(-0.112, 0.30), Vector2(-0.078, 0.338), Vector2(0.078, 0.338), Vector2(0.112, 0.30), Vector2(0.115, 0.255)]
	for ring in range(profile.size() - 1):
		for segment in 24:
			var a := TAU * segment / 24.0
			var b := TAU * (segment + 1) / 24.0
			var p := profile[ring]
			var q := profile[ring + 1]
			_quad(Vector3(p.y * cos(a), p.x, p.y * sin(a)), Vector3(p.y * cos(b), p.x, p.y * sin(b)), Vector3(q.y * cos(b), q.x, q.y * sin(b)), Vector3(q.y * cos(a), q.x, q.y * sin(a)), "dark", DARK, Vector3(cos((a + b) / 2), 0, sin((a + b) / 2)))
	for side in [-1.0, 1.0]:
		_round_face(Vector3(0, side * 0.116, 0), 0.254, Vector3.UP * side, "dark", DARK, 24)
		_round_face(Vector3(0, side * 0.119, 0), 0.218, Vector3.UP * side, "chrome", CHROME, 24)
		_round_face(Vector3(0, side * 0.123, 0), 0.187, Vector3.UP * side, "paint", ROOF, 24)
		_round_face(Vector3(0, side * 0.13, 0), 0.112, Vector3.UP * side, "chrome", CHROME, 24)
		for hole in 8:
			var angle := TAU * hole / 8.0
			_round_face(Vector3(0.155 * cos(angle), side * 0.127, 0.155 * sin(angle)), 0.025, Vector3.UP * side, "dark", DARK, 8)
		for segment in 24:
			var angle := TAU * segment / 24.0
			_line(Vector3(0.30 * cos(angle), side * 0.112, 0.30 * sin(angle)), Vector3(0.325 * cos(angle + 0.035), side * 0.084, 0.325 * sin(angle + 0.035)), 0.009, "paint", Color("404647"))

func _save_mesh(filename: String) -> bool:
	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in surfaces.values():
		surface.index()
		surface.commit(mesh)
	var error := ResourceSaver.save(mesh, OUTPUT.path_join(filename))
	if error != OK:
		push_error("Could not save Maré 68: %s" % error_string(error))
		return false
	print("Maré 68 saved: %s · %d surfaces · %d triangles" % [filename, mesh.get_surface_count(), mesh.get_faces().size() / 3])
	surfaces.clear()
	return true
