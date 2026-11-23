extends RefCounted

const Route = preload("res://scripts/city/figueiras_route.gd")
const BOUNDS := [Rect2(-73, -72, 54, 145), Rect2(125, 97, 103, 116)]
const ESTACAO_LOADING_APRON := Rect2(154.2, 146.0, 15.8, 28.8)


static func routes(grid_height: Callable) -> Array[Route]:
	var paths: Array[Route] = [
		Route.new("Galeria da Praça", 8.8, [
			[Vector2(-43, 52), Vector2.ZERO, Vector2(0, -13)],
			[Vector2(-40, 20), Vector2(0, 13), Vector2(0, -11)],
			[Vector2(-44, -13), Vector2(0, 11), Vector2(0, -13)],
			[Vector2(-43, -54), Vector2(0, 15), Vector2.ZERO],
		], PackedVector2Array(), -1.0, Vector2(7.05, 6.65)),
		Route.new("Pátio da Estação", 9.2, [
			[Vector2(208, 130), Vector2.ZERO, Vector2(-13, 0)],
			[Vector2(176, 125), Vector2(11, 0), Vector2(-12, 0)],
			[Vector2(150, 150), Vector2(0, -14), Vector2(0, 15)],
			[Vector2(151, 194), Vector2(0, -14), Vector2.ZERO],
		], PackedVector2Array(), -1.0, Vector2(7.40, 6.85)),
	]
	for road in paths:
		var entry: float = grid_height.call(road.points[0])
		var exit: float = grid_height.call(road.points[-1])
		var profile := PackedVector2Array()
		for index in 7:
			var fraction := float(index) / 6.0
			var point := road.point_at(road.length * fraction)
			var local: float = grid_height.call(point)
			profile.append(Vector2(fraction, lerpf(lerpf(entry, exit, fraction), local, 0.23)))
		road.set_elevations(profile)
	return paths
