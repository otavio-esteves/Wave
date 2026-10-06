extends SceneTree

const Layout = preload("res://scripts/rally/rally_layout.gd")
const Props = preload("res://scripts/city/offline_scene_builder.gd")
const Materials = preload("res://scripts/race/race_materials.gd")
var props: Props
var gravel_material: ShaderMaterial
var points: PackedVector3Array
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var output_path := "res://scenes/rally/rally_map.tscn"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	rng.seed = 20261004
	props = Props.new()
	props.batch_size = 84.0
	props.batch_sizes["tussock"] = 48.0
	props.center_batches_vertically = true
	props.begin("RallyMap", "SceneryColliders")
	Materials.apply(props)
	for kind in ["gravel", "rock"]:
		var material := StandardMaterial3D.new()
		material.resource_name = kind
		material.albedo_texture = load("res://assets/textures/rally/%s.png" % kind)
		material.normal_enabled = true
		material.normal_texture = load("res://assets/textures/rally/%s_normal.png" % kind)
		material.normal_scale = 0.8
		material.roughness = 0.97
		material.vertex_color_use_as_albedo = true
		material.uv1_triplanar = kind == "rock"
		material.uv1_world_triplanar = kind == "rock"
		material.uv1_scale = Vector3.ONE * (0.35 if kind == "rock" else 1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		props.materials[kind] = material
	var conifer: StandardMaterial3D = props.materials["foliage"].duplicate()
	conifer.resource_name = "conifer"
	conifer.albedo_texture = load("res://assets/textures/rally/pine-realistic.png")
	conifer.alpha_scissor_threshold = 0.35
	conifer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	conifer.albedo_color = Color(0.72, 0.77, 0.72)
	conifer.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	conifer.billboard_keep_scale = true
	props.materials["conifer"] = conifer
	var crown: StandardMaterial3D = conifer.duplicate()
	crown.resource_name = "crown_near"
	props.materials["crown_near"] = crown
	props.meshes["tree_far"] = _tree_card(1.0)
	props.meshes["crown_near"] = _tree_card(0.8)
	_tree_wood()

	_grass_mesh()
	# The terrain already supplies metric UVs: one projection instead of three.
	props.materials["grass"].uv1_triplanar = false
	props.materials["grass"].uv1_scale = Vector3.ONE * (0.125 / 0.35)
	props.materials["grass"].vertex_color_use_as_albedo = true
	props.materials["grass"].albedo_color = Color(0.74, 0.80, 0.71)
	var stone := SphereMesh.new()
	stone.radius = 1
	stone.height = 2
	stone.radial_segments = 12
	stone.rings = 6
	props.meshes["stone"] = stone
	props.meshes["road_rock"] = _rock_mesh()
	gravel_material = ShaderMaterial.new()
	gravel_material.resource_name = "GravelRoad"
	gravel_material.shader = load("res://assets/shaders/rally/gravel_road.gdshader")
	gravel_material.set_shader_parameter("gravel_color",load("res://assets/textures/rally/gravel.png"))
	gravel_material.set_shader_parameter("gravel_normal",load("res://assets/textures/rally/gravel_normal.png"))
	gravel_material.set_shader_parameter("grass_color",load("res://assets/textures/race/grass.png"))
	points = Layout.route()
	props.scene_root.set_meta("route", points)
	props.scene_root.set_meta("length_m", Layout.length_m(points))
	_terrain()
	_road()
	_scenery()
	props.finish()
	_configure_visibility()
	var packed := PackedScene.new()
	var error := packed.pack(props.scene_root)
	if error == OK:
		error = ResourceSaver.save(packed, output_path)
	print("Rally: %.0f m / %d samples; saved %s" % [Layout.length_m(points), points.size(), error_string(error)])
	props.scene_root.free()
	quit(0 if error == OK else 1)

func _terrain() -> void:
	for tx in range(-9, 4):
		for tz in range(-7, 4):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(props.materials["grass"])
			var faces := PackedVector3Array()
			for x in range(tx * 64, (tx + 1) * 64, 4):
				for z in range(tz * 64, (tz + 1) * 64, 4):
					_quad(tool, faces, [Layout.ground(x,z), Layout.ground(x+4,z), Layout.ground(x+4,z+4), Layout.ground(x,z+4)], true)
			_surface("Terrain_%d_%d" % [tx,tz], tool, faces, "grama", 0.46)

func _road() -> void:
	# Small ribbons let the renderer and physics broadphase discard distant bends.
	for section in 2:
		var start := 0 if section == 0 else 180
		var end := 180 if section == 0 else points.size() - 1
		for chunk in range(start, end, 32):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(props.materials["asphalt"] if section == 0 else gravel_material)
			var faces := PackedVector3Array()
			for index in range(chunk, mini(chunk + 32, end)):
				var a := points[index]
				var b := points[index + 1]
				var ra := Layout.tangent(points, index).cross(Vector3.UP).normalized()
				var rb := Layout.tangent(points, index + 1).cross(Vector3.UP).normalized()
				var bands := [-5.2, -4.2, -1.25, -0.55, 0.55, 1.25, 4.2, 5.2]
				for band in bands.size() - 1:
					var vertices: Array[Vector3] = []
					for point: Vector3 in [a+ra*bands[band], b+rb*bands[band], b+rb*bands[band+1], a+ra*bands[band+1]]:
						vertices.append(Layout.ground(point.x, point.z) + Vector3.UP * 0.14)
					var shade := 0.90 if band in [2, 4] else 1.0
					if band in [0, 6]:
						shade = 0.82
					tool.set_color(Color(shade, shade, shade))
					_quad(tool, faces, vertices, false, [Vector2(bands[band],index*2.0),Vector2(bands[band],(index+1)*2.0),Vector2(bands[band+1],(index+1)*2.0),Vector2(bands[band+1],index*2.0)])
			var label := "Asphalt" if section == 0 else "Gravel"
			if chunk != start:
				label += "_%d" % chunk
			_surface(label, tool, faces, "asfalto" if section == 0 else "cascalho", 1.05 if section == 0 else 0.68)

func _quad(tool: SurfaceTool, faces: PackedVector3Array, corners: Array, terrain: bool, road_uvs: Array = []) -> void:
	for triangle in [[0,1,2],[0,2,3]]:
		var a: Vector3 = corners[triangle[0]]
		var b: Vector3 = corners[triangle[1]]
		var c: Vector3 = corners[triangle[2]]
		# Godot uses clockwise front faces; collision normals follow that winding.
		if (b-a).cross(c-a).y > 0:
			var swap := b
			b = c
			c = swap
		for vertex: Vector3 in [a,b,c]:
			if not road_uvs.is_empty():
				tool.set_uv2(road_uvs[corners.find(vertex)])
			tool.set_normal(Layout.normal_at(vertex.x,vertex.z))
			tool.set_uv(Vector2(vertex.x,vertex.z)*0.35)
			if terrain:
				var shade := 0.78 + 0.18*sin(vertex.x/21.0)*sin(vertex.z/29.0) + 0.04*sin(vertex.x/3.0)
				tool.set_color(Color(shade,shade,shade))
			tool.add_vertex(vertex)
			faces.append(vertex)

func _surface(label: String, tool: SurfaceTool, faces: PackedVector3Array, surface: String, friction: float) -> void:
	tool.index()
	tool.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = label
	var importer := ImporterMesh.new()
	var full_mesh := tool.commit()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, full_mesh.surface_get_arrays(0), [], {}, full_mesh.surface_get_material(0))
	importer.generate_lods(60.0, 25.0, [])
	instance.mesh = importer.get_mesh()
	instance.set_meta("lod_levels", importer.get_surface_lod_count(0))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.scene_root.add_child(instance)
	var body := StaticBody3D.new()
	body.name = label+"Physics"
	body.set_meta("surface",surface)
	body.set_meta("friction",friction)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	props.scene_root.add_child(body)

