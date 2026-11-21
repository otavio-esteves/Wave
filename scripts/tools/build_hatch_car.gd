extends SceneTree

# Gol 1000 (1993), modeled offline from the factory dimensions and period bodywork.
const OUTPUT := "res://assets/models/hatch_1000"
const PAINT := Color("eeeae1")
const BUMPER := Color("535251")
const CHROME := Color("c7c8c7")
const DARK := Color("2a2c2c")
const SEAL := Color("262726")
const GLASS := Color(0.59, 0.64, 0.65, 0.23)
# The body mesh sits 410 mm above the road in the player scene.
const FRONT_AXLE := -1.179
const REAR_AXLE := 1.179
const WHEEL_Y := -0.126
const FRONT_END := -1.945
const REAR_END := 1.865
const FRONT_WING_END := -1.857
const REAR_WING_END := 1.796
const FRONT_GLASS_BOTTOM := Vector3(0.727, 0.429, -0.686)
const FRONT_GLASS_TOP := Vector3(0.600, 0.896, -0.132)
const HATCH_GLASS_BOTTOM := Vector3(0.742, 0.470, 1.772)
const HATCH_GLASS_TOP := Vector3(0.597, 0.907, 0.852)
const SILL_Y := -0.226
const AXLES := [FRONT_AXLE, REAR_AXLE]
var surfaces: Dictionary = {}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_material("paint", 0.26, 0.04)
	_material("bumper", 0.66, 0.0)
	_material("chrome", 0.26, 0.48)
	_material("steel", 0.29, 0.18)
	_material("reflector", 0.23, 0.16)
	_material("dark", 0.67, 0.0)
	_material("glass", 0.09, 0.12)
	_material("fabric", 0.94, 0.0)
	_material("lens", 0.24, 0.0)
	_material("headlight_glass", 0.15, 0.05)
	_material("rubber", 0.82, 0.0)
	_material("tail_lamp", 0.22, 0.0)
	_material("reverse_lamp", 0.25, 0.0)
	_bake_surface("paint", 0.012, 0.018)
	_bake_surface("rubber", 0.16, 0.15)
	_bake_surface("dark", 0.09, 0.10)
	materials["bumper"].albedo_texture = materials["dark"].albedo_texture
	materials["bumper"].normal_texture = materials["dark"].normal_texture
	materials["bumper"].normal_enabled = true
	materials["bumper"].normal_scale = 0.16
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
		material.clearcoat = 0.48
		material.clearcoat_roughness = 0.21
	if label in ["glass", "headlight_glass"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.metallic_specular = 0.65
		material.disable_receive_shadows = true
	if label in ["lens", "tail_lamp", "reverse_lamp"]:
		material.clearcoat_enabled = true
		material.clearcoat = 0.65
		material.clearcoat_roughness = 0.12
	if label in ["tail_lamp", "reverse_lamp"]:
		material.emission_enabled = true
		material.emission = Color("f52013") if label == "tail_lamp" else Color("fff4df")
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
	if (c - a).cross(b - a).length_squared() < 0.00000000000001:
		return
	var normal := (c - a).cross(b - a).normalized()
	var surface := _surface(label)
	for point in [a, b, c]:
		var shading_normal := normal
		if label == "rubber" and absf(normal.y) < 0.3:
			shading_normal = Vector3(point.x, 0, point.z).normalized()
		surface.set_normal(shading_normal)
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
	return 0.793 - 0.047 * smoothstep(1.47, absf(FRONT_END) - 0.035, absf(z))


func _body_height(z: float) -> float:
	if z < FRONT_GLASS_BOTTOM.z:
		var t := inverse_lerp(-1.903, FRONT_GLASS_BOTTOM.z, z)
		return lerpf(0.295, 0.412, t) + 0.012 * sin(t * PI)
	return lerpf(0.412, 0.451, smoothstep(1.30, HATCH_GLASS_BOTTOM.z, z))


func _shoulder_height(z: float) -> float:
	return lerpf(0.220, 0.288, smoothstep(-1.90, -0.57, z))


func _build_body() -> void:
	var stations: Array[float] = [FRONT_WING_END, FRONT_GLASS_BOTTOM.z, HATCH_GLASS_BOTTOM.z, REAR_WING_END]
	for index in range(1, 36):
		stations.append(lerpf(FRONT_WING_END, REAR_WING_END, index / 36.0))
	for axle: float in AXLES:
		for segment in 33:
			stations.append(axle + _arch_width(axle) * cos(PI * segment / 32.0))
		stations.append(axle - _arch_width(axle) - 0.002)
		stations.append(axle + _arch_width(axle) + 0.002)
	stations.sort()
	for index in range(stations.size() - 1):
		var z0 := stations[index]
		var z1 := stations[index + 1]
		if z1 - z0 < 0.00001:
			continue
		# The bonnet and scuttle leave an open cabin behind the windscreen.
		if z1 <= FRONT_GLASS_BOTTOM.z:
			for section in 24:
				var t0 := section / 12.0 - 1.0
				var t1 := (section + 1) / 12.0 - 1.0
				_smooth_quad([_hood_point(z0, t0), _hood_point(z1, t0), _hood_point(z1, t1), _hood_point(z0, t1)],
					[_hood_normal(z0, t0), _hood_normal(z1, t0), _hood_normal(z1, t1), _hood_normal(z0, t1)], "paint", PAINT)
		for side: float in [-1, 1]:
			_build_side_section(side, z0, z1)
	for side: float in [-1, 1]:
		for axle: float in AXLES:
			_build_wheel_well(axle, side)
		var front_foot := Vector2(-0.794, -0.197)
		var rear_foot := Vector2(0.512, -0.197)
		_door_cut(side, Vector2(-0.691, 0.417), Vector2(-0.634, 0.262), Vector2(-0.624, -0.039), front_foot)
		_door_cut(side, Vector2(0.548, 0.420), Vector2(0.638, 0.235), Vector2(0.638, -0.053), rear_foot)
		_panel_seam(side, front_foot, rear_foot)
		_side_molding(side, -0.815, -0.686)
		_side_molding(side, -0.664, 0.603)
		_side_molding(side, 0.618, 0.840)
	_box(Vector3(0, -0.175, -0.033), Vector3(1.19, 0.125, 3.04), "dark", Color("252420"))
	_build_interior()
	_build_cabin()
	_build_ends()
	_panel_details()
	_coachwork_details()


func _build_side_section(side: float, z0: float, z1: float) -> void:
	var left := _side_rows(z0)
	var right := _side_rows(z1)
	for row in range(left.size() - 1):
		var points: Array[Vector3] = [_side_point(z0, left[row], side), _side_point(z1, right[row], side),
			_side_point(z1, right[row + 1], side), _side_point(z0, left[row + 1], side)]
		var normals: Array[Vector3] = []
		for point in points:
			normals.append(_side_normal(point, side))
		_smooth_quad(points, normals, "paint", PAINT)


func _side_rows(z: float) -> PackedFloat32Array:
	var front_corner := smoothstep(1.596, absf(FRONT_WING_END), -z)
	var rear_corner := smoothstep(1.534, REAR_WING_END, z)
	var bottom := maxf(_arch_bottom(z), SILL_Y + 0.272 * front_corner + 0.247 * rear_corner)
	var top := _body_height(z)
	var shoulder := _shoulder_height(z)
	return PackedFloat32Array([bottom, maxf(bottom, SILL_Y + 0.029), maxf(bottom, -0.135), maxf(bottom, 0.044),
		maxf(bottom, shoulder - 0.026), maxf(bottom, shoulder - 0.014), maxf(bottom, shoulder - 0.004),
		maxf(bottom, shoulder + 0.007), maxf(bottom, shoulder + 0.026), top - 0.020, top])


func _build_wheel_well(axle: float, side: float) -> void:
	for segment in 48:
		var a := TAU * segment / 48.0
		var b := TAU * (segment + 1) / 48.0
		var lip_a := _arch_point(axle, side, a)
		var lip_b := _arch_point(axle, side, b)
		var inner_a := _arch_point(axle, side, a, 0.0, 0.20)
		var inner_b := _arch_point(axle, side, b, 0.0, 0.20)
		var inner_center := Vector3(side * 0.55, WHEEL_Y, axle)
		_triangle(inner_a, inner_center, inner_b, "dark", Color("232221"), Vector3.RIGHT * side)
		if maxf(lip_a.y, lip_b.y) > SILL_Y:
			var radial := Vector3(0.0, sin((a + b) * 0.5), cos((a + b) * 0.5))
			_quad(lip_a, inner_a, inner_b, lip_b, "dark", Color("302e2b"), -radial)
			var edge_a := _arch_point(axle, side, a, 0.009) + Vector3.RIGHT * side * 0.004
			var edge_b := _arch_point(axle, side, b, 0.009) + Vector3.RIGHT * side * 0.004
			_quad(lip_a, lip_b, edge_b, edge_a, "paint", PAINT, Vector3.RIGHT * side)


func _arch_width(axle: float) -> float:
	return 0.339 if axle < 0 else 0.326


func _arch_top(axle: float) -> float:
	return 0.355 if axle < 0 else 0.370


func _arch_point(axle: float, side: float, angle: float, flare := 0.0, depth := 0.0) -> Vector3:
	var z := axle + (_arch_width(axle) + flare) * cos(angle)
	var y := maxf(SILL_Y, WHEEL_Y + (_arch_top(axle) + flare) * sin(angle))
	return Vector3(side * (_side_width(z, y) - depth), y, z)


func _build_cabin() -> void:
	for side: float in [-1, 1]:
		var corners: Array[Vector3] = [_cabin_edge(0, 0, side), _cabin_edge(0, 1, side),
			_cabin_edge(1, 1, side), _cabin_edge(1, 0, side)]
		var post_low := _cabin_edge(0.502, 0, side)
		var post_top := _cabin_edge(0.535, 1, side)
		var door: Array[Vector3] = [corners[0], corners[1], post_top, post_low]
		var quarter: Array[Vector3] = [post_low, post_top, corners[2], corners[3]]
		var outward := Vector3.RIGHT * side
		_window(door, [Vector2(0.083, 0.055), Vector2(0.062, 0.920), Vector2(0.950, 0.920), Vector2(0.948, 0.052)], outward, 0.045)
		_window(quarter, [Vector2(0.049, 0.055), Vector2(0.046, 0.920), Vector2(0.895, 0.915), Vector2(0.756, 0.118)], outward, 0.107)
		# A separate fixed quarter-light is visible behind each mirror.
		var divider_top := _panel_point(door, 0.230, 0.916) + outward * 0.010
		var divider_low := _panel_point(door, 0.376, 0.055) + outward * 0.010
		_line(divider_low, divider_top, 0.015, "dark", SEAL)
		var shut_top := post_top + outward * 0.002
		_line(shut_top, post_low + outward * 0.002, 0.004, "dark", Color("52504c"))
		_line(post_low + outward * 0.003, _side_point(post_low.z, 0.416, side) + outward * 0.005, 0.004, "dark", Color("52504c"))
		_line(corners[1] + outward * 0.003, corners[2] + outward * 0.003, 0.007, "dark", SEAL)
		_build_mirror(side)
		for segment in 24:
			var a := _cabin_edge(segment / 24.0, 0.0, side)
			var b := _cabin_edge((segment + 1) / 24.0, 0.0, side)
			_quad(a, b, _side_point(b.z, _body_height(b.z), side),
				_side_point(a.z, _body_height(a.z), side), "paint", PAINT, outward)
	for segment in 24:
		var u := segment / 12.0 - 1.0
		var v := (segment + 1) / 12.0 - 1.0
		var a := _hood_point(FRONT_GLASS_BOTTOM.z, u)
		var b := _hood_point(FRONT_GLASS_BOTTOM.z, v)
		var lip := FRONT_GLASS_BOTTOM
		_quad(a, b, Vector3(lip.x * v, lip.y, lip.z), Vector3(lip.x * u, lip.y, lip.z), "paint", PAINT, Vector3.UP)
	_window(_end_window(FRONT_GLASS_BOTTOM, FRONT_GLASS_TOP),
		[Vector2(0.049, 0.047), Vector2(0.044, 0.927), Vector2(0.956, 0.927), Vector2(0.951, 0.047)], Vector3.FORWARD, 0.063)
	_window(_end_window(HATCH_GLASS_BOTTOM, HATCH_GLASS_TOP),
		[Vector2(0.088, 0.090), Vector2(0.057, 0.897), Vector2(0.943, 0.897), Vector2(0.912, 0.090)], Vector3.BACK, 0.064)
	for column in 20:
		for row in 16:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var u := (column + corner.x) / 10.0 - 1.0
				var v := (row + corner.y) / 16.0
				points.append(_roof_point(u, v))
				var across := _roof_point(u + 0.001, v) - _roof_point(u - 0.001, v)
				var along := _roof_point(u, v + 0.001) - _roof_point(u, v - 0.001)
				normals.append(along.cross(across).normalized())
			_smooth_quad(points, normals, "paint", PAINT)
	for front: bool in [true, false]:
		var edge := FRONT_GLASS_TOP if front else HATCH_GLASS_TOP
		var t := 0.0 if front else 1.0
		for column in 20:
			var u0 := column / 10.0 - 1.0
			var u1 := (column + 1) / 10.0 - 1.0
			_quad(Vector3(u0 * edge.x, edge.y, edge.z), Vector3(u1 * edge.x, edge.y, edge.z),
				_roof_point(u1, t), _roof_point(u0, t), "paint", PAINT, Vector3.FORWARD if front else Vector3.BACK)


func _roof_point(u: float, v: float) -> Vector3:
	var edge := FRONT_GLASS_TOP.lerp(HATCH_GLASS_TOP, v)
	edge.x *= u
	edge.y += (1.0 - u * u) * (0.020 + 0.011 * sin(PI * v))
	return edge


func _cabin_edge(u: float, v: float, side: float) -> Vector3:
	var lower := FRONT_GLASS_BOTTOM.lerp(HATCH_GLASS_BOTTOM, u)
	var upper := FRONT_GLASS_TOP.lerp(HATCH_GLASS_TOP, u)
	return lower.lerp(upper, v) * Vector3(side, 1, 1)


func _end_window(lower: Vector3, upper: Vector3) -> Array[Vector3]:
	var left := Vector3(-1, 1, 1)
	return [lower * left, upper * left, upper, lower]


func _panel_point(points: Array[Vector3], u: float, v: float) -> Vector3:
	return points[0].lerp(points[3], u).lerp(points[1].lerp(points[2], u), v)


func _window(perimeter: Array[Vector3], opening_uv: Array[Vector2], outward: Vector3, rounding: float) -> void:
	var opening: Array[Vector3] = []
	var center := Vector3.ZERO
	for uv in opening_uv:
		var point := _panel_point(perimeter, uv.x, uv.y)
		opening.append(point)
		center += point * 0.25
	var painted_edge: Array[Vector3] = []
	var rubber_edge: Array[Vector3] = []
	for index in 4:
		var previous := opening[index].lerp(opening[(index + 3) % 4], rounding)
		var next := opening[index].lerp(opening[(index + 1) % 4], rounding)
		for sample in 5:
			var t := sample / 4.0
			var boundary := previous.lerp(opening[index], t).lerp(opening[index].lerp(next, t), t)
			painted_edge.append(perimeter[index].lerp(boundary, 0.10))
			rubber_edge.append(boundary)
	for index in rubber_edge.size():
		var next := (index + 1) % rubber_edge.size()
		var a := rubber_edge[index]
		var b := rubber_edge[next]
		var inner_a := a.move_toward(center, 0.017) + outward * 0.004
		var inner_b := b.move_toward(center, 0.017) + outward * 0.004
		var outer_a := painted_edge[index]
		var outer_b := painted_edge[next]
		_triangle(perimeter[index / 5], outer_a, outer_b, "paint", PAINT, outward)
		if index % 5 == 4:
			_triangle(perimeter[index / 5], outer_b, perimeter[next / 5], "paint", PAINT, outward)
		_quad(outer_a, outer_b, b, a, "paint", PAINT, outward)
		_quad(a, b, inner_b, inner_a, "dark", SEAL, outward)
		var apex := center + outward * 0.010
		_triangle(apex, inner_a.lerp(apex, 0.5), inner_b.lerp(apex, 0.5), "glass", GLASS, outward)
		_quad(inner_a.lerp(apex, 0.5), inner_a, inner_b, inner_b.lerp(apex, 0.5), "glass", GLASS, outward)


func _build_mirror(side: float) -> void:
	_line(Vector3(side * 0.724, 0.453, -0.602), Vector3(side * 0.803, 0.471, -0.542), 0.037, "dark", DARK)
	_rounded_box(Vector3(side * 0.853, 0.476, -0.543), Vector3(0.158, 0.088, 0.088), 0.020, "bumper", Color("383737"))
	_rounded_box(Vector3(side * 0.855, 0.478, -0.496), Vector3(0.125, 0.061, 0.011), 0.005, "steel", Color("9ba2a4"))


func _build_ends() -> void:
	for end: float in [-1, 1]:
		_build_fascia(end)
		_build_bumper(end)
		_license_plate(end)
	var front := Vector3.FORWARD
	_fascia_panel(Vector2(-0.410, 0.135), Vector2(0.410, 0.292), -1, 0.007, 0.004, "dark", Color("222322"))
	for row in 7:
		var y := 0.143 + row * 0.0235
		_fascia_panel(Vector2(-0.407, y), Vector2(0.407, y + 0.007), -1, 0.013, 0.002, "bumper", Color("575755"))
	for side: float in [-1, 1]:
		_optic(side, 0.409, 0.710, 0.132, 0.293, -1, 0.011, "dark", Color("393936"))
		_reflector(side)
		_optic(side, 0.420, 0.706, 0.143, 0.285, -1, 0.027, "headlight_glass", Color(0.78, 0.81, 0.80, 0.36))
		_optic(side, 0.707, 0.802, 0.129, 0.294, -1, 0.018, "dark", Color("4b3b2e"))
		_optic(side, 0.712, 0.801, 0.135, 0.289, -1, 0.025, "lens", Color("d87911"))
		_lens_flutes(side, 0.718, 0.786, 0.149, 0.278, -1, 0.026, 9, "lens", Color("eca12c"))
		_lamp_return(side, -1, -1.781, 0.132, 0.292, 0.014, "dark", Color("4b3b2e"))
		_lamp_return(side, -1, -1.786, 0.139, 0.285, 0.021, "lens", Color("c87616"))
		_rear_lamp(side)
	var front_badge := _fascia_point(Vector2(0, 0.209), -1, 0.021)
	_vw_badge(front_badge, 0.052, front)
	_vw_badge(_hatch_point(-0.605, 0.402) + Vector3.BACK * 0.006, 0.042, Vector3(0, 0.32, 1).normalized())
	_model_text(_hatch_point(0.579, 0.408) + Vector3.BACK * 0.012, "GOL", 0.00103)
	_model_text(_hatch_point(0.618, 0.377) + Vector3.BACK * 0.012, "1000", 0.00075, Color("92521c"))
	var lock := _hatch_point(0, 0.390) + Vector3.BACK * 0.004
	_round_face(lock, 0.014, Vector3.BACK, "chrome", CHROME, 16)
	_round_face(lock + Vector3.BACK * 0.002, 0.009, Vector3.BACK, "dark", DARK, 12)
	_exhaust(Vector3(-0.529, -0.240, 1.799))


func _build_fascia(end: float) -> void:
	var front := end < 0
	var rows := PackedFloat32Array([0.044, 0.095, 0.126, 0.298, 0.321]) if front else PackedFloat32Array([0.001, 0.067, 0.077, 0.100, 0.188, 0.259, 0.287, 0.294])
	for segment in 40:
		var x0 := -0.800 + 1.600 * segment / 40.0
		var x1 := -0.800 + 1.600 * (segment + 1) / 40.0
		for row in range(rows.size() - 1):
			var a := _fascia_point(Vector2(x0, rows[row]), end)
			var b := _fascia_point(Vector2(x1, rows[row]), end)
			var c := _fascia_point(Vector2(x1, rows[row + 1]), end)
			var d := _fascia_point(Vector2(x0, rows[row + 1]), end)
			_quad(a, b, c, d, "paint", PAINT, Vector3.BACK * end)
		if front:
			# Form the leading edge of the bonnet from the last stamped section.
			var a := _fascia_point(Vector2(x0, rows[-1]), end)
			var b := _fascia_point(Vector2(x1, rows[-1]), end)
			var c := _hood_point(FRONT_WING_END, x1 / 0.800)
			var d := _hood_point(FRONT_WING_END, x0 / 0.800)
			_quad(a, b, c, d, "paint", PAINT, Vector3.UP + Vector3.FORWARD)
		else:
			var a := _fascia_point(Vector2(x0, 0.294), end)
			var b := _fascia_point(Vector2(x1, 0.294), end)
			var c := _hatch_point(x1 * 0.935, 0.306)
			var d := _hatch_point(x0 * 0.935, 0.306)
			_quad(a, b, c, d, "paint", PAINT, Vector3.BACK)
			_quad(d, c, _hatch_point(x1 * 0.930, 0.470), _hatch_point(x0 * 0.930, 0.470), "paint", PAINT, Vector3.BACK)
			_line(a + Vector3.BACK * 0.001, b + Vector3.BACK * 0.001, 0.004, "dark", Color("58524b"))
	for side: float in [-1, 1]:
		if not front:
			var lower := _hatch_point(side * 0.745, 0.306)
			var upper := _hatch_point(side * 0.742, 0.470)
			_quad(lower, upper, _side_point(REAR_WING_END, _body_height(REAR_WING_END), side),
				_fascia_point(Vector2(side * 0.800, 0.294), end), "paint", PAINT, Vector3.RIGHT * side)
			_line(lower + Vector3.BACK * 0.002, upper + Vector3.BACK * 0.002, 0.005, "dark", Color("59534d"))


func _fascia_point(point: Vector2, end: float, offset := 0.0) -> Vector3:
	var corner := smoothstep(0.610, 0.800, absf(point.x))
	var flat := 1.904 if end < 0 else 1.832
	var wing := FRONT_WING_END if end < 0 else REAR_WING_END
	var width := _side_width(wing, point.y)
	var x := lerpf(point.x, point.x * width / 0.800, smoothstep(0.40, 0.800, absf(point.x)))
	var z := lerpf(flat * end, wing, corner) + offset * end * (1.0 - corner * 0.72)
	if end > 0:
		var recess := (1.0 - smoothstep(0.186, 0.240, absf(point.x))) * smoothstep(0.077, 0.100, point.y)
		z -= 0.021 * recess * (1.0 - smoothstep(0.259, 0.287, point.y))
	return Vector3(x + signf(x) * offset * corner * 0.65, point.y, z)


func _hatch_point(x: float, y: float) -> Vector3:
	var height := inverse_lerp(0.306, 0.470, y)
	return Vector3(x, y, lerpf(1.832, HATCH_GLASS_BOTTOM.z, height) - 0.013 * pow(absf(x) / 0.745, 4) * (1.0 - height))


func _build_bumper(end: float) -> void:
	# Cross sections follow one molded bumper from the axle back around the nose.
	var front := end < 0
	var z := absf(FRONT_END if front else REAR_END)
	var outline: Array[Vector2] = [Vector2(0, z), Vector2(0.35, z - 0.004), Vector2(0.59, z - 0.021),
		Vector2(0.710, z - 0.050), Vector2(0.773, z - 0.084), Vector2(0.8005, z - 0.142),
		Vector2(0.799, z - 0.192), Vector2(0.790, z - 0.331)]
	var upper := 0.060 if front else 0.036
	var profiles: Array[Vector2] = [Vector2(upper + 0.008, 0.037), Vector2(upper, 0.006),
		Vector2(upper - 0.020, 0), Vector2(-0.026, 0.003), Vector2(-0.035, 0.009),
		Vector2(-0.042, 0.002), Vector2(-0.129, 0.015), Vector2(-0.207, 0.076), Vector2(-0.220, 0.114)]
	var shades: Array[Color] = [Color("61605d"), BUMPER, BUMPER, Color("333231"), Color("393735"), BUMPER, Color("4b4946"), Color("3c3936")]
	for side: float in [-1, 1]:
		for row in range(profiles.size() - 1):
			for column in range(outline.size() - 1):
				var a := _bumper_point(outline[column], profiles[row], column, end, side)
				var b := _bumper_point(outline[column + 1], profiles[row], column + 1, end, side)
				var c := _bumper_point(outline[column + 1], profiles[row + 1], column + 1, end, side)
				var d := _bumper_point(outline[column], profiles[row + 1], column, end, side)
				var normal_a := _bumper_normal(outline, profiles[row], profiles[row + 1], column, end, side)
				var normal_b := _bumper_normal(outline, profiles[row], profiles[row + 1], column + 1, end, side)
				_smooth_quad([a, b, c, d], [normal_a, normal_b, normal_b, normal_a], "bumper", shades[row])
			var outer_a := _bumper_point(outline[-1], profiles[row], 7, end, side)
			var outer_b := _bumper_point(outline[-1], profiles[row + 1], 7, end, side)
			var inward := Vector3(-side * 0.055, 0, 0)
			_quad(outer_a, outer_b, outer_b + inward, outer_a + inward, "bumper", BUMPER, Vector3.FORWARD * end)
	if front:
		for side: float in [-1, 1]:
			for slot in 4:
				var y := -0.106 - slot * 0.014
				var inner := Vector3(side * 0.207, y, -z + 0.003 + slot * 0.008)
				var outer := Vector3(side * (0.641 - slot * 0.020), y, -z + 0.028 + slot * 0.010)
				_line(inner, outer, 0.009, "dark", Color("2c2b2a"))


func _bumper_point(station: Vector2, profile: Vector2, column: int, end: float, side: float) -> Vector3:
	var corner := smoothstep(2, 6, column)
	var y := profile.x + 0.055 * smoothstep(5, 7, column) * smoothstep(0.0, 0.22, -profile.x)
	return Vector3(side * (station.x - profile.y * corner * 0.38), y, end * (station.y - profile.y * (1.0 - corner * 0.7)))


func _bumper_normal(outline: Array[Vector2], top: Vector2, bottom: Vector2, column: int, end: float, side: float) -> Vector3:
	var previous := maxi(0, column - 1)
	var next := mini(outline.size() - 1, column + 1)
	var middle := (top + bottom) * 0.5
	var tangent := _bumper_point(outline[next], middle, next, end, side) - _bumper_point(outline[previous], middle, previous, end, side)
	if column == 0:
		tangent = Vector3.RIGHT * side
	var down := _bumper_point(outline[column], bottom, column, end, side) - _bumper_point(outline[column], top, column, end, side)
	return (down.cross(tangent) * side * end).normalized()


func _rear_lamp(side: float) -> void:
	_optic(side, 0.305, 0.801, 0.073, 0.289, 1, 0.010, "dark", Color("292221"))
	_optic(side, 0.317, 0.423, 0.194, 0.280, 1, 0.018, "reverse_lamp", Color("c0c5c4"))
	_optic(side, 0.430, 0.678, 0.194, 0.280, 1, 0.018, "lens", Color("b8641c"))
	_optic(side, 0.685, 0.800, 0.194, 0.280, 1, 0.018, "lens", Color("ca6d17"))
	_lens_flutes(side, 0.444, 0.767, 0.205, 0.260, 1, 0.020, 28, "lens", Color("d28c32"))
	var red: Array[Color] = [Color("8e2221"), Color("a52422"), Color("7b201d")]
	var split := PackedFloat32Array([0.317, 0.438, 0.681, 0.801])
	for column in 3:
		_optic(side, split[column] + 0.003, split[column + 1] - 0.005, 0.081, 0.187, 1, 0.019, "tail_lamp", red[column])
	_lens_flutes(side, 0.325, 0.786, 0.095, 0.172, 1, 0.021, 30, "tail_lamp", Color("aa3431"))
	_lamp_return(side, 1, 1.714, 0.073, 0.289, 0.013, "dark", Color("292221"))
	_lamp_return(side, 1, 1.721, 0.084, 0.185, 0.017, "tail_lamp", Color("81211f"))
	_lamp_return(side, 1, 1.721, 0.195, 0.281, 0.017, "lens", Color("ad561b"))


func _lamp_return(side: float, end: float, z: float, low: float, high: float, depth: float, label: String, color: Color) -> void:
	# Follow the stamped side through the shoulder instead of spanning it with a flat lens.
	for row in 12:
		var y0 := lerpf(low, high, row / 12.0)
		var y1 := lerpf(low, high, (row + 1) / 12.0)
		for section in 6:
			var t0 := section / 6.0
			var t1 := (section + 1) / 6.0
			var points: Array[Vector3] = [_lamp_return_point(side, end, z, y0, t0, depth),
				_lamp_return_point(side, end, z, y0, t1, depth), _lamp_return_point(side, end, z, y1, t1, depth),
				_lamp_return_point(side, end, z, y1, t0, depth)]
			_quad(points[0], points[1], points[2], points[3], label, color, Vector3.RIGHT * side)


func _lamp_return_point(side: float, end: float, z: float, y: float, t: float, depth: float) -> Vector3:
	var corner := _fascia_point(Vector2(side * 0.798, y), end, depth)
	var along := lerpf(corner.z, z, t)
	var sidewall := _side_point(along, y, side) + Vector3.RIGHT * (depth * 1.03 * side)
	sidewall.x = lerpf(corner.x, sidewall.x, smoothstep(0.0, 0.28, t))
	return sidewall


func _optic(side: float, inner: float, outer: float, bottom: float, top: float, end: float, depth: float, label: String, color: Color) -> void:
	var x0 := minf(inner * side, outer * side)
	var x1 := maxf(inner * side, outer * side)
	_fascia_panel(Vector2(x0, bottom), Vector2(x1, top), end, depth, 0.010, label, color)


func _fascia_panel(lo: Vector2, hi: Vector2, end: float, depth: float, bevel: float, label: String, color: Color) -> void:
	var rise := minf(bevel, (hi.y - lo.y) * 0.37)
	var sections: Array[float] = [lo.x, lo.x + rise]
	for index in range(1, ceili((hi.x - lo.x) / 0.028)):
		var x := lerpf(lo.x, hi.x, index / float(ceili((hi.x - lo.x) / 0.028)))
		if x > lo.x + rise and x < hi.x - rise:
			sections.append(x)
	sections.append(hi.x - rise)
	sections.append(hi.x)
	var heights: Array[float] = [lo.y, lo.y + rise, hi.y - rise, hi.y]
	for column in range(sections.size() - 1):
		for row in 3:
			var face: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var i := column + corner.x
				var j := row + corner.y
				var edge := j == 0 or j == 3 or i == 0 or i == sections.size() - 1
				var x := sections[i]
				if j == 0 or j == 3:
					x = clampf(x, lo.x + rise * 0.45, hi.x - rise * 0.45)
				face.append(_fascia_point(Vector2(x, heights[j]), end, depth - (rise * 0.55 if edge else 0.0)))
			_quad(face[0], face[1], face[2], face[3], label, color, Vector3.BACK * end)


func _lens_flutes(side: float, inner: float, outer: float, low: float, high: float, end: float, offset: float, count: int, label: String, color: Color) -> void:
	for index in count:
		var x := side * lerpf(inner, outer, (index + 0.5) / count)
		_line(_fascia_point(Vector2(x, low), end, offset), _fascia_point(Vector2(x, high), end, offset), 0.0014, label, color)


func _license_plate(end: float) -> void:
	var front := end < 0
	var y := -0.082 if front else 0.176
	var z := FRONT_END - 0.002 if front else REAR_END - 0.041
	var direction := Vector3.BACK * end
	_rounded_box(Vector3(0, y, z), Vector3(0.377, 0.135, 0.016), 0.008, "dark", Color("292928"))
	_rounded_box(Vector3(0, y, z) + direction * 0.010, Vector3(0.357, 0.117, 0.007), 0.003, "lens", Color("c5c3b9"))
	_plate_text(Vector3(0, y - 0.009, z) + direction * 0.015, end)
	for x in [-0.146, 0.146]:
		_round_face(Vector3(x, y + 0.041, z) + direction * 0.014, 0.003, direction, "dark", Color("77746d"), 8)


func _exhaust(tip: Vector3) -> void:
	var inlet := tip + Vector3(0.016, 0.045, -0.26)
	var bend := tip + Vector3(0.0, -0.004, -0.08)
	for segment in 20:
		var a := TAU * segment / 20.0
		var b := TAU * (segment + 1) / 20.0
		var radial_a := Vector3(cos(a), sin(a), 0)
		var radial_b := Vector3(cos(b), sin(b), 0)
		var normals: Array[Vector3] = [radial_a, radial_b, radial_b, radial_a]
		_smooth_quad([inlet + radial_a * 0.021, inlet + radial_b * 0.021,
			bend + radial_b * 0.021, bend + radial_a * 0.021], normals, "dark", Color("494740"))
		_smooth_quad([bend + radial_a * 0.021, bend + radial_b * 0.021,
			tip + radial_b * 0.024, tip + radial_a * 0.024], normals, "steel", Color("77756d"))
		_quad(tip + radial_a * 0.024, tip + radial_b * 0.024, tip + radial_b * 0.019, tip + radial_a * 0.019,
			"steel", Color("99978e"), Vector3.BACK)
	_round_face(tip - Vector3.BACK * 0.006, 0.020, Vector3.BACK, "dark", Color("181714"), 20)


func _vw_badge(center: Vector3, radius: float, outward: Vector3) -> void:
	var right := Vector3.RIGHT * signf(outward.z)
	var up := outward.cross(right).normalized()
	_round_face(center, radius, outward, "dark", Color("242427"), 32)
	for segment in 32:
		var a := TAU * segment / 32.0
		var b := TAU * (segment + 1) / 32.0
		var rim := center + outward * 0.003
		_line(rim + radius * (right * cos(a) + up * sin(a)), rim + radius * (right * cos(b) + up * sin(b)), radius * 0.067, "chrome", CHROME)
	for stroke in [[Vector2(-0.41, 0.65), Vector2(0, 0.05), Vector2(0.41, 0.65)],
			[Vector2(-0.70, 0.20), Vector2(-0.33, -0.65), Vector2(0, -0.13), Vector2(0.33, -0.65), Vector2(0.70, 0.20)]]:
		for index in range(stroke.size() - 1):
			var a: Vector2 = stroke[index] * radius
			var b: Vector2 = stroke[index + 1] * radius
			var face := center + outward * 0.004
			_line(face + right * a.x + up * a.y, face + right * b.x + up * b.y, radius * 0.074, "chrome", CHROME)


func _build_interior() -> void:
	var fabric := Color("66615d")
	_box(Vector3(0, 0.06, 0.40), Vector3(1.35, 0.10, 2.35), "dark", Color("171c20"))
	_box(Vector3(0, 0.384, -0.48), Vector3(1.34, 0.16, 0.38), "dark", DARK)
	_box(Vector3(0, 0.27, 0.18), Vector3(0.18, 0.25, 0.68), "dark", DARK)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.35, 0.28, 0.14), Vector3(0.23, 0.075, 0.235), "dark", fabric)
		_rounded_box(Vector3(side * 0.35, 0.504, 0.355), Vector3(0.439, 0.463, 0.159), 0.070, "fabric", fabric)
		_rounded_box(Vector3(side * 0.35, 0.794, 0.378), Vector3(0.234, 0.126, 0.108), 0.049, "fabric", fabric.lightened(0.04))
		for pin in [-0.059, 0.059]:
			_line(Vector3(side * 0.35 + pin, 0.713, 0.378), Vector3(side * 0.35 + pin, 0.755, 0.378), 0.008, "steel", Color("6d6b65"))
		for seam in [-0.16, 0.16]:
			_line(Vector3(side * 0.35 + seam, 0.31, 0.284), Vector3(side * 0.35 + seam, 0.69, 0.284), 0.003, "fabric", Color("686b66"))
		for rib in 5:
			_line(Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, -0.05), Vector3(side * 0.35 - 0.18 + rib * 0.09, 0.35, 0.30), 0.005, "dark", Color("53595b"))
		_box(Vector3(side * 0.697, 0.33, 0.58), Vector3(0.025, 0.25, 1.3), "dark", fabric)
	_rounded_box(Vector3(0, 0.28, 1.08), Vector3(1.12, 0.15, 0.40), 0.04, "fabric", fabric)
	_rounded_box(Vector3(0, 0.48, 1.24), Vector3(1.12, 0.34, 0.12), 0.04, "fabric", fabric)
	_rounded_box(Vector3(0, 0.459, 1.480), Vector3(1.28, 0.036, 0.385), 0.014, "fabric", Color("353432"))
	var steering := Vector3(-0.34, 0.57, -0.26)
	for segment in 24:
		var a := TAU * segment / 24
		var b := TAU * (segment + 1) / 24
		_line(steering + Vector3(cos(a) * 0.14, sin(a) * 0.11, 0), steering + Vector3(cos(b) * 0.14, sin(b) * 0.11, 0), 0.016, "dark", DARK)
	for side in [-1.0, 1.0]:
		_line(steering, steering + Vector3(side * 0.13, 0, 0), 0.02, "dark", DARK)
	_line(Vector3(0, 0.40, 0.02), Vector3(0, 0.51, 0.02), 0.009, "dark", DARK)
	_box(Vector3(0, 0.764, -0.09), Vector3(0.20, 0.07, 0.04), "dark", DARK)
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
	_box(Vector3(0.08, 0.398, -0.282), Vector3(0.18, 0.038, 0.008), "dark", Color("111718"))
	_box(Vector3(0.05, 0.403, -0.272), Vector3(0.08, 0.012, 0.002), "dark", Color("62645d"))
	_line(Vector3(0.29, 0.37, -0.278), Vector3(0.61, 0.37, -0.278), 0.003, "dark", Color("111718"))
	_rounded_box(Vector3(0.45, 0.386, -0.270), Vector3(0.09, 0.015, 0.009), 0.003, "dark", DARK)
	# Roof lining sits behind the painted roof, leaving the windows unobstructed.
	_box(Vector3(0, 0.892, 0.36), Vector3(1.15, 0.014, 0.93), "fabric", Color("a2a094"))


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
	for side: float in [-1, 1]:
		var a := _hood_point(-1.87, side * 0.93) + Vector3.UP * 0.002
		for segment in range(1, 17):
			var z := lerpf(-1.87, -0.755, segment / 16.0)
			var b := _hood_point(z, side * 0.93) + Vector3.UP * 0.002
			_line(a, b, 0.003, "dark", Color("6e6b65"))
			a = b
		_line(a, _hood_point(-0.748, side * 0.025) + Vector3.UP * 0.002, 0.003, "dark", Color("6e6b65"))
		var pivot := _windshield_point(side * 0.429, 0.041)
		var blade := _windshield_point(side * 0.242, 0.115)
		_line(pivot, blade, 0.010, "dark", Color("292927"))
		_line(blade + Vector3.LEFT * 0.165, blade + Vector3.RIGHT * 0.151, 0.011, "dark", Color("242522"))
	for slot in 31:
		var x := (slot - 15) * 0.022
		var z := -0.723 - 0.021 * absf(x)
		var a := _hood_point(z, x / 0.77) + Vector3.UP * 0.002
		var b := _hood_point(z - 0.018, x / 0.77) + Vector3.UP * 0.002
		_line(a, b, 0.005, "dark", Color("3c3c38"))


