class_name SpaceFogMap
extends SubViewport
## The fog of [SpaceSky]'s parallax layer as a texture, for the sky to read instead of
## working the fog out on every pixel of the screen every frame. The layer is one fixed
## picture, so the map draws the part of it in view once, with room round it, and again
## only when the view leaves what it holds: [method cover].
## The sky stretches the map over the screen, and the fog is soft enough to take it:
## at [constant TEXELS_PER_UNIT] the smallest detail in the fog spans ten texels, and
## what the stretch changes is under one step of an 8-bit colour.

const SHADER := preload("res://game/space_sky/space_fog_map.gdshader")
## Texels per unit of the fog layer. The fog's finest noise has about 24 cells a unit.
const TEXELS_PER_UNIT := 240.0
## Units of the layer drawn past each side of the view asked for, so a camera that pans
## stays inside the map for long.
const MARGIN := 0.25
## The most units a side of the map covers, however far a view reaches.
const MAX_SPAN := 16.0

# The part of the layer the texture holds.
var _held := Rect2()
var _material := ShaderMaterial.new()


func _init() -> void:
	disable_3d = true
	render_target_update_mode = UPDATE_DISABLED
	_material.shader = SHADER
	var fill := ColorRect.new()
	fill.material = _material
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fill)


## Makes the map hold [param view], a part of the fog layer in the layer's units, and
## returns the part it holds, which is as big or bigger. It draws only when it doesn't
## hold the view yet.
func cover(view: Rect2) -> Rect2:
	var room := Vector2.ONE * (MAX_SPAN - MARGIN * 2.0)
	view = Rect2(view.get_center() - view.size.min(room) * 0.5, view.size.min(room))
	if _held.encloses(view):
		return _held
	var texels := ((view.size + Vector2.ONE * MARGIN * 2.0) * TEXELS_PER_UNIT).ceil()
	var span := texels / TEXELS_PER_UNIT
	_held = Rect2(view.get_center() - span * 0.5, span)
	size = Vector2i(texels)
	_material.set_shader_parameter(&"origin", _held.position)
	_material.set_shader_parameter(&"span", _held.size)
	render_target_update_mode = UPDATE_ONCE
	return _held
