extends RefCounted

const STAGES := ["alameda", "galeria", "estacao", "passo", "mercado"]
const PATH := "user://figueiras-cup-v1.cfg"
var active := false
var wet := false
var rounds := PackedInt32Array()
var _records := Vector2i(-1, -1)


func _init() -> void:
	var saved := ConfigFile.new()
	if saved.load(PATH) != OK:
		return
	for surface in 2:
		var record: Variant = saved.get_value("records", "wet" if surface == 1 else "dry", -1)
		if record is int and record >= 0 and record <= STAGES.size() * 3:
			_records[surface] = record
	var markers: Variant = saved.get_value("cup", "rounds", -1)
	var conditions: Variant = saved.get_value("cup", "wet", -1)
	if markers is PackedInt32Array and conditions is bool and markers.size() < STAGES.size():
		for medal in markers:
			if medal < 0 or medal > 3:
				return
		rounds = markers
		wet = conditions
		active = true


func start(raining: bool) -> void:
	rounds.clear()
	wet = raining
	active = true
	_save()


func abort() -> void:
	active = false
	rounds.clear()
	_save()


func event_id() -> String:
	return STAGES[rounds.size()] if active else ""


func points() -> int:
	var total := 0
	for points_in_round in rounds:
		total += points_in_round
	return total


func complete_round(medal: int) -> void:
	if not active:
		return
	rounds.append(clampi(medal, 0, 3))
	if rounds.size() == STAGES.size():
		active = false
		var surface := int(wet)
		_records[surface] = maxi(_records[surface], points())
	_save()


func record(raining: bool) -> int:
	return _records[int(raining)]


static func trophy(total: int) -> String:
	if total >= 13:
		return "Ouro"
	if total >= 9:
		return "Prata"
	if total >= 5:
		return "Bronze"
	return "Concluída"


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "dry", _records.x)
	config.set_value("records", "wet", _records.y)
	if active:
		config.set_value("cup", "wet", wet)
		config.set_value("cup", "rounds", rounds)
	var temporary := "%s.tmp-%d" % [PATH, OS.get_process_id()]
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(PATH))
	if error != OK:
		push_warning("Não foi possível salvar a Copa da Vila (%s)" % error_string(error))
