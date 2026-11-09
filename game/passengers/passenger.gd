class_name Passenger
extends RefCounted
## One passenger and the small simulation of their ride: their happiness, what they are
## doing, and the needs they ask to have served. The [Cabin] ticks every passenger on
## board; the card only reads them.
## Happiness slides toward a target: [constant BASE_HAPPINESS], plus the bus's [Comfort]
## bonus, plus their timing (how their ride compares with the trip time), or 0 while a
## request is open. It falls fast and climbs back slowly. A [method shock] changes it at
## once.

enum Mood { HAPPY, OKAY, ANNOYED, FURIOUS }

## What each mood pays, as a multiple of the fare.
const PAY: Dictionary[Mood, float] = {
	Mood.HAPPY: 1.2,
	Mood.OKAY: 1.0,
	Mood.ANNOYED: 0.5,
	Mood.FURIOUS: 0.0,
}
const MAX_STARS := 5.0
## Happiness runs from 0 to this.
const MAX_HAPPINESS := 100.0
## The happiness a bus that does its job settles them at, and where they start.
const BASE_HAPPINESS := 60.0
## How fast happiness falls toward a lower target, and climbs toward a higher one, a second.
const FALL_RATE := 3.0
const CLIMB_RATE := 1.0
## Timing's bonus while the ride takes no longer than the direct trip.
const ON_TIME_BONUS := 12.0
## Where timing ends up, one more trip time after the expected time: low enough that
## everyone reaches 0, however comfortable the bus.
const WORN_OUT := -100.0
## What being woken by a shock adds to it.
const WAKE_SHOCK := -10.0
## Their ride clock runs this much slower while the bus is docked.
const DOCKED_CLOCK := 0.5
## How long an idle line shows before the next one, in seconds.
const IDLE_MIN := 6.0
const IDLE_MAX := 14.0
## The line they show on boarding, and for how long, in seconds.
const BOARDING_LINE := "Finding their seat..."
const BOARDING_SECONDS := 3.0

# What a tick with no comfort given uses: a bare bus.
static var _no_comfort := Comfort.new()

var name: String
var type: PassengerType
## The planet they boarded at, or null when not known.
var origin: Planet
var destination: Planet
var fare: float
## How content they are, from 0 to [constant MAX_HAPPINESS].
var happiness := BASE_HAPPINESS
## The direct trip time, and the time they expect the ride to take, the trip with the
## type's slack, in seconds of their ride clock.
var trip_seconds: float
var expected_seconds: float
## The card's line: what they are doing now.
var activity := ""
## The need they are asking for, or null.
var request: Need
## Whether they are asleep: their activity is one of the type's sleep lines. Only a bus
## with somewhere to sleep ([Comfort]) lets them, and a sleep runs its length unless a
## [method shock] wakes them.
var asleep := false
## Their race: their skin colour, and the research point delivering them earns.
var race: Race.Type
## What their portrait acts out: eating or drinking while a served need lasts.
var action := Need.Action.NONE
## What they look like in their portrait.
var look: AlienLook

var _rng: RandomNumberGenerator
# Seconds left of the current activity line.
var _activity_left := 0.0
# Whether the current activity is a served need, which no new request interrupts.
var _busy := false
# Seconds until each need in type.needs asks again.
var _need_timers := PackedFloat32Array()
# Whether the bus has left the planet they boarded at. Happiness holds until it has.
var _departed := false
# Seconds of the ride so far, on their clock, which timing reads.
var _clock := 0.0


## A passenger of [param kind] going to [param to]. [param trip_seconds] is the direct
## trip time, which the type's slack stretches into the time they expect, and their fare
## is [param base_fare] times the type's multiplier. [param rng] picks the name, the lines,
## the timers, the race and the look; pass a seeded one for a repeatable ride.
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
	self.trip_seconds = trip_seconds
	expected_seconds = trip_seconds * type.slack
	for need: Need in type.needs:
		_need_timers.append(_interval(need))
	activity = BOARDING_LINE
	_activity_left = BOARDING_SECONDS
	race = Race.random(_rng)
	look = AlienLook.random(_rng, race)


## The mood for [param value] of happiness: happy at 70 or more, okay at 50 or more,
## annoyed at 25 or more, furious below.
static func mood_for(value: float) -> Mood:
	if value >= 70.0:
		return Mood.HAPPY
	if value >= 50.0:
		return Mood.OKAY
	if value >= 25.0:
		return Mood.ANNOYED
	return Mood.FURIOUS


