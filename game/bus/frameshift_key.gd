class_name FrameshiftKey
extends BusKey
## The Frameshift key in the bus bar, a [BusKey] with a label. The bus status sets what it
## shows: [member charge], how far the drive has charged, fills the cap in the bus's yellow
## and latches the key down; [member warmth], how warm the drive is, fills it the same way
## with the key up and ready; [member stop] turns it into the red Stop key; disabled, the
## cap is dim. Enabled and neither charging nor Stop, it is ready: the cap pulses slightly
## lighter, with a hard outline in the bus's yellow round it. [method release] pops it up
## while the pointer still holds it down.

const SIZE := Vector2(104.0, 44.0)
const STOP_SIDE_COLOR := Color(0.639, 0.169, 0.251)
const STOP_FACE_COLOR := Color(0.949, 0.302, 0.4)
const STOP_PRESSED_COLOR := Color(0.839, 0.247, 0.345)
const CHARGE_COLOR := Color(0.961, 0.78, 0.29, 0.6)
const TEXT_COLOR := Color(0.957, 0.945, 1.0)
const OUTLINE_COLOR := Color(0.961, 0.78, 0.29)
const OUTLINE_WIDTH := 2
# Ready, the cap lightens by up to PULSE_LIGHTEN and the outline's opacity swings between
# OUTLINE_DIM and OUTLINE_BRIGHT, once every PULSE_SECONDS.
const PULSE_LIGHTEN := 0.1
const OUTLINE_DIM := 0.35
const OUTLINE_BRIGHT := 1.0
const PULSE_SECONDS := 2.0

## How far the drive has charged, from 0 to 1. Above 0 the key latches down and fills.
var charge := 0.0:
	set(value):
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()
## How warm the drive is, from 0 to 1. Fills the cap without latching the key down.
var warmth := 0.0:
	set(value):
		if not is_equal_approx(value, warmth):
			warmth = value
			queue_redraw()
## Whether the key is the red Stop key.
var stop := false:
	set(value):
		if value != stop:
			stop = value
			queue_redraw()

var _outline := StyleBoxFlat.new()


func _ready() -> void:
	super()
	custom_minimum_size = custom_minimum_size.max(SIZE)
	_outline.draw_center = false
	_outline.set_border_width_all(OUTLINE_WIDTH)
	_outline.set_corner_radius_all(CAP_RADIUS + OUTLINE_WIDTH)


# The cap and its outline pulse, so the key redraws every frame while it shows.
func _process(_delta: float) -> void:
	if _is_ready() and not Settings.reduce_motion:
		queue_redraw()


func _draw() -> void:
	var face := _draw_cap()
	if _is_ready():
		# Round the whole cap, its side too, in the well's gap.
		var cap := Rect2(WELL_PAD, WELL_PAD, face.size.x, CAP_HEIGHT + RAISE)
		_outline.border_color = Color(OUTLINE_COLOR, lerpf(OUTLINE_DIM, OUTLINE_BRIGHT, _pulse()))
		_outline.draw(get_canvas_item(), cap.grow(OUTLINE_WIDTH))
	var fill := maxf(charge, warmth)
	if fill > 0.0:
		RoundedFill.draw(self, face, CAP_RADIUS, fill, CHARGE_COLOR)
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var label := "Stop" if stop else "Frameshift"
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := face.get_center().x - text_width * 0.5
	var ink := Color(TEXT_COLOR, 0.4) if disabled else TEXT_COLOR
	var baseline := (
		face.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	draw_string(font, Vector2(left, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Pops the key up as if let go, while the pointer still holds it, so its release does
## nothing more. Disabling a button is the only way to drop its press.
func release() -> void:
	if not is_pressed():
		return
	var was_disabled := disabled
	disabled = true
	disabled = was_disabled
	queue_redraw()


func _is_down() -> bool:
	return is_pressed() or charge > 0.0


# Whether the key waits to be held: a course is set and the drive hasn't started to charge.
func _is_ready() -> bool:
	return not disabled and not stop and charge <= 0.0


# How far through its pulse the ready key is, from 0 to 1 and back. Reduce motion holds it.
func _pulse() -> float:
	if Settings.reduce_motion:
		return 1.0
	return 0.5 - 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU / PULSE_SECONDS)


func _side_color() -> Color:
	return STOP_SIDE_COLOR if stop else SIDE_COLOR


func _face_color(down: bool) -> Color:
	if stop:
		return STOP_PRESSED_COLOR if down else STOP_FACE_COLOR
	if disabled or down:
		return FACE_COLOR
	var face := FACE_RAISED_COLOR if is_hovered() else FACE_COLOR
	return face.lightened(PULSE_LIGHTEN * _pulse()) if _is_ready() else face
