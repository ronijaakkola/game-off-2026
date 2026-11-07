class_name CreditsCounter
extends MarginContainer
## The player's credits in the top right corner. A payment counts the total up to its new
## value and shows what was paid just under it ("+15"), which fades in, stays a moment and
## fades out. Payments that come while it shows add up in it, so a stop where several
## passengers get off reads as one sum growing.

## Seconds the total takes to count up to a payment.
const COUNT_SECONDS := 0.4
const FADE_IN_SECONDS := 0.15
## Seconds the gain stays after the last payment before it fades out.
const HOLD_SECONDS := 1.2
const FADE_OUT_SECONDS := 0.5

## The credits the player has. Setting it shows it at once, with no gain.
var credits := 0:
	set(value):
		credits = value
		if _count:
			_count.kill()
		_show_total(credits)

# The total as it shows while counting up.
var _shown := 0
# What the gain shows: the payments since it last faded out.
var _gain := 0
var _count: Tween
var _fade: Tween


func _ready() -> void:
	(%GainLabel as Label).modulate.a = 0.0
	_show_total(credits)


## Adds [param amount] to [member credits], counts the total up to it and shows the gain.
func add(amount: int) -> void:
	var from := _shown
	credits += amount
	_show_total(from)
	_count = create_tween()
	_count.tween_method(_show_total, from, credits, COUNT_SECONDS)
	_show_gain(amount)


func _show_gain(amount: int) -> void:
	var label := %GainLabel as Label
	if label.modulate.a == 0.0:
		_gain = 0
	_gain += amount
	label.text = "+%d" % _gain
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(label, ^"modulate:a", 1.0, FADE_IN_SECONDS)
	_fade.tween_interval(HOLD_SECONDS)
	_fade.tween_property(label, ^"modulate:a", 0.0, FADE_OUT_SECONDS)


func _show_total(value: int) -> void:
	_shown = value
	(%TotalLabel as Label).text = "%d credits" % value
