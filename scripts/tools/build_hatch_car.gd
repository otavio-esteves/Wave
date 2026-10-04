extends SceneTree

# Wave hatch inspired by the early Gol 1000; original geometry. Build offline; gameplay loads only these saved meshes.
const OUTPUT := "res://assets/models/hatch_1000"
const PAINT := Color("e5e3da")
const ROOF := Color("e5e3da")
const CHROME := Color("919a9d")
const DARK := Color("252a2c")
const GLASS := Color("607c85")
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_material("paint", 0.48, 0.18)
	_material("chrome", 0.55, 0.4)
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
	material.resource_name = "Hatch1000_" + label
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
	return lerpf(0.72, 0.80, clampf((1.86 - absf(z)) / 0.3, 0.0, 1.0))

func _body_height(z: float) -> float:
	return lerpf(0.31, 0.47, clampf((1.86 - absf(z)) / 0.25, 0.0, 1.0))

func _build_body() -> void:
	var stations: Array[float] = [-1.86, -1.74, -1.56, -0.72, 0.72, 1.56, 1.74, 1.86]
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
		outline.append(Vector2(1.86, -0.20))
		for wheel_z in [1.13, -1.13]:
			outline.append(Vector2(wheel_z + 0.365, -0.20))
			for segment in 17:
				var angle := PI * segment / 16.0
				outline.append(Vector2(wheel_z + 0.365 * cos(angle), -0.04 + 0.365 * sin(angle)))
			outline.append(Vector2(wheel_z - 0.365, -0.20))
		outline.append(Vector2(-1.86, -0.20))
		var triangles := Geometry2D.triangulate_polygon(PackedVector2Array(outline))
		assert(not triangles.is_empty(), "Wheel arch outline must triangulate")
		for index in range(0, triangles.size(), 3):
			var vertices: Array[Vector3] = []
			for corner in 3:
				var point := outline[triangles[index + corner]]
				vertices.append(Vector3(side * _body_width(point.x), point.y, point.x))
			_triangle(vertices[0], vertices[1], vertices[2], "paint", PAINT, Vector3.RIGHT * side)
		for wheel_z in [-1.13, 1.13]:
			for segment in 16:
				var a := PI * segment / 16.0
				var b := PI * (segment + 1) / 16.0
				_line(Vector3(side * 0.807, -0.04 + 0.373 * sin(a), wheel_z + 0.373 * cos(a)), Vector3(side * 0.807, -0.04 + 0.373 * sin(b), wheel_z + 0.373 * cos(b)), 0.014, "dark", DARK)
		_line(Vector3(side * 0.81, 0.365, -1.35), Vector3(side * 0.81, 0.365, 1.35), 0.018, "dark", DARK)
		for z in [-0.57, 0.57]:
			_line(Vector3(side * 0.806, -0.12, z), Vector3(side * 0.806, 0.4, z), 0.008, "dark", DARK)
		_line(Vector3(side * 0.807, -0.12, -0.57), Vector3(side * 0.807, -0.12, 0.57), 0.008, "dark", DARK)
		_box(Vector3(side * 0.817, 0.34, 0.37), Vector3(0.028, 0.028, 0.14), "dark", DARK)
		_box(Vector3(side * 0.82, 0.335, -0.82), Vector3(0.025, 0.05, 0.09), "lens", Color("e5a546"))
	_box(Vector3(0, -0.18, 0), Vector3(1.35, 0.07, 3.15), "dark", DARK)
	_build_cabin()
	_build_ends()

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
		_quad(fl, ft, rt, rl, "paint", PAINT, Vector3.RIGHT * side)
		var window: Array[Vector3] = [Vector3(side * 0.735, 0.55, -0.53), Vector3(side * 0.655, 0.965, -0.17), Vector3(side * 0.655, 0.965, 0.81), Vector3(side * 0.735, 0.55, 1.58)]
		_quad(window[0], window[1], window[2], window[3], "glass", GLASS, Vector3.RIGHT * side)
		for index in 4:
			_line(window[index], window[(index + 1) % 4], 0.018, "dark", DARK)
		_line(Vector3(side * 0.739, 0.55, 0.48), Vector3(side * 0.655, 0.965, 0.48), 0.06, "dark", DARK)
		_line(Vector3(side * 0.739, 0.55, -0.35), Vector3(side * 0.65, 0.93, -0.15), 0.015, "dark", DARK)
		_line(Vector3(side * 0.78, 0.53, -0.57), Vector3(side * 1.00, 0.59, -0.57), 0.025, "dark", DARK)
		_box(Vector3(side * 1.01, 0.61, -0.57), Vector3(0.10, 0.11, 0.15), "dark", DARK)
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
			_line(points[index] + normal * 0.006, points[(index + 1) % 4] + normal * 0.006, 0.012, "dark", DARK)
		if front:
			for side in [-1.0, 1.0]:
				_line(Vector3(side * 0.32, 0.555, -0.62), Vector3(side * 0.15, 0.62, -0.568), 0.012, "dark", DARK)
	for index in 8:
		var x0 := -0.62 + 1.24 * index / 8.0
		var x1 := -0.62 + 1.24 * (index + 1) / 8.0
		var h0 := 1.025 + 0.065 * (1.0 - pow(x0 / 0.62, 2))
		var h1 := 1.025 + 0.065 * (1.0 - pow(x1 / 0.62, 2))
		_quad(Vector3(x0, h0, -0.17), Vector3(x0, h0, 0.91), Vector3(x1, h1, 0.91), Vector3(x1, h1, -0.17), "paint", ROOF, Vector3.UP)
		for z in [-0.17, 0.91]:
			_quad(Vector3(x0, h0, z), Vector3(x1, h1, z), Vector3(x1, 1.015, z), Vector3(x0, 1.015, z), "paint", ROOF, Vector3.FORWARD if z < 0 else Vector3.BACK)

