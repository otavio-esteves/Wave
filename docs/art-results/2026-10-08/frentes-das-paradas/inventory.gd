extends SceneTree
func _initialize() -> void:
	var result := {}
	for index in range(1, 4):
		var cell: Node3D = load("res://scenes/world/cells/sol-serra/cell-%d.tscn" % index).instantiate()
		var counts := {"batches": 0, "instances": 0, "surface_triangles": 0, "colliders": {}}
		for child in cell.get_children():
			if child is MultiMeshInstance3D:
				counts.batches += 1
				counts.instances += child.multimesh.instance_count
			elif child is MeshInstance3D:
				for surface in child.mesh.get_surface_count():
					var arrays: Array = child.mesh.surface_get_arrays(surface)
					var indices = arrays[Mesh.ARRAY_INDEX]
					counts.surface_triangles += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		for collider in cell.get_node("Colliders").get_children():
			counts.colliders[collider.name] = {"transform": var_to_str(collider.transform), "size": var_to_str(collider.shape.size)}
		result[str(index)] = counts
		cell.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	quit()
