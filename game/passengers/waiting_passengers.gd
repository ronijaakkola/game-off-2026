class_name WaitingPassengers
extends Node
## The passengers waiting at each planet, shown in the open planet's panel and the dock
## panel. Each planet gets a new one every so often, up to [member max_per_planet], except
## the one the bus waits at: its clock holds until the bus leaves.
## Someone waiting is only a count until the player first sees the line
## ([method get_waiting]). Then each is decided, one after another: a destination that
## leans toward where those on board and those already in the line are going, a race dealt
## from a bag, and a type by the band of the player's recent rating ([RatingBand]). Their
## trip time and fare come from the distance to their destination then.
## Once seen, the one who has waited longest leaves after [member leave_seconds] without
## being picked up, so a line the player passes over doesn't stay the same for good.

## The line at [param planet] changed: someone joined it, left it or was taken from it.
signal changed(planet: Planet)

## How many of each race go into the bag the races are dealt from.
const RACE_BAG_COPIES := 2
## How many in one line go to the same planet at most, so a line always holds a choice.
const MAX_SAME_DESTINATION := 2

## The ordinary kinds of passenger that turn up, picked at random.
@export var types: Array[PassengerType] = []
## The harder, better-paying kind, which turns up more often the higher the player's recent
## rating. Without one, everyone is ordinary.
@export var business: PassengerType
## The bus, whose speed and charge time set how long a trip should take.
@export var bus: FrameshiftBus
## Who is on board: destinations they are going to turn up more often.
@export var cabin: Cabin
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
## How much likelier a destination is when someone on board is going there, and when
## someone already in the line is. Likelier, never certain.
@export_range(1.0, 10.0, 0.1) var on_board_weight := 2.5
@export_range(1.0, 10.0, 0.1) var in_line_weight := 1.5
## Seconds the longest-waiting passenger of a line the player has seen stays before they
## leave.
@export_range(1.0, 600.0, 1.0) var leave_seconds := 60.0

## The player's ratings, whose recent mean sets how many are Business. Without one, the
## lowest band counts.
var ledger: Ledger

var _rng := RandomNumberGenerator.new()
var _planets: Array[Planet] = []
# Those the player has seen, longest waiting first.
var _waiting: Dictionary[Planet, Array] = {}
# How many more wait at each planet, not yet seen and so not yet decided. They joined
# after everyone in _waiting.
var _undecided: Dictionary[Planet, int] = {}
var _until_next: Dictionary[Planet, float] = {}
# Who is first in each seen line, and the seconds until they leave.
var _first: Dictionary[Planet, Passenger] = {}
var _until_leave: Dictionary[Planet, float] = {}
var _race_bag: Array[Race.Type] = []


func _process(delta: float) -> void:
	var held: Planet = bus.get_docked_planet() if bus and bus.is_at_planet() else null
	for planet: Planet in _planets:
		if planet == held:
			continue
		_until_next[planet] -= delta
		if _until_next[planet] <= 0.0:
			_until_next[planet] = _interval()
			add(planet)
		_wait(planet, delta)


## Makes every roll from here on, and those of the passengers decided after it, follow from
## [param value], so a run can be played again: a balance run (`tools/balance.py`).
func seed_dice(value: int) -> void:
	_rng.seed = value


## The planets passengers wait at and travel between. Starts every planet empty.
func set_planets(planets: Array[Planet]) -> void:
	_planets = planets.duplicate()
	_waiting.clear()
	_undecided.clear()
	_until_next.clear()
	_first.clear()
	_until_leave.clear()
	for planet: Planet in _planets:
		_waiting[planet] = []
		_undecided[planet] = 0
		_until_next[planet] = _interval()


## Starts the game's lines: [method set_planets] with [param planets], the passengers who
## wait from the start ([method add_starting_passengers]), and [param ratings] as the
## [member ledger].
func start(planets: Array[Planet], bus_planet: Planet, ratings: Ledger) -> void:
	ledger = ratings
	set_planets(planets)
	add_starting_passengers(bus_planet)


## Puts the passengers who wait when the game starts in line: [member starting_at_bus] at
## [param bus_planet] and [member starting_per_planet] at every other planet, each up to
## [member max_per_planet].
func add_starting_passengers(bus_planet: Planet) -> void:
	for planet: Planet in _planets:
		var count := starting_at_bus if planet == bus_planet else starting_per_planet
		for i: int in count:
			add(planet)


## Puts someone new in line at [param planet], not yet decided, unless
## [member max_per_planet] already wait there.
func add(planet: Planet) -> void:
	if not _waiting.has(planet) or count_at(planet) >= max_per_planet:
		return
	_undecided[planet] += 1
	changed.emit(planet)


## How many wait at [param planet], seen or not.
func count_at(planet: Planet) -> int:
	return _waiting.get(planet, []).size() + _undecided.get(planet, 0)


