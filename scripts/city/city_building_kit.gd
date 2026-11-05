extends RefCounted

# Shared authored palette and atlas building, independent of either map generator.

static func palette(builder: RefCounted) -> void:
	var materials: Dictionary = builder.materials
	var meshes: Dictionary = builder.meshes
	for entry in [["asphalt", "asphalt", Color(0.92, 0.93, 0.95)], ["sidewalk", "concrete", Color(0.94, 0.91, 0.85)], ["grass", "grass", Color(0.90, 0.92, 0.87)], ["brick", "brick", Color(0.87, 0.80, 0.70)], ["roof", "brick", Color(0.83, 0.63, 0.49)], ["plaster", "concrete", Color(0.88, 0.86, 0.79)], ["metal", "metal", Color(0.48, 0.51, 0.51)]]:
		var material := StandardMaterial3D.new()
		material.resource_name = entry[0]
		material.albedo_texture = load("res://assets/textures/race/%s.png" % entry[1])
		material.albedo_color = entry[2]
		material.roughness = 0.95
		material.vertex_color_use_as_albedo = true
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[entry[0]] = material
	var patch: StandardMaterial3D = materials["asphalt"].duplicate()
	patch.resource_name = "patch"
	patch.albedo_color = Color(0.79, 0.81, 0.82)
	materials["patch"] = patch
	for index in 4:
		var facade := StandardMaterial3D.new()
		facade.resource_name = "facade%d" % index
		facade.albedo_texture = load("res://assets/textures/corridor/facades-v1.png")
		facade.uv1_scale = Vector3(0.49, 0.47, 1)
		facade.uv1_offset = Vector3((index % 2) * 0.5 + 0.005, floori(float(index) / 2.0) * 0.5 + 0.005, 0)
		facade.texture_repeat = false
		facade.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		facade.roughness = 1.0
		materials[facade.resource_name] = facade
	for index in 4:
		var sign: StandardMaterial3D = materials["facade%d" % index].duplicate()
		sign.resource_name = "sign%d" % index
		sign.albedo_texture = load("res://assets/textures/corridor/signs.png")
		sign.uv1_scale = Vector3(0.49, 0.49, 1)
		sign.uv1_offset = Vector3((index % 2) * 0.5 + 0.005, floori(float(index) / 2.0) * 0.5 + 0.005, 0)
		materials[sign.resource_name] = sign
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	meshes["facade"] = card
	var tree := StandardMaterial3D.new()
	tree.resource_name = "street_tree"
	tree.albedo_texture = load("res://assets/textures/corridor/street-tree-v1.png")
	tree.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	tree.alpha_scissor_threshold = 0.45
	tree.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	tree.billboard_keep_scale = true
	tree.cull_mode = BaseMaterial3D.CULL_DISABLED
	tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tree.roughness = 1.0
	materials["street_tree"] = tree
	materials["white"].albedo_color = Color("ccc7a8")
	materials["yellow"].albedo_color = Color("c9ab56")
	materials["blue"].albedo_color = Color("344c5b")
	materials["wood"].albedo_color = Color("625647")
	materials["glass"].albedo_color = Color("283333")
	materials["hill"].albedo_color = Color("858d89")
	var hill := SphereMesh.new()
	hill.radius = 1.0
	hill.height = 2.0
	hill.radial_segments = 24
	hill.rings = 8
	meshes["horizon_hill"] = hill


static func building(builder: RefCounted, origin: Vector3, width: float, height: float, depth: float, yaw: float, facade: int) -> void:
	builder._ground_ao(Vector2(origin.x, origin.z), Vector2(depth + 5, width + 4), "grass", 0.007, 0.16)
	builder.add_part(origin, Vector3(0, height / 2, 0), Vector3(width, height, depth), "plaster", yaw, true)
	builder.add_part(origin, Vector3(0, height + 0.75, 0), Vector3(width + 0.6, 1.5, depth + 0.7), "roof", yaw, false, "roof")
	builder.add_part(origin, Vector3(0, height / 2, depth / 2 + 0.025), Vector3(width, height, 1), "facade%d" % facade, yaw, false, "facade")
	# Silhouette trim and awning stay real; the atlas carries fine windows/grilles.
	builder.add_part(origin, Vector3(0, height - 0.15, depth / 2 + 0.15), Vector3(width + 0.25, 0.2, 0.32), "plaster", yaw)
	builder.add_part(origin, Vector3(0, 0.15, depth / 2 + 0.15), Vector3(width, 0.3, 0.35), "sidewalk", yaw)
