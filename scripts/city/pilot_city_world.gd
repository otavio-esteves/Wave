extends DrivingWorld

const Layout = preload("res://scripts/city/pilot_city_layout.gd")


func _enter_tree() -> void:
	super._enter_tree()
	# Set the authored spawn before PlayerCar records its reset transform.
	$PlayerCar.transform = Layout.spawn()


func apply_graphics() -> void:
	super.apply_graphics()
	var settings := get_node("/root/WaveSettings")
	# The economical profile keeps sky reflections; local captures belong to Medium/High.
	var reflection := get_node_or_null("NeighborhoodReflection")
	if reflection != null:
		reflection.visible = bool(settings.graphics["antialiasing"])

	# Micro-normal maps belong to Medium/High; Economy retains the same geometry/albedo.
	var detailed := bool(settings.graphics["antialiasing"])
	var city := get_node_or_null("City")
	if city != null:
		for child in city.get_children():
			if child is GeometryInstance3D:
				var material := child.material_override as StandardMaterial3D
				if material != null and material.normal_texture != null and material.resource_name in ["ivory", "stone", "timber", "sidewalk", "paving"]:
					material.normal_enabled = detailed
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if detailed else BaseMaterial3D.SHADING_MODE_PER_VERTEX
