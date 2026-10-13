extends SceneTree

# Gol 1000 quadrado (1993), modeled from photographic references; original geometry. Build offline; gameplay loads only these saved meshes.
const OUTPUT := "res://assets/models/hatch_1000"
const PAINT := Color("cfcec6")
const ROOF := PAINT
const CHROME := Color("919a9d")
const DARK := Color("252b30")
const GLASS := Color("7198ab")
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_material("paint", 0.23, 0.08)
	_material("chrome", 0.25, 0.82)
	_material("dark", 0.67, 0.0)
	_material("glass", 0.045, 0.08)
	_material("fabric", 0.94, 0.0)
	_material("lens", 0.24, 0.0)
	_material("headlight_glass", 0.15, 0.05)
	_material("rubber", 0.82, 0.0)
	_material("tail_lamp", 0.22, 0.0)
	_material("reverse_lamp", 0.25, 0.0)
	_bake_surface("paint", 0.018, 0.025)
	_bake_surface("rubber", 0.16, 0.15)
	_bake_surface("dark", 0.09, 0.10)
	_bake_surface("fabric", 0.22, 0.25)
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
		material.clearcoat = 0.75
		material.clearcoat_roughness = 0.12
	if label in ["glass", "headlight_glass"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.metallic_specular = 0.8
	if label in ["lens", "tail_lamp", "reverse_lamp"]:
		material.clearcoat_enabled = true
		material.clearcoat = 0.65
		material.clearcoat_roughness = 0.12
	if label in ["tail_lamp", "reverse_lamp"]:
		material.emission_enabled = true
		material.emission = Color("fb2e17") if label == "tail_lamp" else Color("fff4df")
		material.emission_energy_multiplier = 0.12 if label == "tail_lamp" else 0.0
	materials[label] = material

func _bake_surface(label: String, contrast: float, strength: float) -> void:
	# Local-space triplanar detail follows the vehicle; maps are original offline assets.
	var image := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
	var relief := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + label.hash()
	for y in 128:
		for x in 128:
			var noise := rng.randf_range(-1.0, 1.0)
			var weave := sin(x * PI / 2.0) * sin(y * PI / 2.0) if label == "fabric" else 0.0
			var tone := 0.96 + noise * contrast * 0.25 + weave * contrast * 0.2
			image.set_pixel(x, y, Color(tone, tone, tone))
			var height := 0.5 + noise * 0.12 + weave * 0.08
			relief.set_pixel(x, y, Color(height, height, height))
	relief.bump_map_to_normal_map(strength)
	image.generate_mipmaps()
	relief.generate_mipmaps()
	var albedo := ImageTexture.create_from_image(image)
	var normal := ImageTexture.create_from_image(relief)
	ResourceSaver.save(albedo, OUTPUT.path_join(label + "-albedo.res"))
	ResourceSaver.save(normal, OUTPUT.path_join(label + "-normal.res"))
	var material: StandardMaterial3D = materials[label]
	material.albedo_texture = albedo
	material.normal_texture = normal
	material.normal_enabled = true
	material.normal_scale = 0.22 if label == "paint" else 0.45
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * (8.0 if label == "paint" else 12.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

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
		surface.set_color(Color(color, 0.48 if label in ["glass", "headlight_glass"] else color.a).srgb_to_linear())
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
	return lerpf(0.40, 0.47, clampf((1.86 - absf(z)) / 0.25, 0.0, 1.0))

func _build_body() -> void:
	# Dense longitudinal rings and an actual curved shoulder replace flat panels.
	var stations: Array[float] = []
	for index in 25:
		stations.append(lerpf(-1.86, 1.86, index / 24.0))
	stations.append(-0.70)
	stations.append(1.80)
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
			# The cabin is hollow: the bonnet sheet must not pass through the seats.
			if z0 >= -0.70 and z1 <= 1.80 and absf((t0 + t1) / 2) < 0.83:
				continue
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
				_line(Vector3(side * 0.807, -0.04 + 0.373 * sin(a), wheel_z + 0.373 * cos(a)), Vector3(side * 0.807, -0.04 + 0.373 * sin(b), wheel_z + 0.373 * cos(b)), 0.008, "dark", DARK)
		_line(Vector3(side * 0.81, 0.365, -1.35), Vector3(side * 0.81, 0.365, 1.35), 0.012, "paint", Color("b8bdb5"))
		for z in [-0.64, 0.66]:
			_panel_seam(side, Vector2(z, -0.12), Vector2(z, 0.4))
		_panel_seam(side, Vector2(-0.64, -0.12), Vector2(0.66, -0.12))
		_rounded_box(Vector3(side * 0.817, 0.36, 0.51), Vector3(0.028, 0.028, 0.14), 0.012, "dark", DARK)
	_box(Vector3(0, -0.18, 0), Vector3(1.35, 0.07, 3.15), "dark", DARK)
	_build_interior()
	_build_cabin()
	_build_ends()
	_panel_details()
	_coachwork_details()

func _build_cabin() -> void:
	var front_low := Vector3(0.74, 0.49, -0.70)
	var front_top := Vector3(0.64, 1.02, -0.16)
	var rear_low := Vector3(0.74, 0.58, 1.80)
	var rear_top := Vector3(0.64, 1.02, 1.20)
	for side in [-1.0, 1.0]:
		var fl := front_low * Vector3(side, 1, 1)
		var ft := front_top * Vector3(side, 1, 1)
		var rl := Vector3(side * 0.74, 0.49, 1.80)
		var rt := rear_top * Vector3(side, 1, 1)
		var window: Array[Vector3] = [Vector3(side * 0.735, 0.55, -0.53), Vector3(side * 0.655, 0.965, -0.17), Vector3(side * 0.655, 0.965, 1.08), Vector3(side * 0.735, 0.55, 1.49)]
		# Close the shoulder below the glazing and the taller hatch corner.
		_quad(fl, rl, _hood_point(rl.z, side), _hood_point(fl.z, side), "paint", PAINT, Vector3.RIGHT * side)
		_triangle(rl, rear_low * Vector3(side, 1, 1), rt, "paint", PAINT, Vector3.RIGHT * side)
		var perimeter: Array[Vector3] = [fl, ft, rt, rl]
		for index in 4:
			_quad(perimeter[index], perimeter[(index + 1) % 4], window[(index + 1) % 4], window[index], "paint", PAINT, Vector3.RIGHT * side)
		_glass_panel(window, Vector3.RIGHT * side)
		for index in 4:
			_line(window[index], window[(index + 1) % 4], 0.009, "dark", DARK)
		_line(Vector3(side * 0.739, 0.55, 0.66), Vector3(side * 0.655, 0.965, 0.66), 0.055, "dark", DARK)
		_line(Vector3(side * 0.78, 0.53, -0.57), Vector3(side * 1.00, 0.59, -0.57), 0.014, "dark", DARK)
		_rounded_box(Vector3(side * 0.94, 0.61, -0.57), Vector3(0.22, 0.115, 0.15), 0.018, "dark", DARK)
		_box(Vector3(side * 0.94, 0.61, -0.488), Vector3(0.18, 0.075, 0.006), "glass", GLASS)
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
			_line(points[index], points[(index + 1) % 4], 0.014, "dark", DARK)
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
				var z := -0.16 + 1.36 * (row + corner.y) / 12.0
				var y := 1.02 + 0.040 * (1.0 - pow(x / 0.64, 2)) + 0.012 * sin(PI * (z + 0.16) / 1.36)
				points.append(Vector3(x, y, z))
				normals.append(Vector3(0.08 * x / (0.64 * 0.64), 1, -0.012 * PI / 1.36 * cos(PI * (z + 0.16) / 1.36)).normalized())
			_smooth_quad(points, normals, "paint", ROOF)

	for z in [-0.16, 1.20]:
		for column in 24:
			var x0 := lerpf(-0.64, 0.64, column / 24.0)
			var x1 := lerpf(-0.64, 0.64, (column + 1) / 24.0)
			var y0 := 1.02 + 0.04 * (1.0 - pow(x0 / 0.64, 2))
			var y1 := 1.02 + 0.04 * (1.0 - pow(x1 / 0.64, 2))
			_quad(Vector3(x0, 1.02, z), Vector3(x1, 1.02, z), Vector3(x1, y1, z), Vector3(x0, y0, z), "paint", PAINT, Vector3.FORWARD if z < 0 else Vector3.BACK)

func _build_ends() -> void:
	for side in [-1.0, 1.0]:
		var normal: Vector3 = Vector3.BACK * side
		_quad(Vector3(-0.72, -0.20, side * 1.86), Vector3(0.72, -0.20, side * 1.86), Vector3(0.72, 0.40, side * 1.86), Vector3(-0.72, 0.40, side * 1.86), "paint", PAINT, normal)
		_rounded_box(Vector3(0, -0.045, side * 1.89), Vector3(1.64, 0.25, 0.16), 0.025, "dark", Color("363a3a"))
		_line(Vector3(-0.78, -0.035, side * 1.975), Vector3(0.78, -0.035, side * 1.975), 0.008, "dark", Color("202423"))
		for x in [-0.74, 0.74]:
			_rounded_box(Vector3(x, -0.045, side * 1.79), Vector3(0.12, 0.25, 0.28), 0.024, "dark", Color("363a3a"))
	_box(Vector3(0, 0.275, -1.875), Vector3(0.80, 0.225, 0.025), "dark", Color("141919"))
	for row in 7:
		_box(Vector3(0, 0.178 + row * 0.031, -1.899), Vector3(0.80, 0.008, 0.020), "dark", Color("4b5050"))
	for row in 3:
		_box(Vector3(0, -0.12 + row * 0.020, -1.977), Vector3(1.22, 0.007, 0.005), "dark", Color("171c1c"))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.56, 0.275, -1.877), Vector3(0.325, 0.225, 0.020), "dark", DARK)
		_box(Vector3(side * 0.56, 0.275, -1.896), Vector3(0.30, 0.205, 0.012), "chrome", Color("a2aaa7"))
		_reflector(Vector3(side * 0.56, 0.275, -1.907))
		_box(Vector3(side * 0.56, 0.275, -1.929), Vector3(0.30, 0.205, 0.008), "headlight_glass", Color("c8d4cf"))
		_box(Vector3(side * 0.75, 0.275, -1.905), Vector3(0.08, 0.205, 0.045), "lens", Color("e68b17"))
		_box(Vector3(side * 0.51, 0.265, 1.875), Vector3(0.43, 0.215, 0.025), "dark", DARK)
		_box(Vector3(side * 0.51, 0.217, 1.891), Vector3(0.415, 0.103, 0.012), "tail_lamp", Color("b7201a"))
		_box(Vector3(side * 0.56, 0.322, 1.891), Vector3(0.315, 0.085, 0.012), "lens", Color("df8b20"))
		_box(Vector3(side * 0.35, 0.322, 1.891), Vector3(0.093, 0.085, 0.012), "reverse_lamp", Color("c7d0c6"))
		for rib in 11:
			var x: float = side * 0.51 + (rib - 5) * 0.037
			_line(Vector3(x, 0.169, 1.900), Vector3(x, 0.26, 1.900), 0.002, "tail_lamp", Color("cf3825"))
		for division in [-0.102, 0.102]:
			_line(Vector3(side * 0.51 + division, 0.165, 1.902), Vector3(side * 0.51 + division, 0.368, 1.902), 0.008, "dark", DARK)
	_quad(Vector3(-0.72, 0.40, 1.862), Vector3(0.72, 0.40, 1.862), Vector3(0.74, 0.58, 1.80), Vector3(-0.74, 0.58, 1.80), "paint", PAINT, Vector3.BACK)
	_round_face(Vector3(0, 0.47, 1.845), 0.016, Vector3.BACK, "dark", DARK, 12)
	_line(Vector3(-0.26, 0.65, 1.717), Vector3(0.23, 0.65, 1.717), 0.013, "dark", DARK)
	_box(Vector3(-0.52, -0.23, 1.73), Vector3(0.07, 0.07, 0.24), "dark", DARK)
	_vw_badge(Vector3(0, 0.275, -1.93), 0.065, -1.0)
	_vw_badge(Vector3(-0.56, 0.48, 1.840), 0.033, 1.0)
	_model_text(Vector3(0.50, 0.478, 1.842), "Gol 1000", 0.0010, 1.0)