func _windshield_point(x: float, t: float) -> Vector3:
	var edge := FRONT_GLASS_BOTTOM.lerp(FRONT_GLASS_TOP, t)
	return Vector3(x, edge.y + 0.004, edge.z - 0.013)


func _coachwork_details() -> void:
	for side: float in [-1, 1]:
		var handle_x := side * (_side_width(0.467, 0.348) + 0.012)
		_rounded_box(Vector3(handle_x - side * 0.009, 0.350, 0.455), Vector3(0.019, 0.052, 0.132), 0.008, "paint", Color("a5a098"))
		_rounded_box(Vector3(handle_x, 0.354, 0.468), Vector3(0.027, 0.024, 0.146), 0.006, "dark", Color("2d2c2a"))
		_round_face(Vector3(handle_x + side * 0.015, 0.352, 0.520), 0.007, Vector3.RIGHT * side, "chrome", CHROME, 12)
	var filler := _side_point(1.579, 0.182, 1.0) + Vector3.RIGHT * 0.004
	_round_face(filler, 0.050, Vector3.RIGHT, "bumper", Color("363533"), 24)
	_round_face(filler + Vector3.RIGHT * 0.002, 0.011, Vector3.RIGHT, "dark", Color("212220"), 12)
	_line(filler + Vector3(0.003, 0, -0.007), filler + Vector3(0.003, 0, 0.007), 0.002, "chrome", Color("8b8881"))
	for row in 8:
		var t := 0.161 + row * 0.097
		var edge := HATCH_GLASS_BOTTOM.lerp(HATCH_GLASS_TOP, t)
		var width := edge.x - 0.124
		_line(Vector3(-width, edge.y, edge.z + 0.011), Vector3(width, edge.y, edge.z + 0.011), 0.0010, "lens", Color("897257"))


