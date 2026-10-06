extends RefCounted

# Offline assembly shared by city, circuit, rally and future cells.
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")

var batch_size := 84.0
var batch_sizes: Dictionary[String, float] = {}
var center_batches_vertically := false

var scene_root: Node3D
var _colliders: StaticBody3D
var _batches: Dictionary = {}
var materials: Dictionary[String, StandardMaterial3D] = {}
var meshes: Dictionary[String, Mesh] = {}
var _shapes: Dictionary[Vector3, BoxShape3D] = {}


func begin(map_name: String, collider_name: String) -> Node3D:
	# Each build owns independent registries, colliders and pending batches.
	scene_root = Node3D.new()
	scene_root.name = map_name
	_colliders = StaticBody3D.new()
	_colliders.name = collider_name
	scene_root.add_child(_colliders)
	_batches.clear()
	materials.clear()
	meshes.clear()
	_shapes.clear()
	_setup_palette()
	_setup_meshes()
	return scene_root


func finish() -> Node3D:
	flush_batches()
	_assign_owner(scene_root)
	return scene_root


func _setup_palette() -> void:
	var colors: Dictionary[String, Color] = {
		"grass": Color("747c58"), "asphalt": Color("3d4144"),
		"sidewalk": Color("b9ac94"), "white": Color("e8ddc1"),
		"yellow": Color("d9b55b"), "terracotta": Color("a65f48"),
		"cream": Color("d9bd91"), "sage": Color("93a68f"),
		"blue": Color("87a0ac"), "rose": Color("c58d77"),
		"roof": Color("79554c"), "metal": Color("454b4b"),
		"glass": Color("526c72"), "wood": Color("8b6850"),
		"foliage": Color("63794e"), "light": Color("f1c785"),
		"water": Color("7ba6aa"), "hill": Color("758067"),
	}
	for key: String in colors:
		var material := StandardMaterial3D.new()
		material.resource_name = key
		material.albedo_color = colors[key]
		material.roughness = 0.95
		if key == "light":
			material.emission_enabled = true
			material.emission = Color("efbd72")
			material.emission_energy_multiplier = 0.7
		materials[key] = material


func _setup_meshes() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	meshes["box"] = box
	var roof := PrismMesh.new()
	roof.size = Vector3.ONE
	meshes["roof"] = roof
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 10
	meshes["cylinder"] = cylinder
	var foliage := SphereMesh.new()
	foliage.radius = 1.0
	foliage.height = 2.0
	foliage.radial_segments = 8
	foliage.rings = 4
	meshes["foliage"] = foliage


func add_tree(position: Vector3, scale_factor: float) -> void:
	add_instance("cylinder", "wood", position + Vector3.UP * 1.7 * scale_factor, Vector3(0.22, 3.4, 0.22) * scale_factor)
	add_instance("foliage", "foliage", position + Vector3.UP * 4.7 * scale_factor, Vector3(2.8, 2.7, 2.8) * scale_factor)
	add_collision(position + Vector3.UP * 1.5 * scale_factor, Vector3(0.5, 3, 0.5) * scale_factor)


func add_part(origin: Vector3, offset: Vector3, size: Vector3, material: String, yaw: float, solid: bool = false, primitive: String = "box") -> void:
	var center := origin + Basis(Vector3.UP, yaw) * offset
	add_instance(primitive, material, center, size, yaw)
	if solid:
		add_collision(center, size, yaw)


func add_box(center: Vector3, size: Vector3, material: String, solid: bool = false, yaw: float = 0.0, shadows: bool = true) -> void:
	add_instance("box", material, center, size, yaw, shadows)
	if solid:
		add_collision(center, size, yaw)


func add_instance(primitive: String, material: String, center: Vector3, size: Vector3, yaw: float = 0.0, shadows: bool = true) -> void:
	var sector_width := float(batch_sizes.get(material, batch_size))
	var key := "%s:%s:%s:%d:%d" % [primitive, material, shadows, floori(center.x / sector_width), floori(center.z / sector_width)]
	if not _batches.has(key):
		_batches[key] = []
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	_batches[key].append(Transform3D(basis, center))


func add_collision(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	if not _shapes.has(size):
		var shape := BoxShape3D.new()
		shape.size = size
		_shapes[size] = shape
	var collider := CollisionShape3D.new()
	collider.name = "Solid_%03d" % _colliders.get_child_count()
	collider.shape = _shapes[size]
	collider.position = center
	collider.rotation.y = yaw
	_colliders.add_child(collider)


func add_label(text: String, position: Vector3, yaw: float, pixel_size: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_%02d" % scene_root.get_child_count()
	label.text = text
	label.position = position
	label.rotation.y = yaw
	label.font_size = 40
	label.pixel_size = pixel_size
	label.visibility_range_end = 130.0
	label.outline_size = 3
	label.modulate = Color("f6e6c7")
	scene_root.add_child(label)


func flush_batches() -> void:
	for key: String in _batches:
		var parts := key.split(":")
		var transforms: Array = _batches[key]
		var multimesh := BakedMultiMesh.new()
		multimesh.mesh = meshes[parts[0]]
		var saved_transforms: Array[Transform3D] = []
		var sector_width := float(batch_sizes.get(parts[1], batch_size))
		var origin := Vector3((float(parts[3]) + 0.5) * sector_width, 0.0, (float(parts[4]) + 0.5) * sector_width)
		if center_batches_vertically:
			for placement: Transform3D in transforms:
				origin.y += placement.origin.y / transforms.size()
		for placement: Transform3D in transforms:
			placement.origin -= origin
			saved_transforms.append(placement)
		multimesh.instance_transforms = saved_transforms
		var instance := MultiMeshInstance3D.new()
		instance.name = key.replace(":", "_")
		instance.position = origin
		instance.multimesh = multimesh
		instance.material_override = materials[parts[1]]
		# Keep distant districts out of the draw list; the horizon is covered by fog.
		if parts[1] not in ["asphalt", "hill"] and multimesh.custom_aabb.size.x < 200.0 and multimesh.custom_aabb.size.z < 200.0:
			instance.visibility_range_end = 240.0
		if parts[2] == "false":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene_root.add_child(instance)
	_batches.clear()


func _assign_owner(node: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner(child)