func _vw_badge(center: Vector3, radius: float, side: float) -> void:
	var basis := Basis(Vector3.RIGHT, -atan(0.062 / 0.18)) if side > 0 else Basis.IDENTITY
	_round_face(center, radius, basis * Vector3.BACK * side, "dark", Color("111817"), 32)
	for segment in 32:
		var a := TAU * segment / 32.0
		var b := TAU * (segment + 1) / 32.0
		_line(center + basis * Vector3(radius * cos(a), radius * sin(a), side * 0.002), center + basis * Vector3(radius * cos(b), radius * sin(b), side * 0.002), radius * 0.065, "chrome", CHROME)
	for points in [[Vector2(-0.42, 0.64), Vector2(0, 0.05), Vector2(0.42, 0.64)], [Vector2(-0.67, 0.18), Vector2(-0.32, -0.65), Vector2(0, -0.13), Vector2(0.32, -0.65), Vector2(0.67, 0.18)]]:
		for index in range(points.size() - 1):
			var a: Vector2 = points[index] * radius
			var b: Vector2 = points[index + 1] * radius
			_line(center + basis * Vector3(a.x, a.y, side * 0.004), center + basis * Vector3(b.x, b.y, side * 0.004), radius * 0.07, "chrome", CHROME)

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
			_smooth_quad(vertices, normals, "glass", Color(Color("82989d"), 0.32))

