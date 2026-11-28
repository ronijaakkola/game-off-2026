class_name Seating
extends RefCounted
## How many of the bus's seats passengers take: each as many as their type says
## ([member PassengerType.seats]), so a VIP takes two. A VIP can always be picked up on a
## bus with seats enough: with too few free, passengers on board picked at random are
## kicked off to make room, one at a time, [constant KICK_GAP_SECONDS] apart so their
## screams don't overlap, and the VIP is picked up after the last. The rest on board take no
## shock: the player didn't kick them. The Boss ([BossPassenger]) takes every seat the bus
## has, however many that is, and is never one of those kicked off.

## Seconds from one passenger kicked off to make room to the next.
const KICK_GAP_SECONDS := 1.2


## How many seats [param passenger] takes on a bus with [param all] seats: as many as
## their type says, or for The Boss every one.
static func get_seats(passenger: Passenger, all: int) -> int:
	return maxi(all, 1) if BossPassenger.is_boss(passenger) else passenger.type.seats


## How many seats [param passengers] take in all, on a bus with [param all] seats.
static func count(passengers: Array[Passenger], all := 0) -> int:
	var taken := 0
	for passenger: Passenger in passengers:
		taken += get_seats(passenger, all)
	return taken


## Whether those on board [param cabin] leave seats enough for [param passenger], whoever
## else has been picked up and has yet to board.
static func has_room(cabin: Cabin, passenger: Passenger) -> bool:
	var taken := count(cabin.get_passengers(), cabin.seats)
	return taken + get_seats(passenger, cabin.seats) <= cabin.seats


## Whether [param passenger] fits in the seats free on [param cabin] now.
static func fits(passenger: Passenger, cabin: Cabin) -> bool:
	return cabin.get_free_seats() >= get_seats(passenger, cabin.seats)


## Whether [param passenger] can be picked up: they fit, or they are a VIP and kicking
## passengers off would make room.
static func can_pick_up(cabin: Cabin, passenger: Passenger) -> bool:
	if fits(passenger, cabin) or not Vip.is_vip(passenger):
		return fits(passenger, cabin)
	return cabin.get_free_seats() + count(_get_kickable(cabin)) >= passenger.type.seats


## Picks [param passenger] up on [param cabin], first kicking passengers off to make room
## for a VIP, if they need it. Ask [method can_pick_up] first.
static func pick_up(cabin: Cabin, passenger: Passenger) -> void:
	var on_board := _get_kickable(cabin)
	on_board.shuffle()
	var short := get_seats(passenger, cabin.seats) - cabin.get_free_seats()
	var kicks: Array[Passenger] = []
	while short > 0 and not on_board.is_empty():
		var other: Passenger = on_board.pop_back()
		kicks.append(other)
		short -= other.type.seats
	await _kick(cabin, kicks)
	if is_instance_valid(cabin):
		cabin.pick_up(passenger)


## Kicks everyone off [param cabin] the same way, as The Boss does before boarding
## ([BossPickUp]). It returns once the last one is off.
static func clear(cabin: Cabin) -> void:
	await _kick(cabin, _get_kickable(cabin))


# Who on [param cabin] can be kicked off to make room: everyone but The Boss.
static func _get_kickable(cabin: Cabin) -> Array[Passenger]:
	return cabin.get_passengers().filter(
		func(other: Passenger) -> bool: return not BossPassenger.is_boss(other)
	)


# Kicks [param kicks] off [param cabin] one at a time, [constant KICK_GAP_SECONDS] apart.
static func _kick(cabin: Cabin, kicks: Array[Passenger]) -> void:
	for i: int in kicks.size():
		if i > 0:
			await cabin.get_tree().create_timer(KICK_GAP_SECONDS).timeout
			if not is_instance_valid(cabin):
				return
		cabin.kick(kicks[i], false)
