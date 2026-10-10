extends DrivingWorld

const Layout = preload("res://scripts/city/pilot_city_layout.gd")


func _enter_tree() -> void:
	super._enter_tree()
	# Set the authored spawn before PlayerCar records its reset transform.
	$PlayerCar.transform = Layout.spawn()


func _ready() -> void:
	super._ready()
	var minimap := preload("res://scripts/city/city_minimap.gd").new()
	minimap.name = "CityMinimap"
	minimap.car = $PlayerCar
	$HUD/Overlay.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 20
	minimap.offset_top = -223
	minimap.offset_right = 230
	minimap.offset_bottom = -20
	$HUD/Overlay/Telemetry.offset_top = -104
	var map := preload("res://scripts/city/city_map.gd").new()
	map.name = "CityMap"
	map.car = $PlayerCar
	map.hud = $HUD
	$HUD/Overlay.add_child(map)
	$HUD.city_map = map
	var button := Button.new()
	button.text = "Mapa da cidade"
	$HUD.buttons.add_child(button)
	$HUD.buttons.move_child(button, 3)
	button.pressed.connect(map.open_map)


func apply_graphics() -> void:
	super.apply_graphics()
	# Moonlight stays soft; avoid a second directional shadow atlas.
	var moon := get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		moon.shadow_enabled = false
	var settings := get_node("/root/WaveSettings")
	# Reflections follow the evolving sky in all profiles.
	# Micro-normal maps belong to Medium/High; Economy retains the same geometry/albedo.
	var detailed := bool(settings.graphics["antialiasing"])
	var city := get_node_or_null("City")
	if city != null:
		for child in city.find_children("*", "GeometryInstance3D", true, false):
			if child is GeometryInstance3D:
				var material := child.material_override as StandardMaterial3D
				if material != null and material.normal_texture != null and material.resource_name in ["ivory", "stone", "timber", "sidewalk", "paving"]:
					material.normal_enabled = detailed
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if detailed else BaseMaterial3D.SHADING_MODE_PER_VERTEX
