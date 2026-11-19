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


func _ready() -> void:
	# A material set in the scene would be shared by every icon using it, so each would
	# show the last planet's colours. Set here rather than in _init(): the editor's save,
	# which check.py ids runs, would write one set there into the scene.
	if material:
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


## Cuts a circle of [param radius] pixels at [param center], in the icon's own pixels, out
## of the icon, as where something sits on top of it and the background should show
## between. A radius of 0 cuts nothing.
func cut(center: Vector2, radius: float) -> void:
	var width := size.x if size.x > 0.0 else 1.0
	_material.set_shader_parameter(&"cut_center", center / width)
	_material.set_shader_parameter(&"cut_radius", radius / width)