func _scenery() -> void:
	# Dense, irregular forest; collision kept on nearby trunks and large rocks.
	for x in range(-540,230,12):
		for z in range(-410,220,12):
			var p := Layout.ground(x+rng.randf_range(-5,5),z+rng.randf_range(-5,5))
			var distance := _clearance(p)
			if distance < 9.0 or rng.randf() < 0.17:
				continue
			var size := rng.randf_range(8.0,16.0)
			var yaw := rng.randf_range(0,TAU)
			props.add_instance("tree_far","conifer",p+Vector3.UP*size*0.5,Vector3(size*0.30,size*0.5,size*0.30),yaw,false)
			props.add_instance("crown_near","crown_near",p+Vector3.UP*size*0.60,Vector3(size*0.30,size*0.40,size*0.30),yaw,true)
			props.add_instance("treewood","bark",p,Vector3.ONE*size,yaw,true)
			if distance < 45:
				props.add_collision(p+Vector3.UP*size*0.36,Vector3(size*0.05,size*0.72,size*0.05))
	for index in range(0,points.size(),5):
		var point := points[index]
		var right := Layout.tangent(points,index).cross(Vector3.UP).normalized()
		for side in [-1.0,1.0]:
			var p: Vector3 = point+right*side*rng.randf_range(6.8,15.0)
			p = Layout.ground(p.x,p.z)
			if _clearance(p) < 6.5:
				continue
			if rng.randf() < 0.62:
				var scale := Vector3(rng.randf_range(0.4,1.5),rng.randf_range(0.25,0.8),rng.randf_range(0.5,1.9))
				props.add_instance("road_rock","rock",p+Vector3.UP*scale.y*0.3,scale,rng.randf_range(0,TAU))
				if scale.x > 1.1:
					props.add_collision(p+Vector3.UP*scale.y*0.5,Vector3(scale.x*1.4,scale.y,scale.z*1.4))
			if index%15==0:
				props.add_box(p+Vector3.UP*0.55,Vector3(0.14,1.1,0.14),"white",true)
				props.add_box(p+Vector3.UP*0.85,Vector3(0.17,0.17,0.17),"terracotta")
	# Irregular tussocks break up the flat ground close to the road.
	for index in range(0,points.size(),2):
		var point := points[index]
		var right := Layout.tangent(points,index).cross(Vector3.UP).normalized()
		for side in [-1.0,1.0]:
			for patch in 12:
				var p: Vector3 = point+right*side*rng.randf_range(5.6,22.0)+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2))
				if _clearance(p)<5.5:
					continue
				p=Layout.ground(p.x,p.z)
				props.add_instance("tussock","tussock",p,Vector3.ONE*rng.randf_range(0.65,1.5),rng.randf_range(0,TAU),false)
	# Start/finish arches and readable roadside markers.
	for index in [18,points.size()-20]:
		var p := points[index]
		var direction := Layout.tangent(points,index)
		var yaw := atan2(-direction.x,-direction.z)
		for side in [-1.0,1.0]:
			props.add_part(p,Vector3(side*6,2.5,0),Vector3(0.3,5,0.3),"metal",yaw,true)
		props.add_part(p,Vector3(0,5,0),Vector3(12.3,0.9,0.3),"terracotta",yaw)
		props.add_label("LARGADA · SERRA" if index==18 else "CHEGADA",p+Vector3.UP*5-direction*0.2,yaw,0.019)
	# Distant mountains outside the playable terrain.
	for x in range(-800,500,160):
		props.add_instance("stone","rock",Vector3(x,0,-540),Vector3(180,rng.randf_range(90,160),170),0,false)

