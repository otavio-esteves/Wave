extends Node3D

const Layout = preload("res://scripts/city/figueiras_layout.gd")
const TrafficRoute = preload("res://scripts/city/figueiras_traffic_route.gd")
const TrafficVisuals = preload("res://scripts/city/figueiras_traffic_visuals.gd")
const TRAFFIC_LAYER := 4
const DECISION_STEPS := 3
const PERCEPTION_RADIUS_SQUARED := 44.0 * 44.0
const CIRCUITS := [
	[Vector2(-194, 52), Vector2(208, 52), Vector2(208, 194), Vector2(-194, 194)],
	[Vector2(-194, -176), Vector2(208, -176), Vector2(208, -54), Vector2(-194, -54)],
	[Vector2(-63, -54), Vector2(64, -54), Vector2(64, 52), Vector2(-63, 52)],
]

class Driver:
	var ordinal: int
	var route: TrafficRoute
	var body: AnimatableBody3D
	var pose := Transform3D.IDENTITY
	var braking := false
	var station: float
	var odometer := 0.0
	var speed: float
	var cruise: float
	var length: float
	var site: Vector2
	var heading: Vector2
	var wanted: float
	var steering := 0.0
	var nearby := PackedVector2Array()
	var neighbors := PackedInt32Array()

var drivers: Array[Driver] = []
var active := true
var _decision_group := 0
@onready var _signals: Node3D = $"../Signals"
@onready var _player: PlayerCar = $"../PlayerCar"


func _ready() -> void:
	process_physics_priority = -2
	_player.collision_mask |= TRAFFIC_LAYER
	get_parent().get_node("ChaseCamera/SpringArm3D").collision_mask |= TRAFFIC_LAYER
	var saved: Array = get_node("../City").get_meta("traffic_routes", [])
	var routes: Array[TrafficRoute] = []
	if saved.size() == (CIRCUITS.size() + 1) * 2:
		for data in saved:
			routes.append(TrafficRoute.from_bake(data))
	else:
		routes = make_routes()
	for index in routes.size():
		var route := routes[index]
		var count := 2 if index >= CIRCUITS.size() * 2 else (4 if index < 2 else 3)
		for slot in count:
			var ordinal := drivers.size()
			var driver := Driver.new()
			driver.ordinal = ordinal
			driver.route = route
			driver.station = route.length * (slot + (0.31 if index % 2 else 0.14)) / count
			# Keep the opening view moving and the player's spawn lane clear.
			if ordinal == 0:
				driver.station = 56.0
			driver.speed = 8.0 + float(ordinal % 3)
			driver.cruise = 11.0 + float(ordinal % 5) * 0.95
			driver.wanted = driver.speed
			var style := ordinal % TrafficVisuals.COLORS.size() % 3
			driver.length = [4.05, 4.46, 4.32][style]
			_create_vehicle(driver)
			driver.site = route.point(driver.station)
			driver.heading = route.direction(driver.station)
			_refresh_preview(driver)
			_place(driver)
			drivers.append(driver)
	for driver in drivers:
		_refresh_neighbors(driver)

	if DisplayServer.get_name() != "headless":
		var visuals := TrafficVisuals.new()
		visuals.name = "TrafficMeshes"
		add_child(visuals)


static func make_routes() -> Array[TrafficRoute]:
	var circuits := CIRCUITS.duplicate()
	circuits.append(TrafficRoute.baixada_loop())
	var routes: Array[TrafficRoute] = []
	for index in circuits.size():
		for reverse in [false, true]:
			routes.append(TrafficRoute.new(PackedVector2Array(circuits[index]), reverse, index >= CIRCUITS.size()))
	return routes


func _create_vehicle(driver: Driver) -> void:
	driver.body = AnimatableBody3D.new()
	driver.body.name = "TrafficCar%02d" % drivers.size()
	driver.body.collision_layer = TRAFFIC_LAYER
	driver.body.collision_mask = 0
	driver.body.set_meta("traffic_vehicle", true)
	add_child(driver.body)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.70, 1.0, driver.length - 0.12)
	collider.shape = box
	collider.position.y = 0.40
	driver.body.add_child(collider)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
	for driver in drivers:
		driver.body.set_deferred("collision_layer", TRAFFIC_LAYER if value else 0)


func _physics_process(delta: float) -> void:
	var car := Vector2(_player.global_position.x, _player.global_position.z)
	var car_velocity := Vector2(_player.velocity.x, _player.velocity.z)
	var car_heading := Vector2(-_player.global_basis.z.x, -_player.global_basis.z.z).normalized()
	var road_grip := lerpf(1.0, 0.78, _player.road_wetness)
	var cruise_scale := sqrt(road_grip)
	# Stagger perception across physics frames. Bodies and overlap checks
	# still advance at the full simulation rate.
	for index in range(_decision_group, drivers.size(), DECISION_STEPS):
		var driver := drivers[index]
		_refresh_preview(driver)
		_refresh_neighbors(driver)
		driver.steering = driver.heading.angle_to(driver.route.direction(driver.station + 3.2))
		var upcoming := driver.route.direction(driver.station + 10.0)
		var bend := absf(driver.heading.angle_to(upcoming))
		driver.wanted = minf(driver.cruise, 5.85 + 11.0 * exp(-bend * 4.0)) * cruise_scale
		driver.wanted = _signals.speed_limit(driver.site, driver.heading, driver.speed, driver.wanted, driver.length * 0.5, road_grip)
		driver.wanted = _follow(driver, car, car_velocity.dot(driver.heading), 4.05, road_grip, driver.wanted)
		for other_index in driver.neighbors:
			var other := drivers[other_index]
			var alignment := driver.heading.dot(other.heading)
			if alignment > 0.55:
				driver.wanted = _follow(driver, other.site, other.speed * alignment, other.length, road_grip, driver.wanted)
			if driver.route != other.route and alignment < 0.93:
				driver.wanted = _yield_for_merge(driver, other, driver.wanted)
	_decision_group = (_decision_group + 1) % DECISION_STEPS
	for driver in drivers:
		var braking := driver.speed > driver.wanted + 0.45
		driver.speed = move_toward(driver.speed, driver.wanted, (7.5 if braking else 2.65) * delta)
		var distance := driver.speed * delta
		if distance <= 0.0:
			driver.braking = driver.wanted <= 0.01
			continue
		var proposed := driver.station + distance
		var next_site := driver.route.point(proposed)
		var next_heading := driver.route.direction(proposed)
		if _blocked(driver, next_site, next_heading, car, car_heading):
			driver.speed = 0.0
			distance = 0.0
			braking = true
		driver.station = fposmod(driver.station + distance, driver.route.length)
		driver.odometer = fposmod(driver.odometer + distance, TAU * 0.31)
		if distance > 0.0:
			driver.site = next_site
			driver.heading = next_heading
			_place(driver)
		driver.braking = braking


