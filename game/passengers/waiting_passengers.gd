class_name WaitingPassengers
extends Node
## The passengers waiting at each planet, shown in the open planet's panel. Each planet gets
## a new one every so often, up to [member max_per_planet], going to another planet at
## random, except the one the bus waits at: its clock holds until the bus leaves. Their
## patience and fare come from the distance to their destination when they
## board.

## The line at [param planet] changed: someone joined it or was taken from it.
signal changed(planet: Planet)

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
## How many wait at each planet when the game starts, so the first route has somewhere to go.
@export_range(0, 10) var starting_per_planet := 1
## How many wait at the planet the bus starts docked at, whose clock holds while it is
## there, so the first stop has someone to pick up.
@export_range(0, 10) var starting_at_bus := 2

var _rng := RandomNumberGenerator.new()
var _planets: Array[Planet] = []
var _waiting: Dictionary[Planet, Array] = {}
var _until_next: Dictionary[Planet, float] = {}


func _process(delta: float) -> void:
	var held: Planet = bus.get_docked_planet() if bus and bus.is_at_planet() else null
	for planet: Planet in _planets:
		if planet == held:
			continue
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


## Puts the passengers who wait when the game starts in line: [member starting_at_bus] at
## [param bus_planet] and [member starting_per_planet] at every other planet, each up to
## [member max_per_planet].
func add_starting_passengers(bus_planet: Planet) -> void:
	for planet: Planet in _planets:
		var count := starting_at_bus if planet == bus_planet else starting_per_planet
		for i: int in count:
			add(planet)


## Puts a new passenger in line at [param planet], unless [member max_per_planet] already
## wait there.
func add(planet: Planet) -> void:
	if not _waiting.has(planet) or _waiting[planet].size() >= max_per_planet:
		return
	var passenger := create(planet)
	if passenger:
		_waiting[planet].append(passenger)
		changed.emit(planet)


## How many wait at [param planet].
func count_at(planet: Planet) -> int:
	return _waiting.get(planet, []).size()


## Who waits at [param planet], longest waiting first.
func get_waiting(planet: Planet) -> Array[Passenger]:
	var line: Array[Passenger] = []
	line.assign(_waiting.get(planet, []))
	return line


## Takes [param passenger] out of the line at [param planet], as they are picked up. False
## when they don't wait there.
func take(planet: Planet, passenger: Passenger) -> bool:
	var queue: Array = _waiting.get(planet, [])
	if passenger not in queue:
		return false
	queue.erase(passenger)
	changed.emit(planet)
	return true


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
	var passenger := Passenger.new(
		kind, destination, _trip_seconds(distance), distance * fare_per_unit, _rng
	)
	passenger.origin = origin
	return passenger


# A rough direct trip: the charge, then the distance at top speed, plus the time to speed
# up and slow down. Planets move, so it is only an estimate. It uses the top speed before
# upgrades on purpose, so a faster bus makes for happier passengers instead of less patient
# ones.
func _trip_seconds(distance: float) -> float:
	if not bus:
		return distance
	return bus.charge_time + distance / bus.max_speed + bus.max_speed / bus.acceleration


func _interval() -> float:
	return _rng.randf_range(min_interval, maxf(min_interval, max_interval))
