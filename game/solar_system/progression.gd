class_name Progression
extends Node
## The player's way through the star systems ([StarMap]). Each system gives the goals a
## promotion takes there, and once they have all held at once for [constant CALL_DELAY]
## seconds of play, The Boss calls with the promotion ([GoalsMetCall]). Answered, the goals
## stay on show as they stand, the next system opens, and the [SystemJump] takes the bus
## across at once, from wherever it is, after any stop under way; whoever is still on board
## stays behind, paying and rating nothing. There the lines start at the new system's
## planets, its goals replace the old ones, and the mechanic calls with the next research
## stage ([MechanicCall]). The promotion in the last system joins every system instead:
## lines start at every planet, passengers go anywhere, and the last goals come.
## The debug panel's Star systems card has The Boss call at once, or completes the system:
## promoted, the bus jumps to the next one at once, as answering the call does.

## The bus has started a jump: the parent closes whatever is open.
signal jump_started

const JOINED := "Promoted! Every star system is open, and passengers now travel between them."
const ARRIVED := "Welcome to {system}. Deliver passengers to get promotion."
## Seconds of play every goal must hold before The Boss calls with the promotion. A goal
## dropping back starts it over.
const CALL_DELAY := 5.0
## Seconds the notices that a system or every system is open show.
const NOTICE_SECONDS := 8.0
const DEBUG_CALL_TEXT := "Promotion call"
const DEBUG_COMPLETE_TEXT := "Complete system"
## The debug panel's group for the star system buttons: its own card.
const DEBUG_GROUP := "Star systems"

@export var star_map: StarMap
## The goals a promotion takes.
@export var goals: GoalTracker
@export var waiting: WaitingPassengers
@export var quest_giver: QuestGiver
@export var notices: NoticeStack
@export var cabin: Cabin
## The Boss's call with the promotion.
@export var boss_call: GoalsMetCall
@export var system_jump: SystemJump
## Saves nothing through a jump.
@export var saver: GameSaver

## The player's credits and ratings, for the quests. The parent sets it.
var ledger: Ledger
## Whether meeting every goal has The Boss call with the promotion. A balance run
## (`tools/balance.py`) turns it off, so it plays in the first system throughout.
var promotes := true

var _started := false
# Seconds of play every goal has held at once.
var _met_seconds := 0.0


func _ready() -> void:
	boss_call.answered.connect(advance)
	system_jump.crossed.connect(_on_crossed)
	system_jump.finished.connect(_on_jumped)
	DebugPanel.add_button(DEBUG_CALL_TEXT, _ring, self, DEBUG_GROUP)
	DebugPanel.add_button(DEBUG_COMPLETE_TEXT, _debug_complete_system, self, DEBUG_GROUP)


func _process(delta: float) -> void:
	var counting := (
		promotes
		and _started
		and not star_map.is_joined()
		and not boss_call.is_ringing()
		and not system_jump.is_jumping()
		and not goals.frozen
		and goals.are_all_met()
	)
	_met_seconds = _met_seconds + delta if counting else 0.0
	if _met_seconds >= CALL_DELAY and not quest_giver.is_calling():
		_ring()


## Starts the run proper, once the tutorial is over: quests, and the goals of the system the
## bus works in. A run saved after a promotion but before its jump has The Boss call again.
func start() -> void:
	_started = true
	if star_map.is_joined():
		waiting.max_total = star_map.joined_max_waiting
	_start_quests(star_map.get_active_planets())
	if star_map.get_jump_target():
		_ring()
	else:
		_add_goals()


## Promotes the player: the goals go, and the next star system opens, or every system
## joins after the last one.
func promote() -> void:
	if star_map.is_joined():
		return
	_met_seconds = 0.0
	# The goals stay on the panel, ticked, until the next system's replace them.
	goals.frozen = true
	star_map.promote()
	if star_map.is_joined():
		_join()


## Takes the promotion, as answering The Boss's call does: promoted, unless the next system
## is already open, the bus jumps there at once, wherever it is, once any stop under way is
## over. In the last system the promotion joins every system instead, and nothing jumps.
func advance() -> void:
	if star_map.is_joined() or system_jump.is_jumping():
		return
	if not star_map.get_jump_target() and _is_last():
		promote()
		return
	# Nothing saves through the promotion and the jump: quit before the jump ends, the run
	# continues from before the call was answered.
	saver.holding = true
	if not star_map.get_jump_target():
		promote()
	if cabin.is_stopping():
		await cabin.stop_finished
		if system_jump.is_jumping():
			return
	jump_started.emit()
	system_jump.start(star_map.get_jump_target())


# Passengers call with quests about [param planets], which pay by the system the bus works
# in: the last one once they are joined.
func _start_quests(planets: Array[Planet]) -> void:
	var systems := star_map.get_systems()
	var level := systems.find(star_map.get_current())
	if star_map.is_joined():
		level = systems.size() - 1
	quest_giver.start(planets, ledger, waiting, level)


func _join() -> void:
	waiting.max_total = star_map.joined_max_waiting
	waiting.add_planets(star_map.get_active_planets())
	_start_quests(star_map.get_active_planets())
	notices.push(JOINED, Notice.Kind.INFO, false, NOTICE_SECONDS)
	_add_goals()


func _add_goals() -> void:
	for goal: Goal in goals.get_goals():
		goals.remove(goal)
	goals.frozen = false
	var deliveries := star_map.joined_deliveries
	var rating := star_map.joined_rating
	if not star_map.is_joined():
		deliveries = star_map.get_current().deliveries
		rating = star_map.get_current().rating
	goals.add(DeliveryCountGoal.new(deliveries))
	goals.add(RatingGoal.new(rating))


# The camera is over the new system: it becomes the one the bus works in, and its lines
# start empty. Whoever was still on board is gone, out of sight, paying and rating nothing.
func _on_crossed(system: StarSystem) -> void:
	for passenger: Passenger in cabin.get_passengers():
		cabin.leave_behind(passenger)
	star_map.enter(system)
	waiting.set_planets(system.get_planets())
	_start_quests(system.get_planets())


func _on_jumped(system: StarSystem) -> void:
	waiting.add_starting_passengers(system.home)
	_add_goals()
	saver.holding = false
	var arrived := ARRIVED.format({"system": system.display_name})
	notices.push(arrived, Notice.Kind.INFO, false, NOTICE_SECONDS)


# The Boss calls with the promotion now, in the system the bus works in, unless the
# systems are joined. Nothing happens before the run starts, while the tutorial has the map
# zoomed in.
func _ring() -> void:
	if not _started or star_map.is_joined() or system_jump.is_jumping():
		return
	_met_seconds = 0.0
	boss_call.ring(star_map.get_jump_target() == null and _is_last())


# Whether the bus works in the last system, whose promotion joins them all.
func _is_last() -> bool:
	var systems := star_map.get_systems()
	return systems.find(star_map.get_current()) == systems.size() - 1


# Completes the system the bus works in at once, as answering The Boss's call does.
func _debug_complete_system() -> void:
	if _started:
		advance()