func _glazing_point(points: Array, u: float, v: float, outward: Vector3) -> Vector3:
	return points[0].lerp(points[3], u).lerp(points[1].lerp(points[2], u), v) + outward * (0.003 + 0.012 * sin(PI * u) * sin(PI * v))

func _build_interior() -> void:
	var fabric := Color("343a3d")
	_box(Vector3(0, 0.06, 0.40), Vector3(1.35, 0.10, 2.35), "dark", Color("171c20"))
	_box(Vector3(0, 0.43, -0.48), Vector3(1.34, 0.16, 0.38), "dark", DARK)
	_box(Vector3(0, 0.27, 0.18), Vector3(0.18, 0.25, 0.68), "dark", DARK)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.35, 0.28, 0.14), Vector3(0.23, 0.075, 0.235), "dark", fabric)
		_rounded_box(Vector3(side * 0.35, 0.51, 0.36), Vector3(0.46, 0.48, 0.13), 0.045, "fabric", fabric)
		_rounded_box(Vector3(side * 0.35, 0.80, 0.38), Vector3(0.26, 0.13, 0.11), 0.038, "fabric", fabric)
		for seam in [-0.16, 0.16]:
			_line(Vector3(side * 0.35 + seam, 0.31, 0.284), Vector3(side * 0.35 + seam, 0.69, 0.284), 0.003, "fabric", Color("686b66"))
		for rib in 5:
			_line(Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, -0.05), Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, 0.30), 0.005, "dark", Color("53595b"))
		_box(Vector3(side * 0.697, 0.33, 0.58), Vector3(0.025, 0.25, 1.3), "dark", fabric)
	_rounded_box(Vector3(0, 0.28, 1.08), Vector3(1.12, 0.15, 0.40), 0.04, "fabric", fabric)
	_rounded_box(Vector3(0, 0.48, 1.24), Vector3(1.12, 0.34, 0.12), 0.04, "fabric", fabric)
	_box(Vector3(0, 0.51, 1.44), Vector3(1.30, 0.04, 0.28), "dark", Color("20262b"))
	var steering := Vector3(-0.34, 0.57, -0.26)
	for segment in 24:
		var a := TAU * segment / 24
		var b := TAU * (segment + 1) / 24
		_line(steering + Vector3(cos(a) * 0.14, sin(a) * 0.11, 0), steering + Vector3(cos(b) * 0.14, sin(b) * 0.11, 0), 0.016, "dark", DARK)
	for side in [-1.0, 1.0]:
		_line(steering, steering + Vector3(side * 0.13, 0, 0), 0.02, "dark", DARK)
	_line(Vector3(0, 0.40, 0.02), Vector3(0, 0.51, 0.02), 0.009, "dark", DARK)
	_box(Vector3(0, 0.83, -0.09), Vector3(0.20, 0.07, 0.04), "dark", DARK)
	_box(Vector3(-0.34, 0.50, -0.27), Vector3(0.26, 0.09, 0.012), "dark", Color("161a1d"))
	# Instrument cluster, dashboard vents, radio and glovebox, visible through glazing.
	for x in [-0.40, -0.28]:
		_round_face(Vector3(x, 0.51, -0.256), 0.033, Vector3.BACK, "dark", Color("0e1416"), 24)
		for tick in 9:
			var angle := -0.3 + tick * 0.43
			var inner := Vector3(x + cos(angle) * 0.027, 0.51 + sin(angle) * 0.027, -0.254)
			var outer := Vector3(x + cos(angle) * 0.031, 0.51 + sin(angle) * 0.031, -0.254)
			_line(inner, outer, 0.0015, "lens", Color("c3c9b7"))
		_line(Vector3(x, 0.51, -0.252), Vector3(x - 0.02, 0.516, -0.252), 0.002, "lens", Color("b76540"))
	for x in [-0.58, 0.08, 0.48]:
		_box(Vector3(x, 0.477, -0.280), Vector3(0.14, 0.038, 0.006), "dark", Color("111718"))
		for slat in 5:
			_box(Vector3(x - 0.054 + slat * 0.027, 0.477, -0.275), Vector3(0.007, 0.029, 0.004), "dark", Color("4b5049"))
	_box(Vector3(0.08, 0.398, -0.279), Vector3(0.18, 0.038, 0.008), "dark", Color("111718"))
	_box(Vector3(0.05, 0.403, -0.272), Vector3(0.08, 0.012, 0.002), "glass", Color("789183"))
	_line(Vector3(0.29, 0.37, -0.278), Vector3(0.61, 0.37, -0.278), 0.003, "dark", Color("111718"))
	_rounded_box(Vector3(0.45, 0.386, -0.270), Vector3(0.09, 0.015, 0.009), 0.003, "dark", DARK)
	# Roof lining sits behind the painted roof, leaving the windows unobstructed.
	_box(Vector3(0, 0.997, 0.47), Vector3(1.18, 0.018, 1.25), "fabric", Color("a2a094"))


