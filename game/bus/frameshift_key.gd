class_name FrameshiftKey
extends BusKey
## The Frameshift key in the bus bar, a [BusKey] with a lamp and a label. The bus status
## sets what it shows: [member charge], how far the drive has charged, fills the cap in the
## bus's yellow and latches the key down with its lamp lit; [member stop] turns it into the
## red Stop key, lit; disabled, the cap is dim and its lamp off.

const SIZE := Vector2(104.0, 44.0)
const STOP_SIDE_COLOR := Color(0.639, 0.169, 0.251)
const STOP_FACE_COLOR := Color(0.949, 0.302, 0.4)
const STOP_PRESSED_COLOR := Color(0.839, 0.247, 0.345)
const CHARGE_COLOR := Color(0.961, 0.78, 0.29, 0.6)
const LAMP_OFF_COLOR := Color(0.0, 0.0, 0.0, 0.4)
const LAMP_ON_COLOR := Color(1.0, 1.0, 1.0)
const TEXT_COLOR := Color(0.957, 0.945, 1.0)
const LAMP_SIZE := 6.0
const LAMP_GAP := 4.0

## How far the drive has charged, from 0 to 1. Above 0 the key latches down and fills.
var charge := 0.0:
	set(value):
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()
## Whether the key is the red Stop key.
var stop := false:
	set(value):
		if value != stop:
			stop = value
			queue_redraw()

var _fill := StyleBoxFlat.new()


func _ready() -> void:
	super()
	custom_minimum_size = custom_minimum_size.max(SIZE)
	_fill.bg_color = CHARGE_COLOR
	_fill.set_corner_radius_all(8)


func _draw() -> void:
	var lit := charge > 0.0 or stop
	var face := _draw_cap()
	if charge > 0.0:
		_fill.draw(
			get_canvas_item(), Rect2(face.position, Vector2(face.size.x * charge, face.size.y))
		)
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var label := "Stop" if stop else "Frameshift"
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var row := LAMP_SIZE + LAMP_GAP + text_width
	var left := face.get_center().x - row * 0.5
	var lamp_at := Vector2(left + LAMP_SIZE * 0.5, face.get_center().y)
	draw_circle(lamp_at, LAMP_SIZE * 0.5, LAMP_ON_COLOR if lit else LAMP_OFF_COLOR)
	var ink := Color(TEXT_COLOR, 0.4) if disabled else TEXT_COLOR
	var baseline := (
		face.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	draw_string(
		font,
		Vector2(left + LAMP_SIZE + LAMP_GAP, baseline),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ink
	)


func _is_down() -> bool:
	return is_pressed() or charge > 0.0


func _side_color() -> Color:
	return STOP_SIDE_COLOR if stop else SIDE_COLOR


func _face_color(down: bool) -> Color:
	if stop:
		return STOP_PRESSED_COLOR if down else STOP_FACE_COLOR
	if disabled or down:
		return FACE_COLOR
	return FACE_RAISED_COLOR if is_hovered() else FACE_COLOR