## Who waits at [param planet], longest waiting first. Asking is the player seeing the
## line: it decides everyone in it who wasn't yet, as the bus and the line are now.
func get_waiting(planet: Planet) -> Array[Passenger]:
	while _undecided.get(planet, 0) > 0:
		_undecided[planet] -= 1
		var passenger := create(planet)
		if passenger:
			_waiting[planet].append(passenger)
	var line: Array[Passenger] = []
	line.assign(_waiting.get(planet, []))
	return line


## Who waits at [param planet] that the player has seen, longest waiting first, without
## deciding anyone: [method count_at] less that many aren't decided yet.
func get_seen(planet: Planet) -> Array[Passenger]:
	var line: Array[Passenger] = []
	line.assign(_waiting.get(planet, []))
	return line


## Puts the line at [param planet] back as a save game had it: [param seen] first, then
## [param unseen] more not yet decided. The line's clocks start afresh.
func restore(planet: Planet, seen: Array[Passenger], unseen: int) -> void:
	if not _waiting.has(planet):
		return
	_waiting[planet] = seen.slice(0, max_per_planet)
	_undecided[planet] = clampi(unseen, 0, max_per_planet - _waiting[planet].size())
	_first.erase(planet)
	changed.emit(planet)


## Takes [param passenger] out of the line at [param planet], as they are picked up. False
## when they don't wait there.
func take(planet: Planet, passenger: Passenger) -> bool:
	var queue: Array = _waiting.get(planet, [])
	if passenger not in queue:
		return false
	queue.erase(passenger)
	changed.emit(planet)
	return true


## A new passenger at [param origin], decided as one joining its line now would be. Null
## when there is no other planet or no type. They are not put in the line.
func create(origin: Planet) -> Passenger:
	var line: Array = _waiting.get(origin, [])
	var destination := _pick_destination(origin, line)
	if not destination or types.is_empty():
		return null
	var distance := origin.get_body_global_position().distance_to(
		destination.get_body_global_position()
	)
	var passenger := Passenger.new(
		_pick_type(line), destination, _trip_seconds(distance), distance * fare_per_unit, _rng
	)
	passenger.origin = origin
	passenger.race = _deal_race()
	passenger.look = AlienLook.random(_rng, passenger.race)
	return passenger


# A weighted roll among the other planets: likelier where someone on board or in
# [param line] is going, and never where MAX_SAME_DESTINATION of the line already go,
# unless that leaves nowhere.
func _pick_destination(origin: Planet, line: Array) -> Planet:
	var others := _planets.filter(func(planet: Planet) -> bool: return planet != origin)
	if others.is_empty():
		return null
	var weights := PackedFloat32Array()
	var total := 0.0
	for planet: Planet in others:
		var same := line.filter(func(p: Passenger) -> bool: return p.destination == planet).size()
		var weight := 1.0
		if same >= MAX_SAME_DESTINATION:
			weight = 0.0
		elif same > 0:
			weight *= in_line_weight
		if cabin and cabin.count_going_to(planet) > 0:
			weight *= on_board_weight
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return others[_rng.randi_range(0, others.size() - 1)]
	return others[_rng.rand_weighted(weights)]


# Business by the share of the band the recent rating is in, while [param line] has room
# for one more of them and still a place for someone ordinary.
func _pick_type(line: Array) -> PassengerType:
	var ordinary := types[_rng.randi_range(0, types.size() - 1)]
	if not business:
		return ordinary
	var band := RatingBand.of(ledger.get_recent_rating() if ledger else 0.0)
	var limit := mini(RatingBand.BUSINESS_PER_LINE[band], max_per_planet - 1)
	var count := line.filter(func(p: Passenger) -> bool: return p.type == business).size()
	if count < limit and _rng.randf() < RatingBand.BUSINESS_SHARE[band]:
		return business
	return ordinary


# The next race from the bag, which holds RACE_BAG_COPIES of each, shuffled, so no race
# stays away for long.
func _deal_race() -> Race.Type:
	if _race_bag.is_empty():
		for value: int in Race.Type.values():
			for i: int in RACE_BAG_COPIES:
				_race_bag.insert(_rng.randi_range(0, _race_bag.size()), value as Race.Type)
	return _race_bag.pop_back()


# Runs the clock of whoever is first in the seen line at [param planet], who leaves when
# it runs out. Someone new at the front starts it afresh.
func _wait(planet: Planet, delta: float) -> void:
	var line: Array = _waiting[planet]
	var first: Passenger = line[0] if not line.is_empty() else null
	if first != _first.get(planet):
		_first[planet] = first
		_until_leave[planet] = leave_seconds
	if not first:
		return
	_until_leave[planet] -= delta
	if _until_leave[planet] <= 0.0:
		line.erase(first)
		changed.emit(planet)


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
