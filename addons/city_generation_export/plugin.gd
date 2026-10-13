@tool
extends EditorPlugin

class GenerationFilter extends EditorExportPlugin:
	var active_generation := ""

	func _get_name() -> String:
		return "WaveCityGeneration"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		active_generation = ""
		var city := load("res://scenes/city/pilot/pilot_city.scn") as PackedScene
		if city == null:
			return
		var state := city.get_state()
		for index in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) == &"metadata/generation_directory":
				active_generation = str(state.get_node_property_value(0, index)) + "/"
				break

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if path.begins_with("res://scenes/city/pilot/pilot_city_generations/") and not active_generation.is_empty() and not path.begins_with(active_generation):
			skip()

var generation_filter: GenerationFilter


func _enter_tree() -> void:
	generation_filter = GenerationFilter.new()
	add_export_plugin(generation_filter)


func _exit_tree() -> void:
	remove_export_plugin(generation_filter)
	generation_filter = null