func _rounded_box(center: Vector3, size: Vector3, radius: float, label: String, color: Color) -> void:
	var half := size * 0.5
	radius = minf(radius, minf(half.x, minf(half.y, half.z)) * 0.95)
	var core := half - Vector3.ONE * radius
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var coords_u := [-half[u], -half[u] + radius * 0.3, -core[u], 0.0, core[u], half[u] - radius * 0.3, half[u]]
		var coords_v := [-half[v], -half[v] + radius * 0.3, -core[v], 0.0, core[v], half[v] - radius * 0.3, half[v]]
		for side in [-1.0, 1.0]:
			for row in 6:
				for column in 6:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
						var point := Vector3.ZERO
						point[axis] = side * half[axis]
						point[u] = coords_u[column + corner.x]
						point[v] = coords_v[row + corner.y]
						var inset := point.clamp(-core, core)
						var normal := (point - inset).normalized()
						points.append(center + inset + normal * radius)
						normals.append(normal)
					_smooth_quad(points, normals, label, color)


func _panel_details() -> void:
	# Panel seams, hood crease, grille depth, lens ribs and inset plates.
	for side in [-1.0, 1.0]:
		for segment in 8:
			var z0 := lerpf(-0.75, -1.57, segment / 8.0)
			var z1 := lerpf(-0.75, -1.57, (segment + 1) / 8.0)
			var a := _hood_point(z0, side * 0.68 / (_body_width(z0) - 0.006)) + Vector3.UP * 0.002
			var b := _hood_point(z1, side * 0.68 / (_body_width(z1) - 0.006)) + Vector3.UP * 0.002
			_line(a, b, 0.004, "dark", Color("243542"))
		_line(Vector3(side * 0.79, 0.04, -0.49), Vector3(side * 0.79, 0.04, 0.50), 0.018, "paint", Color("b4b8b0"))
		for rib in 15:
			_box(Vector3(side * 0.56 + (rib - 7) * 0.019, 0.275, -1.934), Vector3(0.0015, 0.185, 0.002), "headlight_glass", Color("a9b2af"))
		_line(Vector3(side * 0.34, 0.195, 1.901), Vector3(side * 0.69, 0.195, 1.901), 0.009, "dark", DARK)
	for z in [-1.982, 1.910]:
		var plate_y := -0.025 if z < 0 else 0.26
		_box(Vector3(0, plate_y, z), Vector3(0.34, 0.115, 0.006), "dark", DARK)
		_box(Vector3(0, plate_y, z + signf(z) * 0.004), Vector3(0.30, 0.080, 0.004), "lens", Color("d4dcdb"))
		_plate_text(Vector3(0, plate_y - 0.013, z + signf(z) * 0.008), signf(z))
	_line(Vector3(-0.46, 1.05, 0.80), Vector3(-0.46, 1.37, 1.01), 0.007, "dark", DARK)
	for side in [-1.0, 1.0]:
		for slot in 12:
			_box(Vector3(side * (0.12 + slot * 0.031), 0.476, -0.72), Vector3(0.012, 0.003, 0.035), "dark", DARK)
	_box(Vector3(0.797, 0.24, 1.56), Vector3(0.008, 0.15, 0.135), "dark", DARK)

