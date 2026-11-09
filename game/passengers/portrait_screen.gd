class_name PortraitScreen
extends RefCounted
## What a portrait shows while they watch something: the light of a screen just in front
## of them on their face, cutting from one shot's colour to the next, and now and then a
## laugh. The screen sits where the camera is, so its light falls on what faces the
## camera. The [AlienPortrait] it belongs to adds [member light] to its materials, shows
## [member laugh] as joy, and lifts and tips the head by [member bounce] and [member pitch].

## How fast the screen's light comes up and goes away, per second.
const SHOW_SPEED := 2.0
## How bright the light is on the face, added to its colour.
const STRENGTH := 0.3
## The colours of the shots, one picked at each cut, mostly a TV's cold blue. Each shot
## is also brighter or darker than the last, which reads as a screen more than the hue.
const SHOT_COLORS: Array[Color] = [
	Color(0.3, 0.5, 1.0),
	Color(0.3, 0.5, 1.0),
	Color(0.35, 0.9, 1.0),
	Color(1.0, 0.6, 0.3),
	Color(0.85, 0.35, 1.0),
	Color(0.9, 0.95, 1.0),
]
const SHOT_BRIGHTNESS := Vector2(0.35, 1.2)
## Seconds from one cut to the next: a range. At most about two cuts a second, well under
## the three flashes a second that can set off photosensitive seizures.
const SHOT_SECONDS := Vector2(0.5, 1.6)
## How fast the light blends into the next shot's colour, per second, so a cut is soft.
const CUT_SPEED := 12.0
## How much the light flickers within a shot, as a share of it.
const FLICKER := 0.15
## Seconds a laugh lasts, and the wait between laughs: a range each.
const LAUGH_SECONDS := Vector2(0.9, 1.6)
const LAUGH_WAIT := Vector2(2.0, 5.0)
## Laughing, the head bounces up and down: how fast, and how high, in the model's units.
const LAUGH_SPEED := 18.0
const LAUGH_BOUNCE := 0.035
## Laughing, the head tips back, in radians.
const LAUGH_TIP := 0.1

## Whether they watch something now. The light fades out once they stop.
var watching := false
## Whether they may laugh: not while angry.
var may_laugh := true
## The light the screen throws on the face this frame.
var light := Color.BLACK
## How hard they laugh this frame, from 0 to 1.
var laugh := 0.0
## How far the head lifts and tips forward this frame, for the portrait to add.
var bounce := 0.0
var pitch := 0.0

var _on := 0.0
var _time := 0.0
# The light's colour now, at full strength, and the shot it blends toward.
var _color: Color = SHOT_COLORS[0]
var _shot: Color = SHOT_COLORS[0]
var _cut_in := 0.0
var _laugh_in := randf_range(0.8, 2.5)
var _laugh_left := 0.0
var _laugh_length := 1.0


## Moves the light and the laughs on by [param delta] seconds. With [param motion] 0, as
## under Reduce motion, the light holds one steady colour and a laugh only shows on the
## face.
func advance(delta: float, motion: float) -> void:
	_time += delta
	_on = move_toward(_on, 1.0 if watching else 0.0, delta * SHOW_SPEED)
	_cut_in -= delta
	if _cut_in <= 0.0 and motion > 0.0:
		_shot = SHOT_COLORS[randi() % SHOT_COLORS.size()]
		_shot *= randf_range(SHOT_BRIGHTNESS.x, SHOT_BRIGHTNESS.y)
		_cut_in = randf_range(SHOT_SECONDS.x, SHOT_SECONDS.y)
	_color = _color.lerp(_shot, 1.0 - exp(-CUT_SPEED * delta))
	var flicker := 1.0 + sin(_time * 21.0) * sin(_time * 7.3) * FLICKER * motion
	var strength := ease(_on, -2.0) * STRENGTH * flicker
	light = Color(_color.r * strength, _color.g * strength, _color.b * strength)

	_laugh_left -= delta
	if watching and may_laugh and is_equal_approx(_on, 1.0):
		_laugh_in -= delta
		if _laugh_in <= 0.0:
			_laugh_length = randf_range(LAUGH_SECONDS.x, LAUGH_SECONDS.y)
			_laugh_left = _laugh_length
			_laugh_in = _laugh_length + randf_range(LAUGH_WAIT.x, LAUGH_WAIT.y)
	if not may_laugh or not watching:
		_laugh_left = minf(_laugh_left, 0.0)
	# A laugh bursts out, holds, and trails off over its last third.
	var into := 1.0 - _laugh_left / _laugh_length
	laugh = 0.0
	if _laugh_left > 0.0:
		laugh = smoothstep(0.0, 0.08, into) * (1.0 - smoothstep(0.65, 1.0, into))
	bounce = absf(sin(_time * LAUGH_SPEED)) * LAUGH_BOUNCE * laugh * motion
	pitch = -LAUGH_TIP * laugh * motion
