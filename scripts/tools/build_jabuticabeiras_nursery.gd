extends RefCounted

const Masonry = preload("res://scripts/tools/build_jabuticabeiras_masonry.gd")
const M = Masonry.Finish
const GLASS = preload("res://assets/shaders/jabuticabeiras/greenhouse_glass.gdshader")
const CLOUDS = preload("res://assets/textures/jabuticabeiras/ceu-apos-garoa.png")
const BRICK := Color("aa8872")
const BASALT := Color("777a70")
const BASE := Color("adab97")
const TRIM := Color("647d68")
const FRAME := Color("596f5a")
const IRON := "steel_gate"

var _street
var _masonry: Masonry
var _frame: Transform3D


func _init(street, masonry: Masonry) -> void:
	_street = street
	_masonry = masonry


func build(origin: Vector3, yaw: float) -> void:
	_frame = Transform3D(Basis(Vector3.UP, yaw), origin)
	_masonry.begin(_frame)
	_entry()
	_glasshouse(Vector3(-3.1, 0.30, -7.98))


func _entry() -> void:
	var yaw := _frame.basis.get_euler().y
	_street.add_collision(_frame * Vector3(0.0, 0.16, 0.0), Vector3(34.1, 0.47, 0.64), yaw)
	for side: float in [-1.0, 1.0]:
		_street.add_collision(_frame * Vector3(side * 9.45, 0.64, 0.0), Vector3(12.25, 1.39, 0.51), yaw)
		_masonry.box(Vector3(side * 9.58, 0.58, 0.0), Vector3(13.55, 1.27, 0.53), M.STONE, BASALT)
		_masonry.box(Vector3(side * 9.58, 1.24, 0.0), Vector3(13.69, 0.11, 0.64), M.STONE, BASE)
		for pier: float in [3.13, 7.61, 12.06]:
			var width := 0.75 if pier < 4.0 else 0.49
			var high := 2.62 if pier < 4.0 else 2.14
			var pos := Vector3(side * pier, 0.0, 0.035)
			_masonry.box(pos + Vector3.UP * high * 0.5, Vector3(width, high, 0.78), M.BRICK, BRICK)
			for line: float in [0.23, high - 0.15, high + 0.018]:
				_masonry.box(pos + Vector3.UP * line, Vector3(width + 0.12, 0.079, 0.85), M.STONE, BASE)
		_fence(side * 3.36, side * 7.33, 1.31, 2.02, 16, false)
		_fence(side * 7.86, side * 11.82, 1.31, 2.02, 16, false)
		_fence(side * 0.047, side * 2.75, 0.24, 2.18, 13, true)
		var site := Vector3(side * 3.88, 0.31, -1.68)
		_street.planter(_frame * site, 1.26, yaw + side)
		_street.understory(_frame * (site + Vector3(side * 0.64, -0.08, -0.16)), 1.11, yaw + side * 1.58, false)
	var blocks := 23
	for segment in blocks:
		var near := (segment + 0.035) * PI / blocks
		var far := (segment + 0.965) * PI / blocks
		var inner_a := _arch(near, 2.78, 1.09)
		var outer_a := _arch(near, 3.26, 1.56)
		var inner_b := _arch(far, 2.78, 1.09)
		var outer_b := _arch(far, 3.26, 1.56)
		var shade := BRICK.lightened(0.03 * (segment % 4))
		if segment == blocks / 2:
			shade = BASE
		_arch_to_wall(inner_a, outer_a, inner_b, outer_b, shade)
	_street.add_collision(_frame * Vector3(0.0, 1.12, 0.0), Vector3(5.78, 2.16, 0.32), yaw)
	var plaque := Vector3(0.0, 3.15, 0.315)
	_masonry.box(plaque, Vector3(2.58, 0.386, 0.106), M.WOOD, Color("a68e67"))
	_masonry.box(plaque + Vector3.BACK * 0.064, Vector3(2.49, 0.302, 0.058), M.METAL, Color("3c5949"))
	_street.lettering("VIVEIRO MUNICIPAL", _frame * (plaque + Vector3.BACK * 0.097),
		yaw, 0.0056, Color("efe3bc"), true)
	for side: float in [-1.0, 1.0]:
		var sconce := Vector3(3.12 * side, 2.13, 0.43)
		_masonry.box(sconce, Vector3(0.176, 0.238, 0.154), M.LIGHT, Color("e6bb80"))
		_masonry.box(sconce + Vector3.UP * 0.144, Vector3(0.22, 0.039, 0.193), M.METAL, FRAME)
		_street.add_lamp(_frame * (sconce + Vector3.BACK * 0.10), 3.1, 0.84)


