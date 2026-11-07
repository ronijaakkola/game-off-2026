class_name PlanetIcon
extends ColorRect
## A planet as a small flat icon: a disc in its icon colour with a night side, and its
## rings at its tilt when it has them. A planet with rings gets a smaller disc, so the
## rings fit inside the icon at any tilt. Keep the icon square, and give it a
## ShaderMaterial on planet_icon.gdshader that is local to its scene, so each icon has
## its own colours. It reads the planet when [member planet] is set, so it doesn't follow
## later changes to the planet's colours.

## The planet shown. None hides the icon.
var planet: Planet:
	set(value):
		planet = value
		_show()


func _show() -> void:
	visible = planet != null
	if not planet:
		return
	var shader_material := material as ShaderMaterial
	if not shader_material:
		push_error("PlanetIcon needs a ShaderMaterial on planet_icon.gdshader")
		return
	shader_material.set_shader_parameter(&"color", planet.icon_color)
	shader_material.set_shader_parameter(&"has_rings", planet.has_rings())
	shader_material.set_shader_parameter(&"ring_color", planet.icon_ring_color)
	shader_material.set_shader_parameter(&"ring_tilt", deg_to_rad(planet.tilt))
