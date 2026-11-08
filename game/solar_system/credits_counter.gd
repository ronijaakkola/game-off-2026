class_name CreditsCounter
extends MarginContainer
## The player's credits in the top right corner. Payments collect in a gain just under the
## total ("+15"), which pops bigger for a moment and shows the new sum with each payment.
## Once [method commit] is called, after a short delay the total counts up to include it,
## number by number, while the gain fades out drifting upward. [member credits] already
## counts every payment; only what shows waits.

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
## once and clears the gain.
var credits: int:
	get:
		return _credits
	set(value):
		_credits = value
		_pending = 0
		if _fade:
			_fade.kill()
		if is_node_ready():
			(%GainLabel as Label).modulate.a = 0.0
			_show_total(_credits)

var _credits := 0
# Paid since the last commit, so not yet in the total shown.
var _pending := 0
# How far the gain has drifted up, in pixels.
var _rise := 0.0
# The commit: the delay, then the count up, the fade and the drift, together.
var _fade: Tween
var _pop: Tween


func _ready() -> void:
	(%GainLabel as Label).modulate.a = 0.0
	_show_total(_credits)
	_place_gain()


func _process(_delta: float) -> void:
	_place_gain()


## Adds [param amount] to [member credits] and to the gain, which pops with the new sum.
## The total shown waits for [method commit].
func add(amount: int) -> void:
	# A commit still under way finishes at once, so its credits aren't lost from the total.
	if _fade:
		_fade.kill()
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


## Takes [param amount] off [member credits] and off the total shown, at once. A count up
## under way finishes at once first; a gain still waiting for [method commit] stays.
func spend(amount: int) -> void:
	if _fade and _fade.is_running():
		_fade.kill()
		(%GainLabel as Label).modulate.a = 0.0
	_credits -= amount
	_show_total(_credits - _pending)


## Moves the gain into the total: after [constant COMMIT_DELAY], the total counts up one
## credit at a time while the gain fades out drifting upward. Nothing happens without a
## gain.
func commit() -> void:
	if _pending == 0:
		return
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


func _set_rise(value: float) -> void:
	_rise = value
	_place_gain()


# The gain sits right-aligned in its slot, drifted up by _rise, and pops from its centre.
func _place_gain() -> void:
	var label := %GainLabel as Label
	var slot := %GainSlot as Control
	var size_needed := label.get_combined_minimum_size()
	if slot.custom_minimum_size != size_needed:
		slot.custom_minimum_size = size_needed
	label.size = size_needed
	label.position = Vector2(slot.size.x - size_needed.x, -_rise)
	label.pivot_offset = size_needed * 0.5
