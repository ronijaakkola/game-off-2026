class_name Passenger
extends RefCounted
## One passenger and the small simulation of their ride: their happiness, what they are
## doing, and the needs they ask to have served. The [Cabin] ticks every passenger on
## board; the card only reads them.
## Happiness slides toward a target: [constant BASE_HAPPINESS], plus the bus's [Comfort]
## bonus, plus their timing (how their ride compares with the trip time), less what
## frustration with a late ride or too many stops takes off ([RideProgress]), or 0 while a
## request is open and nobody serves it. They start the ride at that target
## ([method settle]), so a quick ride keeps them there; it falls fast and climbs back
## slowly. A [method shock] changes it at once.
## A request is served over time: the player's hold on the serve button and the bus's food
## amenities [method feed] it, and it closes once full.

## They changed their mind mid-ride and are going somewhere else ([method reroute]).
signal rerouted

enum Mood { HAPPY, OKAY, ANNOYED, FURIOUS }

const MAX_STARS := 5.0
## Happiness runs from 0 to this.
const MAX_HAPPINESS := 100.0
## The happiness a bus that does its job settles them at, before comfort and timing, and
## where they stand until they take a seat.
const BASE_HAPPINESS := 64.0
## How fast happiness falls toward a lower target, and climbs toward a higher one, a second.
const FALL_RATE := 3.0
const CLIMB_RATE := 1.0
## What being woken by a shock adds to it.
const WAKE_SHOCK := -10.0
## The shock of arriving with a request still unserved, once it has been open at least
## [constant REQUEST_GRACE] seconds of flying, so one asked just before arriving is no
## fault of the player's.
const UNSERVED_SHOCK := -10.0
const REQUEST_GRACE := 5.0
## The most quick stops add to what they can reach over one ride.
const QUICK_BONUS_MAX := 6.0
## Seconds of flying a request is open before their happiness starts to fall, so serving
## it at once costs nothing.
const REQUEST_LEEWAY := 1.5
## While the bus is docked, their ride clock and their needs' timers run at this speed, and
## their happiness falls at this much of its speed: a stop barely costs them. Climbing back
## isn't slowed, so a stop is a fine place to recover. The cabin can give a faster one.
const DOCKED_RATE := 0.1
## Seconds a complaint shows on their card: a stop too many, or the ride running late.
const COMPLAINT_SECONDS := 4.0
## The seconds of change [member trend] gives.
const TREND_SECONDS := 10.0
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
## How their happiness is changing, as of the last [method tick]: how much it changes in
## [constant TREND_SECONDS] at the speed it moved then, so positive while it climbs and
## negative while it falls, and larger the faster it goes. 0 while it holds.
var trend := 0.0
## Their ride's timing and the stops on the way, which frustrate them past a point.
var ride: RideProgress
## How much happiness frustration takes off the most they can reach, as of the last
## [method tick]: the part of the bar they can no longer fill.
var frustration := 0.0
## The card's line: what they are doing now.
var activity := ""
## The need they are asking for, or null.
var request: Need
## Added to the happiness they settle at, all ride long, for the time they waited before
## the Station waiting lounge picked them up ([WaitingPassengers]).
var lounge_bonus := 0.0
## What the quick stops on their ride add to the most they can reach, up to
## [constant QUICK_BONUS_MAX] ([method admire]).
var quick_bonus := 0.0
## How much of the open request is served so far, from 0 to 1 ([method feed]).
var serving := 0.0
## Whether they are asleep: their activity is one of the type's sleep lines. Only a bus
## with somewhere to sleep ([Comfort]) lets them, and a sleep runs its length unless a
## [method shock] wakes them.
var asleep := false
## Whether they are watching a show: their activity is one of the type's watch lines,
## which only a bus with an entertainment system ([Comfort]) lets them, and their clock runs
## as the comfort says while they do. A request interrupts it.
var watching := false
## Their race: their skin colour, and the research point delivering them earns.
var race: Race.Type
## What their portrait acts out: eating or drinking while a served need lasts, or watching
## a show.
var action := Need.Action.NONE
## What they look like in their portrait.
var look: AlienLook
## What the quest about them asks, such as "Rush Zib to Frost", or empty while there is
## none. Their portrait wears a flag while it is set. Whoever gives the quest sets it.
var quest_line := ""
## The planet the bus stops at for them, as an errand quest asks, or null. A stop there is
## no stop on the way to them. Whoever gives the quest sets it.
var errand: Planet

