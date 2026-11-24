class_name FuelTank
extends Node
## The bus's fuel. It burns by distance flown, so a reroute costs only the distance it adds.
## It starts full. With the Reserve tank, running dry in flight opens [member reserve] more
## fuel instead, once each time the tank is filled up.

## The tank ran dry: [member fuel] reached 0.
signal emptied
## The tank ran dry and the Reserve tank opened its [member reserve] instead.
signal reserve_opened

## How much fuel a full tank holds: the base of the FUEL_CAPACITY stat it follows
## ([method follow]). Shrunk below [member fuel], it spills what no longer fits; grown, the
## new room starts empty.
@export_range(1.0, 1000.0, 1.0) var capacity := 100.0:
	set(value):
		capacity = value
		fuel = minf(fuel, capacity)
## Fuel burnt per unit flown, before the FUEL_BURN stat scales it. A full tank flies
## [member capacity] / this far.
@export_range(0.0, 100.0, 0.05) var burn_per_unit := 2.5
## The fuel the Reserve tank opens on running dry.
@export_range(0.0, 100.0, 1.0) var reserve := 20.0

## The fuel left, from 0 to [member capacity].
var fuel := capacity:
	set(value):
		fuel = value
		if fuel >= capacity:
			reserve_used = false

## Whether the reserve has opened since the tank was last full, so it can't open again
## until the tank is. A saved run keeps it.
var reserve_used := false

var _stats: BusStats


func _ready() -> void:
	fuel = capacity


## Makes [member capacity] the base of [param stats]' FUEL_CAPACITY, and from then on its
## value, as upgrades change it. The stats' FUEL_BURN scales the burn, and their Reserve
## tank trait gives the reserve.
func follow(stats: BusStats) -> void:
	_stats = stats
	var stat := stats.get_stat(BusStats.Type.FUEL_CAPACITY)
	stat.base = capacity
	stat.changed.connect(_on_capacity_stat_changed)


## Burns the fuel for [param distance] flown. Emits [signal emptied] once, when it runs dry,
## unless the reserve opens instead.
func burn(distance: float) -> void:
	if is_empty() or distance <= 0.0:
		return
	fuel = maxf(fuel - distance * get_burn_per_unit(), 0.0)
	if not is_empty():
		return
	if _has_reserve():
		# After the fuel: a reserve that fills a tiny tank would otherwise clear it again.
		fuel = minf(reserve, capacity)
		reserve_used = true
		reserve_opened.emit()
		return
	emptied.emit()


## Fuel burnt per unit flown now: [member burn_per_unit] scaled by the FUEL_BURN stat.
func get_burn_per_unit() -> float:
	var scale := _stats.get_stat(BusStats.Type.FUEL_BURN).get_value() if _stats else 1.0
	return burn_per_unit * scale


## Empties the tank at once. Emits [signal emptied] unless it already was empty. The reserve
## doesn't open.
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


# Whether running dry now opens the reserve: with the Reserve tank, once each time the tank
# is filled up.
func _has_reserve() -> bool:
	if reserve_used or reserve <= 0.0 or not _stats:
		return false
	return _stats.get_traits().has(BusTraits.Type.RESERVE_TANK)


func _on_capacity_stat_changed() -> void:
	capacity = _stats.get_stat(BusStats.Type.FUEL_CAPACITY).get_value()