func _side_molding(side: float, from: float, to: float) -> void:
	for segment in 12:
		var a := _side_point(lerpf(from, to, segment / 12.0), -0.068, side)
		var b := _side_point(lerpf(from, to, (segment + 1) / 12.0), -0.068, side)
		_line(a + Vector3.RIGHT * side * 0.006, b + Vector3.RIGHT * side * 0.006, 0.014, "bumper", Color("3e3b38"))


func _build_wheel() -> void:
	# The narrow 145 R13 tire has a 568 mm outside diameter and a tall sidewall.
	var profile: Array[Vector2] = [Vector2(-0.063, 0.176), Vector2(-0.071, 0.211), Vector2(-0.075, 0.245),
		Vector2(-0.065, 0.270), Vector2(-0.047, 0.283), Vector2(0.0, 0.284),
		Vector2(0.047, 0.283), Vector2(0.065, 0.270), Vector2(0.075, 0.245), Vector2(0.071, 0.211), Vector2(0.063, 0.176)]
	for row in range(profile.size() - 1):
		for segment in 72:
			var points: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var index := row + corner.x
				var angle := TAU * (segment + corner.y) / 72.0
				var tangent := profile[mini(index + 1, profile.size() - 1)] - profile[maxi(index - 1, 0)]
				points.append(_wheel_point(profile[index], angle, 1.0))
				normals.append(Vector3(tangent.x * cos(angle), -tangent.y, tangent.x * sin(angle)).normalized())
			_smooth_quad(points, normals, "rubber", Color("242322"))
	for side: float in [-1, 1]:
		_wheel_face(side)
		for segment in 60:
			var a := TAU * segment / 60.0
			var center := _wheel_point(Vector2(side * 0.005, 0.285), a, 1)
			var shoulder := _wheel_point(Vector2(side * 0.051, 0.281), a + side * 0.085, 1)
			_line(center, shoulder, 0.0027, "rubber", Color("171715"))