## Their happiness as a fraction of [constant MAX_HAPPINESS], for a bar.
func get_happiness_fraction() -> float:
	return happiness / MAX_HAPPINESS


func get_mood() -> Mood:
	return mood_for(happiness)


## The credits they pay on getting off now, by their mood.
func get_payout() -> int:
	return roundi(fare * PAY[get_mood()])


## The stars they rate the ride on getting off now, from 0 to [constant MAX_STARS]: their
## happiness in fifths, to the nearest whole star.
func get_rating() -> float:
	return clampf(roundf(happiness / MAX_HAPPINESS * MAX_STARS), 0.0, MAX_STARS)


## What their ride's timing adds to the happiness they settle at, now: [constant
## ON_TIME_BONUS] up to the direct trip time, falling to 0 at the expected time, then on
## to [constant WORN_OUT] one more trip time after that.
func get_timing() -> float:
	if _clock <= trip_seconds:
		return ON_TIME_BONUS
	if _clock < expected_seconds:
		return lerpf(ON_TIME_BONUS, 0.0, inverse_lerp(trip_seconds, expected_seconds, _clock))
	var worn := expected_seconds + trip_seconds
	if _clock >= worn:
		return WORN_OUT
	return lerpf(0.0, WORN_OUT, inverse_lerp(expected_seconds, worn, _clock))


## The happiness they slide toward now, with the bus giving [param comfort]: 0 while a
## request is open. Comfort lifts it no higher than [constant MAX_HAPPINESS] before timing,
## so a worn-out ride brings anyone to 0.
func get_target(comfort: Comfort = null) -> float:
	if request:
		return 0.0
	var bonus := comfort.bonus if comfort else 0.0
	var settled := minf(BASE_HAPPINESS + bonus, MAX_HAPPINESS)
	return clampf(settled + get_timing(), 0.0, MAX_HAPPINESS)


## Changes their happiness by [param amount] at once, as a scare does, leaving the target
## alone, so it slides back from there. It wakes them if they sleep, which costs
## [constant WAKE_SHOCK] more.
func shock(amount: float) -> void:
	if asleep:
		amount += WAKE_SHOCK
		asleep = false
		_activity_left = 0.0
	happiness = clampf(happiness + amount, 0.0, MAX_HAPPINESS)


## The bus has left the planet they boarded at, so their ride, and their happiness, start.
func depart() -> void:
	_departed = true


## Runs [param delta] seconds of the ride, on a bus giving [param comfort]. Happiness and
## the ride clock hold until [method depart], and while [param holds]. The clock runs at
## half speed while [param docked], and as the comfort says while awake or asleep. Needs
## wait while they sleep, so a sleep runs its length.
func tick(delta: float, docked: bool, holds := false, comfort: Comfort = null) -> void:
	var giving := comfort if comfort else _no_comfort
	if _departed and not holds:
		var rate := giving.sleep_clock if asleep else giving.clock
		_clock += delta * rate * (DOCKED_CLOCK if docked else 1.0)
		var target := get_target(giving)
		var speed := FALL_RATE if target < happiness else CLIMB_RATE
		happiness = move_toward(happiness, target, speed * delta)
	if request:
		return
	_activity_left -= delta
	if not asleep:
		for i: int in _need_timers.size():
			_need_timers[i] -= delta
	if (_busy or asleep) and _activity_left > 0.0:
		return
	_busy = false
	asleep = false
	action = Need.Action.NONE
	for i: int in _need_timers.size():
		if _need_timers[i] <= 0.0:
			_open(type.needs[i])
			return
	if _activity_left <= 0.0:
		_idle(giving)


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
	action = request.served_action
	request = null
	asleep = false
	activity = line
	_activity_left = seconds
	_busy = true


# A new idle line. Where the bus lets them sleep, a sleep line comes up as often as any
# one idle line, and lasts as long as the comfort's sleeps do.
func _idle(comfort: Comfort) -> void:
	var lines := type.idle_lines.duplicate()
	if comfort.can_sleep():
		lines.append_array(type.sleep_lines)
	var index := _rng.randi_range(0, lines.size() - 1) if not lines.is_empty() else -1
	activity = lines[index] if index >= 0 else ""
	asleep = index >= type.idle_lines.size()
	if asleep:
		_activity_left = _rng.randf_range(comfort.sleep_min, comfort.sleep_max)
	else:
		_activity_left = _rng.randf_range(IDLE_MIN, IDLE_MAX)


func _interval(need: Need) -> float:
	return _rng.randf_range(need.min_interval, maxf(need.min_interval, need.max_interval))


func _pick(lines: Array[String]) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)] if not lines.is_empty() else ""
