class_name WaitingPassengers
extends Node
## The passengers waiting at each planet, hidden for now. Each planet gets a new one every
## so often, up to [member max_per_planet], going to another planet at random. Their
## patience and fare come from the distance to their destination when they board.

## The kinds of passenger that turn up, picked at random.
@export var types: Array[PassengerType] = []
## The bus, whose speed and charge time set how long a trip should take.
@export var bus: FrameshiftBus
@export_range(0, 10) var max_per_planet := 3
## Seconds between new passengers at one planet: a random value between these two.
@export_range(1.0, 300.0, 1.0) var min_interval := 8.0
@export_range(1.0, 300.0, 1.0) var max_interval := 20.0
## Credits per world unit from the origin to the destination, before the type's multiplier.
@export_range(0.0, 50.0, 0.5) var fare_per_unit := 3.0

var _rng := RandomNumberGenerator.new()
var _planets: Array[Planet] = []
var _waiting: Dictionary[Planet, Array] = {}
var _until_next: Dictionary[Planet, float] = {}


func _process(delta: float) -> void:
	for planet: Planet in _planets:
		_until_next[planet] -= delta
		if _until_next[planet] > 0.0:
			continue
		_until_next[planet] = _interval()
		add(planet)


## The planets passengers wait at and travel between. Starts every planet empty.
func set_planets(planets: Array[Planet]) -> void:
	_planets = planets.duplicate()
	_waiting.clear()
	_until_next.clear()
	for planet: Planet in _planets:
		_waiting[planet] = []
		_until_next[planet] = _interval()


## Puts a new passenger in line at [param planet], unless [member max_per_planet] already
## wait there.
func add(planet: Planet) -> void:
	if not _waiting.has(planet) or _waiting[planet].size() >= max_per_planet:
		return
	var passenger := create(planet)
	if passenger:
		_waiting[planet].append(passenger)


## How many wait at [param planet].
func count_at(planet: Planet) -> int:
	return _waiting.get(planet, []).size()


## Takes up to [param count] passengers waiting at [param planet], longest waiting first.
func take(planet: Planet, count: int) -> Array[Passenger]:
	var taken: Array[Passenger] = []
	var queue: Array = _waiting.get(planet, [])
	while taken.size() < count and not queue.is_empty():
		taken.append(queue.pop_front())
	return taken


## A new passenger at [param origin], going to another planet at random. Null when there is
## no other planet or no type.
func create(origin: Planet) -> Passenger:
	var others := _planets.filter(func(planet: Planet) -> bool: return planet != origin)
	if others.is_empty() or types.is_empty():
		return null
	var destination: Planet = others[_rng.randi_range(0, others.size() - 1)]
	var kind := types[_rng.randi_range(0, types.size() - 1)]
	var distance := origin.get_body_global_position().distance_to(
		destination.get_body_global_position()
	)
	return Passenger.new(kind, destination, _trip_seconds(distance), distance * fare_per_unit, _rng)


# A rough direct trip: the charge, then the distance at top speed, plus the time to speed
# up and slow down. Planets move, so it is only an estimate.
func _trip_seconds(distance: float) -> float:
	if not bus:
		return distance
	return bus.charge_time + distance / bus.max_speed + bus.max_speed / bus.acceleration


func _interval() -> float:
	return _rng.randf_range(min_interval, maxf(min_interval, max_interval))