func _wheel_face(side: float) -> void:
	var silver := Color("babbba")
	var rims: Array[Vector2] = [Vector2(0.048, 0.184), Vector2(0.066, 0.183), Vector2(0.073, 0.178),
		Vector2(0.074, 0.172), Vector2(0.061, 0.164), Vector2(0.048, 0.153), Vector2(0.046, 0.145)]
	var finish: Array[Color] = [silver, Color("d5d4d0"), Color("a2a4a4"), Color("737675"), Color("9c9c98"), silver]
	var rim_normals: Array[Vector2] = [Vector2(0, 1), Vector2(0.55, 0.83), Vector2(0.98, 0.2),
		Vector2(0.88, -0.48), Vector2(0.5, -0.86), Vector2(0.76, -0.65), Vector2(1, 0)]
	for row in range(rims.size() - 1):
		for segment in 72:
			var a := TAU * segment / 72.0
			var b := TAU * (segment + 1) / 72.0
			_smooth_quad([_wheel_point(rims[row], a, side), _wheel_point(rims[row], b, side),
				_wheel_point(rims[row + 1], b, side), _wheel_point(rims[row + 1], a, side)],
				[_wheel_point(rim_normals[row], a, side), _wheel_point(rim_normals[row], b, side),
				_wheel_point(rim_normals[row + 1], b, side), _wheel_point(rim_normals[row + 1], a, side)], "steel", finish[row])
	_round_face(Vector3(0, side * 0.025, 0), 0.160, Vector3.UP * side, "dark", Color("252625"), 48)
	for slot in 6:
		_steel_vent(TAU * (slot + 0.5) / 6, side, silver)
	_round_face(Vector3(0, side * 0.058, 0), 0.076, Vector3.UP * side, "steel", Color("a1a4a3"), 32)
	_round_face(Vector3(0, side * 0.062, 0), 0.047, Vector3.UP * side, "dark", Color("272925"), 24)
	for bolt in 4:
		var angle := TAU * (bolt + 0.5) / 4
		var center := _wheel_point(Vector2(0.060, 0.056), angle, side)
		_round_face(center, 0.011, Vector3.UP * side, "dark", Color("575953"), 12)
		_round_face(center + Vector3.UP * side * 0.003, 0.006, Vector3.UP * side, "steel", Color("bbbcb5"), 6)
	_round_face(Vector3(0, side * 0.068, 0), 0.033, Vector3.UP * side, "dark", Color("363936"), 24)
	var valve := _wheel_point(Vector2(0.063, 0.158), PI / 6.0, side)
	_round_face(valve, 0.005, Vector3.UP * side, "dark", DARK, 10)