func _coachwork_details() -> void:
	# Small manufacturing details give the square silhouette depth at driving distance.
	for side in [-1.0, 1.0]:
		# Protective moulding and a shaded rocker run between, rather than across, the arches.
		_rounded_box(Vector3(side * 0.811, 0.13, 0.0), Vector3(0.026, 0.045, 1.42), 0.009, "dark", Color("414442"))
		_line(Vector3(side * 0.778, -0.155, -0.70), Vector3(side * 0.778, -0.155, 0.70), 0.026, "paint", Color("a9aca3"))
		# A fine roof gutter follows the roof shoulder, with a painted edge above it.
		_line(Vector3(side * 0.643, 1.024, -0.14), Vector3(side * 0.643, 1.024, 1.20), 0.007, "dark", Color("505954"))
		_line(Vector3(side * 0.651, 1.035, -0.14), Vector3(side * 0.651, 1.035, 1.20), 0.009, "paint", PAINT)
		# Handle recess and latch, side marker, and mirror backing are separate materials.
		_rounded_box(Vector3(side * 0.810, 0.345, 0.51), Vector3(0.016, 0.049, 0.18), 0.015, "dark", Color("656a63"))
		_rounded_box(Vector3(side * 0.830, 0.354, 0.51), Vector3(0.017, 0.019, 0.125), 0.006, "dark", Color("252b29"))
		_rounded_box(Vector3(side * 0.814, 0.29, -1.54), Vector3(0.015, 0.044, 0.086), 0.012, "lens", Color("b97628"))
		_box(Vector3(side * 0.94, 0.612, -0.484), Vector3(0.165, 0.065, 0.003), "chrome", Color("b7c4c5"))
		# Dark A-pillar rubber and triangular quarter-light seal.
		_line(Vector3(side * 0.738, 0.555, -0.53), Vector3(side * 0.660, 0.956, -0.17), 0.012, "dark", DARK)
		_line(Vector3(side * 0.720, 0.63, -0.39), Vector3(side * 0.735, 0.55, -0.38), 0.010, "dark", DARK)
	# Headlight bulbs and lens cross-ribs sit behind the outer glass.
	for side in [-1.0, 1.0]:
		_round_face(Vector3(side * 0.56, 0.275, -1.924), 0.024, Vector3.FORWARD, "lens", Color("e3dbc6"), 16)
		for row in 4:
			_line(Vector3(side * 0.56 - 0.145, 0.195 + row * 0.05, -1.936), Vector3(side * 0.56 + 0.145, 0.195 + row * 0.05, -1.936), 0.0018, "headlight_glass", Color("a3b0ac"))
		for slot in 8:
			_box(Vector3(side * 0.75, 0.19 + slot * 0.022, -1.929), Vector3(0.073, 0.002, 0.002), "lens", Color("a16120"))
	# Heated rear glass follows the inclined hatch, including its bus bars.
	for row in 9:
		var fraction := 0.16 + row * 0.073
		var y := lerpf(0.58, 1.02, fraction)
		var z := lerpf(1.80, 1.20, fraction) + 0.027
		var width := lerpf(0.66, 0.58, fraction)
		_line(Vector3(-width, y, z), Vector3(width, y, z), 0.0018, "dark", Color("71624a"))
	# Properly seated double wipers and washer nozzles on the scuttle.
	for side in [-1.0, 1.0]:
		_line(Vector3(side * 0.47, 0.555, -0.653), Vector3(side * 0.31, 0.65, -0.555), 0.009, "dark", DARK)
		_line(Vector3(side * 0.31 - 0.12, 0.650, -0.562), Vector3(side * 0.31 + 0.15, 0.650, -0.562), 0.012, "dark", DARK)
		_rounded_box(Vector3(side * 0.36, 0.477, -0.88), Vector3(0.018, 0.009, 0.024), 0.004, "dark", DARK)
	# Plate screws, rubber gasket and bumper end caps avoid floating markings.
	for z in [-1.994, 1.922]:
		var plate_y := -0.025 if z < 0 else 0.26
		for x in [-0.125, 0.125]:
			_round_face(Vector3(x, plate_y + 0.027, z), 0.003, Vector3.BACK * signf(z), "chrome", CHROME, 8)

