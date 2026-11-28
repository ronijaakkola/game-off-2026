class_name SlideSlot
extends Control
## A slot in a column for one child, which it brings in and takes out as the notices do,
## so the column grows and shrinks without a jump. Closed, it takes no room.
## [method open] grows the slot to the child's height over [constant GAP_SECONDS] while the
## child rises [constant RISE] pixels into place and fades in over
## [constant ENTER_SECONDS]. [method close] fades the child out, sinking, over
## [constant EXIT_SECONDS], then shrinks the slot away and says [signal closed].
## [member sideways], the child slides in from past the slot's right edge and back out
## instead, without fading, as the dock panel's rows do.
## Under Reduce motion the child only fades, and the slot changes height at once.
## It cuts the child off at its edges only while it moves, so at rest what sticks out of
## the child, such as a rating goal's target mark, still shows.
## Add the child before the slot enters the tree. The slot is as wide as its column makes
## it, and as tall as the child's minimum height times how far open it is.

## It has closed, all the way.
signal closed

## Seconds for the child to rise in, and to fade out.
const ENTER_SECONDS := 0.3
const EXIT_SECONDS := 0.18
## Seconds for the child to slide in sideways, and back out, as the dock panel's rows do.
const SIDE_ENTER_SECONDS := 0.35
const SIDE_EXIT_SECONDS := 0.25
## Seconds for the slot to grow to the child's height, and to shrink away.
const GAP_SECONDS := 0.25
## How far under its place the child starts and ends, in pixels.
const RISE := 8.0

## Whether the child slides in from past the right edge and back out, rather than rising
## in and fading.
@export var sideways := false

# From 0, closed, to 1, as tall as the child.
var _open := 0.0
# Whether it is open or opening, rather than closed or closing.
var _wanted := false
# How far under its place the child sits, in pixels, and how far right of it.
var _sunk := 0.0
var _shifted := 0.0
var _motion: Tween
var _gap: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	var content := _content()
	if content:
		content.minimum_size_changed.connect(_fit)
		content.modulate.a = 1.0 if _wanted else 0.0
	visible = _wanted
	_fit()


## Whether it is open or opening.
func is_open() -> bool:
	return _wanted


## Opens it. Without [param animated], it is open at once.
func open(animated := true) -> void:
	if _wanted:
		return
	_wanted = true
	visible = true
	var content := _content()
	_kill_tweens()
	var still := Settings.reduce_motion
	if not animated or not content or not is_inside_tree():
		_open = 1.0
		_sunk = 0.0
		_shifted = 0.0
		if content:
			content.modulate.a = 1.0
		_fit()
		return
	if sideways and not still:
		content.modulate.a = 1.0
		_shifted = _width()
		_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_gap.tween_method(_set_open, _open, 1.0, GAP_SECONDS)
		_motion = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_motion.tween_method(_set_shifted, _shifted, 0.0, SIDE_ENTER_SECONDS)
		return
	if still:
		_set_open(1.0)
	else:
		_sunk = RISE
		_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_gap.tween_method(_set_open, _open, 1.0, GAP_SECONDS)
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_motion.tween_property(content, ^"modulate:a", 1.0, ENTER_SECONDS)
	_motion.tween_method(_set_sunk, _sunk, 0.0, ENTER_SECONDS)


## Closes it, from wherever it is, then says [signal closed]. Without [param animated], it
## is closed at once.
func close(animated := true) -> void:
	if not _wanted:
		return
	_wanted = false
	var content := _content()
	_kill_tweens()
	if not animated or not content or not is_inside_tree():
		_finish_closing()
		return
	var still := Settings.reduce_motion
	if sideways and not still:
		_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion.tween_method(_set_shifted, _shifted, _width(), SIDE_EXIT_SECONDS)
		_motion.tween_callback(_close_gap.bind(false))
		return
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(content, ^"modulate:a", 0.0, EXIT_SECONDS)
	if not still:
		_motion.tween_method(_set_sunk, _sunk, RISE * 0.75, EXIT_SECONDS)
	_motion.chain().tween_callback(_close_gap.bind(still))


func _close_gap(still: bool) -> void:
	if still:
		_finish_closing()
		return
	_gap = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_gap.tween_method(_set_open, _open, 0.0, GAP_SECONDS)
	_gap.tween_callback(_finish_closing)


func _finish_closing() -> void:
	_open = 0.0
	visible = false
	_fit()
	closed.emit()


func _kill_tweens() -> void:
	for tween: Tween in [_motion, _gap]:
		if tween:
			tween.kill()


func _set_open(open_share: float) -> void:
	_open = open_share
	_fit()


func _set_sunk(pixels: float) -> void:
	_sunk = pixels
	_fit()


func _set_shifted(pixels: float) -> void:
	_shifted = pixels
	_fit()


# Far enough right for the child to be past the slot's edge, which cuts it off.
func _width() -> float:
	var content := _content()
	return maxf(size.x, content.get_combined_minimum_size().x if content else 0.0)


func _content() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


# Sizes the slot to the child, by how far open it is, and lays the child out in it at its
# full height, so opening uncovers it rather than squeezing it.
func _fit() -> void:
	var content := _content()
	if not content:
		return
	var wanted := content.get_combined_minimum_size()
	custom_minimum_size = Vector2(wanted.x, wanted.y * _open)
	content.position = Vector2(_shifted, _sunk)
	clip_contents = _open < 1.0 or _sunk != 0.0 or _shifted != 0.0
	content.size = Vector2(maxf(size.x, wanted.x), wanted.y)
