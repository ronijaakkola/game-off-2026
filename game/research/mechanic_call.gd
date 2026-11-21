class_name MechanicCall
extends Node
## The mechanic's calls, which open research a part at a time ([Research]). In the first
## star system the trees open one at a time on their first stage: the first once the player
## can pay for one of the upgrades at its top, each next once the run has delivered
## [member tree_deliveries] passengers. In each system after it, the mechanic calls as the
## bus works there, and the next stage opens in every tree. Once the systems are joined,
## nobody calls: every stage is open.
## The call notice shows the mechanic as an unknown caller until the run has had a call
## from them, so on their first; its Answer opens the mechanic's transmission; left unanswered for
## [constant ANSWER_SECONDS] seconds of play while it shows, it opens by itself. Once the
## player closes it, what it brings opens. It calls only after [method start], never while
## another transmission is open or a passenger's call rings, during a stop or a jump, and
## holds the passengers' calls while its own rings. What is open is the save's, so a run
## continued before a call was answered gets it again.
## Until a tree is open there is nothing to research: the lab badges hide, as does the
## station's Research button ([member DockPanel.research_hidden]), and they come in with
## the first tree, the badges popping in.
## The debug panel's Mechanic calls rings the next call at once.

## A call opened research, where nothing was open before: the player can research now.
signal research_opened
## A call opened [param tree], or the next stage in every tree when it is null. After
## [signal research_opened], on the call that opens research.
signal research_added(tree: ResearchTree)

## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 10.0
## What the mechanic says as each tree opens, in the order they open.
const TREE_TEXTS: Array[String] = [
	(
		"Hey, rookie! I'm the company mechanic. Word is you've got some [money]credits[/money] "
		+ "saved up. Drop by any planet with a lab and I'll fit the bus with performance parts: "
		+ "speed, fuel, the drive. You bring the research points, I bring the wrench."
	),
	(
		"Me again. Your stations look sad. I've got parts for the stops now: door chimes, "
		+ "waiting lounges, timetables. Find them in the lab."
	),
	(
		"Passengers keep moaning about the seats. Comfort parts just came in: pillows, movies, "
		+ "bigger portions. They're in the lab."
	),
]
## What the mechanic says as each stage after the first opens, from the second.
const STAGE_TEXTS: Array[String] = [
	"New system, new parts. Every tree in the lab has a new row of upgrades for you.",
	"Last shipment, and the best I've got. The lab has the final upgrades in every tree.",
]
## The two answers, which mean the same.
const ANSWERS: Array[String] = ["Thanks", "On my way"]
const DEBUG_TEXT := "Mechanic calls"

## Which trees and stages are open, and the trees, in the order they open.
@export var research_lab: ResearchLab
## Which system the bus works in.
@export var star_map: StarMap
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Holds its calls while the mechanic's rings, and nobody calls over one of its.
@export var quest_giver: QuestGiver
## Nobody calls during a stop.
@export var cabin: Cabin
## Nobody calls during a jump.
@export var system_jump: SystemJump
## Show only once a tree is open, as does the dock panel's Research button.
@export var lab_badges: LabBadges
@export var dock_panel: DockPanel
## How many passengers the run has delivered when each tree after the first opens.
@export var tree_deliveries: Array[int] = [7, 14]

## The player's credits, research points and deliveries. The parent sets it.
var ledger: Ledger
## Whether the mechanic calls. A balance run turns it off, unless it is measuring the calls.
var enabled := true

var _started := false
var _notice: Notice
# Seconds of play the call notice has shown unanswered.
var _ringing_seconds := 0.0
# Whether the transmission is open.
var _talking := false
# Whether the quest giver had calls on before the mechanic's call held them.
var _quests_were_enabled := false


func _ready() -> void:
	DebugPanel.add_button(DEBUG_TEXT, _debug_ring, self)


