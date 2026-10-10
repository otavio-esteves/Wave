extends RefCounted

# Small clustered petals, shared by flowering trees and park planting beds.
static func build() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for flower in 9:
		var angle := flower * 2.4
		var centre := Vector3(cos(angle) * 0.33, sin(flower * 1.7) * 0.18, sin(angle) * 0.33)
		var orientation := Basis.from_euler(Vector3(flower * 0.7, angle, flower * 0.43))
		for petal in 5:
			var direction := TAU * petal / 5
			var tip := Vector3(cos(direction), 0, sin(direction)) * 0.14
			var side := Vector3(-sin(direction), 0, cos(direction)) * 0.047
			for point in [Vector3.ZERO, tip * 0.6 + side + Vector3.UP * 0.035, tip, Vector3.ZERO, tip, tip * 0.6 - side + Vector3.UP * 0.035]:
				tool.add_vertex(centre + orientation * point)
	tool.generate_normals()
	tool.index()
	return tool.commit()
