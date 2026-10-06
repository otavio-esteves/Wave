extends RefCounted

const Corridor = preload("res://scripts/corridor/corridor_builder.gd")
const Baked = preload("res://scripts/city/baked_multimesh.gd")
const LIMITS: Array[Vector2] = [Vector2(-200, 110), Vector2(-400, -200), Vector2(-710, -400)]
const ORIGINS: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -200), Vector3(0, 0, -400)]


func build(output: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(output + "/shared")
	if error != OK:
		return error
	var source := Corridor.new().build()
	var roots: Array[Node3D] = []
	var bodies: Array[StaticBody3D] = []
	var horizon := Node3D.new()
	horizon.name = "ValeHorizon"
	for index in 3:
		var cell := Node3D.new()
		cell.name = "ValeCell%d" % index
		var body := StaticBody3D.new()
		body.name = "Colliders"
		cell.add_child(body)
		var floor_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(260, 0.6, LIMITS[index].y - LIMITS[index].x)
		floor_shape.shape = box
		floor_shape.name = "Floor"
		floor_shape.position = Vector3(0, -0.3, (LIMITS[index].x + LIMITS[index].y) / 2) - ORIGINS[index]
		body.add_child(floor_shape)
		roots.append(cell)
		bodies.append(body)
	var shared: Dictionary = {}
	for node in source.get_children():
		if node is StaticBody3D:
			for shape: CollisionShape3D in node.get_children():
				if shape.shape.size == Vector3(260, 0.6, 820):
					continue
				var index := _cell(shape.position.z)
				var copy := shape.duplicate() as CollisionShape3D
				copy.position -= ORIGINS[index]
				bodies[index].add_child(copy)
		elif node is MultiMeshInstance3D:
			_share(node.material_override, output, "material", shared)
			_share(node.multimesh.mesh, output, "mesh", shared)
			if node.material_override.resource_name == "hill":
				horizon.add_child(node.duplicate())
				continue
			var placements: Array = [[], [], []]
			for placement: Transform3D in node.multimesh.instance_transforms:
				placements[_cell((node.transform * placement.origin).z)].append(placement)
			for index in 3:
				if placements[index].is_empty():
					continue
				var copy := node.duplicate() as MultiMeshInstance3D
				var batch := Baked.new()
				batch.mesh = node.multimesh.mesh
				batch.billboard_radius = node.multimesh.billboard_radius
				var transforms: Array[Transform3D] = []
				transforms.assign(placements[index])
				batch.instance_transforms = transforms
				copy.multimesh = batch
				copy.position -= ORIGINS[index]
				roots[index].add_child(copy)
		elif node is MeshInstance3D:
			_share(node.material_override, output, "material", shared)
			for index in 3:
				var mesh := _clip_mesh(node.mesh, LIMITS[index])
				if mesh == null:
					continue
				var copy := node.duplicate() as MeshInstance3D
				copy.mesh = mesh
				copy.position -= ORIGINS[index]
				roots[index].add_child(copy)
		else:
			var index := _cell(node.position.z)
			var copy := node.duplicate() as Node3D
			copy.position -= ORIGINS[index]
			roots[index].add_child(copy)
	var records: Array[Dictionary] = []
	for index in 3:
		var path := "%s/cell-%d.tscn" % [output, index]
		error = _save(roots[index], path)
		if error != OK:
			break
		var neighbors: Array[String] = []
		for other in [index - 1, index + 1]:
			if other >= 0 and other < 3:
				neighbors.append("vale-%d" % other)
		records.append({"id": "vale-%d" % index, "scene": path, "origin": [0, 0, ORIGINS[index].z], "bounds": [-130, -1, LIMITS[index].x, 260, 50, LIMITS[index].y - LIMITS[index].x], "neighbors": neighbors, "nodes": roots[index].get_child_count(), "colliders": bodies[index].get_child_count()})
	if error == OK:
		error = _save(horizon, output + "/horizon.tscn")
	if error == OK:
		var distant := preload("res://scripts/world/corridor_hlod_builder.gd").new().build(roots, ORIGINS)
		error = _save(distant, output + "/distant.tscn")
		distant.free()
	if error == OK:
		var file := FileAccess.open(output + "/manifest.json", FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_string(JSON.stringify({"version": 1, "generator_version": source.get_meta("generator_version"), "region": "avenida-do-vale", "seed": 5547, "cells": records}, "\t") + "\n")
	for cell in roots:
		cell.free()
	horizon.free()
	source.free()
	return error


func _cell(z: float) -> int:
	return 0 if z >= -200 else 1 if z >= -400 else 2


func _share(resource: Resource, output: String, prefix: String, seen: Dictionary) -> void:
	if resource == null or seen.has(resource):
		return
	var path := "%s/shared/%s-%03d.tres" % [output, prefix, seen.size()]
	var error := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	assert(error == OK, "Could not save shared cell resource")
	resource.take_over_path(path)
	seen[resource] = path


func _save(root: Node3D, path: String) -> Error:
	_owners(root, root)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	return ResourceSaver.save(packed, path) if error == OK else error


func _owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_owners(child, root)


func _clip_mesh(mesh: ArrayMesh, limits: Vector2) -> ArrayMesh:
	# Current corridor surfaces/wires have identity transforms and authored UVs.
	# Clip triangles, interpolating all attributes so asphalt/ground have no seams.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for surface in mesh.get_surface_count():
		var data := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, total, 3):
			var polygon: Array[Dictionary] = []
			for offset in 3:
				var index := indices[triangle + offset] if not indices.is_empty() else triangle + offset
				polygon.append({"p": vertices[index], "n": data[Mesh.ARRAY_NORMAL][index] if data[Mesh.ARRAY_NORMAL] != null and not data[Mesh.ARRAY_NORMAL].is_empty() else Vector3.UP, "uv": data[Mesh.ARRAY_TEX_UV][index] if data[Mesh.ARRAY_TEX_UV] != null and not data[Mesh.ARRAY_TEX_UV].is_empty() else Vector2.ZERO, "c": data[Mesh.ARRAY_COLOR][index] if data[Mesh.ARRAY_COLOR] != null and not data[Mesh.ARRAY_COLOR].is_empty() else Color.WHITE})
			polygon = _clip(polygon, limits.x, true)
			polygon = _clip(polygon, limits.y, false)
			for index in range(1, polygon.size() - 1):
				if ((polygon[index].p - polygon[0].p) as Vector3).cross(polygon[index + 1].p - polygon[0].p).length_squared() < 0.000000001:
					continue
				for vertex in [polygon[0], polygon[index], polygon[index + 1]]:
					tool.set_normal(vertex.n)
					tool.set_uv(vertex.uv)
					tool.set_color(vertex.c)
					tool.add_vertex(vertex.p)
					count += 1
	return tool.commit() if count > 0 else null


func _clip(polygon: Array[Dictionary], plane: float, keep_greater: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty():
		return result
	var previous: Dictionary = polygon[-1]
	var previous_inside: bool = previous.p.z >= plane if keep_greater else previous.p.z <= plane
	for current in polygon:
		var inside: bool = current.p.z >= plane if keep_greater else current.p.z <= plane
		if inside != previous_inside:
			var weight: float = (plane - previous.p.z) / (current.p.z - previous.p.z)
			result.append({"p": previous.p.lerp(current.p, weight), "n": previous.n.lerp(current.n, weight).normalized(), "uv": previous.uv.lerp(current.uv, weight), "c": previous.c.lerp(current.c, weight)})
		if inside:
			result.append(current)
		previous = current
		previous_inside = inside
	return result
