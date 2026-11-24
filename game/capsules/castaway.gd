class_name Castaway
## The one passenger every passenger capsule holds: always the same person, by name, type,
## race and look, who keeps drifting off in space. Once the player has rescued them in a run,
## they come back as a returning passenger every time after ([member Passenger.returning]),
## with the badge, the better fare and the happier ride. They never wait in a line, so a
## five-star ride doesn't send them to one.

const NAME := "Driff"
const RACE := Race.Type.GREEN
## Their look, as [method AlienLook.to_save] keeps one: the hammer head and googly eyes.
const LOOK := {"head": 1, "eyes": 0}


## Makes [param passenger] the castaway, as a returning passenger when the player has
## [param met] them before in the run.
static func dress(passenger: Passenger, met: bool) -> void:
	passenger.name = NAME
	passenger.race = RACE
	passenger.look = AlienLook.from_save(LOOK, RACE)
	passenger.returning = met


## Whether [param passenger] is the castaway.
static func is_castaway(passenger: Passenger) -> bool:
	return passenger.name == NAME
