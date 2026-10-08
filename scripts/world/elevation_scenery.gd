extends RefCounted

const Layout = preload("res://scripts/world/elevation_layout.gd")
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")


func decorate(cell: Node3D, origin_z: float) -> void:
	_groves(cell, origin_z)
	if origin_z == -200:
		_lookout(cell, origin_z)


func horizon() -> Node3D:
	var root := Node3D.new()
	root.name = "SerraHorizon"
	for side in [-1, 1]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(250):
			var z0 := 100.0 - row * 4.0
			var z1 := z0 - 4.0
			for band in range(3):
				var a := _ridge(side, band, z0)
				var b := _ridge(side, band + 1, z0)
				var c := _ridge(side, band, z1)
				var d := _ridge(side, band + 1, z1)
				var vertices := [a, c, b, b, c, d] if side > 0 else [a, b, c, b, d, c]
				for vertex in vertices:
					tool.set_uv(Vector2(vertex.x, vertex.z) / 24.0)
					tool.add_vertex(vertex)
		tool.generate_normals()
		var node := MeshInstance3D.new()
		node.name = "RidgeRight" if side > 0 else "RidgeLeft"
		node.mesh = tool.commit()
		node.material_override = _material(Color("7c876b"))
		root.add_child(node)
	return root


func _ridge(side: int, band: int, z: float) -> Vector3:
	var distances := [40.0, 90.0, 180.0, 300.0]
	var bases := [0.0, -12.0, 40.0, 20.0]
	var amplitudes := [0.0, 6.0, 23.0, 14.0]
	var ripple := sin(z * 0.011 + side * 1.7) + sin(z * 0.031 + side) * 0.3
	return Vector3(side * distances[band], Layout.height(z) + bases[band] + ripple * amplitudes[band], z)


func _groves(cell: Node3D, origin_z: float) -> void:
	var transforms: Array[Transform3D] = []
	var material := _material(Color("dadfc9"))
	material.albedo_texture = load("res://assets/textures/corridor/street-tree-v1.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.45
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for local_z in [-40.0, -135.0]:
		for side in [-1, 1]:
			for member in range(3):
				var z: float = origin_z + local_z + [-9.0, 4.0, 12.0][member]
				if side > 0 and z < -250 and z > -370:
					continue
				var x: float = Layout.center_x(z) + side * (17.0 + member * 3.0)
				var height := 7.0 + member * 0.8
				var position := Vector3(x, Layout.height(z), z - origin_z)
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(height * 0.82, height, 1)), position + Vector3.UP * height / 2))
				_collider(cell, "Tree%d" % transforms.size(), position + Vector3.UP, Vector3(0.45, 2, 0.45))
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var multimesh := BakedMultiMesh.new()
	multimesh.mesh = mesh
	# Include shader rotation of the cards in the culling bounds.
	multimesh.billboard_radius = 5.0
	multimesh.instance_transforms = transforms
	var node := MultiMeshInstance3D.new()
	node.name = "Groves"
	node.multimesh = multimesh
	node.material_override = material
	cell.add_child(node)


func _lookout(cell: Node3D, origin_z: float) -> void:
	var landmark := Node3D.new()
	landmark.name = "Mirante"
	cell.add_child(landmark)
	var z := Layout.LOOKOUT_Z
	var center := Vector3(Layout.center_x(z) + 28, Layout.height(z), z - origin_z)
	# Shelter and seats sit beyond the parking apron, leaving its center clear.
	_box(landmark, "Roof", center + Vector3.UP * 2.75, Vector3(5.6, 0.18, 10), Color("9a765b"))
	for x in [-2.3, 2.3]:
		for dz in [-4.0, 4.0]:
			var base := Vector3(center.x + x, Layout.height(z + dz), center.z + dz)
			var height := center.y + 2.66 - base.y
			var pillar_center := base + Vector3.UP * height / 2
			_box(landmark, "Pillar%d" % landmark.get_child_count(), pillar_center, Vector3(0.18, height, 0.18), Color("cabba0"))
			_collider(cell, "Pillar%d" % landmark.get_child_count(), pillar_center, Vector3(0.18, height, 0.18))
	for dz in [-2.5, 2.5]:
		var base := Vector3(center.x, Layout.height(z + dz), center.z + dz)
		_box(landmark, "Bench%d" % landmark.get_child_count(), base + Vector3.UP * 0.5, Vector3(3.4, 0.18, 0.7), Color("8a7056"))
		_collider(cell, "Bench%d" % landmark.get_child_count(), base + Vector3.UP * 0.3, Vector3(3.4, 0.6, 0.7))
		for leg_x in [-1.4, 1.4]:
			for leg_z in [-0.25, 0.25]:
				_box(landmark, "BenchLeg%d" % landmark.get_child_count(), base + Vector3(leg_x, 0.21, leg_z), Vector3(0.12, 0.42, 0.12), Color("6f695d"))
	for sign_z in [-245.0, -375.0]:
		_sign(cell, landmark, origin_z, sign_z, 0.0 if sign_z > z else PI)
	for local_z in [-289.0, -305.0, -325.0, -342.0]:
		var position := Vector3(Layout.center_x(local_z) + 25.5, Layout.height(local_z) + 0.5, local_z - origin_z)
		_box(landmark, "EdgePost%d" % landmark.get_child_count(), position, Vector3(0.18, 1, 0.18), Color("cabba0"))
		_collider(cell, "EdgePost%d" % landmark.get_child_count(), position, Vector3(0.18, 1, 0.18))


func _sign(cell: Node3D, parent: Node3D, origin_z: float, z: float, yaw: float) -> void:
	var sign := Node3D.new()
	sign.name = "LookoutSign%d" % parent.get_child_count()
	sign.position = Vector3(Layout.center_x(z) + 10.3, Layout.height(z), z - origin_z)
	sign.rotation.y = yaw
	parent.add_child(sign)
	_box(sign, "Post", Vector3(0, 1.1, 0), Vector3(0.15, 2.2, 0.15), Color("cabba0"))
	_box(sign, "Board", Vector3(0, 2.35, 0), Vector3(3.9, 0.8, 0.12), Color("344c5b"))
	_collider(cell, "Sign%d" % parent.get_child_count(), sign.position + Vector3.UP * 1.1, Vector3(0.15, 2.2, 0.15))
	var label := Label3D.new()
	label.name = "Label"
	label.text = "MIRANTE DA SERRA"
	label.font_size = 56
	label.pixel_size = 0.006
	label.position = Vector3(0, 2.35, 0.07)
	label.modulate = Color("ece2c6")
	label.outline_size = 0
	sign.add_child(label)


func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)


func _collider(cell: Node3D, label: String, position: Vector3, size: Vector3) -> void:
	var node := CollisionShape3D.new()
	node.name = label
	node.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	cell.get_node("Colliders").add_child(node)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
