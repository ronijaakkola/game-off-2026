class_name BusTurning
extends RefCounted
## How the bus turns on the orbit plane: each method takes its heading, the rotation about
## +Y that makes its +Z face a way, and gives the heading a turn of [param delta] seconds
## leaves it at. It keeps how fast the last turn went ([member rate]), which the model
## leans by. [FrameshiftBus] owns one.

## How fast the heading changed in the last turn, in radians a second: positive to the left.
## 0 after [method stop].
var rate := 0.0


## Turns [param heading] toward facing [param direction], at most [param speed] radians a
## second.
func toward(heading: float, direction: Vector3, speed: float, delta: float) -> float:
	var target := atan2(direction.x, direction.z)
	return _turn(heading, rotate_toward(heading, target, speed * delta), delta)


## Turns [param heading] toward [param target], at most [param speed] radians a second,
## easing out by [param ease_rate] as it gets there, as when it swings side-on to dock.
func ease_to(heading: float, target: float, speed: float, ease_rate: float, delta: float) -> float:
	var left := absf(angle_difference(heading, target))
	var step := minf(speed * delta, left * (1.0 - exp(-ease_rate * delta)))
	return _turn(heading, rotate_toward(heading, target, step), delta)


## Holds still: the bus isn't turning, as while it moves with its planet or holds in space.
func stop() -> void:
	rate = 0.0


func _turn(from: float, to: float, delta: float) -> float:
	rate = angle_difference(from, to) / delta if delta > 0.0 else 0.0
	return to
