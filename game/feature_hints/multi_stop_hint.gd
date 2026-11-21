extends Node
## Offers the multi-stop feature hint, on the route bar, the first time the bus waits at a
## planet with passengers on board going to two different planets, once those getting off
## there are off and [constant SETTLE_SECONDS] have passed, so the card of the passenger
## who just boarded has slid in. A player who already sets a route through two planets needs
## no hint, so it is no longer offered once one is set, until the scene loads again.

## Seconds the bus waits with passengers going to two planets before the hint opens: time
## for the last one's card to slide into the On board panel, and a beat.
const SETTLE_SECONDS := PassengerCard.ENTER_SECONDS + 0.3

@export var hints: FeatureHints
@export var bus: FrameshiftBus
@export var cabin: Cabin
## Holds the route bar the hint points at.
@export var bus_bars: BusStatusPanel

# For how long the bus has waited with passengers going to two planets.
var _wanted_for := 0.0


func _process(delta: float) -> void:
	if bus.get_route_planets().size() >= 2:
		set_process(false)
		return
	_wanted_for = _wanted_for + delta if _wants_two_planets() else 0.0
	if _wanted_for >= SETTLE_SECONDS and hints.offer(&"multi_stop", bus_bars.get_route_bar()):
		set_process(false)


# Whether the bus waits at a planet, nobody is getting off, and those on board are going
# to more than one planet.
func _wants_two_planets() -> bool:
	if not bus.is_at_planet() or cabin.is_stopping():
		return false
	var destinations := {}
	for passenger: Passenger in cabin.get_passengers():
		destinations[passenger.destination] = true
	return destinations.size() >= 2