func _build_wheel() -> void:
	# Rounded shoulders with continuous normals; local Y remains the physical axle.
	var profile: Array[Vector2] = [Vector2(-0.096, 0.212), Vector2(-0.10, 0.252), Vector2(-0.086, 0.290), Vector2(-0.064, 0.308), Vector2(0.064, 0.308), Vector2(0.086, 0.290), Vector2(0.10, 0.252), Vector2(0.096, 0.212)]
	for ring in range(profile.size() - 1):
		for segment in 64:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var row := ring + corner.x
				var angle := TAU * (segment + corner.y) / 64.0
				var p := profile[row]
				var tangent := profile[mini(row + 1, profile.size() - 1)] - profile[maxi(row - 1, 0)]
				points.append(Vector3(p.y * cos(angle), p.x, p.y * sin(angle)))
				normals.append(Vector3(tangent.x * cos(angle), -tangent.y, tangent.x * sin(angle)).normalized())
			_smooth_quad(points, normals, "rubber", Color("282c2b"))
	for segment in 64:
		var angle := TAU * segment / 64.0
		for side in [-1.0, 1.0]:
			var next: float = angle + side * 0.085
			_line(Vector3(0.309 * cos(angle), 0, 0.309 * sin(angle)), Vector3(0.309 * cos(next), side * 0.054, 0.309 * sin(next)), 0.0025, "rubber", Color("181d20"))
	# Pressed steel wheel, eight recessed slots and four bolts; no alloy spokes.
	for side in [-1.0, 1.0]:
		_round_face(Vector3(0, side * 0.098, 0), 0.212, Vector3.UP * side, "dark", Color("202624"), 48)
		_round_face(Vector3(0, side * 0.110, 0), 0.195, Vector3.UP * side, "chrome", Color("b5bdb9"), 48)
		_torus(0.202, 0.007, side * 0.113, "chrome", Color("d0d5cf"))
		_torus(0.181, 0.006, side * 0.116, "chrome", Color("a7b0aa"))
		for slot in 8:
			var angle := TAU * slot / 8.0
			var radial := Vector3(cos(angle), 0, sin(angle))
			var tangent := Vector3(-sin(angle), 0, cos(angle))
			var center: Vector3 = radial * 0.152 + Vector3.UP * side * 0.119
			# Oval recesses sit over the solid disk, with raised stamped edges.
			for segment in 16:
				var a := TAU * segment / 16.0
				var b := TAU * (segment + 1) / 16.0
				_triangle(center, center + radial * 0.014 * cos(a) + tangent * 0.032 * sin(a), center + radial * 0.014 * cos(b) + tangent * 0.032 * sin(b), "dark", Color("19211e"), Vector3.UP * side)
		_round_face(Vector3(0, side * 0.120, 0), 0.082, Vector3.UP * side, "chrome", Color("c0c8c1"), 32)
		_round_face(Vector3(0, side * 0.124, 0), 0.051, Vector3.UP * side, "dark", Color("242e29"), 24)
		for bolt in 4:
			var angle := TAU * bolt / 4.0 + PI / 4.0
			_round_face(Vector3(0.068 * cos(angle), side * 0.126, 0.068 * sin(angle)), 0.009, Vector3.UP * side, "chrome", Color("d2d8cf"), 8)
		for radius in [0.235, 0.276]:
			_torus(radius, 0.002, side * 0.099, "rubber", Color("51565a"))
		# Valve, balance weight and sidewall lettering are baked into the wheel mesh.
		_round_face(Vector3(0.175, side * 0.126, 0.03), 0.006, Vector3.UP * side, "dark", DARK, 10)
		_box(Vector3(-0.10, side * 0.119, 0.174), Vector3(0.024, 0.010, 0.009), "chrome", Color("969e96"))
		_wheel_text("175/70 R13", Vector3(0, side * 0.104, -0.252), side)
		_wheel_text("RADIAL", Vector3(0, side * 0.104, 0.254), side)
		for block in 48:
			var a := TAU * block / 48.0
			for shoulder in [-1.0, 1.0]:
				_line(Vector3(0.296 * cos(a), shoulder * 0.079, 0.296 * sin(a)), Vector3(0.289 * cos(a + 0.026), shoulder * 0.088, 0.289 * sin(a + 0.026)), 0.004, "rubber", Color("161a18"))

