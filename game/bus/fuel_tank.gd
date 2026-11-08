class_name FuelTank
extends Node
## The bus's fuel. It burns by distance flown, so a reroute costs only the distance it adds.
## It starts full.

## The tank ran dry: [member fuel] reached 0.
signal emptied

## How much fuel a full tank holds.
@export_range(1.0, 1000.0, 1.0) var capacity := 100.0
## Fuel burnt per unit flown. A full tank flies [member capacity] / this far.
@export_range(0.0, 100.0, 0.05) var burn_per_unit := 2.5

## The fuel left, from 0 to [member capacity].
var fuel := capacity


func _ready() -> void:
	fuel = capacity


## Burns the fuel for [param distance] flown. Emits [signal emptied] once, when it runs dry.
func burn(distance: float) -> void:
	if is_empty() or distance <= 0.0:
		return
	fuel = maxf(fuel - distance * burn_per_unit, 0.0)
	if is_empty():
		emptied.emit()


## Empties the tank at once. Emits [signal emptied] unless it already was empty.
func drain() -> void:
	if is_empty():
		return
	fuel = 0.0
	emptied.emit()


## Adds [param amount] of fuel, up to [member capacity].
func refuel(amount: float) -> void:
	fuel = minf(fuel + maxf(amount, 0.0), capacity)


## Fills the tank to [member capacity].
func fill() -> void:
	fuel = capacity


func is_empty() -> bool:
	return fuel <= 0.0


## How full the tank is, from 0 to 1.
func get_fraction() -> float:
	return fuel / capacity if capacity > 0.0 else 0.0
