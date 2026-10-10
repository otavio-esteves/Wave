extends RefCounted

# A parked vehicle needs the silhouette and optics, not the player's cabin,
# suspension and multi-material wheel assemblies. One opaque surface per car.
static func build(paint: Color) -> ArrayMesh:
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
			_wheel(tool, Vector3(side * 0.77, -0.04, z))
	tool.generate_normals()
	tool.index()
	return tool.commit()


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	for point in [a, c, b, a, d, c]:
		tool.add_vertex(point)


static func _box(tool: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var p := size / 2
	var corners := [centre + Vector3(-p.x, -p.y, -p.z), centre + Vector3(p.x, -p.y, -p.z), centre + Vector3(p.x, p.y, -p.z), centre + Vector3(-p.x, p.y, -p.z), centre + Vector3(-p.x, -p.y, p.z), centre + Vector3(p.x, -p.y, p.z), centre + Vector3(p.x, p.y, p.z), centre + Vector3(-p.x, p.y, p.z)]
	for face in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]:
		_quad(tool, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], color)


static func _wheel(tool: SurfaceTool, centre: Vector3) -> void:
	for index in 10:
		var first := TAU * index / 10.0
		var last := TAU * (index + 1) / 10.0
		var a := centre + Vector3(-0.1, cos(first) * 0.31, sin(first) * 0.31)
		var b := centre + Vector3(0.1, cos(first) * 0.31, sin(first) * 0.31)
		var c := centre + Vector3(0.1, cos(last) * 0.31, sin(last) * 0.31)
		var d := centre + Vector3(-0.1, cos(last) * 0.31, sin(last) * 0.31)
		_quad(tool, a, d, c, b, Color("242b2c"))
		for side: float in [-1, 1]:
			var origin := centre + Vector3(side * 0.101, 0, 0)
			var first_point := origin + Vector3(0, cos(first) * 0.31, sin(first) * 0.31)
			var last_point := origin + Vector3(0, cos(last) * 0.31, sin(last) * 0.31)
			tool.set_color(Color("596266"))
			for point in ([origin, last_point, first_point] if side > 0 else [origin, first_point, last_point]):
				tool.add_vertex(point)
