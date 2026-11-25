class_name MechanicCall
extends Node
## The mechanic's calls, which open research a part at a time ([Research]). In the first
## star system the first call opens research, every tree on its first stage, once the run
## has delivered [member research_deliveries] passengers and the bus is docked at a planet
## with a lab, where it holds the bus ([member FrameshiftBus.grounded]) from then until
## the player closes it, so the [ResearchGuide] starts at a lab. In each system after it, the
## mechanic calls once the player has delivered [member stage_deliveries] passengers there,
## wherever the bus is, and the next stage opens in every tree. Research is open there from
## the start: a player promoted before the first call has it open, on its first stage, with
## no call, as the bus works past the first system. Once the systems are joined,
## nobody calls: every stage is open.
## The call notice shows the mechanic as an unknown caller until the run has had a call
## from them, so on their first; its Answer opens the mechanic's transmission; left
## unanswered for
## [constant ANSWER_SECONDS] seconds of play while it shows, it opens by itself. Once the
## player closes it, what it brings opens. It calls only after [method start], never while
## another transmission is open or a passenger's call rings, during a stop or a jump, and
## holds the passengers' calls while its own rings. What is open is the save's, so a run
## continued before a call was answered gets it again.
## Until research is open there is nothing to research: the lab badges hide, as do the
## station's Research button ([member DockPanel.research_hidden]) and the resource bar's
## research points ([member ResourceBar.research_hidden]), and they come in as the first
## call closes, the badges popping in and the points growing into the bar.
## The debug panel's Mechanic calls rings the next call at once, and its Unlock research
## has the call that opens research ring the next time the bus is docked at a lab, however
## few passengers are delivered. Its Unlock all opens research and every stage at once,
## with no call, wherever the bus is.

## A call opened research, where nothing was open before: the player can research now.
signal research_opened
## A call opened research or the next stage in every tree. After [signal research_opened],
## on the call that opens research.
signal research_added

## Seconds of play the call notice shows, unanswered, before the transmission opens by itself.
const ANSWER_SECONDS := 10.0
## What the mechanic says as research opens, and the two answers, which mean the same.
const RESEARCH_TEXT := (
	"Hey! I'm Rusty, the company mechanic. The boss didn't tell you about upgrading your "
	+ "bus? Keep this between us, but the boss just wants to save company money. Open the "
	+ "research lab here, and let's get your bus in shape!"
)
const RESEARCH_ANSWERS: Array[String] = ["Thanks Rusty!", "Let's do it!"]
## What the mechanic says as each stage after the first opens, from the second.
const STAGE_TEXTS: Array[String] = [
	(
		"Good news, kid! A new shipment of parts just came in. Find a research lab, and it "
		+ "will have a lot of new toys for you!"
	),
	"Last shipment, and the best I've got. The lab has the final upgrades in every tree.",
]
## The two answers to a call that opens a stage, which mean the same.
const ANSWERS: Array[String] = ["Thanks, Rusty!", "Will do!"]
const DEBUG_TEXT := "Mechanic calls"
const DEBUG_UNLOCK_TEXT := "Unlock research"
const DEBUG_UNLOCK_ALL_TEXT := "Unlock all"

## Whether research and which stages are open.
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
## The first call waits until it is docked at a lab, and holds it there.
@export var bus: FrameshiftBus
## Show only once research is open, as do the dock panel's Research button and the
## resource bar's research points.
@export var lab_badges: LabBadges
@export var dock_panel: DockPanel
@export var resource_bar: ResourceBar
## How many passengers the run has delivered before the first call opens research.
@export var research_deliveries := 10
## How many passengers the player has delivered in a system after the first before the
## call that opens its stage.
@export var stage_deliveries := 3
## Counts the deliveries in the system the bus works in, through its delivery goal.
@export var goals: GoalTracker

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
# Whether the debug panel asked for the call that opens research, whatever is delivered.
var _debug_due := false


func _ready() -> void:
	var group := ResearchLab.DEBUG_GROUP
	DebugPanel.add_button(DEBUG_TEXT, _debug_ring, self, group)
	DebugPanel.add_button(DEBUG_UNLOCK_TEXT, _debug_unlock, self, group)
	DebugPanel.add_button(DEBUG_UNLOCK_ALL_TEXT, _debug_unlock_all, self, group)