var _rng: RandomNumberGenerator
# Seconds left of the current activity line.
var _activity_left := 0.0
# Whether the current activity is a served need, which no new request interrupts.
var _busy := false
# Seconds until each need in type.needs asks again.
var _need_timers := PackedFloat32Array()
# Whether the bus has left the planet they boarded at. Happiness holds until it has.
var _departed := false
# Whether a shock reached them before the bus left, so they no longer start at the target.
var _shaken := false
# A request put on hold while the bus stops, which opens again once it flies on.
var _held_request: Need
# Seconds of flying the open or held request has gone unserved.
var _request_age := 0.0
# Whether something fed the open request since the last tick: while it is being served,
# their happiness holds rather than heading for 0.
var _fed := false


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
	ride = RideProgress.new(trip_seconds, trip_seconds * type.slack, type.stop_tolerance)
	for need: Need in type.needs:
		_need_timers.append(_interval(need))
	activity = BOARDING_LINE
	_activity_left = BOARDING_SECONDS
	race = Race.random(_rng)
	look = AlienLook.random(_rng, race)


## A passenger [method to_save] gave, with their [member type] found by its resource path
## in [param types] and their planets by name in [param planets]. Null when either isn't
## there. What they were doing isn't kept: they start a new idle line, and a request open
## or on hold is put back on hold, as at a stop.
static func from_save(
	saved: Dictionary, types: Dictionary[String, PassengerType], planets: Dictionary[String, Planet]
) -> Passenger:
	var kind: PassengerType = types.get(saved.get("type", ""))
	var to: Planet = planets.get(saved.get("destination", ""))
	if not kind or not to:
		return null
	var passenger := Passenger.new(kind, to, float(saved.get("trip_seconds", 0.0)), 0.0)
	passenger.origin = planets.get(saved.get("origin", ""))
	passenger.name = saved.get("name", passenger.name)
	passenger.fare = float(saved.get("fare", 0.0))
	var ride := passenger.ride
	ride.expected_seconds = float(saved.get("expected_seconds", ride.expected_seconds))
	ride.leeway = float(saved.get("leeway", 0.0))
	ride.clock = float(saved.get("clock", 0.0))
	ride.stops = int(saved.get("stops", 0))
	passenger.race = int(saved.get("race", passenger.race)) as Race.Type
	passenger.look = AlienLook.from_save(saved.get("look", {}), passenger.race)
	passenger.happiness = float(saved.get("happiness", BASE_HAPPINESS))
	passenger.lounge_bonus = float(saved.get("lounge_bonus", 0.0))
	passenger.quick_bonus = float(saved.get("quick_bonus", 0.0))
	passenger.activity = ""
	passenger._activity_left = 0.0
	passenger._departed = bool(saved.get("departed", false))
	passenger._shaken = bool(saved.get("shaken", false))
	var timers: Array = saved.get("need_timers", [])
	for i: int in mini(timers.size(), passenger._need_timers.size()):
		passenger._need_timers[i] = float(timers[i])
	var held := int(saved.get("held_need", -1))
	if held >= 0 and held < kind.needs.size():
		passenger._held_request = kind.needs[held]
		passenger._request_age = float(saved.get("request_age", 0.0))
	return passenger


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


