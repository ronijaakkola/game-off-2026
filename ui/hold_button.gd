class_name HoldButton
extends Button
## A button held down to confirm an action that is hard to undo, such as starting a new
## game over a save. While it is held, a faint fill grows across it from the left, and
## [signal confirmed] comes once it is full. Let go before that, and the fill drains back
## and nothing happens. A click alone does nothing, so connect [signal confirmed], never
## [signal BaseButton.pressed].

## It was held until the fill was full.
signal confirmed

## How much faster the fill drains than it grows, once let go.
const DRAIN_SPEED := 2.0
## How opaque the fill is, so the text stays readable through it.
const FILL_ALPHA := 0.3

## Seconds it has to be held.
@export_range(0.1, 5.0, 0.1) var hold_seconds := 1.2

var _held := false
# How full the fill is, from 0 to 1.
var _progress := 0.0
# The fill's style: a flat box with the button's corners.
var _fill_style := StyleBoxFlat.new()


func _ready() -> void:
	add_to_group(ButtonFeel.OWN_PRESS)
	var button_style := get_theme_stylebox(&"normal") as StyleBoxFlat
	if button_style:
		for corner: int in 4:
			_fill_style.set_corner_radius(corner, button_style.get_corner_radius(corner))
		_fill_style.corner_detail = button_style.corner_detail
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	set_process(false)


func _notification(what: int) -> void:
	# Hidden while held, it may never see the release.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_held = false


func _process(delta: float) -> void:
	if _held:
		_progress = minf(_progress + delta / hold_seconds, 1.0)
	else:
		_progress = maxf(_progress - delta * DRAIN_SPEED / hold_seconds, 0.0)
	queue_redraw()
	if _progress >= 1.0:
		_held = false
		_progress = 0.0
		set_process(false)
		confirmed.emit()
	elif _progress <= 0.0 and not _held:
		set_process(false)


## How full the fill is, from 0 to 1.
func get_progress() -> float:
	return _progress


# Over the button's own drawing, so it shows on any style; faint enough to read through.
func _draw() -> void:
	if _progress <= 0.0:
		return
	_fill_style.bg_color = Color(get_theme_color(&"font_color"), FILL_ALPHA)
	draw_style_box(_fill_style, Rect2(Vector2.ZERO, Vector2(size.x * _progress, size.y)))


func _on_button_down() -> void:
	_held = true
	set_process(true)


func _on_button_up() -> void:
	_held = false