func _steel_vent(angle: float, side: float, silver: Color) -> void:
	var edge := TAU / 12.0
	var angles: Array[float] = [-edge, -0.29, -0.178, -0.153, -0.107, 0.0, 0.107, 0.153, 0.178, 0.29, edge]
	for segment in range(angles.size() - 1):
		var a := angles[segment]
		var b := angles[segment + 1]
		var lower_a := _vent_radius(a, -1.0)
		var lower_b := _vent_radius(b, -1.0)
		var upper_a := _vent_radius(a, 1.0)
		var upper_b := _vent_radius(b, 1.0)
		var outward := Vector3.UP * side
		_quad(_wheel_point(Vector2(0.058, 0.071), angle + a, side), _wheel_point(Vector2(0.058, 0.071), angle + b, side),
			_wheel_point(Vector2(0.055, lower_b), angle + b, side), _wheel_point(Vector2(0.055, lower_a), angle + a, side), "steel", silver, outward)
		_quad(_wheel_point(Vector2(0.055, upper_a), angle + a, side), _wheel_point(Vector2(0.055, upper_b), angle + b, side),
			_wheel_point(Vector2(0.046, 0.145), angle + b, side), _wheel_point(Vector2(0.046, 0.145), angle + a, side), "steel", silver, outward)
		if a >= -0.178 and b <= 0.178:
			for rim: float in [-1, 1]:
				var r0 := _vent_radius(a, rim)
				var r1 := _vent_radius(b, rim)
				_quad(_wheel_point(Vector2(0.055, r0), angle + a, side), _wheel_point(Vector2(0.055, r1), angle + b, side),
					_wheel_point(Vector2(0.042, r1 - rim * 0.003), angle + b, side),
					_wheel_point(Vector2(0.042, r0 - rim * 0.003), angle + a, side), "steel", Color("878986"), outward)


