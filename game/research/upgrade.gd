class_name Upgrade
extends Resource
## One step in a research tree: what researching it costs, the upgrades that must
## be researched before it, and what it does to the bus once researched. [Research] keeps
## which upgrades are researched and applies their effects.

## What the tree and the hover card call it.
@export var title := ""
## What it does, in a short line on the hover card.
@export_multiline var description := ""
## What its tile in the tree shows.
@export var icon: Texture2D
## Its cost in credits.
@export var credits := 0
## Its cost in research points, by race. A race left out costs none.
@export var points: Dictionary[Race.Type, int] = {}
## The upgrades that must all be researched first, from the same tree. Each one is
## an [Upgrade]: typed as one, the script names itself and leaks at exit.
@export var requires: Array[Resource] = []
## Shown as a silhouette with "???" on its card until everything it requires is researched.
@export var hidden := false
## Applied to the bus's stats once researched.
@export var modifiers: Array[StatModifier] = []
## Given to the bus once researched.
@export var traits: Array[BusTraits.Type] = []
## Its row in the tree, from the top, and its place in the row, from the left; its row sets
## its stage ([method Research.get_stage]). An upgrade sits below what it requires.
@export var tier := 0
@export var column := 0


## The race whose points it costs most, the first in [enum Race.Type] on a tie: its tile
## shows in that race's colours, since each race's points are for one part of the bus. Only
## for an upgrade that costs points.
func get_race() -> Race.Type:
	var race := Race.Type.BLUE
	var most := -1
	for value: int in Race.Type.values():
		var amount: int = points.get(value as Race.Type, 0)
		if amount > most:
			race = value as Race.Type
			most = amount
	return race


## Whether [param credits_held] and [param points_held], research points by race, pay for it.
func can_afford(credits_held: int, points_held: Dictionary[Race.Type, int]) -> bool:
	if credits_held < credits:
		return false
	for race: Race.Type in points:
		if points_held.get(race, 0) < points[race]:
			return false
	return true
