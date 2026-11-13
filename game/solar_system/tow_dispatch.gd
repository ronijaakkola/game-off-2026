class_name TowDispatch
extends Node
## Sends the tow. Running out of fuel in space scares everyone on board
## ([constant OUT_OF_FUEL_SHOCK]), and a notice offers a tow for [constant TOW_FEE] credits.
## Requesting it pays, into debt when the player has less, and a tow ship, a child of this
## node, comes from the nearest planet on the map and pulls the bus there, where it docks
## with a full tank.

## What a tow costs, in credits.
const TOW_FEE := 100
## The scare everyone on board takes when the bus runs out of fuel in space.
const OUT_OF_FUEL_SHOCK := -15.0
const TOW_SHIP := preload("res://game/bus/tow_ship.tscn")

@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack

## Who pays. The parent sets it.
var ledger: Ledger
## The planets a tow can come from; only those showing on the map do. The parent sets it.
var planets: Array[Planet] = []


func _ready() -> void:
	bus.ran_out_of_fuel.connect(_on_bus_ran_out_of_fuel)


func _on_bus_ran_out_of_fuel() -> void:
	cabin.shock(OUT_OF_FUEL_SHOCK)
	notices.offer_tow(TOW_FEE).action_pressed.connect(_on_tow_requested)


# Bills the tow and sends a tow ship from the planet nearest to the bus, to tow it there.
func _on_tow_requested() -> void:
	ledger.spend(TOW_FEE)
	var shown: Array[Planet] = []
	shown.assign(planets.filter(func(planet: Planet) -> bool: return planet.is_visible_in_tree()))
	var nearest := Planet.nearest_to(bus.global_position, shown)
	if not nearest:
		return
	var ship := TOW_SHIP.instantiate() as TowShip
	add_child(ship)
	ship.hitched.connect(bus.tow_to.bind(nearest))
	ship.come_for(bus, nearest)
