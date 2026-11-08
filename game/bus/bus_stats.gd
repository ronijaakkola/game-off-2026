class_name BusStats
extends RefCounted
## The bus's stats: one [Stat] of each [enum Type], made here, with the bus setting their
## bases. Upgrades hand their [StatModifier]s to [method add_modifier], which applies each
## to the stat it names.

## Which stat a [StatModifier] changes. A [code].tres[/code] saves a type as its number, so
## add new ones only at the end.
enum Type { MAX_SPEED }

var _stats: Dictionary[Type, Stat] = {}


func _init() -> void:
	for type: int in Type.values():
		_stats[type as Type] = Stat.new()


## The [param type] stat, with every modifier applied.
func get_stat(type: Type) -> Stat:
	return _stats[type]


## Applies [param modifier] to the stat it names.
func add_modifier(modifier: StatModifier) -> void:
	get_stat(modifier.stat).add_modifier(modifier)


## Takes [param modifier] back out of the stat it names.
func remove_modifier(modifier: StatModifier) -> void:
	get_stat(modifier.stat).remove_modifier(modifier)
