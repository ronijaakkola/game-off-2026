class_name TutorialRules
extends RefCounted
## What the [Tutorial] changes about the game while it runs, and puts back once it is over
## ([method lift]): who waits where, what the HUD holds back, what the player can't do, and
## the numbers that make the ride teach what it should. Only home and the destination have
## lines, with one passenger at home, always of [constant Tutorial.PASSENGER_RACE] so every
## tutorial looks the same, and nobody joins or leaves a line. The lab badges hide. The
## station has no fuel button until the tutorial shows it, and that one is off until it says
## so, nor a Board all or Research button, and the On board panel holds arrivals and offers
## no kicks. Fuel is free at home and the destination, a trip between them burns half the
## tank ([method set_trip_burn]) and the way home whatever share [WayHome] asks for
## ([method set_burn]), and the passenger pays [constant FARE]
## ([method hold_fare]). The lab badges and the Research button stay hidden once it is over,
## until the mechanic opens research ([MechanicCall]).

## What the passenger pays.
const FARE := 120.0
## The share of the tank a trip between home and the destination burns.
const TRIP_FUEL := 0.5

var _tutorial: Tutorial
# What it changed, as it was.
var _burn := 0.0
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
	t.passenger_panel.kicks_allowed = false
	_burn = t.bus.get_fuel_tank().burn_per_unit
	for planet: Planet in [t.home, t.destination]:
		_prices[planet] = planet.fuel_price
		planet.fuel_price = 0.0


## Puts the game back as it was, and fills the tank, so the run proper starts full
## however much the tutorial's trips burnt.
func lift() -> void:
	var t := _tutorial
	t.waiting.set_process(true)
	t.dock_panel.fuel_hidden = false
	t.dock_panel.fuel_locked = false
	t.dock_panel.board_all_hidden = false
	t.passenger_panel.arrivals_held = false
	t.passenger_panel.kicks_allowed = true
	t.bus.get_fuel_tank().burn_per_unit = _burn
	t.bus.get_fuel_tank().fill()
	for planet: Planet in _prices:
		planet.fuel_price = _prices[planet]


## Burns fuel so that the way from where the bus is to where it docks at [param goal] takes
## TRIP_FUEL of the tank.
func set_trip_burn(goal: Planet) -> void:
	var bus := _tutorial.bus
	var tank := bus.get_fuel_tank()
	var stop := RouteStop.at_planet(goal).get_target(bus.global_position, bus.dock_gap)
	tank.burn_per_unit = TRIP_FUEL * tank.capacity / bus.global_position.distance_to(stop)


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


## Keeps what [param passenger] pays at FARE whatever their mood, as long as they pay at all.
func hold_fare(passenger: Passenger) -> void:
	var pay: float = Passenger.PAY[passenger.get_mood()]
	if pay > 0.0:
		passenger.fare = FARE / pay
