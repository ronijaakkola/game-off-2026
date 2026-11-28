class_name CreatorGuest
extends Node
## Sami's photo on the credits screen, and Henna in it: alone, Sami bobs to the music. Now
## and then she squeezes in from the right as Sami shuffles over to make room, stays a few
## seconds and slips out again. Under Reduce motion nothing bobs or slides, and she is there
## or gone.

## How far in she is now, from 0 out of sight to 1 beside Sami.
signal moved(here: float)
## How joyful both look from now: beaming while she is there.
signal mood_changed(joy: float)

## Seconds before her first visit and between visits, from and to.
const FIRST_WAIT := Vector2(3.0, 6.0)
const WAIT := Vector2(9.0, 18.0)
const STAY_SECONDS := 4.0
## The least she stays after a tap on the photo, in seconds.
const TAPPED_STAY_SECONDS := 2.5
const SLIDE_IN_SECONDS := 0.5
const SLIDE_OUT_SECONDS := 0.35
## Where they end up, in photo widths from where Sami sits alone: Sami to the left, and her
## from out of sight at the right to butting in beside them, over their headphones. Each
## leans toward their left, in radians.
const HOST_SHIFT := -0.2
const HOST_LEAN := 0.05
const GUEST_OUT := 0.95
const GUEST_IN := 0.27
const GUEST_LEAN := 0.16
## How far in front of Sami she is, in world units, so the two heads never cut into each
## other. The camera is orthographic, so it doesn't change her size.
const GUEST_FORWARD := 1.2
## How far Sami dips on each beat of the music while alone, in photo widths.
const BOB := 0.035

var _host: AlienPortrait
var _guest: AlienPortrait
var _host_rest := Vector3.ZERO
var _inside := false
# How far in she is, from 0 out of sight to 1 beside Sami.
var _here := 0.0
var _wait := 0.0
# Keeps the music's tempo for the bob while no music plays.
var _time := 0.0


## Takes [param host], Sami's portrait, and [param guest], hers, both in place and dressed.
func setup(host: AlienPortrait, guest: AlienPortrait) -> void:
	_host = host
	_guest = guest
	_host_rest = host.position
	leave()


## Puts her out of sight at once, with her first visit ahead again.
func leave() -> void:
	_inside = false
	_here = 0.0
	_wait = randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	_set_mood()
	_place()


## Has her start squeezing in now.
func visit() -> void:
	if not _inside:
		_wait = 0.0


## Has her stay a moment longer if she is there, as after a tap on the photo.
func linger() -> void:
	if _inside:
		_wait = maxf(_wait, TAPPED_STAY_SECONDS)


## Whether a tap [param across] the photo, from 0 at its left edge to 1 at its right, is on
## her: she has the right half once she is mostly in.
func is_guest_at(across: float) -> bool:
	return _here > 0.5 and across > 0.5


func _process(delta: float) -> void:
	if not _host:
		return
	_time += delta
	_wait -= delta
	if _wait <= 0.0:
		_inside = not _inside
		_wait = STAY_SECONDS if _inside else randf_range(WAIT.x, WAIT.y)
		_set_mood()
	var target := 1.0 if _inside else 0.0
	if Settings.reduce_motion:
		_here = target
	else:
		var seconds := SLIDE_IN_SECONDS if _inside else SLIDE_OUT_SECONDS
		_here = move_toward(_here, target, delta / seconds)
	_place()


# Both beam while she is there.
func _set_mood() -> void:
	mood_changed.emit(1.0 if _inside else 0.0)


func _place() -> void:
	# In with a small overshoot, as she bumps Sami over, and out smoothly. She only turns
	# back once she has arrived or gone, so the two curves never meet part way.
	var way := Tween.TRANS_BACK if _inside else Tween.TRANS_SINE
	var ease_type := Tween.EASE_OUT if _inside else Tween.EASE_IN_OUT
	var at: float = Tween.interpolate_value(0.0, 1.0, _here, 1.0, way, ease_type)
	var width := PortraitStudio.SLOT
	var shift := Vector3.RIGHT * HOST_SHIFT * width * at
	_host.position = _host_rest + shift + Vector3.DOWN * _get_bob() * width
	_host.rotation.z = HOST_LEAN * at
	var beside := lerpf(GUEST_OUT, GUEST_IN, at) * width
	_guest.position = _host_rest + Vector3(beside, 0.0, GUEST_FORWARD)
	_guest.rotation.z = GUEST_LEAN * at
	_guest.visible = _here > 0.0
	moved.emit(_here)


# How far Sami dips now, in photo widths: lowest right on the music's beat, easing into it
# and off it, and nearly still half way between. It dies away as she comes in. Only ever
# down, so the bust's base stays under the photo's edge.
func _get_bob() -> float:
	if Settings.reduce_motion:
		return 0.0
	var beat := 60.0 / Audio.MUSIC_BPM
	var to_beat := Audio.seconds_to_beat()
	var into := 1.0 - to_beat / beat if to_beat > 0.0 else fposmod(_time / beat, 1.0)
	return pow(0.5 + 0.5 * cos(into * TAU), 2.0) * BOB * (1.0 - _here)