func _fence(first: float, last: float, bottom: float, top: float, slats: int, gate: bool) -> void:
	var low := minf(first, last)
	var high := maxf(first, last)
	var span := high - low
	var mid := (first + last) * 0.5
	var depth := 0.088
	for y: float in [bottom + 0.026, top - 0.08]:
		_masonry.box(Vector3(mid, y, depth), Vector3(span, 0.058, 0.09), M.METAL, TRIM)
	if gate:
		_masonry.box(Vector3(mid, bottom + 0.22, depth), Vector3(span - 0.05, 0.39, 0.081), M.METAL, FRAME)
		_beam(Vector3(first, bottom + 0.39, depth + 0.06), Vector3(last, top - 0.08, depth + 0.06), 0.019, IRON)
	for index in slats:
		var x := lerpf(low + 0.041, high - 0.041, float(index) / (slats - 1.0))
		var head := top + (0.067 if index % 3 == 1 else 0.016)
		_masonry.box(Vector3(x, (bottom + head) * 0.5, depth), Vector3(0.024, head - bottom, 0.040), M.METAL, TRIM)
		if index % 3 == 1:
			var lower := Vector3(x, top - 0.253, depth + 0.028)
			var upper := lower + Vector3.UP * 0.183
			for side: float in [-1.0, 1.0]:
				var offset := lower + Vector3(side * 0.066, 0.12, 0.0)
				_beam(lower, offset, 0.009, IRON)
				_beam(offset, upper, 0.009, IRON)


func _arch(angle: float, radius: float, lift: float) -> Vector3:
	return Vector3(cos(angle) * radius, 2.49 + sin(angle) * lift, 0.0)


