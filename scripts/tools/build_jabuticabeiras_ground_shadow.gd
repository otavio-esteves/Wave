extends RefCounted

const Layout = preload("res://scripts/city/jabuticabeiras_layout.gd")
const Ground = preload("res://scripts/tools/build_jabuticabeiras_ground.gd")
const BakedMultiMesh = preload("res://scripts/city/baked_multimesh.gd")
const BOUNDS := Rect2(-20, -171, 46, 184)
const SIZE := Vector2i(276, 1104)
const SUN_DEPTH := 45.0

var _projection := PackedByteArray()
var _space: PhysicsDirectSpaceState3D
var _query := PhysicsRayQueryParameters3D.new()


func bake(map: Node3D, space: PhysicsDirectSpaceState3D, mask: int, rays: PackedVector3Array) -> PackedByteArray:
	_space = space
	_query.collision_mask = mask
	_query.hit_back_faces = true
	_projection.resize(SIZE.x * SIZE.y)
	var walls := _masonry_occlusion(rays)
	_leaf_impressions(map)
	var source := PackedByteArray()
	source.resize(walls.size())
	for index in walls.size():
		var open_ground := 255 - int(walls[index])
		var shaded_tree := 255 - int(_projection[index])
		source[index] = 255 - ((open_ground * shaded_tree + 127) / 255)
	return _penumbra(source)


func _masonry_occlusion(rays: PackedVector3Array) -> PackedByteArray:
	var visibility := PackedByteArray()
	visibility.resize(SIZE.x * SIZE.y)
	var increments := BOUNDS.size / Vector2(SIZE)
	var sunbeam := PackedVector3Array()
	for ray in rays:
		sunbeam.append(ray * SUN_DEPTH)
	for row in SIZE.y:
		var z := BOUNDS.position.y + (row + 0.5) * increments.y
		for column in SIZE.x:
			var x := BOUNDS.position.x + (column + 0.5) * increments.x
			var coordinates := Layout.coordinates(Vector2(x, z))
			# The verge behind the facades falls outside the asphalt shadow.
			if absf(coordinates.x) > 12.9:
				continue
			var lift := Ground.surface_lift(coordinates.y, coordinates.x)
			var height := Layout.position_at(coordinates.y, coordinates.x, lift).y
			var point := Vector3(x, height + 0.041, z)
			_query.from = point
			var occultation := 0
			for direction in sunbeam:
				_query.to = point + direction
				occultation += int(not _space.intersect_ray(_query).is_empty())
			visibility[row * SIZE.x + column] = roundi(float(occultation) / sunbeam.size() * 246.0)
	return visibility


func _leaf_impressions(map: Node3D) -> void:
	var masks: Dictionary[Texture2D, Image] = {}
	for node in map.get_children():
		if not node is MultiMeshInstance3D:
			continue
		var label := str(node.name)
		if not label.begins_with("crown_") and not label.begins_with("ipe_crown_"):
			continue
		var finish := node.material_override as ShaderMaterial
		var foliage := finish.get_shader_parameter("leaf_spray") as Texture2D
		if not masks.has(foliage):
			masks[foliage] = _alpha_image(foliage)
		var instancing := node.multimesh as BakedMultiMesh
		var canopy := instancing.mesh.surface_get_arrays(0)
		var tri: PackedInt32Array = canopy[Mesh.ARRAY_INDEX]
		var points: PackedVector3Array = canopy[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = canopy[Mesh.ARRAY_TEX_UV]
		var opacity := 0.38 if finish.get_shader_parameter("flowers") else 0.33
		for tree in instancing.instance_transforms:
			var matrix: Transform3D = node.transform * tree
			var coordinates := PackedVector2Array()
			coordinates.resize(points.size())
			for index in points.size():
				coordinates[index] = _project(matrix * points[index])
			for index in range(0, tri.size(), 3):
				var a := tri[index]
				var b := tri[index + 1]
				var c := tri[index + 2]
				_triangle(coordinates[a], coordinates[b], coordinates[c], uv[a], uv[b], uv[c], masks[foliage], opacity)


func _alpha_image(texture: Texture2D) -> Image:
	var alpha := texture.get_image()
	if alpha.is_compressed():
		alpha.decompress()
	alpha.clear_mipmaps()
	alpha.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	return alpha


func _project(point: Vector3) -> Vector2:
	var sun := Layout.SUN_DIRECTION
	var on_grade := point
	for iteration in 3:
		var nearby := Layout.coordinates(Vector2(on_grade.x, on_grade.z))
		var lift := Ground.surface_lift(nearby.y, nearby.x)
		var height := Layout.position_at(nearby.y, nearby.x, lift).y
		on_grade = point - sun * ((point.y - height) / sun.y)
	return (Vector2(on_grade.x, on_grade.z) - BOUNDS.position) / BOUNDS.size * Vector2(SIZE)


func _triangle(a: Vector2, b: Vector2, c: Vector2, ua: Vector2, ub: Vector2, uc: Vector2,
		texture: Image, opacity: float) -> void:
	var ab := b - a
	var ac := c - a
	var area := ab.cross(ac)
	if absf(area) < 0.02:
		return
	var first := Vector2i(a.min(b).min(c).floor()).clamp(Vector2i.ZERO, SIZE)
	var last := Vector2i(a.max(b).max(c).ceil()).clamp(Vector2i.ZERO, SIZE)
	var pixel_extent := Vector2(texture.get_size() - Vector2i.ONE)
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var delta := Vector2(x + 0.5, y + 0.5) - a
			var weight_b := delta.cross(ac) / area
			var weight_c := ab.cross(delta) / area
			if weight_b < 0.0 or weight_c < 0.0 or weight_b + weight_c > 1.0:
				continue
			var texel := ua + (ub - ua) * weight_b + (uc - ua) * weight_c
			var sample := Vector2i(texel.clamp(Vector2.ZERO, Vector2.ONE) * pixel_extent)
			var coverage := smoothstep(opacity - 0.06, opacity + 0.23, texture.get_pixelv(sample).a)
			var index := y * SIZE.x + x
			_projection[index] = mini(226, _projection[index] + roundi(coverage * 114.0))


func _penumbra(source: PackedByteArray) -> PackedByteArray:
	var blurred := PackedByteArray()
	blurred.resize(source.size())
	for y in SIZE.y:
		var row := y * SIZE.x
		var lower := maxi(y - 1, 0) * SIZE.x
		var upper := mini(y + 1, SIZE.y - 1) * SIZE.x
		for x in SIZE.x:
			var center := row + x
			var left := row + maxi(x - 1, 0)
			var right := row + mini(x + 1, SIZE.x - 1)
			var average := source[center] * 8 + source[left] + source[right] + source[lower + x] + source[upper + x]
			blurred[center] = roundi(average / 12.0)
	return blurred
