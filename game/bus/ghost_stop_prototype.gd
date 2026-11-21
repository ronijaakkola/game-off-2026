class_name GhostStopPrototype
extends Control
## PROTOTYPE, throwaway (variant B of [ControlsPrototype]): a ghost stop past the end of
## the route bar's line, which says the route can go on: a dashed link to a dashed ring
## with a plus, then the queue key and the right mouse button. While the queue key is held
## it lights up in the route's colour. The route bar makes room for it at the line's right
## end and fades it in and out.

const ICON := 16.0
const LINK := 12.0
const GAP := 3.0
const KEY_GAP := 5.0
const QUIET_COLOR := Color(0.957, 0.945, 1.0, 0.5)
const LIT_COLOR := Color(1.0, 0.6, 0.22, 1.0)

var _key: Texture2D
var _mouse: Texture2D = ControlIcons.ICONS["mouse_right"]
var _lit := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_name := QueueKey.get_icons().trim_prefix("{").trim_suffix("}")
	_key = ControlIcons.ICONS[key_name]
	custom_minimum_size = Vector2(get_width(), ICON)
	size = custom_minimum_size


func _process(delta: float) -> void:
	var target := 1.0 if QueueKey.is_held() else 0.0
	_lit = lerpf(_lit, target, 1.0 - exp(-14.0 * delta))
	queue_redraw()


## The room it takes at the end of the line, in pixels.
func get_width() -> float:
	return GAP + LINK + GAP + ICON + KEY_GAP + _wide(_key) + 2.0 + _wide(_mouse)


# How wide [param icon] is at the line's height.
func _wide(icon: Texture2D) -> float:
	return roundf(icon.get_width() * ICON / icon.get_height()) if icon else 28.0


func _draw() -> void:
	var color := QUIET_COLOR.lerp(LIT_COLOR, _lit)
	var y := ICON * 0.5
	draw_dashed_line(Vector2(GAP, y), Vector2(GAP + LINK, y), color, 2.0, 3.0)
	var middle := Vector2(GAP + LINK + GAP + ICON * 0.5, y)
	var radius := ICON * 0.5 - 1.5
	for i: int in 8:
		var from := TAU * i / 8.0
		draw_arc(middle, radius, from, from + TAU / 16.0, 6, color, 1.5, true)
	draw_line(middle - Vector2(3.0, 0.0), middle + Vector2(3.0, 0.0), color, 1.5)
	draw_line(middle - Vector2(0.0, 3.0), middle + Vector2(0.0, 3.0), color, 1.5)
	var x := middle.x + ICON * 0.5 + KEY_GAP
	var keys := Color(1.0, 1.0, 1.0, lerpf(0.75, 1.0, _lit))
	draw_texture_rect(_key, Rect2(x, 0.0, _wide(_key), ICON), false, keys)
	x += _wide(_key) + 2.0
	draw_texture_rect(_mouse, Rect2(x, 0.0, _wide(_mouse), ICON), false, keys)
