class_name FeltPush
extends RefCounted
## The push someone on board the bus feels as it speeds up, brakes and turns: the opposite
## of its acceleration, in its own frame, smoothed and capped.

## How fast the push follows the acceleration, per second, so a sudden change, such as
## cancelling a course mid-turn, comes on over a moment.
const SMOOTHING := 12.0
## The strongest push felt, in units per second squared, so nothing throws the passengers.
## Braking and turning at full rate stay under it.
const MAX := 3.5

var _velocity := Vector3.ZERO
var _felt := Vector2.ZERO


## The push in units per second squared: +x toward the bus's right, +y forward.
func get_value() -> Vector2:
	return _felt


## Feels the bus moving at [param velocity] on the orbit plane, facing [param forward],
## [param delta] seconds after last time.
func feel(velocity: Vector3, forward: Vector3, delta: float) -> void:
	var push := (_velocity - velocity) / delta if delta > 0.0 else Vector3.ZERO
	_velocity = velocity
	var felt := Vector2(push.dot(forward.cross(Vector3.UP)), push.dot(forward))
	_felt = _felt.lerp(felt, 1.0 - exp(-SMOOTHING * delta)).limit_length(MAX)
