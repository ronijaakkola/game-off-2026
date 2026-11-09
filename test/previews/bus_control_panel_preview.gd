extends Node
## The solar system with the bus control panel, for capturing it: 8 seats, 3 of them taken,
## and a course from Ember to Terra. By default the bus is already flying it, so the button
## is the Emergency stop; with the user arg `docked`, the bus waits docked for the player to
## hold the frameshift button.

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
	if not "docked" in OS.get_cmdline_user_args():
		# Charges at once, with no hold, and leaves on the next frame.
		bus.hold_to_charge = false
		bus.charge_time = 0.0
	bus.plot_course(RouteStop.at_planet(system.get_node(^"Terra") as Planet))