func _process(delta: float) -> void:
	if _notice:
		# Only while the player can see it: not while the notices are hidden behind a panel.
		if _notice.is_visible_in_tree():
			_ringing_seconds += delta
		if _ringing_seconds >= ANSWER_SECONDS:
			_notice.dismiss()
			_open()
		return
	if _started and enabled and not _talking and _is_due() and _can_ring():
		ring()


## Starts calling, once the run proper starts: the lab badges and the Research button show
## only if a tree is open.
func start() -> void:
	_started = true
	var open := _research().get_open_trees() > 0
	lab_badges.visible = open
	dock_panel.research_hidden = not open


## Whether the mechanic's call rings or talks.
func is_calling() -> bool:
	return _notice != null or _talking


## The mechanic calls now, about whatever opens next. Nothing happens with a call under way
## or everything open.
func ring() -> void:
	if is_calling() or _opens_nothing():
		return
	_quests_were_enabled = quest_giver.enabled
	quest_giver.enabled = false
	_ringing_seconds = 0.0
	var known := _research().get_open_trees() > 0
	_notice = notices.announce_transmission(Transmission.from_mechanic(), known)
	_notice.action_pressed.connect(_open)


# Whether something should open now: the next stage in a system past the first, or in the
# first, the next tree.
func _is_due() -> bool:
	if _opens_nothing():
		return false
	if _opens_stage():
		return true
	if _system_index() > 0:
		return false
	var next := _research().get_open_trees()
	if next == 0:
		return _can_pay_for(_research().get_next_tree())
	var index := next - 1
	return index < tree_deliveries.size() and ledger.get_rating_count() >= tree_deliveries[index]


# Whether a call can ring now.
func _can_ring() -> bool:
	if transmission_panel.is_open() or quest_giver.is_calling() or cabin.is_stopping():
		return false
	return not system_jump.is_jumping()


# Whether the call opens the next stage, rather than the next tree.
func _opens_stage() -> bool:
	return not star_map.is_joined() and _research().get_open_stages() <= _system_index()


func _opens_nothing() -> bool:
	return not _opens_stage() and _research().get_next_tree() == null


# The mechanic's transmission opens, answered or by itself.
func _open() -> void:
	_notice = null
	_talking = true
	var stage := _opens_stage()
	var call := Transmission.from_mechanic()
	if stage:
		call.text = STAGE_TEXTS[mini(_research().get_open_stages() - 1, STAGE_TEXTS.size() - 1)]
	else:
		call.text = TREE_TEXTS[mini(_research().get_open_trees(), TREE_TEXTS.size() - 1)]
	call.decline_text = ANSWERS[0]
	call.accept_text = ANSWERS[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	_talking = false
	quest_giver.enabled = _quests_were_enabled
	var had_none := _research().get_open_trees() == 0
	var tree: ResearchTree = null
	if stage:
		_research().open_next_stage()
	else:
		tree = _research().get_next_tree()
		_research().open_next_tree()
	if had_none:
		_pop_in_badges()
		research_opened.emit()
	research_added.emit(tree)


# The Research button shows, and the lab badges, each popping in.
func _pop_in_badges() -> void:
	dock_panel.research_hidden = false
	lab_badges.show()
	for planet: Planet in star_map.get_active_planets():
		if planet.has_lab:
			lab_badges.pop_in(planet)


# Whether the player can pay for one of the upgrades at the top of [param tree].
func _can_pay_for(tree: ResearchTree) -> bool:
	if not tree or not ledger:
		return false
	for upgrade: Upgrade in tree.upgrades:
		var top := upgrade.requires.is_empty() and Research.get_stage(upgrade) == 0
		if top and upgrade.can_afford(ledger.credits, ledger.get_research()):
			return true
	return false


# Which system the bus works in, counting from 0 in the order they open.
func _system_index() -> int:
	return star_map.get_systems().find(star_map.get_current())


func _research() -> Research:
	return research_lab.get_research()


# The debug panel's Mechanic calls: the next call rings now.
func _debug_ring() -> void:
	ring()
