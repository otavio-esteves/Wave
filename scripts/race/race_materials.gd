extends RefCounted

# Shared, baked textures. World projection keeps texel density across scaled props.
static func apply(props: RefCounted) -> void:
	for entry in [["asphalt", "asphalt", Color.WHITE], ["sidewalk", "concrete", Color.WHITE], ["cream", "brick", Color.WHITE], ["grass", "grass", Color.WHITE], ["metal", "metal", Color(0.67, 0.68, 0.69)], ["roof", "metal", Color(0.46, 0.47, 0.44)], ["sage", "concrete", Color(0.71, 0.73, 0.66)]]:
		var material: StandardMaterial3D = props._materials[entry[0]]
		material.albedo_color = entry[2]
		material.albedo_texture = load("res://assets/textures/race/%s.png" % entry[1])
		material.normal_enabled = true
		material.normal_texture = load("res://assets/textures/race/%s_normal.png" % entry[1])
		material.normal_scale = 0.5
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * (0.125 if entry[0] == "grass" else 0.25)
		if entry[0] == "asphalt":
			# Road ribbon supplies world-sized UVs; avoid three projections per pixel.
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE
		elif entry[1] == "brick":
			material.uv1_scale = Vector3.ONE * 0.5
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.roughness = 0.93
		if entry[1] == "metal":
			material.metallic = 0.35
			material.roughness = 0.65
	var pit: StandardMaterial3D = props._materials["asphalt"].duplicate()
	pit.resource_name = "pit_asphalt"
	pit.uv1_triplanar = true
	pit.uv1_scale = Vector3.ONE * 0.25
	props._materials["pit_asphalt"] = pit
	var glass: StandardMaterial3D = props._materials["glass"]
	glass.albedo_color = Color(0.22, 0.29, 0.31)
	glass.metallic = 0.45
	glass.roughness = 0.25
	var foliage: StandardMaterial3D = props._materials["foliage"]
	foliage.albedo_color = Color.WHITE
	foliage.albedo_texture = load("res://assets/textures/race/foliage.png")
	foliage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage.alpha_scissor_threshold = 0.45
	foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	foliage.roughness = 1.0
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for yaw in [0.0, PI * 0.5, PI * 0.25]:
		var basis := Basis(Vector3.UP, yaw)
		for vertex in [0, 2, 1, 0, 3, 2]:
			var corners: Array[Vector3] = [Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)]
			var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			leaves.set_normal(basis * Vector3.FORWARD)
			leaves.set_uv(uvs[vertex])
			leaves.add_vertex(basis * corners[vertex])
	leaves.index()
	props._meshes["foliage"] = leaves.commit()
