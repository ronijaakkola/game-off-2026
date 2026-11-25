class_name ResearchLab
extends Node
## Where the player researches upgrades: it keeps the [Research] for the bus and every research
## tree, opens the research screen ([ResearchScreen]) on all of them, and researches an upgrade the
## player holds there when the player can pay for it, taking its credits and research points off
## first. Which planets open the screen is the dock panel's to say: those with a lab ([member
## Planet.has_lab]). It adds the debug panel's Resources card, whose buttons give credits and
## research points for testing, and Research, which opens the screen from anywhere. So the
## first visit always has something to research, the screen opening with nothing researched and
## nothing the player can pay for quietly raises their credits to the cheapest upgrade's. It
## remembers which upgrades the player could pay for when they last closed the screen, so the dock
## panel nudges only when that has changed ([method has_unseen_upgrade]).

## The credits the debug panel's Add credits button gives.
const DEBUG_CREDITS := 1000
## The research points the debug panel's Add research button gives.
const DEBUG_RESEARCH := 100
## The debug panel's group for the research buttons, the mechanic's ([MechanicCall]) too.
const DEBUG_GROUP := "Research"
## The debug panel's group for the buttons that give credits and research points.
const DEBUG_RESOURCES_GROUP := "Resources"
## The debug panel's button that opens the screen from anywhere.
const DEBUG_OPEN_TEXT := "Research"

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

var _research: Research
# The upgrades the player could pay for when they last closed the screen.
var _seen: Array[Upgrade] = []


func _ready() -> void:
	_research = Research.new(bus.get_stats())
	research_screen.research = _research
	research_screen.upgrade_held.connect(research)
	research_screen.closed.connect(resource_bar.show)
	research_screen.closed.connect(_remember_seen)
	DebugPanel.add_button(DEBUG_OPEN_TEXT, open_screen, self, DEBUG_GROUP)
	var credits_text := "Add %d credits" % DEBUG_CREDITS
	DebugPanel.add_button(credits_text, _debug_add_credits, self, DEBUG_RESOURCES_GROUP)
	var research_text := "Add %d research" % DEBUG_RESEARCH
	DebugPanel.add_button(research_text, _debug_add_research, self, DEBUG_RESOURCES_GROUP)


## Which upgrades are researched, and whether research and which stages are open.
func get_research() -> Research:
	return _research


## The credits the player has to pay with.
func get_credits() -> int:
	return ledger.credits


## The research points the player has to pay with.
func get_points() -> int:
	return ledger.get_research()


## Whether the player can pay for an upgrade they couldn't pay for when they last closed
## the screen. The same ones still waiting don't count again, nor fewer of them.
func has_unseen_upgrade() -> bool:
	for upgrade: Upgrade in _get_available():
		if upgrade not in _seen:
			return true
	return false


# Every upgrade, in any tree, the player could research now and can pay for.
func _get_available() -> Array[Upgrade]:
	var available: Array[Upgrade] = []
	if not ledger:
		return available
	var credits := get_credits()
	var points := get_points()
	for tree: ResearchTree in trees:
		for upgrade: Upgrade in tree.upgrades:
			if _research.get_state(upgrade, credits, points) == Research.State.AVAILABLE:
				available.append(upgrade)
	return available


func _remember_seen() -> void:
	_seen = _get_available()


## Opens the research screen on every tree, pausing the game.
func open_screen() -> void:
	_afford_first()
	research_screen.open(trees)
	# The screen's header has the bar of its own; the HUD's would peek out above the sheet.
	resource_bar.hide()


# With nothing researched yet and nothing the player can pay for, their credits become the
# cheapest upgrade's among those they have the research points for, with no gain shown.
func _afford_first() -> void:
	if not ledger or _research.has_researched_any() or not _get_available().is_empty():
		return
	var cheapest: Upgrade = null
	for tree: ResearchTree in trees:
		for upgrade: Upgrade in tree.upgrades:
			var state := _research.get_state(upgrade, upgrade.credits, get_points())
			if state != Research.State.AVAILABLE:
				continue
			if not cheapest or upgrade.credits < cheapest.credits:
				cheapest = upgrade
	if cheapest:
		ledger.credits = cheapest.credits


## Shows the credits and ratings earned since the last commit in both resource bars, the
## HUD's and the screen's, so the two always show the same totals: each holds earnings
## back until its own commit.
func commit() -> void:
	resource_bar.commit()
	research_screen.commit()


## Researches [param upgrade] when it is available, paying its cost. Otherwise it does
## nothing.
func research(upgrade: Upgrade) -> void:
	if _research.get_state(upgrade, get_credits(), get_points()) != Research.State.AVAILABLE:
		return
	if upgrade.credits > 0:
		ledger.spend(upgrade.credits)
	if upgrade.points > 0:
		ledger.spend_research(upgrade.points)
	_research.research(upgrade)


# The debug panel's Add credits, shown as a gain that counts into the total, like a fare.
func _debug_add_credits() -> void:
	ledger.earn(DEBUG_CREDITS)
	commit()


# The debug panel's Add research, shown under the research points' count.
func _debug_add_research() -> void:
	ledger.earn_research(DEBUG_RESEARCH)
