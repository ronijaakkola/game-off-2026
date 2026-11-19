class_name Progression
extends Node
## The player's way through the star systems ([StarMap]). Each system gives the goals a
## promotion takes there, and once they are all met at once, and still are a moment later,
## the player is promoted: the goals go, the next research stage opens, and the next system
## opens. Then the dock panel offers to jump there, which it allows only with nobody on
## board, and the [SystemJump] takes the bus across. There the lines start at the new
## system's planets and its goals come. The promotion in the last system joins every system
## instead: lines start at every planet, passengers go anywhere, and the last goals come.
## The debug panel's Star systems card promotes at once, or completes the system: promoted,
## the bus jumps to the next one at once, from wherever it is, kicking anyone on board.

## The bus has started a jump: the parent closes whatever is open.
signal jump_started

const PROMOTED := (
	"Promoted! The {system} system is open. Drop off your passengers, then jump there"
	+ " from a station."
)
const JOINED := "Promoted! Every star system is open, and passengers now travel between them."
const ARRIVED := "Welcome to {system}. Deliver passengers to get promotion."
## Seconds every goal must stay met before the promotion, so the player sees them ticked.
const PROMOTION_DELAY := 1.5
## Seconds the notices that a system or every system is open show.
const NOTICE_SECONDS := 8.0
const DEBUG_PROMOTE_TEXT := "Promote"
const DEBUG_COMPLETE_TEXT := "Complete system"
## The debug panel's group for the star system buttons: its own card.
const DEBUG_GROUP := "Star systems"

@export var star_map: StarMap
## The goals a promotion takes.
@export var goals: GoalTracker
## Opens the next research stage on a promotion.
@export var research_lab: ResearchLab
@export var waiting: WaitingPassengers
@export var quest_giver: QuestGiver
@export var notices: NoticeStack
@export var bus: FrameshiftBus
@export var cabin: Cabin
## Offers the jump while the bus is docked.
@export var dock_panel: DockPanel
@export var system_jump: SystemJump
## Saves nothing through a jump.
@export var saver: GameSaver

## The player's credits and ratings, for the quests. The parent sets it.
var ledger: Ledger
## Whether meeting every goal promotes. A balance run (`tools/balance.py`) turns it off, so
## it plays on the first research stage throughout.
var promotes := true

var _started := false
# Seconds until every goal met promotes, or below 0 while not every goal is met.
var _until_promotion := -1.0
# Says where to jump, until the bus jumps.
var _jump_notice: Notice


func _ready() -> void:
	goals.goal_changed.connect(_on_goals_changed.unbind(1))
	goals.goal_completed.connect(_on_goals_changed.unbind(1))
	dock_panel.jump_pressed.connect(_on_jump_pressed)
	system_jump.crossed.connect(_on_crossed)
	system_jump.finished.connect(_on_jumped)
	DebugPanel.add_button(DEBUG_PROMOTE_TEXT, promote, self, DEBUG_GROUP)
	DebugPanel.add_button(DEBUG_COMPLETE_TEXT, _debug_complete_system, self, DEBUG_GROUP)


func _process(delta: float) -> void:
	_show_jump()
	if _until_promotion < 0.0:
		return
	_until_promotion -= delta
	if _until_promotion <= 0.0:
		_until_promotion = -1.0
		if goals.are_all_met():
			promote()


## Starts the run proper, once the tutorial is over: quests, and the goals of the system the
## bus works in, or where to jump when a promotion already opened the next one.
func start() -> void:
	_started = true
	if star_map.is_joined():
		waiting.max_total = star_map.joined_max_waiting
	quest_giver.start(star_map.get_active_planets(), ledger, waiting)
	if star_map.get_jump_target():
		_announce_jump()
	else:
		_add_goals()


## Promotes the player: the goals go, the next research stage opens, and the next star
## system opens, or every system joins after the last one.
func promote() -> void:
	if star_map.is_joined():
		return
	_until_promotion = -1.0
	for goal: Goal in goals.get_goals():
		goals.remove(goal)
	research_lab.get_research().open_next_stage()
	star_map.promote()
	if star_map.is_joined():
		_join()
	else:
		_announce_jump()


func _join() -> void:
	waiting.max_total = star_map.joined_max_waiting
	waiting.add_planets(star_map.get_active_planets())
	quest_giver.start(star_map.get_active_planets(), ledger, waiting)
	notices.push(JOINED, Notice.Kind.INFO, false, NOTICE_SECONDS)
	_add_goals()


func _add_goals() -> void:
	var deliveries := star_map.joined_deliveries
	var rating := star_map.joined_rating
	if not star_map.is_joined():
		deliveries = star_map.get_current().deliveries
		rating = star_map.get_current().rating
	goals.add(DeliveryCountGoal.new(deliveries))
	goals.add(RatingGoal.new(rating))


func _announce_jump() -> void:
	var target := star_map.get_jump_target()
	_jump_notice = notices.push(PROMOTED.format({"system": target.display_name}))


# Offers the jump in the dock panel while there is a system to jump to, and allows it only
# docked, with nobody on board and no stop under way.
func _show_jump() -> void:
	var target := star_map.get_jump_target()
	var jumping := system_jump.is_jumping()
	dock_panel.jump_target = target.display_name if target and not jumping else ""
	dock_panel.can_jump = _can_jump()


func _can_jump() -> bool:
	return (
		star_map.get_jump_target() != null
		and not system_jump.is_jumping()
		and bus.state == FrameshiftBus.State.DOCKED
		and cabin.get_passengers().is_empty()
		and not cabin.is_stopping()
	)


func _on_goals_changed() -> void:
	if promotes and _started and goals.are_all_met() and _until_promotion < 0.0:
		_until_promotion = PROMOTION_DELAY


func _on_jump_pressed() -> void:
	if _can_jump():
		_jump()


func _jump() -> void:
	if _jump_notice:
		_jump_notice.dismiss()
		_jump_notice = null
	saver.holding = true
	jump_started.emit()
	system_jump.start(star_map.get_jump_target())


# The camera is over the new system: it becomes the one the bus works in, and its lines
# start empty.
func _on_crossed(system: StarSystem) -> void:
	star_map.enter(system)
	waiting.set_planets(system.get_planets())
	quest_giver.start(system.get_planets(), ledger, waiting)


func _on_jumped(system: StarSystem) -> void:
	waiting.add_starting_passengers(system.home)
	_add_goals()
	saver.holding = false
	var arrived := ARRIVED.format({"system": system.display_name})
	notices.push(arrived, Notice.Kind.INFO, false, NOTICE_SECONDS)


# Completes the system the bus works in: promoted if it isn't yet, the bus jumps to the
# next system at once, wherever it is, after any stop under way, kicking anyone on board.
# In the last system the promotion joins every system instead, and nothing jumps. Nothing
# happens before the run starts, while the tutorial has the map zoomed in.
func _debug_complete_system() -> void:
	if not _started:
		return
	if not star_map.get_jump_target():
		promote()
	var target := star_map.get_jump_target()
	if not target or system_jump.is_jumping():
		return
	if cabin.is_stopping():
		await cabin.stop_finished
		if system_jump.is_jumping():
			return
	for passenger: Passenger in cabin.get_passengers().duplicate():
		cabin.kick(passenger)
	_jump()
