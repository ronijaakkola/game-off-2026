class_name ResearchLab
extends Node
## Where the player researches upgrades: it keeps the [Research] for the bus, shows the open
## planet's tree in its panel's Research tab every frame, and researches an upgrade the
## player clicks there only while the bus is docked or charging at that planet and the
## player can pay for it, taking its credits and research points off first. It adds the
## debug panel's Resources buttons, which give credits and research points for testing.

## The credits the debug panel's Add credits button gives.
const DEBUG_CREDITS := 1000
## The research points of each race the debug panel's Add research button gives.
const DEBUG_RESEARCH := 100
## The debug panel's group for the buttons that give credits and research points.
const DEBUG_RESOURCES_GROUP := "Resources"

## The bus whose stats upgrades change, and where it is docked.
@export var bus: FrameshiftBus
## Shows the credits and research points; the debug panel's credits are committed to it.
@export var resource_bar: ResourceBar
## The open planet's panel, whose Research tab draws the planet's tree.
@export var planet_panel: PlanetPanel

## The player's credits and research points, which pay for upgrades. The parent sets it.
var ledger: Ledger

var _research: Research


func _ready() -> void:
	_research = Research.new(bus.get_stats())
	planet_panel.research = _research
	planet_panel.upgrade_clicked.connect(_on_upgrade_clicked)
	var credits_text := "Add %d credits" % DEBUG_CREDITS
	DebugPanel.add_button(credits_text, _debug_add_credits, self, DEBUG_RESOURCES_GROUP)
	var research_text := "Add %d research of each" % DEBUG_RESEARCH
	DebugPanel.add_button(research_text, _debug_add_research, self, DEBUG_RESOURCES_GROUP)


func _process(_delta: float) -> void:
	var planet := planet_panel.get_planet()
	if planet and planet.research_tree:
		planet_panel.show_research(get_credits(), get_points(), can_research_at(planet))


## Which upgrades are researched.
func get_research() -> Research:
	return _research


## The credits the player has to pay with.
func get_credits() -> int:
	return ledger.credits


## The research points the player has to pay with, by race.
func get_points() -> Dictionary[Race.Type, int]:
	return ledger.get_all_research()


## Whether the bus is docked or charging at [param planet], where its tree can be researched.
func can_research_at(planet: Planet) -> bool:
	return planet != null and bus.is_at_planet() and bus.get_docked_planet() == planet


## Researches [param upgrade] from [param planet]'s tree when the bus is there and it is
## available, paying its cost. Otherwise it does nothing.
func research_at(upgrade: Upgrade, planet: Planet) -> void:
	if not can_research_at(planet):
		return
	if _research.get_state(upgrade, get_credits(), get_points()) != Research.State.AVAILABLE:
		return
	if upgrade.credits > 0:
		ledger.spend(upgrade.credits)
	for race: Race.Type in upgrade.points:
		ledger.spend_research(race, upgrade.points[race])
	_research.research(upgrade)


func _on_upgrade_clicked(upgrade: Upgrade) -> void:
	research_at(upgrade, planet_panel.get_planet())


# The debug panel's Add credits, shown as a gain that counts into the total, like a fare.
func _debug_add_credits() -> void:
	ledger.earn(DEBUG_CREDITS)
	resource_bar.commit()


# The debug panel's Add research, which gives points of every race, each count popping.
func _debug_add_research() -> void:
	for value: int in Race.Type.values():
		ledger.earn_research(value as Race.Type, DEBUG_RESEARCH)
