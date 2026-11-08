class_name PlanetIcon
extends ColorRect
## A planet as a small flat icon: a disc in its icon colour with a night side, and its
## rings at its tilt when it has them. A planet with rings gets a smaller disc, so the
## rings fit inside the icon at any tilt. Keep the icon square. Each icon draws with its
## own material, made here, so a scene sets no material on it. It reads the planet when
## [member planet] is set, so it doesn't follow later changes to the planet's colours.

const SHADER := preload("res://game/passengers/planet_icon.gdshader")

## The planet shown. None hides the icon.
var planet: Planet:
	set(value):
		planet = value
		_show()

var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = SHADER
	material = _material


func _ready() -> void:
	# A scene's saved properties are set after _init(), so a material set in the scene
	# replaces this icon's own, and every icon sharing it shows the last planet's colours.
	if material != _material:
		push_error("%s: PlanetIcon makes its own material; remove the one its scene sets" % name)
		material = _material


func _show() -> void:
	visible = planet != null
	if not planet:
		return
	_material.set_shader_parameter(&"color", planet.icon_color)
	_material.set_shader_parameter(&"has_rings", planet.has_rings())
	_material.set_shader_parameter(&"ring_color", planet.icon_ring_color)
	_material.set_shader_parameter(&"ring_tilt", deg_to_rad(planet.tilt))
