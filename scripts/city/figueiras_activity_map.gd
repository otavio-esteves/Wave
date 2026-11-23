extends PanelContainer

const Minimap = preload("res://scripts/city/figueiras_minimap.gd")
const Events = preload("res://scripts/city/figueiras_events.gd")
const Cup = preload("res://scripts/city/figueiras_cup.gd")
var car: PlayerCar
var sprint: Node3D
var _map: Control
var _condition := Label.new()
var _details := Label.new()
var _scroll := ScrollContainer.new()
var _rows: Array[Button] = []
var _enter := Button.new()
var _retry := Button.new()
var _ghost := CheckButton.new()
var _cup := Button.new()
var _cup_status := Label.new()
var _preview := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	var background := StyleBoxFlat.new()
	background.bg_color = Color("142427")
	background.border_color = Color("4c6667")
	background.set_border_width_all(1)
	background.set_corner_radius_all(12)
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		background.set_content_margin(side, 24.0)
	add_theme_stylebox_override("panel", background)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Vila das Figueiras"
	title.add_theme_font_size_override("font_size", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_condition.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_condition.add_theme_color_override("font_color", Color("b1d6c7"))
	header.add_child(_condition)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	layout.add_child(split)
	_map = Minimap.new()
	_map.car = car
	_map.sprint = sprint
	_map.atlas = true
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_map)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 258.0
	list.add_theme_constant_override("separation", 7)
	split.add_child(list)
	var section := Label.new()
	section.text = "Atividades"
	section.add_theme_font_size_override("font_size", 20)
	list.add_child(section)
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(rows)
	for index in sprint.events.size():
		var button := Button.new()
		button.text = sprint.events[index].title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 30.0
		button.pressed.connect(func() -> void:
			_show_event(index)
			if not _enter.disabled:
				_enter.grab_focus()
		)
		button.focus_entered.connect(func() -> void: _show_event(index))
		rows.add_child(button)
		_rows.append(button)
	_details.custom_minimum_size.x = 258.0
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 14)
	_details.add_theme_color_override("font_color", Color("d0dbd3"))
	list.add_child(_details)
	_ghost.text = "Fantasma do recorde limpo"
	_ghost.button_pressed = true
	list.add_child(_ghost)
	_enter.text = "Marcar largada"
	_enter.custom_minimum_size.y = 38.0
	_enter.pressed.connect(_arm_event)
	list.add_child(_enter)
	_retry.text = "Repetir da largada"
	_retry.pressed.connect(_retry_event)
	list.add_child(_retry)
	_cup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cup_status.add_theme_font_size_override("font_size", 14)
	_cup_status.add_theme_color_override("font_color", Color("f1cd88"))
	list.add_child(_cup_status)
	_cup.pressed.connect(_change_cup)
	list.add_child(_cup)
	var close := Button.new()
	close.text = "Voltar à direção"
	close.pressed.connect(close_map)
	list.add_child(close)
	for index in _rows.size():
		_rows[index].focus_neighbor_top = _rows[index].get_path_to(_rows[index - 1] if index > 0 else close)
		if index + 1 < _rows.size():
			_rows[index].focus_neighbor_bottom = _rows[index].get_path_to(_rows[index + 1])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 28
	offset_right = -28
	offset_top = 26
	offset_bottom = -26


func open_map() -> void:
	get_tree().paused = true
	show()
	_condition.text = "Pista molhada" if sprint.wet else "Pista seca"
	_refresh_cup()
	_show_event(sprint.cup_event_index() if sprint.cup_event_index() >= 0 else sprint.selected)
	_rows[_preview].grab_focus()
	_scroll.ensure_control_visible.call_deferred(_rows[_preview])


func close_map() -> void:
	car.suppress_reset_until_release()
	hide()
	get_tree().paused = false


func _show_event(index: int) -> void:
	_preview = index
	_enter.disabled = not sprint.can_stage(index)
	_retry.visible = not _enter.disabled and sprint.selected == index and sprint.last_time > 0.0
	for row in _rows.size():
		_rows[row].add_theme_color_override("font_color", Color("a0e5c8") if row == index else Color("dde4df"))
	var event: Dictionary = sprint.events[index]
	_ghost.visible = event.type == "Tempo" and not _enter.disabled
	_ghost.focus_neighbor_top = _ghost.get_path_to(_rows[index])
	_enter.focus_neighbor_top = _enter.get_path_to(_ghost if _ghost.visible else _rows[index])
	_rows[-1].focus_neighbor_bottom = _rows[-1].get_path_to(_ghost if _ghost.visible else (_cup if _enter.disabled else _enter))
	var clean: float = sprint.record_for(index, true)
	var previous: float = sprint.record_for(index)
	var record := Events.format_score(event, clean if clean >= 0.0 else previous)
	if clean >= 0.0:
		record += " · " + Events.medal_name(Events.medal(event, clean, sprint.wet))
	var gold := Events.format_score(event, Events.target(event, 3, sprint.wet))
	_details.text = "%s · %s\n%s\n\n%s  %s\nMeta de ouro  %s" % [event.title, event.type, event.description,
		"Recorde limpo" if clean >= 0.0 else "Recorde", record, gold]
	_map.preview = index
	_map.refresh_activity()


func _arm_event() -> void:
	if not sprint.can_stage(_preview):
		return
	sprint.select_event(_preview, true, _ghost.button_pressed)
	close_map()


func _retry_event() -> void:
	if sprint.retry_from_start(_preview, _ghost.button_pressed):
		close_map()


func _refresh_cup() -> void:
	_cup.visible = sprint.cup_available()
	_cup_status.visible = _cup.visible
	if not _cup.visible:
		return
	if sprint.cup.active:
		_cup.text = "Encerrar Copa da Vila"
		_cup_status.text = "Etapa %d de %d · %d pontos\nA condição da pista vale para toda a Copa." % [
			sprint.cup.rounds.size() + 1, Cup.STAGES.size(), sprint.cup.points()]
	else:
		_cup.text = "Iniciar Copa da Vila"
		var record: int = sprint.cup.record(sprint.wet)
		_cup_status.text = "Cinco etapas na Vila" if record < 0 else "Melhor Copa  %s · %d pontos" % [Cup.trophy(record), record]


func _change_cup() -> void:
	if sprint.cup.active:
		sprint.abort_cup()
		_refresh_cup()
		_show_event(_preview)
	else:
		sprint.start_cup(_ghost.button_pressed)
		close_map()