func _process(delta: float) -> void:
	if _notice:
		# Only while the player can see it: not while the notices are hidden behind a panel.
		if _notice.is_visible_in_tree():
			_ringing_seconds += delta
		if _ringing_seconds >= ANSWER_SECONDS:
			_notice.dismiss()
			_open()
		return
	if _started and _system_index() > 0 and not _research().is_opened():
		_open_quietly()
	if _started and enabled and not _talking and _is_due():
		# From the moment it is due, stop included, so a charge held through the stop
		# can't take the bus off before the call rings.
		bus.grounded = not _opens_stage()
		if _can_ring():
			ring()


## Starts calling, once the run proper starts: the lab badges, the Research button and the
## research points show only if research is open.
func start() -> void:
	_started = true
	var open := _research().is_opened()
	lab_badges.visible = open
	dock_panel.research_hidden = not open
	resource_bar.research_hidden = not open


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
	bus.grounded = not _opens_stage() and _is_at_lab()
	var known := _research().is_opened()
	_notice = notices.announce_transmission(Transmission.from_mechanic(), known)
	_notice.action_pressed.connect(_open)


# Whether something should open now: the next stage in a system past the first once enough
# passengers are delivered there, or in the first, research once enough passengers are
# delivered and the bus is docked at a lab.
func _is_due() -> bool:
	if _opens_nothing():
		return false
	if _opens_stage():
		return _delivered_here() >= stage_deliveries
	if _system_index() > 0:
		return false
	if not _is_at_lab():
		return false
	return _debug_due or (ledger and ledger.get_rating_count() >= research_deliveries)


# How many passengers the player has delivered in the system the bus works in: what its
# goal of delivering anyone counts, which the save keeps.
func _delivered_here() -> int:
	var delivered := 0
	for goal: Goal in goals.get_goals():
		if goal is DeliveryCountGoal and not (goal as DeliveryCountGoal).type:
			delivered = maxi(delivered, (goal as DeliveryCountGoal).delivered)
	return delivered


# Whether the bus is docked at a planet with a lab.
func _is_at_lab() -> bool:
	var planet := bus.get_docked_planet()
	return bus.is_at_planet() and planet != null and planet.has_lab


# Whether a call can ring now.
func _can_ring() -> bool:
	if transmission_panel.is_open() or quest_giver.is_calling() or cabin.is_stopping():
		return false
	return not system_jump.is_jumping()


# Whether the call opens the next stage, rather than research.
func _opens_stage() -> bool:
	return not star_map.is_joined() and _research().get_open_stages() <= _system_index()


func _opens_nothing() -> bool:
	return not _opens_stage() and _research().is_opened()


# The mechanic's transmission opens, answered or by itself.
func _open() -> void:
	_notice = null
	_talking = true
	var stage := _opens_stage()
	var call := Transmission.from_mechanic()
	var answers := ANSWERS
	if stage:
		call.text = STAGE_TEXTS[mini(_research().get_open_stages() - 1, STAGE_TEXTS.size() - 1)]
	else:
		call.text = RESEARCH_TEXT
		answers = RESEARCH_ANSWERS
	call.decline_text = answers[0]
	call.accept_text = answers[1]
	call.answers_alike = true
	transmission_panel.open(call)
	await transmission_panel.answered
	_talking = false
	quest_giver.enabled = _quests_were_enabled
	bus.grounded = false
	var had_none := not _research().is_opened()
	if stage:
		_research().open_next_stage()
	else:
		_research().open()
	if had_none:
		_bring_in_research()
		research_opened.emit()
	research_added.emit()


# Research opens on its first stage with no call, as the bus works past the first system
# with research never opened there: the player can research from the start, and the
# mechanic's call a few deliveries in still brings the next stage.
func _open_quietly() -> void:
	_research().open()
	_bring_in_research()


# The Research button and the research points show, and the lab badges, each popping in.
func _bring_in_research() -> void:
	dock_panel.research_hidden = false
	resource_bar.reveal_research()
	lab_badges.show()
	for planet: Planet in star_map.get_active_planets():
		if planet.has_lab:
			lab_badges.pop_in(planet)


# Which system the bus works in, counting from 0 in the order they open.
func _system_index() -> int:
	return star_map.get_systems().find(star_map.get_current())


func _research() -> Research:
	return research_lab.get_research()


# The debug panel's Mechanic calls: the next call rings now.
func _debug_ring() -> void:
	ring()


# The debug panel's Unlock research: the call that opens research rings the next time the
# bus is docked at a lab.
func _debug_unlock() -> void:
	_debug_due = true


# The debug panel's Unlock all: research and every stage open now, with no call.
func _debug_unlock_all() -> void:
	var had_none := not _research().is_opened()
	_research().open()
	while _research().get_open_stages() < Research.STAGES:
		_research().open_next_stage()
	if had_none:
		_bring_in_research()
		research_opened.emit()
	research_added.emit()