func _vent_radius(angle: float, direction: float) -> float:
	return 0.121 + direction * 0.012 * sqrt(maxf(0, 1.0 - pow(angle / 0.178, 2)))


func _wheel_point(section: Vector2, angle: float, side: float) -> Vector3:
	return Vector3(section.y * cos(angle), side * section.x, section.y * sin(angle))


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

func _reflector(side: float) -> void:
	# Prismatic fluting sits over the concave reflector and behind the cover.
	var center := _fascia_point(Vector2(side * 0.558, 0.212), -1, 0.011)
	_optic(side, 0.417, 0.705, 0.138, 0.287, -1, 0.013, "reflector", Color("aeb1ac"))
	for segment in 28:
		var a := TAU * segment / 28.0
		var b := TAU * (segment + 1) / 28.0
		var p := _fascia_point(Vector2(side * (0.558 + cos(a) * 0.125), 0.212 + sin(a) * 0.061), -1, 0.017)
		var q := _fascia_point(Vector2(side * (0.558 + cos(b) * 0.125), 0.212 + sin(b) * 0.061), -1, 0.017)
		var shade := 0.66 + 0.16 * sin(a) + 0.095 * cos(a * 9)
		_triangle(center, p, q, "reflector", Color(shade, shade, shade * 0.98), Vector3.FORWARD)
	_lens_flutes(side, 0.429, 0.690, 0.151, 0.275, -1, 0.018, 26, "reflector", Color("c9ccca"))
	_round_face(center + Vector3.FORWARD * 0.008, 0.011, Vector3.FORWARD, "reflector", Color("deded6"), 16)


