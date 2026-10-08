extends RefCounted

# Coordinates shared by offline authoring and route validation, never generated
# per frame. All road joins have matching positions and zero lateral slope.
const START_Z := -200.0
const CELL_LENGTH := 400.0
const END_Z := -1400.0
const REGIONS: Array[String] = ["bairro-do-sol", "rural", "rodovia", "vila-da-serra"]
const TOWN_ORIGIN_Z := -1000.0
const TOWN_CROSSROAD_Z := -180.0
const TOWN_SQUARE_Z := -240.0
const RURAL_STOP_Z := -300.0
const HIGHWAY_STOP_Z := -810.0
const TOWN_LOTS: Array[Dictionary] = [
	{"x": -22.0, "z": -74.0, "width": 11.0, "height": 3.4, "depth": 9.0, "facade": 0},
	{"x": 24.0, "z": -104.0, "width": 14.0, "height": 4.2, "depth": 10.0, "facade": 3},
	{"x": -25.0, "z": -139.0, "width": 12.0, "height": 3.7, "depth": 10.0, "facade": 1},
	{"x": 22.0, "z": -151.0, "width": 10.0, "height": 3.2, "depth": 8.0, "facade": 0},
	{"x": 24.0, "z": -237.0, "width": 15.0, "height": 4.1, "depth": 10.0, "facade": 3},
	{"x": -24.0, "z": -310.0, "width": 13.0, "height": 3.6, "depth": 10.0, "facade": 2},
	{"x": 27.0, "z": -323.0, "width": 11.0, "height": 3.8, "depth": 9.0, "facade": 1},
]


static func roadside_open(index: int, side: float, z: float, margin: float = 0.0) -> bool:
	return (index == 1 and side < 0 and absf(z + 100) < 26 + margin) or (index == 2 and side > 0 and absf(z + 210) < 26 + margin)


static func town_sidewalk_open(z: float, side: float) -> bool:
	# Clear full-width vehicle access at the crossroad and the square entrance.
	return absf(z - TOWN_CROSSROAD_Z) < 10.0 or (side < 0 and absf(z - TOWN_SQUARE_Z) < 10.0)


static func center_x(z: float) -> float:
	if z >= START_Z or z <= -1000.0:
		return 0.0
	var progress := (START_Z - z) / 800.0
	return 26.0 * sin(progress * TAU) * pow(sin(progress * PI), 2)


static func point(z: float, lane_offset: float = 3.5) -> Vector3:
	return Vector3(center_x(z) + lane_offset, 0.36, z)
