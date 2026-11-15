class_name ChangeChip
extends PanelContainer
## A change to one of the resource bar's numbers ("+15", "-12"): a solid dark chip with a
## thin border in the change's colour, hanging just under the pill, centred under its
## [member target]. It slides out from under the pill as it shows, dips when its number
## changes, and slides back in as it leaves. It sits on whole pixels and nothing scales, so
## its digits stay sharp. Under Reduce motion it only fades. It takes no room in the bar.

## The colours of a gain and of a loss.
const GAIN_COLOR := Color(0.55, 0.85, 0.4)
const LOSS_COLOR := Color(0.95, 0.3, 0.4)
## Seconds the chips of a stop stay once it is over, before they leave together. Each of
## the resource bar's counters waits this long from its commit.
const HOLD_SECONDS := 0.6
## Seconds a spending's chips stay, so the credits and the points of one bill leave together.
const SPENT_SECONDS := 1.2
## How far under its row's bottom edge it rests, in pixels: the pill's padding and edge,
## then 4 px clear of it.
const DROP := 11.0
## How far up, under the pill, it slides in from and out to, in pixels, and the seconds
## each takes.
const SLIDE_PIXELS := 6.0
const IN_SECONDS := 0.15
const OUT_SECONDS := 0.15
## How far it dips when its number changes, in pixels, and the seconds down and back.
const DIP_PIXELS := 2.0
const DIP_SECONDS := 0.12
## The room between it and the chip it sits [member beside], in pixels.
const GAP := 4.0
## How strongly its border shows the change's colour.
const BORDER_ALPHA := 0.4

## What it hangs under, centred.
var target: Control
## What its height is measured from, when its target is shorter than the bar's row: a
## number is, and its chip would hang higher than its neighbours'.
var row: Control
## While this one shows, it sits to its left instead, so that one stays put and neither
## reaches under the next number.
var beside: ChangeChip

# How far down from its resting place it is, in pixels: negative while under the pill.
var _offset := 0.0
# Whether it shows a change, and isn't on its way out.
var _showing := false
# The slide, the dip or the fade under way.
var _move: Tween
var _style: StyleBoxFlat


func _ready() -> void:
	_style = get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override(&"panel", _style)
	set_process(false)


func _process(_delta: float) -> void:
	_place()


## Shows [param text] in [param color]. Hidden, it slides out from under the pill while
## fading in; already showing, it dips and comes back.
func show_change(text: String, color: Color) -> void:
	var label := %Label as Label
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	_style.border_color = Color(color, BORDER_ALPHA)
	var dip := _showing
	_showing = true
	if _move:
		_move.kill()
	if not visible:
		_offset = -SLIDE_PIXELS
		show()
		set_process(true)
	_move = create_tween()
	if dip and not Settings.reduce_motion:
		modulate.a = 1.0
		_move.tween_method(_set_offset, _offset, DIP_PIXELS, DIP_SECONDS * 0.5)
		(
			_move
			. tween_method(_set_offset, DIP_PIXELS, 0.0, DIP_SECONDS * 0.5)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		_move.tween_property(self, ^"modulate:a", 1.0, IN_SECONDS)
		if Settings.reduce_motion:
			_offset = 0.0
		else:
			(
				_move
				. parallel()
				. tween_method(_set_offset, _offset, 0.0, IN_SECONDS)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_OUT)
			)
	_place()


## Slides it back up under the pill while it fades out. Nothing happens unless it shows.
func leave() -> void:
	if not _showing:
		return
	_showing = false
	if _move:
		_move.kill()
	_move = create_tween().set_parallel()
	_move.tween_property(self, ^"modulate:a", 0.0, OUT_SECONDS)
	if not Settings.reduce_motion:
		(
			_move
			. tween_method(_set_offset, _offset, -SLIDE_PIXELS, OUT_SECONDS)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
		)
	_move.chain().tween_callback(hide_now)


## Hides it at once.
func hide_now() -> void:
	if _move:
		_move.kill()
	_showing = false
	modulate.a = 0.0
	hide()
	set_process(false)


## Whether it shows a change and isn't on its way out.
func is_showing() -> bool:
	return _showing


func _set_offset(value: float) -> void:
	_offset = value
	_place()


# Under the middle of its target, or left of the chip it sits beside while that one
# shows, on whole pixels.
func _place() -> void:
	if not target:
		return
	reset_size()
	var under := target.get_global_rect()
	var x := under.position.x + (under.size.x - size.x) * 0.5
	if beside and beside.is_showing():
		x = beside.global_position.x - GAP - size.x
	var bottom := row.get_global_rect().end.y if row else under.end.y
	global_position = Vector2(x, bottom + DROP + _offset).round()
