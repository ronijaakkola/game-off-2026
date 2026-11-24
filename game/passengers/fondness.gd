class_name Fondness
extends RefCounted
## Who on board loves what bothers everyone else, for the rest of their ride, as a quest
## leaves them: a rock's knock lifts them rather than shaking them ([method Cabin.bump]), or
## the heat rather than wearing them down ([method Cabin.get_comfort]). The [Cabin] holds
## it and forgets whoever leaves.

## What they love.
enum Kind { ROCKS, HEAT }

var _fond: Dictionary[Kind, Array] = {Kind.ROCKS: [], Kind.HEAT: []}


## [param passenger] loves [param kind] from now on.
func add(passenger: Passenger, kind: Kind) -> void:
	if passenger not in _fond[kind]:
		_fond[kind].append(passenger)


## Whether [param passenger] loves [param kind].
func has(passenger: Passenger, kind: Kind) -> bool:
	return passenger in _fond[kind]


## [param passenger] left the bus.
func forget(passenger: Passenger) -> void:
	for kind: Kind in _fond:
		_fond[kind].erase(passenger)
