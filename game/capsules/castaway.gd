class_name Castaway
## The one passenger every passenger capsule holds: always the same person, Major Tim, by
## name, race and look, who keeps drifting off in space and doesn't much mind. No one else
## looks like them: silver, in a white helmet open at the front with a bent antenna. Once the
## player has taken them on board in a run, they come back as a returning passenger every time
## after ([member Passenger.returning]), with the badge, the better fare and the happier
## ride. They never wait in a line, so a five-star ride doesn't send them to one.

const NAME := "Major Tim"
## Whose voice they talk in.
const RACE := Race.Type.GREEN
## The Dome's shape in a helmet. A save keeps a look as one of its race's heads, so a
## castaway from a save is dressed again ([method dress]).
const HEAD := preload("res://game/capsules/models/head_castaway.glb")
const EYES := preload("res://game/passengers/eye_styles/bead.tres")
## A colour no race has.
const SKIN := Color(0.74, 0.77, 0.88)
## The space behind their portrait when they are bound for nowhere.
const SPACE := Color(0.13, 0.12, 0.3)


## Makes [param passenger] the castaway, as a returning passenger when the player has
## [param met] them before in the run.
static func dress(passenger: Passenger, met: bool) -> void:
	passenger.name = NAME
	passenger.race = RACE
	passenger.look = AlienLook.new()
	passenger.look.head = HEAD
	passenger.look.eye_style = EYES
	passenger.look.skin_color = SKIN
	passenger.returning = met


## The space behind [param passenger]'s portrait: the sky's fog colour in the star system
## they are bound for.
static func get_space_color(passenger: Passenger) -> Color:
	var node: Node = passenger.destination
	while node and not node is StarSystem:
		node = node.get_parent()
	return (node as StarSystem).fog_color if node else SPACE


## Whether [param passenger] is the castaway.
static func is_castaway(passenger: Passenger) -> bool:
	return passenger.name == NAME