func _hood_point(z: float, t: float) -> Vector3:
	var edge := _body_height(z)
	var crown := 0.018 * maxf(0.0, 1.0 - t * t) + 0.006 * (1.0 - smoothstep(0.87, 1.0, absf(t)))
	return Vector3(_side_width(z, edge) * t, edge + crown, z)


func _hood_normal(z: float, t: float) -> Vector3:
	var across := _hood_point(z, minf(t + 0.001, 1)) - _hood_point(z, maxf(t - 0.001, -1))
	var along := _hood_point(z + 0.001, t) - _hood_point(z - 0.001, t)
	return along.cross(across).normalized()


func _arch_bottom(z: float) -> float:
	var lower := SILL_Y
	for axle: float in AXLES:
		var distance := absf(z - axle) / _arch_width(axle)
		if distance < 1.0:
			lower = maxf(lower, WHEEL_Y + _arch_top(axle) * sqrt(1.0 - distance * distance))
	return lower


func _side_width(z: float, y: float) -> float:
	var y_shoulder := _shoulder_height(z)
	var shoulder := 0.028 * smoothstep(y_shoulder - 0.021, y_shoulder - 0.003, y)
	var roll := 0.040 * smoothstep(y_shoulder + 0.008, _body_height(z), y)
	var sill := 0.041 * smoothstep(-0.025, SILL_Y, y)
	var flare := 0.0
	for axle: float in AXLES:
		var distance := Vector2((z - axle) / _arch_width(axle), (y - WHEEL_Y) / _arch_top(axle)).length()
		flare += 0.014 * (1.0 - smoothstep(0.99, 1.16, distance)) * smoothstep(0.80, 0.99, distance)
	return _body_width(z) - 0.029 + shoulder - roll - sill + flare


