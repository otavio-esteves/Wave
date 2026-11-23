extends RefCounted

const Layout = preload("res://scripts/city/figueiras_layout.gd")


func decorate(city, heading: float, origin: Vector3, width: float, depth: float, height: float, shop: String) -> void:
	match shop:
		"CORREIOS DA VILA":
			_post_office(city, heading, origin, width, depth, height)
		"GALERIA DO RELÓGIO":
			_clock_galleries(city, heading, origin, width, depth, height)


func _post_office(city, yaw: float, origin: Vector3, width: float, depth: float, height: float) -> void:
	var face := depth * 0.5
	for x: float in [-0.46, -0.18, 0.18, 0.46]:
		var offset := Vector3(x * width, height * 0.48, face + 0.16)
		city.add_part(origin, offset, Vector3(0.32, height * 0.96, 0.33), "parapet", yaw)
		city.add_part(origin, offset + Vector3.UP * height * 0.46, Vector3(0.50, 0.22, 0.46), "trim", yaw)
		city.add_part(origin, offset - Vector3.UP * height * 0.39, Vector3(0.57, 0.56, 0.46), "stone", yaw)
	for band: float in [0.38, 0.91]:
		city.add_part(origin, Vector3(0, height * band, face + 0.155), Vector3(width + 0.36, 0.14, 0.34), "trim", yaw)
	city.add_part(origin, Vector3(0, height + 0.20, face + 0.15), Vector3(width + 0.38, 0.26, 0.44), "metal", yaw)
	city.add_part(origin, Vector3(0, height + 0.63, face), Vector3(width * 0.42, 1.08, 0.44), "terracotta", yaw)
	city.add_part(origin, Vector3(0, height + 1.20, face), Vector3(width * 0.34, 0.16, 0.53), "trim", yaw)
	city.add_part(origin, Vector3(0, 2.90, face + 0.92), Vector3(width * 0.86, 0.15, 1.70), "awning_green", yaw)
	for side: float in [-1, 1]:
		city.add_part(origin, Vector3(side * width * 0.39, 1.35, face + 1.52), Vector3(0.18, 2.68, 0.18), "steel_plate", yaw, true)
		city.add_part(origin, Vector3(side * width * 0.26, 2.76, face + 0.96), Vector3(0.89, 0.12, 0.26), "light", yaw)


func _clock_galleries(city, yaw: float, origin: Vector3, width: float, depth: float, height: float) -> void:
	var front := depth * 0.5
	for x: float in [-0.43, -0.31, 0.31, 0.43]:
		city.add_part(origin, Vector3(x * width, (height + 0.50) * 0.5, front + 0.145), Vector3(0.26, height + 0.50, 0.28), "ceramic", yaw)
	for floor_y: float in [3.12, 6.24, 9.36, 12.48, 15.60]:
		if floor_y >= height:
			break
		city.add_part(origin, Vector3(0, floor_y, front + 0.205), Vector3(width + 0.19, 0.12, 0.45), "parapet", yaw)
	city.add_part(origin, Vector3(0, height + 1.36, front - 0.71), Vector3(width * 0.45, 3.0, 2.70), "cream", yaw)
	city.add_part(origin, Vector3(0, height + 2.68, front - 0.71), Vector3(width * 0.49, 0.29, 2.95), "trim", yaw)
	city.add_part(origin, Vector3(0, height + 3.16, front - 0.71), Vector3(width * 0.34, 0.79, 2.27), "roof_gray", yaw, false, "hip_roof")
	var frame := Basis(Vector3.UP, yaw)
	var center := origin + frame * Vector3(0, height + 1.05, front + 0.67)
	var face := Transform3D(frame * Basis(Vector3.RIGHT, PI * 0.5), center)
	city.add_transformed_instance("cylinder", "metal", face.scaled_local(Vector3(0.93, 0.094, 0.93)))
	city.add_transformed_instance("cylinder", "trim", Transform3D(face.basis, center + frame.z * 0.046).scaled_local(Vector3(0.81, 0.038, 0.81)))
	for index in 12:
		var angle := index * TAU / 12.0
		var direction := Vector3(sin(angle), cos(angle), 0)
		var mark := Transform3D(frame * Basis(Vector3.BACK, -angle), center + frame * (direction * 0.66 + Vector3.BACK * 0.070))
		city.add_transformed_instance("box", "sign_ink", mark.scaled_local(Vector3(0.048, 0.12 if index % 3 == 0 else 0.072, 0.018)))
	var marker := Marker3D.new()
	marker.name = "CivicClock"
	marker.transform = Transform3D(frame, center + frame.z * 0.075)
	city.scene_root.add_child(marker)
	for side: float in [-1, 1]:
		city.add_part(origin, Vector3(side * width * 0.43, 1.28, front + 1.31), Vector3(0.26, 2.56, 0.25), "ceramic", yaw, true)
	city.add_part(origin, Vector3(0, 2.67, front + 0.79), Vector3(width * 0.93, 0.22, 1.80), "metal", yaw)
