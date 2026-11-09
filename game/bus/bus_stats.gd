class_name BusStats
extends RefCounted
## The bus's stats: one [Stat] of each [enum Type], made here, with the bus setting their
## bases. Upgrades hand their [StatModifier]s to [method add_modifier], which applies each
## to the stat it names. Each stat has a floor ([constant MINIMUMS]), so however much
## modifiers take away, the bus still moves, holds some fuel and has a seat.
## Most bases come from the bus's exports; the rest start at [constant BASES].
## Its traits ([method get_traits]) are the other kind of stat: features the bus has or
## doesn't, rather than numbers.

## Which stat a [StatModifier] changes. A [code].tres[/code] saves a type as its number, so
## add new ones only at the end.
enum Type {
	## Top speed, in units per second.
	MAX_SPEED,
	## How much fuel a full tank holds.
	FUEL_CAPACITY,
	## How many passengers fit on board, to the nearest whole seat ([method get_seats]).
	SEATS,
	## How long a served snack or drink lasts, as a multiple of the need's own time: the
	## next request for it waits that much longer.
	PORTION_SIZE,
}

## The base of each stat no node of the bus sets: a stat missing here starts at 0.
const BASES: Dictionary[Type, float] = {
	Type.PORTION_SIZE: 1.0,
}

## The lowest each stat goes: the lowest the export it comes from allows.
const MINIMUMS: Dictionary[Type, float] = {
	Type.MAX_SPEED: 0.1,
	Type.FUEL_CAPACITY: 1.0,
	Type.SEATS: 1.0,
	Type.PORTION_SIZE: 0.1,
}

var _stats: Dictionary[Type, Stat] = {}
var _traits := BusTraits.new()


func _init() -> void:
	for value: int in Type.values():
		var type := value as Type
		var stat := Stat.new(BASES.get(type, 0.0))
		stat.minimum = MINIMUMS.get(type, 0.0)
		_stats[type] = stat


## The [param type] stat, with every modifier applied.
func get_stat(type: Type) -> Stat:
	return _stats[type]


## The bus's traits, the features upgrades unlock, such as the fuel forecast.
func get_traits() -> BusTraits:
	return _traits


## The seats the [constant Type.SEATS] stat makes: its value to the nearest whole seat.
func get_seats() -> int:
	return roundi(get_stat(Type.SEATS).get_value())


## Applies [param modifier] to the stat it names.
func add_modifier(modifier: StatModifier) -> void:
	get_stat(modifier.stat).add_modifier(modifier)


## Takes [param modifier] back out of the stat it names.
func remove_modifier(modifier: StatModifier) -> void:
	get_stat(modifier.stat).remove_modifier(modifier)
