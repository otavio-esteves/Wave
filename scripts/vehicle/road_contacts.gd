extends RefCounted

const MAX_PLANES := 4
const MIN_CLOSING := 0.045
const IMPACT_REARM := 0.22
const YAW_INERTIA_PER_KG := 1.49


class Contact:
	var collider: RID
	var normal: Vector3
	var position: Vector3
	var other_velocity: Vector3
	var closing: float
	var sliding: float
	var bodywork: bool
	var age := 0.0

	func strength() -> float:
		return smoothstep(2.8, 17.0, closing)


var motion := Vector3.ZERO
var yaw_rate := 0.0
var impact: Contact
var scrape: Contact
var scrape_strength := 0.0
var _planes: Array[Contact] = []
var _recent: Array[Contact] = []


func begin_tick(delta: float) -> void:
	impact = null
	scrape = null
	scrape_strength = 0.0
	for index in range(_recent.size() - 1, -1, -1):
		_recent[index].age += delta
		if _recent[index].age >= IMPACT_REARM:
			_recent.remove_at(index)


func reset() -> void:
	_recent.clear()
	_planes.clear()
	begin_tick(0.0)


func resolve(car: CharacterBody3D, incoming: Vector3, angular_speed: float, road_support: StaticBody3D) -> void:
	motion = car.velocity
	yaw_rate = angular_speed
	_planes.clear()
	var center := car.global_position
	for slide in car.get_slide_collision_count():
		var hit := car.get_slide_collision(slide)
		for side in hit.get_collision_count():
			var normal := hit.get_normal(side)
			if absf(normal.y) >= 0.53:
				continue
			var point := hit.get_position(side)
			var collider := hit.get_collider(side)
			if road_support != null and collider == road_support and (point - center).dot(car.global_basis.y) < -0.14:
				continue
			normal = Vector3(normal.x, 0.0, normal.z).normalized()
			var spin := Vector3.UP.cross(point - center) * angular_speed
			var other_velocity := hit.get_collider_velocity(side)
			var relative := incoming + spin - other_velocity
			var closing := -relative.dot(normal)
			if closing <= MIN_CLOSING:
				continue
			var contact := Contact.new()
			contact.collider = hit.get_collider_rid(side)
			contact.position = point
			contact.normal = normal
			contact.closing = closing
			contact.other_velocity = other_velocity
			contact.sliding = absf(relative.dot(normal.cross(Vector3.UP)))
			contact.bodywork = is_bodywork(hit, side)
			_add_plane(contact)
	if _planes.is_empty():
		return
	_planes.sort_custom(func(a: Contact, b: Contact) -> bool: return a.closing > b.closing)
	var deflected := false
	for contact in _planes:
		if contact.closing > 2.8:
			_apply_response(contact, center)
			deflected = true
		var grind := smoothstep(1.1, 11.0, contact.sliding) * smoothstep(0.07, 1.6, contact.closing)
		if grind > scrape_strength:
			scrape_strength = grind
			scrape = contact
		if contact.closing > 2.8 and (impact == null or contact.closing > impact.closing) and _new_impact(contact):
			impact = contact
	# Friction at a second face can push back into the first face at a corner.
	# Constraints run on the velocity left by the sweep, with a bounded solve.
	if deflected:
		for iteration in 2:
			for contact in _planes:
				motion -= contact.normal * minf(motion.dot(contact.normal), 0.0)
	_planes.clear()


func _add_plane(contact: Contact) -> void:
	for index in _planes.size():
		var plane := _planes[index]
		if plane.normal.dot(contact.normal) > 0.985:
			if contact.closing > plane.closing:
				_planes[index] = contact
			return
	if _planes.size() < MAX_PLANES:
		_planes.append(contact)


func _apply_response(contact: Contact, center: Vector3) -> void:
	var normal := contact.normal
	var tangent := normal.cross(Vector3.UP)
	var lever := contact.position - center
	var arm := lever.cross(normal).y
	var normal_impulse := contact.closing / (1.0 + arm * arm / YAW_INERTIA_PER_KG)
	var friction := 0.15 if contact.bodywork else 0.23
	var slide := (motion - contact.other_velocity).dot(tangent)
	var tangent_impulse := signf(slide) * minf(absf(slide) * 0.20, normal_impulse * friction)
	motion -= tangent * tangent_impulse
	# Restitution fades in with impact speed. A scrape stays close to the wall.
	var bounce := minf(1.25, maxf(0.0, normal_impulse - 5.0) * (0.12 if contact.bodywork else 0.08))
	var carry := maxf(0.0, contact.other_velocity.dot(normal)) * 0.33
	motion += normal * maxf(0.0, bounce + carry - motion.dot(normal))
	var twist := (arm * normal_impulse - lever.cross(tangent).y * tangent_impulse) * 0.20 / YAW_INERTIA_PER_KG
	yaw_rate = clampf(yaw_rate + clampf(twist, -1.10, 1.10), -2.1, 2.1)


func _new_impact(contact: Contact) -> bool:
	for last in _recent:
		if (last.collider == contact.collider and last.normal.dot(contact.normal) > 0.91
				and last.position.distance_squared_to(contact.position) < 9.0):
			return false
	_recent.append(contact)
	return true


static func is_bodywork(hit: KinematicCollision3D, side: int) -> bool:
	var collider := hit.get_collider(side)
	if collider == null:
		return false
	if collider.has_meta("traffic_vehicle"):
		return true
	if collider.has_meta("parked_vehicle_shapes"):
		var shapes: PackedInt32Array = collider.get_meta("parked_vehicle_shapes")
		return hit.get_collider_shape_index(side) in shapes
	return false
