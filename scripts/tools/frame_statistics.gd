extends RefCounted


static func summarize(frames_ms: Array[float]) -> Dictionary:
	if frames_ms.is_empty():
		return {}
	var sorted := frames_ms.duplicate()
	sorted.sort()
	var total := 0.0
	var slow_count := maxi(1, ceili(sorted.size() * 0.01))
	var slow_total := 0.0
	var over_budget := 0
	var hitches := 0
	for index in sorted.size():
		var ms: float = sorted[index]
		total += ms
		if index >= sorted.size() - slow_count:
			slow_total += ms
		if ms > 1000.0 / 30.0:
			over_budget += 1
		if ms > 50.0:
			hitches += 1
	return {
		"average_fps": 1000.0 * sorted.size() / total,
		"median_frame_ms": sorted[int(sorted.size() / 2)],
		"p95_frame_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_frame_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"slowest_frame_ms": sorted.back(),
		"minimum_instantaneous_fps": 1000.0 / sorted.back(),
		"one_percent_low_fps": 1000.0 * slow_count / slow_total,
		"one_percent_low_method": "reciprocal_mean_slowest_ceil_1_percent_frame_intervals",
		"frames_over_33_33_ms": over_budget,
		"frames_over_50_ms": hitches,
	}