func _clearance(position: Vector3) -> float:
	var distance := INF
	for point in points:
		distance = minf(distance,Vector2(point.x-position.x,point.z-position.z).length())
	return distance

func _grass_mesh() -> void:
	var material := StandardMaterial3D.new()
	material.resource_name = "tussock"
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	material.distance_fade_min_distance = 58.0
	material.distance_fade_max_distance = 40.0
	props.materials["tussock"] = material
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 14:
		var yaw := rng.randf_range(0,TAU)
		var across := Vector3(cos(yaw),0,sin(yaw))*rng.randf_range(0.018,0.040)
		var base := Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
		var tip := base+Vector3(rng.randf_range(-0.18,0.18),rng.randf_range(0.25,0.60),rng.randf_range(-0.18,0.18))
		var middle := base.lerp(tip,0.6)
		var corners := [base-across,base+across,middle+across*0.55,middle-across*0.55,tip]
		for vertex in [0,2,1,0,3,2,3,4,2]:
			tool.set_normal(Vector3.UP)
			tool.set_color(Color(0.20,0.26,0.13) if vertex<2 else Color(0.28,0.34,0.19))
			tool.add_vertex(corners[vertex])
	tool.index()
	props.meshes["tussock"] = tool.commit()

func _tree_card(bottom_uv: float) -> ArrayMesh:
	# Follow the alpha silhouette instead of shading the large empty rectangle
	# around each tree, in both the main view and the close shadow pass.
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/rally/pine-realistic.png"))
	var bands := 12
	var spans: Array[Vector2] = []
	for band in bands:
		var span := Vector2(1.0, 0.0)
		var row_begin := floori(float(band) / bands * bottom_uv * source.get_height())
		var row_end := mini(source.get_height(), ceili(float(band + 1) / bands * bottom_uv * source.get_height()) + 1)
		for row in range(row_begin, row_end):
			for column in source.get_width():
				if source.get_pixel(column, row).a > 0.05:
					span.x = minf(span.x, float(column) / source.get_width())
					span.y = maxf(span.y, float(column + 1) / source.get_width())
		if span.x > span.y:
			span = Vector2(0.49, 0.51)
		spans.append(Vector2(maxf(0, span.x - 0.004), minf(1, span.y + 0.004)))
	var edges: Array[Vector2] = []
	for edge in bands + 1:
		var before := spans[maxi(0, edge - 1)]
		var after := spans[mini(bands - 1, edge)]
		edges.append(Vector2(minf(before.x, after.x), maxf(before.y, after.y)))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in bands:
		var top := float(band) / bands
		var bottom := float(band + 1) / bands
		var uvs := [Vector2(edges[band].x, top), Vector2(edges[band].y, top), Vector2(edges[band + 1].y, bottom), Vector2(edges[band + 1].x, bottom)]
		for index in [0, 1, 2, 0, 2, 3]:
			var uv: Vector2 = uvs[index]
			tool.set_normal(Vector3.FORWARD)
			tool.set_uv(Vector2(uv.x, uv.y * bottom_uv))
			tool.add_vertex(Vector3(uv.x * 2 - 1, 1 - uv.y * 2, 0))
	tool.index()
	return tool.commit()

