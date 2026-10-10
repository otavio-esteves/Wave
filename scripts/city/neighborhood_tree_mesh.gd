extends RefCounted

# Original, deterministic volumetric foliage. Unit height; instanced offline.
# Textured branch-tip clusters are folded and fixed in 3D, never camera-facing.
var random := RandomNumberGenerator.new()
var bark: SurfaceTool
var leaves: SurfaceTool

func build(variant: int) -> Dictionary:
	random.seed = 8719 + variant * 173
	bark = SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Vector3(0.015 * (variant % 3 - 1), 0, 0.016)
	var fork := Vector3(0, 0.38, 0) + lean
	_branch(Vector3.ZERO, fork, 0.022, 0.013)
	for root in 4:
		var angle := TAU * root / 4
		_branch(Vector3(cos(angle) * 0.042, 0.005, sin(angle) * 0.042), Vector3(0, 0.10, 0), 0.007, 0.014)
	var width: float = [0.34, 0.19, 0.14, 0.29, 0.30, 0.25][variant % 6]
	for cluster in 11:
		var angle := TAU * cluster / 7.0 + random.randf_range(-0.3, 0.3)
		var radius := width * (0.54 if cluster < 7 else 0.24)
		var center := Vector3(cos(angle) * radius, 0.55 + (cluster * 0.035 if variant in [1, 2] else (0.20 if cluster >= 7 else random.randf_range(-0.03, 0.12))), sin(angle) * radius) + lean
		var elbow := fork.lerp(center, 0.56) + Vector3.UP * 0.06
		_branch(fork, elbow, 0.011, 0.006)
		_branch(elbow, center, 0.006, 0.002)
		var crown := Vector3(width * 0.65, 0.22 if variant in [1, 2] else 0.13 + variant * 0.006, width * 0.65)
		for twig in 3:
			var end := center + _direction() * crown * 0.7
			_branch(center, end, 0.003, 0.0008)
		for bunch in 6:
			var offset := _direction() * crown * pow(random.randf(), 0.3333)
			var point := center + offset
			var orientation := Basis.from_euler(Vector3(random.randf_range(-1.4, 1.4), random.randf() * TAU, random.randf_range(-1.1, 1.1)))
			var size := random.randf_range(0.085, 0.13)
			var normal := (point - Vector3(0, 0.53, 0)).normalized()
			var shade := lerpf(0.75, 1.0, clampf(offset.y / crown.y * 0.4 + 0.6, 0, 1))
			var tint: Color = [Color("9bac78"), Color("849c8c"), Color("688b68"), Color("a1ab6b"), Color("89a170"), Color("6d965d")][variant % 6] * Color(shade, shade, shade)
			_cluster(point, orientation, size, tint, normal)
	bark.index()
	leaves.index()
	var canopy := leaves.commit()
	var arrays := canopy.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var middle := PackedInt32Array()
	var distant := PackedInt32Array()
	# Every branch keeps foliage at every LOD; only redundant overlapping patches drop.
	for bunch in indices.size() / 12:
		if bunch % 3 != 1:
			middle.append_array(indices.slice(bunch * 12, (bunch + 1) * 12))
		if bunch % 3 == 0:
			distant.append_array(indices.slice(bunch * 12, (bunch + 1) * 12))
	var with_lods := ArrayMesh.new()
	with_lods.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {0.006: middle, 0.020: distant})
	return {"bark": bark.commit(), "leaves": with_lods}

func _direction() -> Vector3:
	return Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1)).normalized()

func _branch(start: Vector3, end: Vector3, bottom: float, top: float) -> void:
	# Fine twigs already appear in the leaf texture; do not draw hidden cylinders.
	if bottom <= 0.003:
		return
	var direction := (end - start).normalized()
	var right := direction.cross(Vector3.FORWARD).normalized()
	var up := direction.cross(right).normalized()
	for segment in 6:
		var angle := TAU * segment / 6.0
		var next := TAU * (segment + 1) / 6.0
		var n0 := right * cos(angle) + up * sin(angle)
		var n1 := right * cos(next) + up * sin(next)
		var tint := Color("655647").darkened(0.10 if segment % 2 else 0)
		_face(bark, start + n0 * bottom, end + n0 * top, end + n1 * top, tint, (n0 + n1).normalized())
		_face(bark, start + n0 * bottom, end + n1 * top, start + n1 * bottom, tint, (n0 + n1).normalized())

func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	for point in [a, b, c]:
		surface.set_color(tint.srgb_to_linear())
		surface.set_normal(normal)
		surface.add_vertex(point)

func _cluster(center: Vector3, orientation: Basis, size: float, tint: Color, normal: Vector3) -> void:
	# Two angled halves give each branch-tip patch physical depth and parallax.
	for half in 2:
		var x0 := float(half) - 1.0
		var x1 := float(half)
		var a := center + orientation * Vector3(x0 * size, -size * 0.10 * absf(x0), -size)
		var b := center + orientation * Vector3(x1 * size, -size * 0.10 * absf(x1), -size)
		var c := center + orientation * Vector3(x1 * size, -size * 0.10 * absf(x1), size)
		var d := center + orientation * Vector3(x0 * size, -size * 0.10 * absf(x0), size)
		var u0 := float(half) / 2
		var u1 := float(half + 1) / 2
		for triangle in [[a, b, c, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1)], [a, c, d, Vector2(u0, 0), Vector2(u1, 1), Vector2(u0, 1)]]:
			for index in 3:
				leaves.set_normal(normal)
				leaves.set_color(tint.srgb_to_linear())
				leaves.set_uv(triangle[index + 3])
				leaves.add_vertex(triangle[index])