func _side_point(z: float, y: float, side: float) -> Vector3:
	return Vector3(side * _side_width(z, y), y, z)


func _side_normal(point: Vector3, side: float) -> Vector3:
	var dy := (_side_width(point.z, point.y + 0.001) - _side_width(point.z, point.y - 0.001)) / 0.002
	var dz := (_side_width(point.z + 0.001, point.y) - _side_width(point.z - 0.001, point.y)) / 0.002
	return Vector3(side, -dy, -dz).normalized()


func _smooth_quad(points: Array[Vector3], normals: Array[Vector3], label: String, color: Color) -> void:
	for ids in [[0, 1, 2], [0, 2, 3]]:
		var face := (points[ids[1]] - points[ids[0]]).cross(points[ids[2]] - points[ids[0]])
		if face.length_squared() < 0.0000000001:
			continue
		if face.dot(normals[ids[0]]) > 0:
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

func _door_cut(side: float, top: Vector2, near_top: Vector2, near_bottom: Vector2, bottom: Vector2) -> void:
	var a := top
	for segment in range(1, 21):
		var b := top.bezier_interpolate(near_top, near_bottom, bottom, segment / 20.0)
		_side_seam_segment(side, a, b)
		a = b


func _panel_seam(side: float, start: Vector2, end: Vector2) -> void:
	for segment in 8:
		var a := start.lerp(end, segment / 8.0)
		var b := start.lerp(end, (segment + 1) / 8.0)
		_side_seam_segment(side, a, b)


func _side_seam_segment(side: float, a: Vector2, b: Vector2) -> void:
	var outward := Vector3.RIGHT * side * 0.004
	_line(_side_point(a.x, a.y, side) + outward, _side_point(b.x, b.y, side) + outward, 0.0045, "dark", Color("45413d"))


func _plate_text(center: Vector3, side: float) -> void:
	var text := TextMesh.new()
	text.text = "WAV-1000"
	text.font_size = 48
	text.pixel_size = 0.00127
	text.curve_step = 1.0
	text.depth = 0.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var points := text.get_faces()
	var transform := Transform3D(Basis(Vector3.UP, PI if side < 0 else 0.0), center)
	for index in range(0, points.size(), 3):
		_triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], "dark", Color("24313a"), Vector3.BACK * side)

func _model_text(center: Vector3, value: String, pixel_size: float, color := Color("34312d")) -> void:
	var mesh := TextMesh.new()
	mesh.text = value
	mesh.font_size = 48
	mesh.pixel_size = pixel_size
	mesh.curve_step = 1.0
	mesh.depth = 0.0
	var points := mesh.get_faces()
	var transform := Transform3D(Basis(Vector3.RIGHT, atan((1.832 - HATCH_GLASS_BOTTOM.z) / (HATCH_GLASS_BOTTOM.y - 0.306))), center)
	for index in range(0, points.size(), 3):
		_triangle(transform * points[index], transform * points[index + 1], transform * points[index + 2], "dark", color, Vector3.BACK)
