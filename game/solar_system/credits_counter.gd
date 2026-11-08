class_name CreditsCounter
extends MarginContainer
## The player's credits in the top right corner. Payments collect in a gain just under the
## total ("+15"), which pops bigger for a moment and shows the new sum with each payment.
## Once [method commit] is called, after a short delay the total counts up to include it,
## number by number, while the gain fades out drifting upward. [member credits] already
## counts every payment; only what shows waits.
## Spending shows the same way, in red ("-12"), at once: it pops, and after a short delay
## the total counts down while it fades out drifting upward. It shows in the gain's place,
## or under the gain while one waits.

## Seconds from [method commit] to the total starting to count up.
const COMMIT_DELAY := 0.25
## Seconds the total takes to count up per credit, and the most it takes in all.
const SECONDS_PER_CREDIT := 0.025
const MAX_COUNT_SECONDS := 1.2
## How much bigger the gain pops with each payment, and the seconds up and back down.
const POP_SCALE := 1.35
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14
## Seconds the gain takes to fade out, and how far up it drifts meanwhile, in pixels.
const FADE_OUT_SECONDS := 0.6
const RISE_PIXELS := 14.0

## The credits the player has, payments not yet shown included. Setting it shows it at
## once and clears the gain and the loss.
var credits: int:
	get:
		return _credits
	set(value):
		_credits = value
		_pending = 0
		if _fade:
			_fade.kill()
		if _loss:
			_loss.kill()
		if is_node_ready():
			(%GainLabel as Label).modulate.a = 0.0
			(%LossLabel as Label).modulate.a = 0.0
			_show_total(_credits)

var _credits := 0
# Paid since the last commit, so not yet in the total shown.
var _pending := 0
# How far the gain has drifted up, in pixels.
var _rise := 0.0
# The commit: the delay, then the count up, the fade and the drift, together.
var _fade: Tween
var _pop: Tween
# How far the loss has drifted up, in pixels.
var _loss_rise := 0.0
# The spending: the pop, the delay, then the count down, the fade and the drift.
var _loss: Tween


func _ready() -> void:
	(%GainLabel as Label).modulate.a = 0.0
	(%LossLabel as Label).modulate.a = 0.0
	_show_total(_credits)
	_place_gain()


func _process(_delta: float) -> void:
	_place_gain()


## Adds [param amount] to [member credits] and to the gain, which pops with the new sum.
## The total shown waits for [method commit].
func add(amount: int) -> void:
	# A commit or a spending still under way finishes at once, so the total stays right.
	if _fade:
		_fade.kill()
	_finish_loss()
	_show_total(_credits - _pending)
	_credits += amount
	_pending += amount
	var label := %GainLabel as Label
	label.text = "+%d" % _pending
	label.modulate.a = 1.0
	_rise = 0.0
	if _pop:
		_pop.kill()
	_pop = create_tween()
	_pop.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_pop
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## Takes [param amount] off [member credits] and shows it in the loss ("-12"), which pops;
## after [constant COMMIT_DELAY] the total counts down to it while the loss fades out
## drifting upward. A count up or down under way finishes at once first; a gain still
## waiting for [method commit] stays.
func spend(amount: int) -> void:
	if _fade and _fade.is_running():
		_fade.kill()
		(%GainLabel as Label).modulate.a = 0.0
	_finish_loss()
	var from := _credits - _pending
	_credits -= amount
	var label := %LossLabel as Label
	label.text = "-%d" % amount
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	_loss_rise = 0.0
	_place_gain()
	var seconds := minf(amount * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_loss = create_tween()
	_loss.tween_property(label, ^"scale", Vector2.ONE * POP_SCALE, POP_UP_SECONDS)
	(
		_loss
		. tween_property(label, ^"scale", Vector2.ONE, POP_DOWN_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_loss.tween_interval(COMMIT_DELAY)
	_loss.tween_method(_show_total, from, _credits - _pending, seconds)
	_loss.parallel().tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
	(
		_loss
		. parallel()
		. tween_method(_set_loss_rise, 0.0, RISE_PIXELS, FADE_OUT_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)


## Moves the gain into the total: after [constant COMMIT_DELAY], the total counts up one
## credit at a time while the gain fades out drifting upward. Nothing happens without a
## gain.
func commit() -> void:
	if _pending == 0:
		return
	_finish_loss()
	var from := _credits - _pending
	var seconds := minf(_pending * SECONDS_PER_CREDIT, MAX_COUNT_SECONDS)
	_pending = 0
	var label := %GainLabel as Label
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_interval(COMMIT_DELAY)
	_fade.tween_method(_show_total, from, _credits, seconds)
	_fade.parallel().tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
	(
		_fade
		. parallel()
		. tween_method(_set_rise, 0.0, RISE_PIXELS, FADE_OUT_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUAD)
	)


func _show_total(value: int) -> void:
	var label := %TotalLabel as Label
	var text := "%d credits" % value
	if label.text != text:
		label.text = text


# Ends a spending under way at once: the total at its new value, the loss gone.
func _finish_loss() -> void:
	if not _loss or not _loss.is_running():
		return
	_loss.kill()
	(%LossLabel as Label).modulate.a = 0.0
	_show_total(_credits - _pending)


func _set_loss_rise(value: float) -> void:
	_loss_rise = value
	_place_gain()


func _set_rise(value: float) -> void:
	_rise = value
	_place_gain()


# The gain sits right-aligned in its slot, drifted up by _rise, and pops from its centre.
# The loss sits the same way in the gain's place, or under the gain while it shows.
func _place_gain() -> void:
	var label := %GainLabel as Label
	var slot := %GainSlot as Control
	var size_needed := label.get_combined_minimum_size()
	if slot.custom_minimum_size != size_needed:
		slot.custom_minimum_size = size_needed
	label.size = size_needed
	label.position = Vector2(slot.size.x - size_needed.x, -_rise)
	label.pivot_offset = size_needed * 0.5
	var loss := %LossLabel as Label
	var loss_size := loss.get_combined_minimum_size()
	loss.size = loss_size
	var below := size_needed.y if label.modulate.a > 0.0 else 0.0
	loss.position = Vector2(slot.size.x - loss_size.x, below - _loss_rise)
	loss.pivot_offset = loss_size * 0.5
