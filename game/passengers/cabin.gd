class_name Cabin
extends Node
## The inside of the bus: the passengers on board and the amenities that serve them. Each
## frame it runs every passenger's ride and serves their requests: the player serves one by
## holding its card's serve button for [constant HAND_SECONDS] ([method hold_serve]), and
## a food amenity starts on a request for food the moment it opens, while it has room for
## one more, so the others asking wait their turn. The player's hold adds to the amenity's
## speed. At a planet it runs a stop: the passengers going there get off one at
## a time and pay by their mood. Those the player picks up get on one at a time, after
## everyone getting off. Each takes [member step_seconds], so a busy stop takes longer.
## Whoever takes a seat starts at the happiness the bus can give them
## ([method Passenger.settle]).
## The bus's comfort upgrades, as traits, set the [Comfort] every passenger rides with and
## which amenities are on board, and its PORTION_SIZE stat how long served food lasts.

signal boarded(passenger: Passenger)
## [param passenger] left their seat at the stop [method stop_at] started, and will get off
## in turn. Emitted for everyone going there, in the order they get off, before the first
## of them is [signal delivered].
signal getting_off(passenger: Passenger)
## [param passenger] got off at their destination and paid [param payout] credits.
signal delivered(passenger: Passenger, payout: int)
## The player kicked [param passenger] off the bus mid-ride ([method kick]). They pay
## nothing and rate nothing, and the rest take a [constant KICK_SHOCK].
signal kicked(passenger: Passenger)
## Everyone getting off at the stop [method stop_at] started has got off, one step after
## the last of them. Emitted even when nobody got off.
signal unloaded
## The stop is over: everyone going there got off, and everyone picked up got on.
signal stop_finished

## The scare everyone left on board takes when the player kicks someone off.
const KICK_SHOCK := -25.0
## Seconds the player holds a serve button to serve a request alone.
const HAND_SECONDS := 1.2
const FOOD_DISPENSER := preload("res://game/passengers/amenities/food_dispenser.tres")
const SERVING_ROBOTS := preload("res://game/passengers/amenities/serving_robots.tres")

## How many passengers fit on board: the base of the bus's SEATS stat once the cabin
## follows it ([method follow]). Taking seats away leaves anyone in them on board, with no
## seat free until enough of them get off.
@export_range(1, 12) var seats := 4
## Every amenity upgrades can put on board, the one tried first first. Once the cabin
## follows the bus ([method follow]), those whose trait the bus has are its
## [member amenities].
@export var fittings: Array[Amenity] = [SERVING_ROBOTS, FOOD_DISPENSER]
## The amenities on board, which serve requests for food by themselves.
@export var amenities: Array[Amenity] = []
## Seconds each passenger takes to get off or on at a stop.
@export_range(0.0, 3.0, 0.05) var step_seconds := 0.6
## What a happy passenger pays, as a multiple of what they would without it, once the bus
## has the Tip jar.
@export_range(1.0, 3.0, 0.05) var tip := 1.2
## How many times as long someone picked up waits for their first requests, once the bus
## has Free station coffee.
@export_range(1.0, 3.0, 0.05) var coffee_delay := 1.5

## Whether the bus waits at a planet, docked or charging, so ride clocks run at half
## speed. The scene that holds the bus sets it. When it turns false the bus has left, and
## everyone on board has departed, so the ride of those who just boarded starts.
var docked := true:
	set(value):
		if docked and not value:
			for passenger: Passenger in _passengers:
				passenger.depart(comfort)
		docked = value

## Whether the bus is parking at a planet, so everyone's happiness holds: the bus has
## arrived. The scene that holds the bus sets it.
var parking := false

## What the bus's comfort upgrades give everyone on board. It follows the bus's traits once
## the cabin follows the bus ([method follow]).
var comfort := Comfort.new()
## How long served food lasts, as a multiple of the need's time: the PORTION_SIZE stat once
## the cabin follows the bus.
var portion := 1.0

var _passengers: Array[Passenger] = []
# The stop under way: who still gets off, with what they pay, and who still gets on.
var _stopping := false
var _unloading := false
var _getting_off: Array[Passenger] = []
var _payouts: Array[int] = []
var _getting_on: Array[Passenger] = []
var _until_step := 0.0
var _bus_stats: BusStats
# The amenity serving each passenger's request now.
var _served_by: Dictionary[Passenger, Amenity] = {}
# The passengers whose serve button the player holds.
var _hands: Dictionary[Passenger, bool] = {}