## The credits they pay on getting off now: their fare, and more for a good ride
## ([Payment]). [param tip] is the Tip jar's.
func get_payout(tip := 0.0) -> int:
	return roundi(fare * Payment.multiple(get_rating(), tip))


## Puts off the first request for each of their needs: what is left of each wait to the
## next one is [param scale] times as long. For someone just on board, as Free station
## coffee does.
func delay_requests(scale: float) -> void:
	for i: int in _need_timers.size():
		_need_timers[i] *= scale


## The stars they rate the ride on getting off now, from 0 to [constant MAX_STARS]: their
## happiness in fifths, to the nearest whole star.
func get_rating() -> float:
	return clampf(roundf(happiness / MAX_HAPPINESS * MAX_STARS), 0.0, MAX_STARS)


## The happiness they slide toward now, with the bus giving [param comfort]: the most it
## can give them, less what frustration takes off, or 0 once a request has been open for
## [constant REQUEST_LEEWAY], though
## [method tick] holds them where they are while it is being served. Comfort lifts it no
## higher than [constant MAX_HAPPINESS].
func get_target(comfort: Comfort = null) -> float:
	if request and _request_age >= REQUEST_LEEWAY:
		return 0.0
	var best := _get_best(comfort if comfort else _no_comfort)
	return best - ride.get_lost(best)


## Changes their happiness by [param amount] at once, as a scare does, leaving the target
## alone, so it slides back from there. It wakes them if they sleep, which costs
## [constant WAKE_SHOCK] more.
func shock(amount: float) -> void:
	if asleep:
		amount += WAKE_SHOCK
		asleep = false
		_activity_left = 0.0
	happiness = clampf(happiness + amount, 0.0, MAX_HAPPINESS)
	if not _departed:
		_shaken = true


## They admire a quick stop: [param amount] more happiness at once, and as much more of
## what they can reach for the rest of the ride, up to [constant QUICK_BONUS_MAX] in all.
func admire(amount: float) -> void:
	var gained := minf(amount, QUICK_BONUS_MAX - quick_bonus)
	quick_bonus += gained
	happiness = minf(happiness + gained, MAX_HAPPINESS)


## Puts their happiness at its target on a bus giving [param comfort]: where they start the
## ride, as they take their seat and again as the bus leaves, so comfort added at the stop
## counts. Does nothing once the bus has left, or once a [method shock] has reached them:
## from then on happiness only slides.
func settle(comfort: Comfort = null) -> void:
	if not _departed and not _shaken:
		happiness = get_target(comfort)


## The bus, giving [param comfort], has left the planet they boarded at, so their ride
## starts, with their happiness at its target ([method settle]).
func depart(comfort: Comfort = null) -> void:
	settle(comfort)
	_departed = true


## They change their mind mid-ride and go to [param to] instead: a new trip of
## [param seconds] direct from here, which their timing counts from now with the type's
## slack and no leeway yet. Their fare becomes [param base_fare] times the type's
## multiplier, when that is more than the one they had.
func reroute(to: Planet, seconds: float, base_fare: float) -> void:
	destination = to
	fare = maxf(fare, base_fare * type.fare_multiplier)
	ride.restart(seconds, type.slack)
	rerouted.emit()


## The bus docked at [param planet] on their ride, which isn't where they are going. A stop
## past their type's tolerance frustrates them, and they say so unless busy. The planet
## they boarded at doesn't count before the bus has left it, and nor does their
## [member errand].
func pass_stop(planet: Planet) -> void:
	if planet == errand:
		return
	if _departed and ride.pass_stop(planet, origin, destination):
		_complain(type.stop_lines, COMPLAINT_SECONDS)


## They have reached their destination. A request they have had open, or on hold, for
## [constant REQUEST_GRACE] seconds of flying or more disappoints them
## ([constant UNSERVED_SHOCK]).
func arrive() -> void:
	if (request or _held_request) and _request_age >= REQUEST_GRACE:
		shock(UNSERVED_SHOCK)


