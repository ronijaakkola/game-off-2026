class_name RideProgress
extends RefCounted
## How a passenger's ride with their ride stands: how long it takes against the time
## they expect, and how many stops the bus makes before theirs. [Passenger] owns one and
## runs it.
## A quick ride earns [constant ON_TIME_BONUS], which fades to 0 by the time they expect.
## Past that, and for every stop past their type's tolerance, they grow frustrated, which
## takes happiness off the most they can reach ([method get_lost]), a steady amount that
## never speeds up and never takes them under [constant CAP_FLOOR]: the bus can still lift
## them up to what is left, with food and comfort. Every number that tunes it is here, but
## the tolerance, which is the type's ([member PassengerType.stop_tolerance]).

## Why they are frustrated, for the line they show.
enum Reason { NONE, STOPS, LATE }

## Timing's bonus while the ride takes no longer than the direct trip. It fades to 0 at the
## expected time.
const ON_TIME_BONUS := 12.0
## The happiness each stop past the type's tolerance takes off the most they can reach.
const STOP_COST := 15.0
## The happiness each second of their clock past the expected time takes off the most they
## can reach: a steady drain that never grows, so a late ride is always worth serving.
const LATE_RATE := 1.0
## Frustration never takes them under this, however many stops or however late: okay and
## three stars, so serving them still pays. A request open still heads for 0.
const CAP_FLOOR := 50.0
## Which stops count. Off, every planet the bus docks at before theirs. On, only one off
## their way: going there and on to their destination is more than [constant DETOUR_RATIO]
## times the straight way from where the bus last left.
const ONLY_DETOURS := false
const DETOUR_RATIO := 1.25
## A good ride makes them patient: while their happiness is at least this, they grant the
## bus leeway, [constant LEEWAY_RATE] seconds of it per second of their ride clock, added to
## the time they expect, up to [constant LEEWAY_MAX] trip times.
const LEEWAY_HAPPINESS := 80.0
const LEEWAY_RATE := 0.5
const LEEWAY_MAX := 0.5

## The direct trip time, and the time they expect the ride to take, the trip with the type's
## slack, in seconds of their ride clock.
var trip_seconds: float
var expected_seconds: float
## Seconds a good ride has added to the time they expect, up to [constant LEEWAY_MAX] trip
## times.
var leeway := 0.0
## Seconds of the ride so far, on their clock.
var clock := 0.0
## The stops that counted so far ([method pass_stop]).
var stops := 0
## How many stops they take before they grow frustrated.
var tolerance := 0

# The planet the bus last left on their ride, for telling a detour. Null for where they
# boarded.
var _left: Planet


func _init(trip: float, expected: float, stop_tolerance: int) -> void:
	trip_seconds = trip
	expected_seconds = expected
	tolerance = stop_tolerance


## Runs [param ride] seconds of their clock, with them at [param happiness].
func run(ride: float, happiness: float) -> void:
	clock += ride
	if happiness >= LEEWAY_HAPPINESS:
		leeway = minf(leeway + ride * LEEWAY_RATE, trip_seconds * LEEWAY_MAX)


## What their ride's timing adds to the happiness they settle at, now: [constant
## ON_TIME_BONUS] up to the direct trip time, falling to 0 at the expected time with their
## [member leeway]. Past it, [method get_lost] takes over.
func get_timing() -> float:
	if clock <= trip_seconds:
		return ON_TIME_BONUS
	var expected := expected_seconds + leeway
	if clock >= expected:
		return 0.0
	return lerpf(ON_TIME_BONUS, 0.0, inverse_lerp(trip_seconds, expected, clock))


## Seconds of their clock past the time they expect, leeway and all.
func get_late_seconds() -> float:
	return maxf(clock - expected_seconds - leeway, 0.0)


## How many stops past their tolerance the bus has made.
func get_extra_stops() -> int:
	return maxi(stops - tolerance, 0)


## The happiness frustration takes off [param best], the most they could reach otherwise:
## [constant STOP_COST] a stop past their tolerance and [constant LATE_RATE] a second late,
## leaving at least [constant CAP_FLOOR], or [param best] when that is under it.
func get_lost(best: float) -> float:
	var lost := get_extra_stops() * STOP_COST + get_late_seconds() * LATE_RATE
	return clampf(lost, 0.0, maxf(best - CAP_FLOOR, 0.0))


## Why they are frustrated now: the larger of the two costs, or none.
func get_reason() -> Reason:
	var stops_cost := get_extra_stops() * STOP_COST
	var late_cost := get_late_seconds() * LATE_RATE
	if stops_cost <= 0.0 and late_cost <= 0.0:
		return Reason.NONE
	return Reason.STOPS if stops_cost >= late_cost else Reason.LATE


## The bus docked at [param planet] on its way to [param destination], from [param origin]
## where they boarded. True when the stop counts and is past their tolerance.
func pass_stop(planet: Planet, origin: Planet, destination: Planet) -> bool:
	var from := _left if _left else origin
	_left = planet
	if ONLY_DETOURS and not _is_detour(from, planet, destination):
		return false
	stops += 1
	return stops > tolerance


## They change their mind and go somewhere else: a new trip of [param seconds] direct from
## here, which their timing counts from now with [param slack] and no leeway yet.
func restart(seconds: float, slack: float) -> void:
	trip_seconds = clock + seconds
	expected_seconds = clock + seconds * slack
	leeway = 0.0


# Whether stopping at [param via] on the way from [param from] to [param to] is off the
# way. Without a planet to measure from, it is.
func _is_detour(from: Planet, via: Planet, to: Planet) -> bool:
	if not from or not via or not to:
		return true
	var a := from.get_body_global_position()
	var b := via.get_body_global_position()
	var c := to.get_body_global_position()
	return a.distance_to(b) + b.distance_to(c) > a.distance_to(c) * DETOUR_RATIO