func _tree_wood() -> void:
	var bark := StandardMaterial3D.new()
	bark.resource_name = "bark"
	bark.albedo_texture = load("res://assets/textures/rally/bark.png")
	bark.normal_enabled = true
	bark.normal_texture = load("res://assets/textures/rally/bark_normal.png")
	bark.normal_scale = 0.7
	bark.roughness = 0.95
	bark.uv1_scale = Vector3(2,4,1)
	props.materials["bark"] = bark
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.009
	trunk.bottom_radius = 0.025
	trunk.height = 0.72
	trunk.radial_segments = 8
	wood.append_from(trunk,0,Transform3D(Basis.IDENTITY,Vector3(0,0.36,0)))
	for branch in 5:
		var yaw := float(branch)*2.4
		var start := Vector3(0,0.40+branch*0.05,0)
		var end := start+Vector3(cos(yaw)*0.15,0.045,sin(yaw)*0.15)
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.003
		cylinder.bottom_radius = 0.010
		cylinder.height = start.distance_to(end)
		cylinder.radial_segments = 5
		var basis := Basis(Quaternion(Vector3.UP,(end-start).normalized()))
		wood.append_from(cylinder,0,Transform3D(basis,(start+end)*0.5))
	wood.index()
	props.meshes["treewood"] = wood.commit()

func _configure_visibility() -> void:
	var distant: Dictionary = {}
	var near: Array[MultiMeshInstance3D] = []
	for geometry in props.scene_root.get_children():
		if not geometry is MultiMeshInstance3D:
			continue
		var kind: String = geometry.material_override.resource_name
		if kind in ["conifer","crown_near"]:
			var radius := 0.0
			for placement: Transform3D in geometry.multimesh.instance_transforms:
				radius = maxf(radius,placement.basis.get_scale().x)
			geometry.multimesh.billboard_radius = radius
		geometry.visibility_range_end_margin = 0.0
		var sector := Vector2i(floori(geometry.position.x/props.batch_size),floori(geometry.position.z/props.batch_size))
		if kind == "conifer":
			geometry.visibility_range_begin = 90.0
			geometry.visibility_range_begin_margin = 6.0
			geometry.visibility_range_end = 520.0
			distant[sector] = geometry
		elif kind in ["crown_near","bark"]:
			geometry.visibility_range_end = 120.0
			near.append(geometry)
		elif kind == "tussock":
			geometry.visibility_range_end = 100.0
		else:
			geometry.visibility_range_end = 220.0
	for geometry in near:
		var sector := Vector2i(floori(geometry.position.x/props.batch_size),floori(geometry.position.z/props.batch_size))
		if distant.has(sector):
			# Far representation controls both near nodes through one boundary.
			geometry.visibility_parent = NodePath("../"+str(distant[sector].name))


func _rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		var v := vertices[index]
		var shape := 0.85+0.14*sin(v.x*5.0+v.y*3.0)*cos(v.z*4.0-v.y*2.0)
		vertices[index] = v*shape+Vector3(0.08*v.y*v.y,0,0)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool := SurfaceTool.new()
	tool.create_from(mesh,0)
	tool.generate_normals()
	return tool.commit()
