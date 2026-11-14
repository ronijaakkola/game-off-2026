class_name ResearchLab
extends Node
## Where the player researches upgrades: it keeps the [Research] for the bus and every
## research tree, opens the research screen ([ResearchScreen]) on all of them, and
## researches an upgrade the player holds there when the player can pay for it, taking its
## credits and research points off first. Which planets open the screen is the dock
## panel's to say: those with a lab ([member Planet.has_lab]). It adds the debug panel's
## Resources buttons, which give credits and research points for testing, its Open
## research button, which opens the screen from anywhere, and its Promote button, which
## opens the next stage until promotions are built. While [member restricted], as in the
## tutorial, only [member researchable] upgrades can be researched.

## The credits the debug panel's Add credits button gives.
const DEBUG_CREDITS := 1000
## The research points of each race the debug panel's Add research button gives.
const DEBUG_RESEARCH := 100
## The debug panel's group for the buttons that give credits and research points.
const DEBUG_RESOURCES_GROUP := "Resources"
## The debug panel's buttons that open the screen from anywhere and open the next stage.
const DEBUG_OPEN_TEXT := "Open research"
const DEBUG_PROMOTE_TEXT := "Promote (open next research stage)"

## The bus whose stats upgrades change.
@export var bus: FrameshiftBus
## The HUD's bar, which shows the credits and research points while the screen is shut.
@export var resource_bar: ResourceBar
## The full-screen modal with every tree.
@export var research_screen: ResearchScreen
## Every research tree, in the order the screen shows them.
@export var trees: Array[ResearchTree] = []

## The player's credits and research points, which pay for upgrades. The parent sets it.
var ledger: Ledger:
	set(value):
		ledger = value
		if research_screen:
			research_screen.ledger = value

## Whether only [member researchable] upgrades can be researched.
var restricted := false
var researchable: Array[Upgrade] = []

var _research: Research


func _ready() -> void:
	_research = Research.new(bus.get_stats())
	research_screen.research = _research
	research_screen.upgrade_held.connect(research)
	research_screen.closed.connect(resource_bar.show)
	DebugPanel.add_button(DEBUG_OPEN_TEXT, open_screen, self)
	DebugPanel.add_button(DEBUG_PROMOTE_TEXT, _research.open_next_stage, self)
	var credits_text := "Add %d credits" % DEBUG_CREDITS
	DebugPanel.add_button(credits_text, _debug_add_credits, self, DEBUG_RESOURCES_GROUP)
	var research_text := "Add %d research of each" % DEBUG_RESEARCH
	DebugPanel.add_button(research_text, _debug_add_research, self, DEBUG_RESOURCES_GROUP)


## Which upgrades are researched, and which stages are open.
func get_research() -> Research:
	return _research


## The credits the player has to pay with.
func get_credits() -> int:
	return ledger.credits


## The research points the player has to pay with, by race.
func get_points() -> Dictionary[Race.Type, int]:
	return ledger.get_all_research()


## Whether the player can pay for any upgrade they could research now, in any tree.
func can_research_any() -> bool:
	if not ledger:
		return false
	var credits := get_credits()
	var points := get_points()
	for tree: ResearchTree in trees:
		for upgrade: Upgrade in tree.upgrades:
			if _research.get_state(upgrade, credits, points) == Research.State.AVAILABLE:
				return true
	return false


## Opens the research screen on every tree, pausing the game.
func open_screen() -> void:
	research_screen.open(trees)
	# The screen's header has the bar of its own; the HUD's would peek out above the sheet.
	resource_bar.hide()


## Shows the credits and ratings earned since the last commit in both resource bars, the
## HUD's and the screen's, so the two always show the same totals: each holds earnings
## back until its own commit.
func commit() -> void:
	resource_bar.commit()
	research_screen.commit()


## Researches [param upgrade] when it is available, paying its cost. Otherwise it does
## nothing.
func research(upgrade: Upgrade) -> void:
	if restricted and upgrade not in researchable:
		return
	if _research.get_state(upgrade, get_credits(), get_points()) != Research.State.AVAILABLE:
		return
	if upgrade.credits > 0:
		ledger.spend(upgrade.credits)
	for race: Race.Type in upgrade.points:
		ledger.spend_research(race, upgrade.points[race])
	_research.research(upgrade)


# The debug panel's Add credits, shown as a gain that counts into the total, like a fare.
func _debug_add_credits() -> void:
	ledger.earn(DEBUG_CREDITS)
	commit()


# The debug panel's Add research, which gives points of every race, each count popping.
func _debug_add_research() -> void:
	for value: int in Race.Type.values():
		ledger.earn_research(value as Race.Type, DEBUG_RESEARCH)
