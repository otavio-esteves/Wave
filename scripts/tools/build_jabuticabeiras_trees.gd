extends "res://scripts/city/neighborhood_tree_mesh.gd"

const FoliageLOD = preload("res://scripts/city/foliage_mesh_lod.gd")
const SILHOUETTE := [Vector3(0.29, 0.66, 0.24), Vector3(0.25, 0.75, 0.30), Vector3(0.31, 0.70, 0.31)]


func build_street_tree(variant: int) -> Dictionary:
	random.seed = 38311 + variant * 159
	bark = SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves = SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spread: Vector3 = SILHOUETTE[variant]
	var fork := Vector3(-0.012, 0.31, 0.014)
	var top := Vector3(0.022, 0.75, -0.018)
	_branch(Vector3.DOWN * 0.018, Vector3(0.01, 0.080, 0.0), 0.029, 0.019)
	_branch(Vector3(0.01, 0.064, 0.0), fork, 0.019, 0.015)
	_branch(fork - Vector3.UP * 0.025, top, 0.015, 0.004)
	for root in 4:
		var direction := Vector2.from_angle(root * 1.61 + 0.20 * variant)
		_branch(Vector3(direction.x * 0.05, -0.007, direction.y * 0.05), Vector3.UP * 0.055, 0.0034, 0.011)
	for index in 12:
		var level := float(index) / 11.0
		var angle := index * 2.399963 + random.randf_range(-0.22, 0.22)
		var reach := lerpf(0.97, 0.28, level * level) * random.randf_range(0.81, 1.12)
		var direction := Vector3(cos(angle) * spread.x, 0, sin(angle) * spread.z)
		var start := fork.lerp(top, level * 0.71)
		var tip := direction * reach + Vector3.UP * (spread.y + 0.24 * level + random.randf_range(-0.09, 0.045))
		var elbow := start.lerp(tip, 0.54) - Vector3.UP * 0.045
		_branch(start, elbow, lerpf(0.010, 0.0042, level), 0.0034)
		_branch(elbow, tip, 0.0034, 0.0015)
		for leaf in 10:
			var jitter := _direction()
			var point := elbow.lerp(tip, 0.37 + leaf * 0.065) + jitter * Vector3(0.094, 0.084, 0.094)
			var size := random.randf_range(0.077, 0.115) * lerpf(1.07, 0.86, level)
			var rotation := Basis.from_euler(Vector3(random.randf_range(-1.45, 1.45), angle + leaf * 2.18,
				random.randf_range(-1.29, 1.29)))
			var crown_normal := (point - Vector3.UP * (spread.y - 0.08)).normalized()
			var tint := Color("bdbf99").lerp(Color("edf0bf"), smoothstep(0.48, 0.94, point.y) * 0.75 + random.randf() * 0.25)
			_cluster(point, rotation, size, tint, crown_normal)
	bark.index()
	leaves.index()
	var crown := FoliageLOD.bake(leaves.commit().surface_get_arrays(0))
	return {"bark": bark.commit(), "leaves": crown, "distant_leaves": FoliageLOD.flatten_patches(crown)}