func _wheel_text(value: String, center: Vector3, side: float) -> void:
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font_size = 32
	mesh.pixel_size = 0.00023
	mesh.depth = 0
	var transform := Transform3D(Basis(Vector3.RIGHT, -side * PI / 2), center)
	var points := mesh.get_faces()
	for index in range(0, points.size(), 3):
		_triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], "rubber", Color("6c7068"), Vector3.UP * side)


func _torus(radius: float, thickness: float, axle: float, label: String, color: Color) -> void:
	for segment in 32:
		for ring in 4:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var angle := TAU * (segment + corner.x) / 32.0
				var tube := TAU * (ring + corner.y) / 4.0
				var radial := Vector3(cos(angle), 0, sin(angle))
				var normal := radial * cos(tube) + Vector3.UP * sin(tube)
				points.append(radial * radius + Vector3.UP * axle + normal * thickness)
				normals.append(normal)
			_smooth_quad(points, normals, label, color)


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
		var p := center + Vector3(cos(a) * 0.120, sin(a) * 0.085, -0.014)
		var q := center + Vector3(cos(b) * 0.120, sin(b) * 0.085, -0.014)
		_triangle(center + Vector3.BACK * 0.015, p, q, "chrome", CHROME, Vector3.FORWARD)
	_round_face(center + Vector3.FORWARD * 0.019, 0.013, Vector3.FORWARD, "lens", Color("dbd1af"), 12)

