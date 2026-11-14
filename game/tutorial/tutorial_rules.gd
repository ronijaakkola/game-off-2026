class_name TutorialRules
extends RefCounted
## What the [Tutorial] changes about the game while it runs, and puts back once it is over
## ([method lift]): what the HUD holds back, what the player can't do, and the numbers that
## make the ride teach what it should. Only home's lab badge can show. The station has no
## fuel button until the tutorial shows it, and that one is off until it says so, nor a
## Board all or Research button, the On board panel holds arrivals and offers no
## kicks, and the Frameshift key never stops the bus. Fuel is free at home and the
## destination, a trip between them burns half the tank ([method set_trip_burn]), and the
## passenger pays [constant FARE] ([method hold_fare]), so the player has just what Fuel
## tank 1 costs, which is one blue research point. Nothing can be researched until the
## tutorial says what ([member ResearchLab.researchable]).

## What the passenger pays.
const FARE := 150.0
## The share of the tank a trip between home and the destination burns.
const TRIP_FUEL := 0.5
## The upgrade the tutorial researches, and what it costs in blue research points then.
const FUEL_TANK := "Fuel tank 1"
const FUEL_TANK_POINTS: Dictionary[Race.Type, int] = {Race.Type.BLUE: 1}

var _tutorial: Tutorial
# What it changed, as it was.
var _burn := 0.0
var _prices: Dictionary[Planet, float] = {}
var _fuel_tank: Upgrade
var _fuel_tank_points: Dictionary[Race.Type, int] = {}


func _init(tutorial: Tutorial) -> void:
	_tutorial = tutorial
	for tree: ResearchTree in tutorial.research_lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if upgrade.title == FUEL_TANK:
				_fuel_tank = upgrade


## Changes the game for the tutorial.
func apply() -> void:
	var t := _tutorial
	t.lab_badges.hide()
	t.lab_badges.only = [t.home]
	t.dock_panel.research_hidden = true
	t.dock_panel.fuel_hidden = true
	t.dock_panel.fuel_locked = true
	t.dock_panel.board_all_hidden = true
	t.passenger_panel.arrivals_held = true
	t.passenger_panel.kicks_allowed = false
	t.bus_bars.stop_locked = true
	t.research_lab.restricted = true
	_burn = t.bus.get_fuel_tank().burn_per_unit
	for planet: Planet in [t.home, t.destination]:
		_prices[planet] = planet.fuel_price
		planet.fuel_price = 0.0
	if _fuel_tank:
		_fuel_tank_points = _fuel_tank.points
		_fuel_tank.points = FUEL_TANK_POINTS.duplicate()


## Puts the game back as it was.
func lift() -> void:
	var t := _tutorial
	t.lab_badges.only = []
	t.dock_panel.research_hidden = false
	t.dock_panel.fuel_hidden = false
	t.dock_panel.fuel_locked = false
	t.dock_panel.board_all_hidden = false
	t.passenger_panel.arrivals_held = false
	t.passenger_panel.kicks_allowed = true
	t.bus_bars.stop_locked = false
	t.research_lab.restricted = false
	t.research_lab.researchable = []
	t.research_screen.close_locked = false
	t.bus.get_fuel_tank().burn_per_unit = _burn
	for planet: Planet in _prices:
		planet.fuel_price = _prices[planet]
	put_back_upgrade()


## Puts Fuel tank 1's cost back. The upgrade is shared, and outlives the scene, so this
## runs even when the scene goes mid-tutorial.
func put_back_upgrade() -> void:
	if _fuel_tank and not _fuel_tank_points.is_empty():
		_fuel_tank.points = _fuel_tank_points


## The upgrade the tutorial researches, or null when no tree has it.
func get_fuel_tank() -> Upgrade:
	return _fuel_tank


## Burns fuel so that the way from where the bus is to where it docks at [param goal] takes
## TRIP_FUEL of the tank.
func set_trip_burn(goal: Planet) -> void:
	var bus := _tutorial.bus
	var tank := bus.get_fuel_tank()
	var stop := RouteStop.at_planet(goal).get_target(bus.global_position, bus.dock_gap)
	tank.burn_per_unit = TRIP_FUEL * tank.capacity / bus.global_position.distance_to(stop)


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
