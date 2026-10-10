extends SceneTree

const Layout = preload("res://scripts/city/pilot_city_layout.gd")
const WORLD := "res://scenes/city/drive_pilot_city.tscn"
const CITY := "res://scenes/city/pilot/pilot_city.scn"
const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "handbrake"]
var checks := 0
var failures := 0
var rendered := false


func _initialize() -> void:
	rendered = DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	root.get_node("WaveSettings").set_graphics_preset("economy")
	var edges := Layout.edges()
	var seen := {0: true}
	for iteration in Layout.NODE_COUNT:
		for edge in edges:
			if seen.has(edge.a):
				seen[edge.b] = true
			if seen.has(edge.b):
				seen[edge.a] = true
	_check(seen.size() == Layout.NODE_COUNT and edges.size() - seen.size() + 1 == Layout.BLOCK_COUNT, "one connected street network encloses two hundred blocks")
	if not "--exported" in OS.get_cmdline_user_args():
		var generated := "user://pilot-city-regenerated.scn"
		var error: Error = preload("res://scripts/city/pilot_city_builder.gd").new().save_city(generated)
		_check(error == OK, "pilot generator saves into isolated user data")
		var original: Node3D = load(CITY).instantiate()
		var rebuilt: Node3D = load(generated).instantiate()
		_check(_geometry(original) == _geometry(rebuilt), "offline regeneration preserves terrain, streets, UVs, placements and all collision")
		original.free()
		rebuilt.free()
		if "--geometry-only" in OS.get_cmdline_user_args():
			_finish.call_deferred()
			return
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	await _frames(3)
	_check(root.gui_get_focus_owner() == current_scene.pilot_button, "pilot city is the default menu destination")
	current_scene.pilot_button.pressed.emit()
	await scene_changed
	await _frames(15)
	_check(current_scene.scene_file_path == WORLD, "menu enters the connected pilot city")
	var world: Node3D = current_scene
	var city := world.get_node("City")
	var car: PlayerCar = world.get_node("PlayerCar")
	var identities := [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()]
	for action in ACTIONS + ["reset_car", "pause", "camera_view", "camera_back"]:
		InputMap.action_erase_events(action)
		Input.action_release(action)
	_check(city.get_meta("block_count") == Layout.BLOCK_COUNT and city.find_children("Block*", "Node3D", false, false).size() == Layout.BLOCK_COUNT, "saved district contains all two hundred connected blocks")
	_check(is_equal_approx(float(city.get_meta("area_m2")), Layout.PREVIOUS_AREA_M2 * 4), "physical terrain area is exactly four times the previous district")
	_check(city.get_meta("parcel_count", 0) >= 1400 and city.find_children("ParkedVehicle*", "Node3D", false, false).size() >= 8, "district fills both street frontages with homes and parked vehicles")
	_check(city.get_meta("district_names", []).size() == 3 and city.get_meta("district_parcels", []).all(func(count: int) -> bool: return count > 150), "three distinct districts each contain substantial playable building frontage")
	_check(city.get_meta("skyscraper_count", 0) > 200, "downtown contains a dense authored skyscraper skyline")
	var min_tower := INF
	var max_tower := 0.0
	for geometry in city.find_children("*", "GeometryInstance3D", true, false):
		if geometry is MultiMeshInstance3D and geometry.material_override.resource_name.begins_with("downtown"):
			for placement in geometry.multimesh.instance_transforms:
				var roof: Vector3 = geometry.transform * placement.origin
				max_tower = maxf(max_tower, roof.y + placement.basis.y.length() / 2 - Layout.height_at(roof.x, roof.z))
			min_tower = minf(min_tower, geometry.visibility_range_end)
	_check(max_tower > 100 and min_tower >= 1500, "towers exceed one hundred metres and remain visible across districts")
	var minimap: Control = world.get_node("HUD/Overlay/CityMinimap")
	_check(minimap.get_global_rect().position.x >= 0 and minimap.get_global_rect().end.y <= root.get_visible_rect().end.y and not minimap.roads.is_empty(), "navigation map stays on screen and contains the connected street network")
	_check(not city.find_children("Terrain", "MeshInstance3D", true, false).is_empty() and not city.find_children("Streets", "MeshInstance3D", true, false).is_empty() and not city.find_children("Sidewalks", "MeshInstance3D", true, false).is_empty(), "saved sector scenes retain visible terrain, road and sidewalk meshes")
	_check(city.get_meta("tree_species_count", 0) >= 6 and city.get_meta("street_detail_count", 0) > 100, "dense city includes six tree forms and substantial sidewalk furniture")
	var footprints: Array = city.get_meta("parcel_footprints", [])
	var separated := not footprints.is_empty()
	for index in footprints.size():
		var polygon := _footprint(footprints[index])
		for other in range(index + 1, footprints.size()):
			if not Geometry2D.intersect_polygons(polygon, _footprint(footprints[other])).is_empty():
				separated = false
	_check(separated, "saved home, workshop and park footprints never overlap")
	_check(city.get_meta("grass_tuft_count", 0) > 15000, "expanded terrain includes baked meadow grass beyond the private gardens")
	var wide := true
	for edge in edges:
		wide = wide and float(edge.width) >= 11.5
	_check(wide, "all authored streets offer at least eleven and a half metres of paved width")
	_check(car.is_on_floor() and car.spawn_transform.origin.distance_to(Layout.spawn().origin) < 0.01, "player spawns and resets on the authored sloping street")
	_check(not car.simulation_handling and car.forward_speed == 220.0 / 3.6, "pilot uses the existing arcade vehicle without a new handling profile")
	var support := true
	var street_clearance := true
	var minimum := INF
	var maximum := -INF
	for edge in edges:
		var points := Layout.edge_points(edge.a, edge.b)
		for index in range(0, points.size()):
			var p := points[index]
			minimum = minf(minimum, p.y)
			maximum = maxf(maximum, p.y)
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2, p - Vector3.UP * 2, 1, [car.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			support = support and not hit.is_empty() and absf(hit.position.y - p.y) < 0.12 and hit.normal.y > 0.97
			var tangent := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
			var right := tangent.cross(Vector3.UP).normalized()
			for side: float in [-1.0, 0.0, 1.0]:
				var lane := p + right * side * (float(edge.width) / 2 - 1.2)
				lane.y = Layout.height_at(lane.x, lane.z) + Layout.ROAD_LIFT
				query.from = lane + Vector3.UP * 40
				query.to = lane - Vector3.UP * 0.2
				var obstruction: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				street_clearance = street_clearance and not obstruction.is_empty() and absf(obstruction.position.y - lane.y) < 0.12

	_check(support, "all authored streets and their joins have real collision matching the terrain heights")
	_check(street_clearance, "street centre and both lanes remain clear of building footprints, walls and balconies")
	_check(maximum - minimum > 10.0 and maximum - minimum < 30.0, "street network offers measurable low town and hillside relief")
	if "--layout-only" in OS.get_cmdline_user_args():
		current_scene.queue_free()
		await _frames(3)
		_finish.call_deferred()
		return
	var results: Array[Dictionary] = []
	for definition in [{"name": "districts", "ids": Layout.OUTER_LOOP, "speed": 35.0}, {"name": "centre", "ids": Layout.CENTRE_LOOP, "speed": 30.0}, {"name": "hill", "ids": Layout.HILL_LOOP, "speed": 30.0}]:
		for returning in [false, true]:
			if "--only-hill-return" in OS.get_cmdline_user_args() and (definition.name != "hill" or not returning):
				continue
			var ids: Array = definition.ids.duplicate()
			if returning:
				ids.reverse()
			var route := Layout.route(ids, 1.5)
			_place(car, route[7], route[8] - route[7])
			await _frames(10)
			var result := await _drive(car, route.slice(7), definition.speed / 3.6)
			result["route"] = definition.name
			result["returning"] = returning
			results.append(result)
			_check(result.arrived and result.max_offset <= 4.0, "%s %s completes a closed drive with real inputs" % [definition.name, "return" if returning else "outward"])
			_check(result.ground_ratio > 0.99 and result.paved_ratio > 0.98 and car.is_on_floor(), "closed drive maintains support and stays on paved streets through slopes and junctions")
			if rendered and "--previews" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://%s-%s.png" % [definition.name, "return" if returning else "outward"])
	for destination in [{"name": "square", "path": Layout.square_access()}, {"name": "workshop", "path": Layout.workshop_access()}]:
		for returning in [false, true]:
			var route: PackedVector3Array = destination.path.duplicate()
			if returning:
				route.reverse()
			_place(car, route[0], route[1] - route[0])
			await _frames(10)
			var result := await _drive(car, route, 12.0 / 3.6)
			_check(result.arrived and result.ground_ratio > 0.99, destination.name + " driveway is physically accessible " + ("back to street" if returning else "from street"))
	_check(identities == [car.get_instance_id(), world.get_node("ChaseCamera").get_instance_id(), world.get_node("HUD").get_instance_id()], "one car, camera and HUD persist throughout every city route")
	car.reset_car()
	await _frames(12)
	_check(car.is_on_floor() and car.global_position.distance_to(Layout.spawn().origin) < 0.1, "reset returns to the original city spawn with support")
	Input.action_press("camera_view")
	await _frames(1)
	Input.action_release("camera_view")
	_check(world.get_node("ChaseCamera").hood_view, "existing hood camera works in the pilot city")
	var hud := world.get_node("HUD")
	hud.set_paused(true)
	var before := car.position
	await _frames(3)
	_check(car.position == before, "pause freezes the pilot vehicle")
	hud.get_node("Overlay/PauseMenu/Center/Buttons/MainMenu").pressed.emit()
	await _frames(5)
	_check(current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn" and not paused, "pilot returns to menu and clears pause")
	var file := FileAccess.open("user://pilot-city-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "height_range_m": maximum - minimum, "checks": checks, "failures": failures, "rendered": rendered, "scope": "functional routes, no FPS or human approval"}, "\t"))
	current_scene.queue_free()
	await _frames(3)
	_finish.call_deferred()


func _place(car: PlayerCar, point: Vector3, forward: Vector3) -> void:
	_release()
	car.reset_car()
	car.global_position = point
	car.rotation = Vector3(0, atan2(-forward.x, -forward.z), 0)
	current_scene.get_node("ChaseCamera").snap_to_target()


func _drive(car: PlayerCar, path: PackedVector3Array, speed: float) -> Dictionary:
	# Junctions are immutable: avoid recomputing terrain/warp for every frame.
	var junctions := PackedVector2Array()
	for node_id in Layout.NODE_COUNT:
		var junction := Layout.node(node_id)
		junctions.append(Vector2(junction.x, junction.z))
	var index := 1
	var ground := 0
	var count := 0
	var max_offset := 0.0
	var paved := 0
	var samples := 0
	var arrived := false
	var stalled_frames := 0
	var route_length := 0.0
	for step in path.size() - 1:
		route_length += path[step].distance_to(path[step + 1])
	var frame_budget := ceili(route_length / maxf(speed, 1.0) * 60.0 * 2.0) + 3600
	for frame in frame_budget:
		var end := path[-1]
		if index == path.size() - 1 and Vector2(end.x - car.position.x, end.z - car.position.z).length() < 1.3:
			arrived = true
			break
		var segment := path[index] - path[index - 1]
		segment.y = 0
		var offset := car.position - path[index - 1]
		offset.y = 0
		var along := offset.dot(segment) / segment.length_squared()
		if along >= 1.0 and index < path.size() - 1:
			index += 1
			continue
		var target := path[index - 1].lerp(path[index], clampf(along, 0, 1))
		max_offset = maxf(max_offset, Vector2(car.position.x - target.x, car.position.z - target.z).length())
		var nearest := INF
		for junction in junctions:
			nearest = minf(nearest, Vector2(car.position.x - junction.x, car.position.z - junction.y).length())
		if Vector2(car.position.x - target.x, car.position.z - target.z).length() > (4.0 if nearest < 14.0 else 2.5):
			break
		var lookahead := 4.0 + absf(car.drive_speed) * 0.4
		for next in range(index, path.size()):
			var distance := target.distance_to(path[next])
			if distance >= lookahead:
				target = target.lerp(path[next], lookahead / distance)
				break
			target = path[next]
			lookahead -= distance
		var delta := target - car.position
		var angle := angle_difference(car.get_heading(), atan2(-delta.x, -delta.z))
		var wheel := atan(2.0 * car.wheelbase * sin(angle) / maxf(Vector2(delta.x, delta.z).length(), 0.5))
		var limit := deg_to_rad(lerpf(car.low_speed_steering_degrees, car.high_speed_steering_degrees, absf(car.drive_speed) / car.forward_speed))
		var steering := clampf(-wheel / limit, -1, 1)
		_release()
		Input.action_press("steer_left" if steering < 0 else "steer_right", absf(steering))
		var target_speed := speed
		target_speed = minf(speed, sqrt(pow(22.0 / 3.6, 2) + 2.0 * 3.0 * maxf(0.0, nearest - 12.0)))
		Input.action_press("accelerate" if car.drive_speed < target_speed else "brake", 0.65)
		await _frames(1)
		count += 1
		stalled_frames = stalled_frames + 1 if absf(car.drive_speed) < 0.2 and count > 180 else 0
		if stalled_frames > 180:
			print("Pilot route stalled at ", car.position)
			for collision_index in car.get_slide_collision_count():
				var collision := car.get_slide_collision(collision_index)
				print("Contact: ", collision.get_position(), " normal ", collision.get_normal())
			break
		ground += 1 if car.is_on_floor() else 0
		if count % 10 == 0:
			var query := PhysicsRayQueryParameters3D.create(car.position + Vector3.UP, car.position - Vector3.UP * 2, 1, [car.get_rid()])
			var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
			samples += 1
			if not hit.is_empty():
				var body: CollisionObject3D = hit.collider
				var owner: Node = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
				paved += 1 if owner.name == "Streets" else 0
	_release()
	print("Pilot route: arrived=%s offset=%.2f support=%.4f paved=%.4f position=%s" % [arrived, max_offset, float(ground) / maxi(count, 1), float(paved) / maxi(samples, 1), car.position])
	return {"arrived": arrived, "max_offset": max_offset, "ground_ratio": float(ground) / maxi(count, 1), "paved_ratio": float(paved) / maxi(samples, 1), "frames": count, "end": str(car.position)}


func _footprint(parcel: Dictionary) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var local: Vector2 = corner * parcel.size / 2
		polygon.append(parcel.center + Vector2(local.x * cos(parcel.yaw) + local.y * sin(parcel.yaw), -local.x * sin(parcel.yaw) + local.y * cos(parcel.yaw)))
	return polygon


func _geometry(node: Node) -> Array:
	var result: Array = [node.name, node.get_class()]
	if node is Node3D:
		result.append(node.transform)
	if node is CollisionShape3D:
		result.append(node.shape.get_faces() if node.shape is ConcavePolygonShape3D else node.shape.size)
	if node is MultiMeshInstance3D:
		result.append(node.multimesh.instance_transforms)
		# Instanced geometry now carries the volumetric tree model, not only placements.
		for surface in node.multimesh.mesh.get_surface_count():
			result.append(node.multimesh.mesh.surface_get_arrays(surface))
		if node.multimesh.mesh is ArrayMesh:
			for surface: Dictionary in node.multimesh.mesh.get("_surfaces"):
				result.append(surface.get("lods", []))
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			result.append(node.mesh.surface_get_arrays(surface))
	var children := node.get_children()
	children.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	for child in children:
		result.append(_geometry(child))
	return result


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _release() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	print("Pilot city smoke: %d checks, %d failures; data %s" % [checks, failures, OS.get_user_data_dir()])
	quit(0 if failures == 0 else 1)
