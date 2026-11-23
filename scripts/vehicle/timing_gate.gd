extends RefCounted


static func crossing_fraction(gate: Transform3D, from: Vector3, to: Vector3, half_width: float, clearance: float) -> float:
	var forward := -gate.basis.z
	var before := (from - gate.origin).dot(forward)
	var after := (to - gate.origin).dot(forward)
	if before > 0.0 or after <= 0.0:
		return INF
	var fraction := -before / (after - before)
	var crossing := from.lerp(to, fraction) - gate.origin
	if absf(crossing.dot(gate.basis.x)) > half_width or absf(crossing.y) >= clearance:
		return INF
	return fraction