## Runs [param delta] seconds of the ride, on a bus giving [param comfort]. A need that
## comes up opens a request only while [param can_ask]. Happiness and
## the ride clock hold until [method depart], and while [param holds] (the bus parks).
## While [param docked] the clock and the needs' timers run, and happiness falls (but not
## climbs), at [param stop_rate] of their speed. The clock runs as the comfort says
## while asleep or watching a show. Needs wait while they sleep, so a sleep runs its
## length, but not while they watch: a request stops the show. While a request is being
## fed, happiness holds. While the bus is docked or parks, no request opens, but one
## already open stays open and can be served. A request saved on hold opens again.
func tick(
	delta: float,
	docked: bool,
	holds := false,
	comfort: Comfort = null,
	stop_rate := DOCKED_RATE,
	can_ask := true
) -> void:
	var giving := comfort if comfort else _no_comfort
	stop_rate = stop_rate if docked else 1.0
	var stopped := docked or holds
	if _held_request:
		request = _held_request
		_held_request = null
		asleep = false
		watching = false
		action = Need.Action.NONE
		activity = request.request_line
	var fed := _fed and request != null
	_fed = false
	trend = 0.0
	if _departed and not holds:
		var rate := 1.0
		if asleep:
			rate = giving.sleep_clock
		elif watching:
			rate = giving.watch_clock
		var was_late := ride.get_late_seconds() > 0.0
		ride.run(delta * rate * stop_rate, happiness)
		if not was_late and ride.get_late_seconds() > 0.0:
			_complain(type.late_lines, COMPLAINT_SECONDS)
		frustration = ride.get_lost(_get_best(giving))
		# A request on its way holds them where they are: they can see it coming.
		var target := happiness if fed else get_target(giving)
		var speed := CLIMB_RATE
		if target < happiness:
			speed = FALL_RATE * stop_rate
		var before := happiness
		happiness = move_toward(happiness, target, speed * delta)
		if delta > 0.0:
			trend = (happiness - before) / delta * TREND_SECONDS
	if request:
		# Parking counts for nothing, so one asked as the bus pulls in is forgiven.
		if _departed and not holds:
			_request_age += delta
		return
	_activity_left -= delta
	if not asleep and not _held_request:
		var need_step := delta * stop_rate
		for i: int in _need_timers.size():
			_need_timers[i] -= need_step
	if (_busy or asleep) and _activity_left > 0.0:
		return
	_busy = false
	asleep = false
	if not watching or _activity_left <= 0.0:
		watching = false
		action = Need.Action.NONE
	if not stopped and not _held_request and can_ask:
		for i: int in _need_timers.size():
			if _need_timers[i] <= 0.0:
				_open(type.needs[i])
				return
	if _activity_left <= 0.0:
		_idle(giving)


## Who they are and how their ride stands, for a save game ([method from_save]). Planets
## go by name, and their type by its resource path.
func to_save() -> Dictionary:
	var held := request if request else _held_request
	return {
		"type": type.resource_path,
		"name": name,
		"origin": String(origin.name) if origin else "",
		"destination": String(destination.name),
		"fare": fare,
		"trip_seconds": ride.trip_seconds,
		"expected_seconds": ride.expected_seconds,
		"race": race,
		"look": look.to_save(race),
		"happiness": happiness,
		"leeway": ride.leeway,
		"stops": ride.stops,
		"departed": _departed,
		"shaken": _shaken,
		"clock": ride.clock,
		"need_timers": Array(_need_timers),
		"held_need": type.needs.find(held) if held else -1,
		"request_age": _request_age,
		"lounge_bonus": lounge_bonus,
		"quick_bonus": quick_bonus,
	}


## Serves the open request at once, all of it, as [method feed] would once full. Does
## nothing when none is open.
func serve(portion := 1.0) -> void:
	if request:
		feed(1.0 - serving, portion)


