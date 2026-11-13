extends Node
## The solar system with the bus status panel mid-trip, for capturing it: 8 seats, 3 of
## them taken, and the bus already flying from Ember to Terra, since the drive charges
## at once and the key is held. With "ready" after `--`, the key isn't held, so the bus
## waits at Ember with its course set.

const SEATS := 8
const ON_BOARD := 3


func _ready() -> void:
	var system := $SolarSystem as Node3D
	var cabin := system.get_node(^"Cabin") as Cabin
	var bus := system.get_node(^"Bus") as FrameshiftBus
	var waiting := system.get_node(^"WaitingPassengers") as WaitingPassengers
	cabin.seats = SEATS
	var home := bus.get_docked_planet()
	while cabin.get_passengers().size() < ON_BOARD:
		cabin.board(waiting.create(home))
	bus.charge_time = 0.0
	bus.plot_course(RouteStop.at_planet(system.get_node(^"World/Terra") as Planet))
	bus.frameshift_held = "ready" not in OS.get_cmdline_user_args()
