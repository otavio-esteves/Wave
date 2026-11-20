extends SceneTree

const Baked = preload("res://scripts/city/baked_multimesh.gd")
const Legacy = preload("res://tests/fixtures/legacy_baked_multimesh.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://buffer-packing-benchmark.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var all_placements: Array[Transform3D] = []
	for index in 32769:
		all_placements.append(Transform3D(Basis.from_euler(Vector3(index * 0.01, index * 0.03, -index * 0.02)).scaled(Vector3(-2 if index % 2 else 2, 3, 4)), Vector3(index - 16384, index % 7, -(index % 29))))
	var partial_tints := PackedColorArray([Color(0.2, 0.4, 0.6, 0.8), Color(0.7, 0.3, 0.9, 0.5)])
	var cases: Array[Dictionary] = []
	var parity := true
	for count in [0, 1, 4095, 4096, 4097, 8193, 32769]:
		var placements: Array[Transform3D] = all_placements.slice(0, count)
		for coloured: bool in [false, true]:
			var tints := partial_tints if coloured else PackedColorArray()
			var expected := Legacy.make_buffer(placements, tints)
			var actual := Baked.make_buffer(placements, tints)
			var equal := expected.to_byte_array() == actual.to_byte_array()
			parity = parity and equal
			cases.append({"instances": count, "coloured": coloured, "byte_identical": equal, "output_bytes": actual.size() * 4})
	var native_bytes: int = Baked._native_vector4_bytes
	Baked._native_vector4_bytes = 32
	var forced_fallback := Baked.make_buffer(all_placements.slice(0, 31), partial_tints)
	Baked._native_vector4_bytes = native_bytes
	var fallback_parity := forced_fallback.to_byte_array() == Legacy.make_buffer(all_placements.slice(0, 31), partial_tints).to_byte_array()
	parity = parity and fallback_parity
	var records: Array[Dictionary] = []
	for count in [4096, 8192]:
		var placements: Array[Transform3D] = all_placements.slice(0, count)
		for coloured: bool in [false, true]:
			var tints := partial_tints if coloured else PackedColorArray()
			var timings: Dictionary = {"scalar": [], "chunked": []}
			for repetition in 5:
				var order := ["scalar", "chunked"] if repetition % 2 == 0 else ["chunked", "scalar"]
				for mode: String in order:
					var started := Time.get_ticks_usec()
					var data := Legacy.make_buffer(placements, tints) if mode == "scalar" else Baked.make_buffer(placements, tints)
					timings[mode].append((Time.get_ticks_usec() - started) / 1000.0)
					data = PackedFloat32Array()
			var medians: Dictionary = {}
			for mode: String in timings:
				timings[mode].sort()
				medians[mode] = timings[mode][2]
			records.append({"instances": count, "coloured": coloured, "median_ms": medians, "speedup": medians.scalar / medians.chunked, "samples_ms": timings})
	var layout := Baked.packing_layout()
	var report := {"scope": "Synthetic CPU packing microbenchmark on a shared machine; no rendering, frame pacing or startup certification. Scalar comparator is frozen historical code. Allocator/driver overhead is excluded from the script-visible scratch estimate.", "engine": Engine.get_version_info().string, "packing_layout": layout, "exact_byte_parity": parity, "simulated_double_precision_fallback_parity": fallback_parity, "cases": cases, "timings": records, "maximum_append_relocation_bytes": Baked.MAX_VECTOR_PACK_INSTANCES * 16 * 4, "maximum_additional_buffer_bytes_bound": layout.maximum_chunk_scratch_bytes + Baked.MAX_VECTOR_PACK_INSTANCES * 16 * 4, "production_script_sha256": FileAccess.get_sha256("res://scripts/city/baked_multimesh.gd"), "historical_script_sha256": FileAccess.get_sha256("res://tests/fixtures/legacy_baked_multimesh.gd")}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("Buffer packing: byte parity=%s; native Vector4=%d bytes; %s" % [parity, native_bytes, output])
	for row in records:
		print("  %d instances colours=%s: scalar %.3f ms; chunked %.3f ms; %.2fx" % [row.instances, row.coloured, row.median_ms.scalar, row.median_ms.chunked, row.speedup])
	quit(0 if parity else 1)