func _process(delta: float) -> void:
	# Kept running through a pause, as for the tutorial's first request: only serving goes
	# on, and the ride holds still.
	if get_tree().paused:
		for passenger: Passenger in _passengers:
			_serve_request(passenger, delta)
		return
	for passenger: Passenger in _passengers:
		passenger.tick(delta, docked, parking, comfort)
		_serve_request(passenger, delta)
	if _stopping:
		_until_step -= delta
		while _stopping and _until_step <= 0.0:
			_step()


## Makes [member seats] the base of [param stats]' SEATS stat, and from then on the seats
## it makes, as upgrades change it. [member comfort] follows its traits. Following other
## stats stops following the ones before. [member amenities] follow its traits, and
## [member portion] its PORTION_SIZE stat.
func follow(stats: BusStats) -> void:
	if _bus_stats:
		_bus_stats.get_stat(BusStats.Type.SEATS).changed.disconnect(_on_seats_stat_changed)
		_bus_stats.get_stat(BusStats.Type.PORTION_SIZE).changed.disconnect(_on_portion_changed)
		_bus_stats.get_traits().changed.disconnect(_on_trait_changed)
	_bus_stats = stats
	var stat := stats.get_stat(BusStats.Type.SEATS)
	stat.base = seats
	stat.changed.connect(_on_seats_stat_changed)
	stats.get_stat(BusStats.Type.PORTION_SIZE).changed.connect(_on_portion_changed)
	_on_portion_changed()
	stats.get_traits().changed.connect(_on_trait_changed)
	_on_trait_changed(BusTraits.Type.FOOD_DISPENSER)


## The passengers on board, in the order they boarded. A copy. Those getting off at a stop
## under way are no longer on board.
func get_passengers() -> Array[Passenger]:
	return _passengers.duplicate()


func has_free_seat() -> bool:
	return _passengers.size() < seats


## Seats no one has taken or been picked up for.
func get_free_seats() -> int:
	return maxi(seats - _passengers.size() - _getting_on.size(), 0)


## How many on board or picked up are going to [param planet].
func count_going_to(planet: Planet) -> int:
	var count := 0
	for passenger: Passenger in _passengers + _getting_on:
		if passenger.destination == planet:
			count += 1
	return count


## Whether a stop is under way: passengers are still getting off or on.
func is_stopping() -> bool:
	return _stopping


## Takes [param passenger] on board at once. False, and nothing happens, when every seat
## is taken.
func board(passenger: Passenger) -> bool:
	if not has_free_seat() or passenger in _passengers:
		return false
	_take_seat(passenger)
	return true


## The player starts holding [param passenger]'s serve button down, with [param held]
## true, or lets go, with it false. While held, their open request fills by hand.
func hold_serve(passenger: Passenger, held: bool) -> void:
	if held and passenger in _passengers:
		_hands[passenger] = true
	else:
		_hands.erase(passenger)


## The amenity serving [param passenger]'s request now, or null.
func get_serving_amenity(passenger: Passenger) -> Amenity:
	return _served_by.get(passenger)


## The player kicks [param passenger] off the bus: they leave their seat at once, wherever
## the bus is, paying and rating nothing, and everyone left takes [constant KICK_SHOCK].
## False, and nothing happens, when they aren't on board, as when they are already getting
## off at a stop.
func kick(passenger: Passenger) -> bool:
	if passenger not in _passengers:
		return false
	_passengers.erase(passenger)
	_forget(passenger)
	shock(KICK_SHOCK)
	kicked.emit(passenger)
	return true


## Everyone on board takes a shock of [param amount] ([method Passenger.shock]), such as
## the scare of running out of fuel.
func shock(amount: float) -> void:
	for passenger: Passenger in _passengers:
		passenger.shock(amount)


