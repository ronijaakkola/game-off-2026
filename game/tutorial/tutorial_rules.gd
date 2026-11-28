class_name TutorialRules
extends RefCounted
## What the [Tutorial] changes about the game while it runs, and puts back once it is over
## ([method lift]): who waits where, what the HUD holds back, what the player can't do, and
## the numbers that make the ride teach what it should. Only home and the destination have
## lines, with one passenger at home, always of [constant Tutorial.PASSENGER_RACE] so every
## tutorial looks the same, and nobody joins or leaves a line. The pause menu offers to
## skip it. The lab badges hide. The
## station has no fuel button until the tutorial shows it, and that one is off until it says
## so, nor a Board all or Research button, and the On board panel holds arrivals. Fuel is
## free at home and the destination, a trip between them burns half the tank
## ([method set_trip_burn]) and the way home whatever share [WayHome] asks for
## ([method set_burn]), and the passenger pays [constant FARE] ([method hold_fare]). Once
## it is over, no capsule it put out is left adrift, and the lab badges and the Research
## button stay hidden once it is over, until the mechanic opens
## research ([MechanicCall]).

## What the passenger pays, and what the capsule on the way home holds ([WayHome]): 120
## credits in all, the first upgrade's price.
const FARE := 70.0
const CAPSULE_CREDITS := 50
## The share of the tank a trip between home and the destination burns.
const TRIP_FUEL := 0.5

var _tutorial: Tutorial
# What it changed, as it was.
var _burn := 0.0
var _warm_time := 0.0
var _prices: Dictionary[Planet, float] = {}


func _init(tutorial: Tutorial) -> void:
	_tutorial = tutorial


## Changes the game for the tutorial.
func apply() -> void:
	var t := _tutorial
	t.waiting.set_process(false)
	t.waiting.set_planets([t.home, t.destination])
	t.waiting.deal_next(Tutorial.PASSENGER_RACE)
	t.waiting.add(t.home)
	# Decided now, so their row shows the fare they will pay.
	t.waiting.get_waiting(t.home)[0].fare = FARE
	t.lab_badges.hide()
	t.dock_panel.research_hidden = true
	t.dock_panel.fuel_hidden = true
	t.dock_panel.fuel_locked = true
	t.dock_panel.board_all_hidden = true
	t.passenger_panel.arrivals_held = true
	t.pause_menu.offers_skip_tutorial = true
	_burn = t.bus.get_fuel_tank().burn_per_unit
	_warm_time = t.bus.warm_time
	for planet: Planet in [t.home, t.destination]:
		_prices[planet] = planet.fuel_price
		planet.fuel_price = 0.0


## Puts the game back as it was, wherever the tutorial got to: unpaused, with the route
## free, the lines running and nothing beckoning or breathing. It fills the tank, so the
## run proper starts full however much the tutorial's trips burnt.
func lift() -> void:
	var t := _tutorial
	t.waiting.set_process(true)
	t.dock_panel.fuel_hidden = false
	t.dock_panel.fuel_locked = false
	t.dock_panel.board_all_hidden = false
	t.passenger_panel.arrivals_held = false
	t.pause_menu.offers_skip_tutorial = false
	t.bus.route_locked = false
	t.dock_panel.beckon_boarding = false
	t.resource_bar.breathe(false)
	pause(false)
	t.bus.get_fuel_tank().burn_per_unit = _burn
	t.bus.warm_time = _warm_time
	t.bus.get_fuel_tank().fill()
	t.capsules.clear()
	for planet: Planet in _prices:
		planet.fuel_price = _prices[planet]


## Burns fuel so that the way from where the bus is to where it docks at [param goal] takes
## TRIP_FUEL of the tank.
func set_trip_burn(goal: Planet) -> void:
	var bus := _tutorial.bus
	var tank := bus.get_fuel_tank()
	var stop := RouteStop.at_planet(goal).get_target(bus.global_position, bus.dock_gap)
	tank.burn_per_unit = TRIP_FUEL * tank.capacity / bus.global_position.distance_to(stop)


## Keeps the drive warm for as long as the bus holds in space, while [param on], so a
## course set there leaves at once; off, it stays warm as long as it does in the game.
func hold_warm(on: bool) -> void:
	_tutorial.bus.warm_time = INF if on else _warm_time


## Burns fuel so that [param distance] takes [param share] of the tank.
func set_burn(share: float, distance: float) -> void:
	var tank := _tutorial.bus.get_fuel_tank()
	tank.burn_per_unit = share * tank.capacity / distance


## Holds the game paused, or lets it go, with the portraits still moving. When
## [param serving], so does serving: the cabin, the On board panel with its serve buttons,
## and the tutorial, which sees it done.
func pause(on: bool, serving := false) -> void:
	var t := _tutorial
	var running: Array[Node] = [t.portrait_studio]
	if serving or not on:
		running.append_array([t, t.cabin, t.passenger_panel])
	for node: Node in running:
		node.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	if on:
		PauseMenu.hold(t)
	else:
		PauseMenu.release(t)


## Keeps what [param passenger] pays at FARE however they rate the ride.
func hold_fare(passenger: Passenger) -> void:
	passenger.fare = FARE / Payment.multiple(passenger.get_rating())
