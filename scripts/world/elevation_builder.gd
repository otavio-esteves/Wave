extends RefCounted

const Layout = preload("res://scripts/world/elevation_layout.gd")
const Scenery = preload("res://scripts/world/elevation_scenery.gd")


func build(output: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error != OK:
		return error
	var cells: Array = []
	for index in Layout.CELL_COUNT:
		var origin_z := -index * Layout.CELL_LENGTH
		var cell := Node3D.new()
		cell.name = "ElevationCell%d" % index
		var road := Layout.ROAD_HALF_WIDTH
		var edge := road + Layout.SHOULDER_WIDTH
		_surface(cell, "Ground", Layout.faces(origin_z), Color("78835a"), origin_z)
		_surface(cell, "Road", Layout.road_faces(origin_z, -road, road, 0.012), Color("88858a"), origin_z, true)
		_surface(cell, "ShoulderLeft", Layout.road_faces(origin_z, -edge, -road, 0.008), Color("a59a80"), origin_z)
		_surface(cell, "ShoulderRight", Layout.road_faces(origin_z, road, edge, 0.008), Color("a59a80"), origin_z)
		for x in [-road + 0.3, 0.0, road - 0.3]:
			var paint_faces := Layout.road_faces(origin_z, x - 0.07, x + 0.07, 0.025)
			if x > 0:
				var open_faces := PackedVector3Array()
				for triangle in range(0, paint_faces.size(), 6):
					if not Layout.lookout_open(origin_z + paint_faces[triangle].z - 0.5):
						open_faces.append_array(paint_faces.slice(triangle, triangle + 6))
				paint_faces = open_faces
			_surface(cell, "Paint%d" % int(x * 10), paint_faces, Color("d7c584") if x == 0 else Color("d5d4be"), origin_z)
		_markers(cell, origin_z)
		var body := StaticBody3D.new()
		body.name = "Colliders"
		body.collision_layer = 1
		cell.add_child(body)
		var collider := CollisionShape3D.new()
		collider.name = "Support"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(Layout.faces(origin_z))
		collider.shape = shape
		body.add_child(collider)
		Scenery.new().decorate(cell, origin_z)
		if index == 1:
			_lookout_apron(cell, origin_z)
		_owners(cell, cell)
		var packed := PackedScene.new()
		error = packed.pack(cell)
		if error == OK:
			error = ResourceSaver.save(packed, "%s/cell-%d.tscn" % [output, index])
		cell.free()
		if error != OK:
			return error
		var neighbors: Array = []
		for neighbor in [index - 1, index + 1]:
			if neighbor >= 0 and neighbor < Layout.CELL_COUNT:
				neighbors.append("elevation-%d" % neighbor)
		cells.append({"id": "elevation-%d" % index, "scene": "%s/cell-%d.tscn" % [output, index], "origin": [0, 0, origin_z], "bounds": [-40, -1, origin_z - 200, 80, 22, 200], "neighbors": neighbors})
	var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "profile": "elevation-lab-v3", "cells": cells}, "\t") + "\n")
	var horizon: Node3D = Scenery.new().horizon()
	_owners(horizon, horizon)
	var packed := PackedScene.new()
	error = packed.pack(horizon)
	if error == OK:
		error = ResourceSaver.save(packed, output + "/horizon.tscn")
	horizon.free()
	if error != OK:
		return error
	return OK


func _surface(parent: Node3D, label: String, faces: PackedVector3Array, color: Color, origin_z: float, textured: bool = false) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in faces:
		var world_z := vertex.z + origin_z
		tool.set_uv(Vector2(vertex.x - Layout.center_x(world_z), world_z) / 8.0)
		tool.add_vertex(vertex)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if textured:
		material.albedo_texture = load("res://assets/textures/race/asphalt.png")
	elif label == "Ground":
		material.albedo_texture = load("res://assets/textures/race/grass.png")
		material.albedo_color = Color("bec5a1")
	node.material_override = material
	parent.add_child(node)
	return node


func _lookout_apron(cell: Node3D, origin_z: float) -> void:
	var faces := PackedVector3Array()
	for index in range(60, 160):
		var z0 := -float(index)
		var z1 := z0 - 1
		var a := Vector3(Layout.center_x(origin_z + z0) + 6, Layout.height(origin_z + z0) + 0.018, z0)
		var b := Vector3(Layout.center_x(origin_z + z0) + Layout.lookout_edge(origin_z + z0), a.y, z0)
		var c := Vector3(Layout.center_x(origin_z + z1) + 6, Layout.height(origin_z + z1) + 0.018, z1)
		var d := Vector3(Layout.center_x(origin_z + z1) + Layout.lookout_edge(origin_z + z1), c.y, z1)
		faces.append_array(PackedVector3Array([a, c, b, b, c, d]))
	_surface(cell, "LookoutApron", faces, Color("a59a80"), origin_z)
	var markings := PackedVector3Array()
	# Parking bays follow the same height samples as their supporting apron.
	for z in range(int(Layout.PARK_Z_MIN), int(Layout.PARK_Z_MAX)):
		for offset in [Layout.PARK_LANE_MIN, Layout.PARK_LANE_MAX]:
			markings.append_array(_parking_strip(origin_z, z, z + 1, offset - 0.06, offset + 0.06))
	for z in [Layout.PARK_Z_MIN, Layout.LOOKOUT_Z, Layout.PARK_Z_MAX]:
		markings.append_array(_parking_strip(origin_z, z - 0.06, z + 0.06, Layout.PARK_LANE_MIN, Layout.PARK_LANE_MAX))
	_surface(cell, "ParkingBays", markings, Color("d5d4be"), origin_z)


func _parking_strip(origin_z: float, z0: float, z1: float, left: float, right: float) -> PackedVector3Array:
	var a := Vector3(Layout.center_x(z1) + left, Layout.height(z1) + 0.035, z1 - origin_z)
	var b := Vector3(Layout.center_x(z1) + right, a.y, a.z)
	var c := Vector3(Layout.center_x(z0) + left, Layout.height(z0) + 0.035, z0 - origin_z)
	var d := Vector3(Layout.center_x(z0) + right, c.y, c.z)
	return PackedVector3Array([a, c, b, b, c, d])


func _markers(cell: Node3D, origin_z: float) -> void:
	# Simple two-sided delineators outside the drivable shoulders, owned once
	# per cell. They give the bends depth without fences across the road.
	for index in int(Layout.CELL_LENGTH / 40):
		var local_z := -20.0 - index * 40.0
		var world_z := origin_z + local_z
		for side in [-1, 1]:
			if side > 0 and Layout.lookout_open(world_z):
				continue
			var marker := Node3D.new()
			marker.name = "Marker%d_%d" % [index, side]
			marker.position = Vector3(Layout.center_x(world_z) + side * (Layout.ROAD_HALF_WIDTH + Layout.SHOULDER_WIDTH + 0.8), Layout.height(world_z), local_z)
			marker.rotation.y = Layout.heading(world_z)
			cell.add_child(marker)
			for part in [0, 1]:
				var mesh := MeshInstance3D.new()
				mesh.name = "Post" if part == 0 else "Reflector"
				var box := BoxMesh.new()
				box.size = Vector3(0.16, 1.0, 0.12) if part == 0 else Vector3(0.18, 0.16, 0.14)
				mesh.mesh = box
				mesh.position.y = 0.5 if part == 0 else 0.78
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("d5d4be") if part == 0 else Color("e3b461")
				material.roughness = 1.0
				mesh.material_override = material
				marker.add_child(mesh)


func _owners(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_owners(child, owner)
