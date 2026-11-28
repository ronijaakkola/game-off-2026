class_name FetchGoal
extends Goal
## A goal The Boss gives once they are on board: fetch [member thing], which they left at
## [member planet]. It is done once the bus docks there. A milestone.

## What to fetch, such as "briefcase".
var thing: String
var planet: Planet


func _init(what: String, at: Planet) -> void:
	thing = what
	planet = at


func get_text() -> String:
	return "Get the %s from" % thing


func get_planet() -> Planet:
	return planet


func _on_bus_docked(at: Planet) -> void:
	if at == planet:
		_complete()