func _arch_to_wall(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var front := Vector3.BACK * 0.387
	var back := Vector3.FORWARD * 0.448
	_masonry.quad(a + front, b + front, d + front, c + front, M.BRICK, color)
	_masonry.quad(c + back, d + back, b + back, a + back, M.BRICK, color.darkened(0.10))
	_masonry.quad(a + back, a + front, c + front, c + back, M.BRICK, color.darkened(0.14))
	_masonry.quad(d + back, d + front, b + front, b + back, M.BRICK, color)


func _glasshouse(center: Vector3) -> void:
	var pane := ShaderMaterial.new()
	pane.resource_name = "VidroAntigoViveiro"
	pane.shader = GLASS
	pane.set_shader_parameter("cloud_map", CLOUDS)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(pane)
	var arcs := 14
	var aisles := 8
	var distance := 7.51
	var step := distance / aisles
	var near := distance * 0.5
	for side: float in [-1.0, 1.0]:
		var sill := center + Vector3(side * 3.06, 0.26, 0.0)
		_masonry.box(sill, Vector3(0.34, 0.54, distance + 0.19), M.STONE, BASALT)
		_masonry.box(sill + Vector3.UP * 0.28, Vector3(0.45, 0.071, distance + 0.24), M.STONE, BASE)
		_beam(center + Vector3(side * 3.03, 2.09, -near), center + Vector3(side * 3.03, 2.09, near), 0.043, IRON)
		var bench := center + Vector3(side * 1.96, 0.81, 0.2)
		_masonry.box(bench, Vector3(0.84, 0.075, 6.27), M.WOOD, Color("887254"))
		for z: float in [-2.82, 0.01, 2.81]:
			_masonry.box(bench + Vector3(0.0, -0.38, z), Vector3(0.59, 0.73, 0.094), M.METAL, FRAME)
		for item in 8:
			var plant := bench + Vector3((item % 2 - 0.5) * 0.23, 0.035, (item - 3.5) * 0.68)
			_street.planter(_frame * plant, 0.75 + 0.11 * (item % 3), item * 0.73)
		for row in aisles:
			var z := near - row * step
			var a := center + Vector3(side * 3.03, 0.58, z)
			var b := center + Vector3(side * 3.03, 0.58, z - step)
			if side < 0.0:
				_glaze(surface, b, a, a + Vector3.UP * 1.51, b + Vector3.UP * 1.51, row)
			else:
				_glaze(surface, a, b, b + Vector3.UP * 1.51, a + Vector3.UP * 1.51, row)
			_beam(a, a + Vector3.UP * 1.51, 0.028, IRON)
	for row in range(aisles + 1):
		var z := near - row * step
		for arc in arcs:
			var alpha := float(arc) / arcs * PI
			var beta := float(arc + 1) / arcs * PI
			var a := center + _cross_section(alpha, z)
			var b := center + _cross_section(beta, z)
			var deeper := Vector3.FORWARD * step
			_beam(a, b, 0.032 if row % 2 == 0 else 0.022, IRON)
			if row < aisles:
				_glaze(surface, b, a, a + deeper, b + deeper, arc * 3 + row)
			if row == 0 and arc % 2 == 0:
				_beam(a, a + Vector3.FORWARD * distance, 0.026, IRON)
		if row in [0, 4, 8]:
			var lamp := center + Vector3(0.0, 2.49, z - 0.14)
			_masonry.box(lamp, Vector3(0.332, 0.067, 0.19), M.LIGHT, Color("e1ceb3"))
			_street.add_lamp(_frame * (lamp + Vector3.DOWN * 0.10), 3.4, 0.75)
	for end: float in [-1.0, 1.0]:
		var z := near * end
		_beam(center + Vector3(end * 3.03, 0.59, z), center + Vector3(end * 3.03, 2.1, z), 0.047, IRON)
		for side: float in [-1.0, 1.0]:
			_beam(center + Vector3(side * 0.94, 0.17, z), center + Vector3(side * 0.94, 2.61, z), 0.043, IRON)
			_masonry.box(center + Vector3(side * 2.06, 0.26, z), Vector3(1.96, 0.53, 0.27), M.STONE, BASALT)
			var left := center + Vector3(side * 0.94, 0.57, z)
			var right := center + Vector3(side * 3.03, 0.57, z)
			_glaze(surface, left, right, right + Vector3.UP * 1.51, left + Vector3.UP * 2.03, 5)
		_beam(center + Vector3(-0.94, 2.61, z), center + Vector3(0.94, 2.61, z), 0.041, IRON)
	var panels := MeshInstance3D.new()
	panels.name = "VidrosDoViveiro"
	panels.mesh = surface.commit()
	panels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panels.visibility_range_end = 103.0
	_street.scene_root.add_child(panels)


func _cross_section(angle: float, depth: float) -> Vector3:
	return Vector3(cos(angle) * 3.03, 2.09 + sin(angle) * 1.61, depth)


func _glaze(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, index: int) -> void:
	var points := [a, b, c, d]
	var coordinates := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	var normal := (b - a).cross(d - a).normalized()
	for corner: int in [0, 2, 1, 0, 3, 2]:
		surface.set_color(Color(float((index * 5 + 4) % 13) / 13.0, 1.0, 1.0))
		surface.set_uv(coordinates[corner])
		surface.set_normal(_frame.basis * normal)
		surface.add_vertex(_frame * points[corner])


func _beam(from: Vector3, to: Vector3, radius: float, material: String) -> void:
	_street.beam(_frame * from, _frame * to, radius, material)
