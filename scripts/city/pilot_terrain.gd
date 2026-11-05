extends RefCounted

# Broad landforms keep a readable urban skyline and smooth vertical curves.
# Cache only requested lattice samples; no full terrain generation at startup.
const HALF_WIDTH := 1536.0
const HALF_DEPTH := 1232.0
const STEP := 8.0
const GRID_COLUMNS := int(HALF_WIDTH * 2 / STEP) + 1
const GRID_ROWS := int(HALF_DEPTH * 2 / STEP) + 1
const REVISION := "2026-11-04-natural-relief"
static var _heights := PackedFloat64Array()
static var _sampled := PackedByteArray()


static func analytic_height(x: float, z: float) -> float:
	var hills := 44.0 * _hill(x, z, -970.0, -420.0, 530.0, 460.0)
	hills += 27.0 * _hill(x, z, -1080.0, 730.0, 470.0, 400.0)
	hills += 20.0 * _hill(x, z, -490.0, 470.0, 440.0, 410.0)
	hills += 18.0 * _hill(x, z, 40.0, 680.0, 460.0, 380.0)
	hills += 19.0 * _hill(x, z, 50.0, -730.0, 440.0, 360.0)
	# A long, curved western ridge joins the hills instead of isolated mounds.
	var ridge := 12.0 * exp(-pow((x + 790.0 + 0.24 * z) / 620.0, 2))
	var valley := 7.0 * _hill(x, z, -170.0, -60.0, 490.0, 580.0)
	var undulation := 1.4 * sin((x + 0.22 * z) / 390.0) * cos((z - 0.13 * x) / 430.0)
	return 12.0 + 0.002 * (x + HALF_WIDTH) + hills + ridge - valley + undulation


static func _hill(x: float, z: float, cx: float, cz: float, width: float, depth: float) -> float:
	return exp(-pow((x - cx) / width, 2) - pow((z - cz) / depth, 2))


static func lattice_height(column: int, row: int) -> float:
	var x := -HALF_WIDTH + column * STEP
	var z := -HALF_DEPTH + row * STEP
	if column < 0 or column >= GRID_COLUMNS or row < 0 or row >= GRID_ROWS:
		return analytic_height(x, z)
	if _heights.is_empty():
		_heights.resize(GRID_COLUMNS * GRID_ROWS)
		_sampled.resize(GRID_COLUMNS * GRID_ROWS)
	var index := row * GRID_COLUMNS + column
	if _sampled[index] == 0:
		_heights[index] = analytic_height(x, z)
		_sampled[index] = 1
	return _heights[index]


static func height_at(x: float, z: float) -> float:
	# Interpolate the exact saved triangle diagonal, including negative cells.
	var column := floori((x + HALF_WIDTH) / STEP)
	var row := floori((z + HALF_DEPTH) / STEP)
	var u := (x + HALF_WIDTH - column * STEP) / STEP
	var v := (z + HALF_DEPTH - row * STEP) / STEP
	var a := lattice_height(column, row)
	var b := lattice_height(column + 1, row)
	var c := lattice_height(column, row + 1)
	var d := lattice_height(column + 1, row + 1)
	return a + (b - a) * u + (c - a) * v if u + v <= 1.0 else d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)
