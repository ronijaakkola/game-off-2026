class_name Seating
extends RefCounted
## How many of the bus's seats passengers take: each as many as their type says
## ([member PassengerType.seats]), so a VIP takes two. A VIP can always be picked up on a
## bus with seats enough: with too few free, passengers on board picked at random are
## kicked off to make room, one at a time, [constant KICK_GAP_SECONDS] apart so their
## screams don't overlap, and the VIP is picked up after the last. The rest on board take no
## shock: the player didn't kick them.

## Seconds from one passenger kicked off to make room to the next.
const KICK_GAP_SECONDS := 1.2


## How many seats [param passengers] take in all.
static func count(passengers: Array[Passenger]) -> int:
	var taken := 0
	for passenger: Passenger in passengers:
		taken += passenger.type.seats
	return taken


## Whether [param passenger] fits in the seats free on [param cabin] now.
static func fits(passenger: Passenger, cabin: Cabin) -> bool:
	return cabin.get_free_seats() >= passenger.type.seats


## Whether [param passenger] can be picked up: they fit, or they are a VIP and kicking
## passengers off would make room.
static func can_pick_up(cabin: Cabin, passenger: Passenger) -> bool:
	if fits(passenger, cabin) or not Vip.is_vip(passenger):
		return fits(passenger, cabin)
	return cabin.get_free_seats() + count(cabin.get_passengers()) >= passenger.type.seats


## Picks [param passenger] up on [param cabin], first kicking passengers off to make room
## for a VIP, if they need it. Ask [method can_pick_up] first.
static func pick_up(cabin: Cabin, passenger: Passenger) -> void:
	var on_board := cabin.get_passengers()
	on_board.shuffle()
	var short := passenger.type.seats - cabin.get_free_seats()
	var kicks: Array[Passenger] = []
	while short > 0 and not on_board.is_empty():
		var other: Passenger = on_board.pop_back()
		kicks.append(other)
		short -= other.type.seats
	for i: int in kicks.size():
		if i > 0:
			await cabin.get_tree().create_timer(KICK_GAP_SECONDS).timeout
			if not is_instance_valid(cabin):
				return
		cabin.kick(kicks[i], false)
	cabin.pick_up(passenger)
