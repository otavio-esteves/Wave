extends RefCounted

const PALETTE := {
	"timber": [Color("957951"), Color("635344"), Color("b0a18a")],
	"iron": [Color("565650"), Color("3f4643"), Color("8e8a7c")],
	"aluminium": [Color("b0aaa0"), Color("646762"), Color("a4a099")],
}


static func install(meshes: Dictionary, materials: Dictionary) -> void:
	var frame := StandardMaterial3D.new()
	frame.resource_name = "facade_frame"
	frame.vertex_color_use_as_albedo = true
	frame.roughness = 0.83
	materials[frame.resource_name] = frame
	for profile: String in PALETTE:
		meshes["facade_frame_" + profile] = _frame(PALETTE[profile], profile == "timber")
	meshes["facade_ironwork"] = _ironwork()
	meshes["facade_frame_arch"] = _arch_frame()
	meshes["pane_arch"] = _arch_pane()


static func add_window(city: RefCounted, origin: Vector3, center: Vector3, size: Vector2, yaw: float, glazing: String, profile: String, arched := false) -> void:
	var frame := Basis(Vector3.UP, yaw)
	var position := origin + frame * center
	city.add_instance("facade_frame_" + ("arch" if arched else profile), "facade_frame", position, Vector3(size.x, size.y, 1.0), yaw, false)
	city.add_instance("pane_arch" if arched else "pane", glazing, position + frame.z * 0.034, Vector3(size.x * 0.932, size.y * 0.922, 1.0), yaw, false)


static func aperture(arched: bool) -> PackedVector2Array:
	if not arched:
		return PackedVector2Array([Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, -0.5)])
	var outline := PackedVector2Array([Vector2(-0.5, -0.5)])
	for segment in 9:
		var angle := PI * segment / 8.0
		outline.append(Vector2(-cos(angle) * 0.5, 0.23 + sin(angle) * 0.27))
	outline.append(Vector2(0.5, -0.5))
	return outline


static func _arch_frame() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var outline := aperture(true)
	for edge in outline.size():
		var a := outline[edge]
		var b := outline[(edge + 1) % outline.size()]
		var inner_a := a * Vector2(0.909, 0.899)
		var inner_b := b * Vector2(0.909, 0.899)
		_quad(surface, Vector3(a.x * 1.024, a.y * 1.024, 0.01), Vector3(b.x * 1.024, b.y * 1.024, 0.01),
			Vector3(b.x, b.y, 0.123), Vector3(a.x, a.y, 0.123), Color("a5947e"))
		_quad(surface, Vector3(a.x, a.y, 0.123), Vector3(b.x, b.y, 0.123),
			Vector3(inner_b.x, inner_b.y, 0.032), Vector3(inner_a.x, inner_a.y, 0.032), Color("74634f"))
	_quad(surface, Vector3(-0.011, -0.452, 0.066), Vector3(-0.011, 0.46, 0.066),
		Vector3(0.011, 0.46, 0.066), Vector3(0.011, -0.452, 0.066), Color("4b4336"))
	_quad(surface, Vector3(-0.465, 0.215, 0.064), Vector3(-0.465, 0.235, 0.064),
		Vector3(0.465, 0.235, 0.064), Vector3(0.465, 0.215, 0.064), Color("4b4336"))
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _arch_pane() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := aperture(true)
	for edge in range(1, outline.size() - 1):
		for point: Vector2 in [outline[0], outline[edge], outline[edge + 1]]:
			surface.set_normal(Vector3.BACK)
			surface.set_uv(Vector2(point.x + 0.5, 0.5 - point.y))
			surface.add_vertex(Vector3(point.x, point.y, 0))
	surface.index()
	return surface.commit()


static func lettering(city: RefCounted, text: String, position: Vector3, yaw: float, width: float, height: float, ink: Color) -> void:
	var extent := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	city.add_label(text, position, yaw, minf(width / maxf(extent.x, 1.0), height / 40.0))
	var label := city.scene_root.get_child(-1) as Label3D
	label.outline_size = 0
	label.modulate = ink


static func _ironwork() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var dark := Color("525b50")
	for x: float in [-0.48, -0.36, -0.24, -0.12, 0.0, 0.12, 0.24, 0.36, 0.48]:
		var a := Vector3(x - 0.005, -0.5, 0)
		var b := Vector3(x - 0.005, 0.50, 0)
		var c := Vector3(x + 0.005, 0.50, 0)
		var d := Vector3(x + 0.005, -0.5, 0)
		_quad(surface, a, b, c, d, dark)
		_quad(surface, d, c, b, a, dark)
	for y: float in [-0.36, 0.42]:
		var a := Vector3(-0.5, y, 0)
		var b := Vector3(-0.5, y + 0.045, 0)
		var c := Vector3(0.5, y + 0.045, 0)
		var d := Vector3(0.5, y, 0)
		_quad(surface, a, b, c, d, dark)
		_quad(surface, d, c, b, a, dark)
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _frame(finishes: Array, sash: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var perimeter := _outline(0.51, 0.51, 0.004)
	var moulding := _outline(0.496, 0.493, 0.110)
	var rebate := _outline(0.461, 0.456, 0.029)
	for edge in 4:
		var next := (edge + 1) % 4
		_quad(surface, perimeter[edge], perimeter[next], moulding[next], moulding[edge], finishes[0].darkened(0.20))
		_quad(surface, moulding[edge], moulding[next], rebate[next], rebate[edge], finishes[0])
	var sill_back := Vector3(-0.53, -0.479, 0.026)
	var sill_edge := Vector3(-0.53, -0.506, 0.182)
	var sill_width := Vector3.RIGHT * 1.06
	_quad(surface, sill_back, sill_back + sill_width, sill_edge + sill_width, sill_edge, finishes[2])
	var sill_drop := Vector3.DOWN * 0.036
	_quad(surface, sill_edge, sill_edge + sill_width, sill_edge + sill_width + sill_drop, sill_edge + sill_drop, finishes[2].darkened(0.19))
	var stile := 0.013 if sash else 0.010
	_quad(surface, Vector3(-stile, -0.468, 0.059), Vector3(-stile, 0.468, 0.059),
		Vector3(stile, 0.468, 0.059), Vector3(stile, -0.468, 0.059), finishes[1])
	if sash:
		_quad(surface, Vector3(-0.47, 0.116, 0.058), Vector3(-0.47, 0.138, 0.058),
			Vector3(0.47, 0.138, 0.058), Vector3(0.47, 0.116, 0.058), finishes[1])
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _outline(x: float, y: float, z: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(-x, -y, z), Vector3(-x, y, z), Vector3(x, y, z), Vector3(x, -y, z)])


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, paint: Color) -> void:
	surface.set_color(paint)
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)
