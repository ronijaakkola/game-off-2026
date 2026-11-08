class_name RatingCounter
extends HBoxContainer
## The player's average rating, beside the credits in the top right: a star and the mean
## of every rating passengers gave on getting off, to one decimal, or a dash before the
## first. With each new rating the number pops bigger for a moment.

## What shows before anyone has rated a ride.
const NO_RATING := "–"
## How much bigger the number pops with each rating, and the seconds up and back down.
const POP_SCALE := 1.3
const POP_UP_SECONDS := 0.06
const POP_DOWN_SECONDS := 0.14

var _total := 0.0
var _count := 0
var _pop: Tween


func _ready() -> void:
	_show()


## Adds a rating of [param stars], from 0 to [constant Passenger.MAX_STARS], to the average
## and pops the number.
func add(stars: float) -> void:
	_total += clampf(stars, 0.0, Passenger.MAX_STARS)
	_count += 1
	_show()
	var label := %AverageLabel as Label
	label.pivot_offset = label.size * 0.5
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


## The mean of every rating so far, from 0 to [constant Passenger.MAX_STARS]. 0 before the
## first; [method get_count] tells the two apart.
func get_average() -> float:
	return _total / _count if _count > 0 else 0.0


## How many rides have been rated.
func get_count() -> int:
	return _count


func _show() -> void:
	var label := %AverageLabel as Label
	label.text = "%.1f" % get_average() if _count > 0 else NO_RATING