func _build_ends() -> void:
	for side in [-1.0, 1.0]:
		var normal: Vector3 = Vector3.BACK * side
		_quad(Vector3(-0.72, -0.20, side * 1.86), Vector3(0.72, -0.20, side * 1.86), Vector3(0.72, 0.31, side * 1.86), Vector3(-0.72, 0.31, side * 1.86), "paint", PAINT, normal)
		_box(Vector3(0, -0.025, side * 1.89), Vector3(1.63, 0.20, 0.15), "dark", DARK)
		_box(Vector3(0, -0.028, side * 1.973), Vector3(0.32, 0.10, 0.012), "paint", ROOF)
		for x in [-0.74, 0.74]:
			_box(Vector3(x, -0.025, side * 1.79), Vector3(0.12, 0.20, 0.28), "dark", DARK)
	_box(Vector3(0, 0.19, -1.875), Vector3(0.52, 0.19, 0.022), "dark", DARK)
	for height in [0.12, 0.17, 0.22, 0.27]:
		_box(Vector3(0, height, -1.89), Vector3(0.51, 0.012, 0.012), "chrome", Color("555c5d"))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.49, 0.19, -1.877), Vector3(0.41, 0.19, 0.018), "dark", DARK)
		_box(Vector3(side * 0.48, 0.19, -1.89), Vector3(0.35, 0.155, 0.012), "lens", Color("dfebdc"))
		_box(Vector3(side * 0.70, 0.19, -1.887), Vector3(0.105, 0.155, 0.025), "lens", Color("de922a"))
		_box(Vector3(side * 0.50, 0.18, 1.875), Vector3(0.40, 0.19, 0.025), "dark", DARK)
		_box(Vector3(side * 0.45, 0.15, 1.891), Vector3(0.25, 0.085, 0.012), "lens", Color("b23229"))
		_box(Vector3(side * 0.63, 0.225, 1.891), Vector3(0.13, 0.065, 0.012), "lens", Color("e7a238"))
		_box(Vector3(side * 0.40, 0.225, 1.891), Vector3(0.13, 0.065, 0.012), "lens", Color("d8d8c7"))
	_box(Vector3(0, 0.33, 1.879), Vector3(0.13, 0.03, 0.015), "dark", DARK)
	_line(Vector3(-0.30, 0.66, 1.49), Vector3(0.20, 0.67, 1.48), 0.015, "dark", DARK)
	_box(Vector3(-0.52, -0.23, 1.73), Vector3(0.07, 0.07, 0.24), "dark", DARK)

func _build_wheel() -> void:
	# Local Y is the axle, matching the existing controller's spin axis.
	var profile: Array[Vector2] = [Vector2(-0.088, 0.24), Vector2(-0.085, 0.28), Vector2(-0.065, 0.31), Vector2(0.065, 0.31), Vector2(0.085, 0.28), Vector2(0.088, 0.24)]
	for ring in range(profile.size() - 1):
		for segment in 24:
			var a := TAU * segment / 24.0
			var b := TAU * (segment + 1) / 24.0
			var p := profile[ring]
			var q := profile[ring + 1]
			_quad(Vector3(p.y * cos(a), p.x, p.y * sin(a)), Vector3(p.y * cos(b), p.x, p.y * sin(b)), Vector3(q.y * cos(b), q.x, q.y * sin(b)), Vector3(q.y * cos(a), q.x, q.y * sin(a)), "dark", DARK, Vector3(cos((a + b) / 2), 0, sin((a + b) / 2)))
	for side in [-1.0, 1.0]:
		_round_face(Vector3(0, side * 0.091, 0), 0.254, Vector3.UP * side, "dark", DARK, 24)
		_round_face(Vector3(0, side * 0.094, 0), 0.198, Vector3.UP * side, "chrome", CHROME, 24)
		_round_face(Vector3(0, side * 0.098, 0), 0.177, Vector3.UP * side, "chrome", CHROME, 24)
		_round_face(Vector3(0, side * 0.105, 0), 0.09, Vector3.UP * side, "dark", DARK, 24)
		for hole in 8:
			var angle := TAU * hole / 8.0
			_round_face(Vector3(0.145 * cos(angle), side * 0.101, 0.145 * sin(angle)), 0.025, Vector3.UP * side, "dark", DARK, 8)
		for segment in 24:
			var angle := TAU * segment / 24.0
			_line(Vector3(0.30 * cos(angle), side * 0.112, 0.30 * sin(angle)), Vector3(0.30 * cos(angle + 0.035), side * 0.084, 0.30 * sin(angle + 0.035)), 0.009, "paint", Color("404647"))

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