## Serves [param amount] more of the open request, as a fraction of all of it: the player
## holding the serve button, or an [Amenity], feeds it a little every frame. Once
## [member serving] is full the request closes and the served line shows, for the need's
## time, times [param portion] for food. Does nothing when none is open.
func feed(amount: float, portion := 1.0) -> void:
	if not request:
		return
	_fed = true
	serving = minf(serving + amount, 1.0)
	if serving >= 1.0:
		var seconds := request.served_seconds * (portion if request.food else 1.0)
		_close(request.served_line, seconds)


## Shows one of their type's overheat lines for [param seconds], as the bus cools down
## after overheating, unless something else holds their line: a request, a sleep, a show
## or a served need.
func react_to_overheat(seconds: float) -> void:
	_complain(type.overheat_lines, seconds)


## Asks for [param need] now, whatever their timers say: the tutorial's way of showing a
## request when it wants one.
func ask_for(need: Need) -> void:
	_open(need)


## Shows [param line] while the request is open, such as who serves it, or the request's
## own line when [param line] is empty. Does nothing when none is open.
func show_request(line: String) -> void:
	if request:
		activity = line if not line.is_empty() else request.request_line


# Shows one of [param lines] for [param seconds], unless a request, a sleep, a show or a
# served need holds their line.
func _complain(lines: Array[String], seconds: float) -> void:
	if request or asleep or watching or _busy or lines.is_empty():
		return
	activity = _pick(lines)
	_activity_left = seconds


# The most the bus giving [param comfort] can give them now, before frustration, less discomfort.
func _get_best(comfort: Comfort) -> float:
	var bonus := comfort.bonus + lounge_bonus + quick_bonus
	var settled := minf(BASE_HAPPINESS + bonus, MAX_HAPPINESS) - comfort.discomfort
	return clampf(settled + ride.get_timing(), 0.0, MAX_HAPPINESS)


func _open(need: Need) -> void:
	request = need
	serving = 0.0
	asleep = false
	watching = false
	action = Need.Action.NONE
	activity = need.request_line
	_request_age = 0.0


func _close(line: String, seconds: float) -> void:
	# The next request waits its interval from when this activity ends. A request that
	# isn't one of the type's needs has no timer to reset.
	var index := type.needs.find(request)
	if index >= 0:
		_need_timers[index] = seconds + _interval(request)
	action = request.served_action
	request = null
	serving = 0.0
	asleep = false
	activity = line
	_activity_left = seconds
	_busy = true


# A new idle line. Where the bus lets them sleep, a sleep line comes up as often as any
# one idle line, and lasts as long as the comfort's sleeps do; where it has shows, so does
# a watch line, as long as the comfort's shows.
func _idle(comfort: Comfort) -> void:
	var lines := type.get_idle_lines(ride.get_reason())
	var sleep_from := lines.size()
	if comfort.can_sleep():
		lines.append_array(type.sleep_lines)
	var watch_from := lines.size()
	if comfort.can_watch():
		lines.append_array(type.watch_lines)
	var index := _rng.randi_range(0, lines.size() - 1) if not lines.is_empty() else -1
	activity = lines[index] if index >= 0 else ""
	asleep = index >= sleep_from and index < watch_from
	watching = index >= watch_from
	action = Need.Action.WATCH if watching else Need.Action.NONE
	if asleep:
		_activity_left = _rng.randf_range(comfort.sleep_min, comfort.sleep_max)
	elif watching:
		_activity_left = _rng.randf_range(comfort.watch_min, comfort.watch_max)
	else:
		_activity_left = _rng.randf_range(IDLE_MIN, IDLE_MAX)


func _interval(need: Need) -> float:
	var seconds := _rng.randf_range(need.min_interval, maxf(need.min_interval, need.max_interval))
	return seconds * type.need_interval_scale


func _pick(lines: Array[String]) -> String:
	return lines[_rng.randi_range(0, lines.size() - 1)] if not lines.is_empty() else ""
