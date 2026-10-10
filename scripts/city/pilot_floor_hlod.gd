extends RefCounted

const WIDTH := 512.0
const NEAR_DISTANCE := 220.0
const SidewalkProxy = preload("res://scripts/city/pilot_sidewalk_proxy.gd")

# Always-resident low-cost backing preserves the distant floor. The detailed
# 128 m meshes and their collision remain independent near the player.
static func bake(nodes: Array, fallback_meshes: Dictionary = {}) -> Array[MeshInstance3D]:
	for node in nodes:
		if node is MeshInstance3D and node.get_meta("surface_kind", "") == "SidewalksFar":
			fallback_meshes[str(node.name).replace("SidewalksFar_", "Sidewalks_")] = node.mesh
	var batches: Dictionary = {}
	for node in nodes:
		if not node is MeshInstance3D:
			continue
		var kind: String = node.get_meta("surface_kind", "")
		if kind not in ["Terrain", "Streets", "Sidewalks", "BackgroundLandscape"]:
			continue
		var mesh: ArrayMesh = node.mesh
		if kind == "Sidewalks":
			var reduced := SidewalkProxy.bake(mesh)
			mesh = fallback_meshes.get(str(node.name), mesh) if reduced == mesh else reduced
			kind = "SidewalksFar"
		var centre: Vector3 = mesh.get_aabb().get_center()
		var key := "%s_%d_%d" % [kind, floori(centre.x / WIDTH), floori(centre.z / WIDTH)]
		if not batches.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key] = {"tool": tool, "material": node.material_override, "kind": kind}
		var tool: SurfaceTool = batches[key].tool
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var lods: Array = mesh.get("_surfaces")[surface].get("lods", [])
			if not lods.is_empty():
				var bytes: PackedByteArray = lods[-1]
				var stride := 2 if arrays[Mesh.ARRAY_VERTEX].size() < 65536 else 4
				indices = PackedInt32Array()
				for offset in range(0, bytes.size(), stride):
					indices.append(bytes.decode_u16(offset) if stride == 2 else bytes.decode_u32(offset))
			for index in indices:
				tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
				tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
				tool.set_color(arrays[Mesh.ARRAY_COLOR][index])
				var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
				point.y -= 0.16 if kind == "Terrain" else (0.08 if kind == "SidewalksFar" else 0.012)
				tool.add_vertex(point)
	var result: Array[MeshInstance3D] = []
	for key in batches:
		var batch: Dictionary = batches[key]
		var tool: SurfaceTool = batch.tool
		tool.index()
		var node := MeshInstance3D.new()
		node.name = "FloorFar_" + key
		node.mesh = tool.commit()
		node.material_override = batch.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("surface_kind", "FloorFar")
		node.set_meta("floor_kind", batch.kind)
		result.append(node)
	return result
