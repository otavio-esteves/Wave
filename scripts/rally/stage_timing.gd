extends Node

const Layout = preload("res://scripts/rally/rally_layout.gd")
var elapsed := 0.0
var best_time := 0.0
var finished_time := 0.0
var active := false
var valid := true
var next_gate := 0
var gates: Array[Transform3D] = []
var route: PackedVector3Array
var length_m := 0.0
var previous := Vector3.ZERO
var car: PlayerCar
var label: Label
var _hud_timer := 0.0
var _closest_index := 0

func _ready() -> void:
	process_physics_priority = 5
	car = get_parent().get_node("PlayerCar")
	route = get_parent().get_node("RallyMap").get_meta("route")
	length_m = Layout.length_m(route)
	for gate in 13:
		var index := 18 + roundi(float(gate) / 12 * (route.size()-38))
		var forward := Layout.tangent(route,index)
		forward.y = 0
		forward = forward.normalized()
		gates.append(Transform3D(Basis(forward.cross(Vector3.UP),Vector3.UP,-forward),route[index]))
	previous = car.global_position
	car.car_reset.connect(_reset_run)
	label = Label.new()
	label.position = Vector2(20,165)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	get_parent().get_node("HUD/Overlay").add_child(label)
	_update_readout()

func _physics_process(delta: float) -> void:
	var current := car.global_position
	if active:
		elapsed += delta
	if current.distance_to(previous) > maxf(car.forward_speed,car.reverse_speed)*delta+2.0:
		_reset_run()
	else:
		if next_gate < gates.size() and _crossed(gates[next_gate],previous,current):
			if next_gate == 0:
				active = true
				valid = true
				elapsed = 0.0
				finished_time = 0.0
			next_gate += 1
			if next_gate == gates.size():
				active = false
				finished_time = elapsed
				if valid:
					best_time = elapsed if best_time == 0.0 else minf(best_time,elapsed)
	previous = current
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		# Exact nearest sample, bounded 2 m spacing, adequate for stage validity.
		var distance := INF
		for index in route.size():
			var candidate := Vector2(route[index].x-current.x,route[index].z-current.z).length_squared()
			if candidate < distance:
				distance = candidate
				_closest_index = index
		if active and distance > pow(Layout.HALF_WIDTH+2.0,2):
			valid = false
		_update_readout()

func _crossed(gate: Transform3D, from: Vector3, to: Vector3) -> bool:
	var normal := -gate.basis.z
	var before := (from-gate.origin).dot(normal)
	var after := (to-gate.origin).dot(normal)
	if before > 0.0 or after <= 0.0:
		return false
	var crossing := from.lerp(to,-before/(after-before))-gate.origin
	return absf(crossing.dot(gate.basis.x)) < Layout.HALF_WIDTH+1.0 and absf(crossing.y) < 3.0

func _reset_run() -> void:
	active = false
	valid = true
	next_gate = 0
	elapsed = 0.0
	finished_time = 0.0
	previous = car.global_position
	if label != null:
		_update_readout()

func _update_readout() -> void:
	var state := "Cruze a largada para iniciar"
	if active:
		state = "%.2f s · Controles %d/12" % [elapsed,next_gate-1]
	elif finished_time > 0.0:
		state = "CHEGADA · %.2f s · R: nova tentativa" % finished_time
	if not valid:
		state += " · Tempo inválido: saiu do percurso"
	var ahead := mini(_closest_index+28,route.size()-1)
	var direction := Layout.tangent(route,_closest_index)
	var upcoming := Layout.tangent(route,ahead)
	var turn := direction.signed_angle_to(upcoming,Vector3.UP)
	var instruction := "Reta"
	if absf(turn) > 0.12:
		instruction = ("Esquerda" if turn > 0 else "Direita") + (" fechada" if absf(turn)>0.55 else " suave")
	label.text = "RALLY · SERRA · %.2f km\n%s\n%s · %s\nMelhor: %s" % [length_m/1000.0,state,instruction,car.surface_name,"--" if best_time==0.0 else "%.2f s" % best_time]