func _follow(driver: Driver, site: Vector2, speed: float, length: float, grip: float, desired: float) -> float:
	var gap := site - driver.site
	var ahead := gap.dot(driver.heading)
	if ahead <= 0.0 or ahead > 26.0:
		return desired
	var closest := driver.route.point(driver.station + ahead)
	if closest.distance_squared_to(site) > 2.0 * 2.0:
		return desired
	var room := maxf(0.0, ahead - (driver.length + length) * 0.5 - 2.0)
	var following := room * (0.55 + 0.60 * grip) + maxf(speed, 0.0) * 0.60
	return minf(desired, minf(sqrt(room * 9.0 * grip), following))


func _yield_for_merge(driver: Driver, other: Driver, desired: float) -> float:
	# Look for trajectories that converge after an intersection. Keeping gap
	# control on the incoming heading alone would miss a neighbouring turn.
	const SPACING := 4.0
	const CONFLICT := 3.0
	if desired < 0.5:
		return desired
	for our_index in range(1, driver.nearby.size()):
		var ours := driver.nearby[our_index]
		if ours.distance_squared_to(other.site) > 27.0 * 27.0:
			continue
		for their_index in other.nearby.size():
			if other.speed < 1.5 and their_index > 1:
				break
			var theirs := other.nearby[their_index]
			if ours.distance_squared_to(theirs) > CONFLICT * CONFLICT:
				continue
			var approach := our_index * SPACING
			var theirs_distance := their_index * SPACING
			var our_arrival := approach / maxf(driver.speed, 4.0)
			var their_arrival := theirs_distance / maxf(other.speed, 4.0)
			var arrival_gap := our_arrival - their_arrival
			# Resolve simultaneous arrivals consistently so two drivers do not
			# both commit to the same space during the next perception update.
			var yield_first := arrival_gap > 0.35 or (absf(arrival_gap) <= 0.35 and driver.ordinal > other.ordinal)
			if yield_first and arrival_gap < 2.55:
				var clear_distance := maxf(0.0, approach - 6.2)
				return minf(desired, sqrt(clear_distance * 7.0))
	return desired


func _blocked(driver: Driver, site: Vector2, heading: Vector2, player: Vector2, player_heading: Vector2) -> bool:
	if overlap(site, heading, driver.length, player, player_heading, 4.05):
		# A slowly moving NPC brakes for a parked player; the player can still
		# ram the NPC via the real body collision during driven movement.
		if absf(Layout.height_at(site) - _player.global_position.y) < 2.1:
			return true
	for index in driver.neighbors:
		var other := drivers[index]
		if overlap(site, heading, driver.length, other.site, other.heading, other.length):
			return true
	return false


static func overlap(site: Vector2, heading: Vector2, length: float, other: Vector2, other_heading: Vector2, other_length: float) -> bool:
	var gap := other - site
	if gap.length_squared() > 5.0 * 5.0:
		return false
	var lateral := heading.orthogonal()
	var other_lateral := other_heading.orthogonal()
	for axis: Vector2 in [heading, lateral, other_heading, other_lateral]:
		var near_extent := absf(heading.dot(axis)) * length * 0.5 + absf(lateral.dot(axis)) * 0.89
		var far_extent := absf(other_heading.dot(axis)) * other_length * 0.5 + absf(other_lateral.dot(axis)) * 0.89
		if absf(gap.dot(axis)) >= near_extent + far_extent:
			return false
	return true


func _refresh_preview(driver: Driver) -> void:
	if driver.nearby.is_empty():
		driver.nearby.resize(6)
	driver.nearby[0] = driver.site
	for index in range(1, driver.nearby.size()):
		driver.nearby[index] = driver.route.point(driver.station + index * 4.0)


func _refresh_neighbors(driver: Driver) -> void:
	driver.neighbors.clear()
	for index in drivers.size():
		var other := drivers[index]
		if driver != other and driver.site.distance_squared_to(other.site) < PERCEPTION_RADIUS_SQUARED:
			driver.neighbors.append(index)


func _place(driver: Driver) -> void:
	var grade := (driver.route.elevation(driver.station + 1.2) - driver.route.elevation(driver.station - 1.2)) / 2.4
	var forward := Vector3(driver.heading.x, grade, driver.heading.y).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var origin := Vector3(driver.site.x, driver.route.elevation(driver.station) + 0.34, driver.site.y)
	driver.pose = Transform3D(Basis(right, right.cross(forward), -forward), origin)
	driver.body.transform = driver.pose