func _hood_point(z: float, t: float) -> Vector3:
	return Vector3((_body_width(z) - 0.006) * t, _body_height(z) - 0.055 + 0.032 * sqrt(maxf(0, 1 - t * t)) + 0.025 * maxf(0, 1 - t * t), z)

func _hood_normal(z: float, t: float) -> Vector3:
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


func _plate_text(center: Vector3, side: float) -> void:
	var text := TextMesh.new()
	text.text = "WAV-1000"
	text.font_size = 48
	text.pixel_size = 0.0009
	text.depth = 0.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var points := text.get_faces()
	var transform := Transform3D(Basis(Vector3.UP, PI if side < 0 else 0.0), center)
	for index in range(0, points.size(), 3):
		_triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], "dark", Color("24313a"), Vector3.BACK * side)

func _model_text(center: Vector3, value: String, pixel_size: float, side: float) -> void:
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font_size = 48
	mesh.pixel_size = pixel_size
	mesh.depth = 0.0
	var points := mesh.get_faces()
	var transform := Transform3D(Basis(Vector3.UP, PI) if side < 0 else Basis(Vector3.RIGHT, -atan(0.062 / 0.18)), center)
	for index in range(0, points.size(), 3):
		_triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], "dark", DARK, Vector3.BACK * side)