## Starts a stop at [param planet]. Everyone going there leaves their seat now, and their
## happiness stops, so they pay by the mood they arrived in, after any disappointment at a
## request left unserved ([method Passenger.arrive]); they get off one at a time.
## The first one goes at once, and [signal stop_finished] comes [member step_seconds] after
## the last, or at once when nobody gets off or on.
func stop_at(planet: Planet) -> void:
	var leaving: Array[Passenger] = []
	for passenger: Passenger in _passengers.duplicate():
		if passenger.destination == planet:
			_passengers.erase(passenger)
			_forget(passenger)
			_getting_off.append(passenger)
			passenger.arrive()
			_payouts.append(passenger.get_payout(tip if _has(BusTraits.Type.TIP_JAR) else 1.0))
			leaving.append(passenger)
	for passenger: Passenger in leaving:
		getting_off.emit(passenger)
	_unloading = true
	_start_stop()


## The player picks up [param passenger]: they get on after everyone getting off and
## everyone picked up before them, one step each, so a stop starts if none is under way.
## False, and nothing happens, when no seat is free for them.
func pick_up(passenger: Passenger) -> bool:
	if get_free_seats() <= 0 or passenger in _passengers or passenger in _getting_on:
		return false
	_getting_on.append(passenger)
	if not _stopping:
		_start_stop()
	return true


func _start_stop() -> void:
	if _stopping:
		return
	_stopping = true
	_until_step = 0.0
	_step()


# One passenger off, else one on, else the stop is over.
func _step() -> void:
	if not _getting_off.is_empty():
		delivered.emit(_getting_off.pop_front(), _payouts.pop_front())
		_until_step += step_seconds
		return
	if _unloading:
		_unloading = false
		unloaded.emit()
	if not _getting_on.is_empty():
		# Picked up with a seat promised, so they get on even if seats went since.
		var boarding: Passenger = _getting_on.pop_front()
		if _has(BusTraits.Type.FREE_COFFEE):
			boarding.delay_requests(coffee_delay)
		_take_seat(boarding)
		_until_step += step_seconds
		return
	_stopping = false
	stop_finished.emit()


# Feeds [param passenger]'s open request for [param delta] seconds: from the amenity serving
# it, or the first with room once one has, and from the player's hand while held. Someone
# waiting for an amenity to have room shows it. A hold ends with the request it served, so
# the next one never starts filling by itself.
func _serve_request(passenger: Passenger, delta: float) -> void:
	var request := passenger.request
	var amenity: Amenity = _served_by.get(passenger)
	if not request or amenity not in amenities:
		_served_by.erase(passenger)
		amenity = null
	if not request:
		_hands.erase(passenger)
		return
	var waiting_for: Amenity = null
	if not amenity and request.food:
		for fitted: Amenity in amenities:
			if _users(fitted) < fitted.capacity:
				amenity = fitted
				_served_by[passenger] = fitted
				break
			if not waiting_for:
				waiting_for = fitted
	var rate := 0.0
	if amenity:
		rate += 1.0 / amenity.seconds
		passenger.show_request(amenity.get_line(request))
	elif waiting_for:
		passenger.show_request(waiting_for.waiting_line)
	else:
		passenger.show_request("")
	if _hands.has(passenger):
		rate += 1.0 / HAND_SECONDS
	if rate > 0.0:
		passenger.feed(rate * delta, portion)
	if not passenger.request:
		_served_by.erase(passenger)
		_hands.erase(passenger)


# How many requests [param amenity] serves now.
func _users(amenity: Amenity) -> int:
	return _served_by.values().count(amenity)


func _forget(passenger: Passenger) -> void:
	_served_by.erase(passenger)
	_hands.erase(passenger)


func _take_seat(passenger: Passenger) -> void:
	_passengers.append(passenger)
	passenger.settle(comfort)
	boarded.emit(passenger)


# Whether the bus the cabin follows has [param type]. Before it follows one, nothing.
func _has(type: BusTraits.Type) -> bool:
	return _bus_stats != null and _bus_stats.get_traits().has(type)


func _on_seats_stat_changed() -> void:
	seats = _bus_stats.get_seats()


func _on_portion_changed() -> void:
	portion = _bus_stats.get_stat(BusStats.Type.PORTION_SIZE).get_value()


func _on_trait_changed(_type: BusTraits.Type) -> void:
	var traits := _bus_stats.get_traits()
	comfort = Comfort.from_traits(traits)
	for passenger: Passenger in _passengers:
		passenger.settle(comfort)
	amenities.clear()
	for fitted: Amenity in fittings:
		if traits.has(fitted.bus_trait):
			amenities.append(fitted)
