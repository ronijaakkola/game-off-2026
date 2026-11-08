class_name Passenger
extends RefCounted
## One passenger and the small simulation of their ride: patience that runs down, what they
## are doing, and the needs they ask to have served. The [Cabin] ticks every passenger on
## board; the card only reads them.

enum Mood { HAPPY, OKAY, ANNOYED, FURIOUS }

## What each mood pays, as a multiple of the fare.
const PAY: Dictionary[Mood, float] = {
	Mood.HAPPY: 1.2,
	Mood.OKAY: 1.0,
	Mood.ANNOYED: 0.5,
	Mood.FURIOUS: 0.0,
}
## The stars each mood rates the ride, out of [constant MAX_STARS].
const STARS: Dictionary[Mood, float] = {
	Mood.HAPPY: 5.0,
	Mood.OKAY: 4.0,
	Mood.ANNOYED: 2.0,
	Mood.FURIOUS: 0.0,
}
const MAX_STARS := 5.0
## Patience runs down this much slower while the bus is docked.
const DOCKED_DRAIN := 0.5
## How long an idle line shows before the next one, in seconds.
const IDLE_MIN := 6.0
const IDLE_MAX := 14.0
## The line they show on boarding, and for how long, in seconds.
const BOARDING_LINE := "Finding their seat..."
const BOARDING_SECONDS := 3.0

var name: String
var type: PassengerType
## The planet they boarded at, or null when not known.
var origin: Planet
var destination: Planet
var fare: float
## Patience at boarding, in seconds of riding.
var patience_max: float
var patience: float
## The card's line: what they are doing now.
var activity := ""
## The need they are asking for, or null.
var request: Need
## Whether they are asleep: their activity is one of the type's sleep lines. A request
## wakes them.
var asleep := false
## What they look like in their portrait.
var look: AlienLook

var _rng: RandomNumberGenerator
# Seconds left of the current activity line.
var _activity_left := 0.0
# Whether the current activity is a served need, which no new request interrupts.
var _busy := false
# Seconds until each need in type.needs asks again.
var _need_timers := PackedFloat32Array()
# Whether the bus has left the planet they boarded at. Patience holds until it has.
var _departed := false


## A passenger of [param kind] going to [param to]. Their patience starts at
## [param trip_seconds], the direct trip time, times the type's slack, and their fare at
## [param base_fare] times the type's multiplier. [param rng] picks the name, the lines,
## the timers and the look; pass a seeded one for a repeatable ride.
func _init(
	kind: PassengerType,
	to: Planet,
	trip_seconds: float,
	base_fare: float,
	rng: RandomNumberGenerator = null
) -> void:
	type = kind
	destination = to
	_rng = rng if rng else RandomNumberGenerator.new()
	name = _pick(type.names)
	fare = base_fare * type.fare_multiplier
	patience_max = trip_seconds * type.patience_slack
	patience = patience_max
	for need: Need in type.needs:
		_need_timers.append(_interval(need))
	activity = BOARDING_LINE
	_activity_left = BOARDING_SECONDS
	look = AlienLook.random(_rng)


## The mood for [param fraction] of patience left: happy at 60 % or more, okay at 30 % or
## more, annoyed above 0, furious at 0.
static func mood_for(fraction: float) -> Mood:
	if fraction >= 0.6:
		return Mood.HAPPY
	if fraction >= 0.3:
		return Mood.OKAY
	if fraction > 0.0:
		return Mood.ANNOYED
	return Mood.FURIOUS


func get_patience_fraction() -> float:
	return patience / patience_max if patience_max > 0.0 else 0.0


func get_mood() -> Mood:
	return mood_for(get_patience_fraction())


## The credits they pay on getting off now, by their mood.
func get_payout() -> int:
	return roundi(fare * PAY[get_mood()])


## The stars they rate the ride on getting off now, from 0 to [constant MAX_STARS]. For
## now only their mood counts.
func get_rating() -> float:
	return STARS[get_mood()]


## The bus has left the planet they boarded at, so their patience starts running down.
func depart() -> void:
	_departed = true


## Runs [param delta] seconds of the ride. Patience holds until [method depart], and while
## [param patience_holds]. Otherwise it runs down at half speed while [param docked], and
## faster while a request is open.
func tick(delta: float, docked: bool, patience_holds := false) -> void:
	if _departed and not patience_holds:
		var drain := delta
		if docked:
			drain *= DOCKED_DRAIN
		if request:
			drain *= request.unmet_drain
		patience = maxf(patience - drain, 0.0)
	if request:
		return
	_activity_left -= delta
	for i: int in _need_timers.size():
		_need_timers[i] -= delta
	if _busy and _activity_left > 0.0:
		return
	_busy = false
	for i: int in _need_timers.size():
		if _need_timers[i] <= 0.0:
			_open(type.needs[i])
			return
	if _activity_left <= 0.0:
		_idle()


## The player serves the open request. Does nothing when none is open.
func serve() -> void:
	if request:
		_close(request.served_line, request.served_seconds)


## [param amenity] serves the open request, with its own line. Does nothing when none is
## open.
func serve_with(amenity: Amenity) -> void:
	if request:
		_close(amenity.line, amenity.seconds)


func _open(need: Need) -> void:
	request = need
	asleep = false
	activity = need.request_line


func _close(line: String, seconds: float) -> void:
	# The next request waits its interval from when this activity ends. A request that
	# isn't one of the type's needs has no timer to reset.
	var index := type.needs.find(request)
	if index >= 0:
		_need_timers[index] = seconds + _interval(request)
	request = null
	asleep = false
	activity = line
	_activity_left = seconds
	_busy = true


func _idle() -> void:
	var lines := type.idle_lines + type.sleep_lines
	var index := _rng.randi_range(0, lines.size() - 1) if not lines.is_empty() else -1
	activity = lines[index] if index >= 0 else ""
	asleep = index >= type.idle_lines.size()
	_activity_left = _rng.randf_range(IDLE_MIN, IDLE_MAX)


func _interval(need: Need) -> float:
	return _rng.randf_range(need.min_interval, maxf(need.min_interval, need.max_interval))


func _pick(lines: Array[String]) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)] if not lines.is_empty() else ""
