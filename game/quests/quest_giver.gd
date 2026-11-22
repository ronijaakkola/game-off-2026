class_name QuestGiver
extends Node
## Gives the player quests. Every so often while the bus flies, once the player has
## delivered [constant FIRST_CALL_DELIVERIES] passengers, a passenger on board calls:
## an incoming transmission notice, whose Answer opens their [Quest]'s transmission. They
## ask to fly past a planet ([FlybyQuest]) or to stop at one ([ErrandQuest]), as likely one
## as the other; a Business passenger asks for an [ExpressQuest] instead, where
## [method start] allows it. One
## call or quest at a time: nobody calls while a quest is under way, and the wait until
## the next call starts only once it has ended.
## Accepting makes the quest's change, tracks its goal in [member quests] and flags the
## passenger. A completed quest pays its reward and lifts the passenger by
## [member done_happiness] for the rest of their ride; a failed one costs the passenger
## [constant FAIL_SHOCK] if they still ride, so nothing more when a kick failed it.
## Declining costs them [constant DECLINE_SHOCK], in the transmission or with the call
## notice's decline button, and so does a call left unanswered until the bus reaches a
## planet. A call ends unanswered, at no cost, when its caller leaves the
## bus.
## A finished quest stays among [method get_quests] for [constant SHOWN_SECONDS], so its
## row shows how it ended.

## A quest was taken on, or the one under way ended.
signal changed
## [param quest] was taken on.
signal quest_added(quest: Quest)
## [param quest], finished a while ago, is no longer shown.
signal quest_removed(quest: Quest)

## Seconds into a run before the first call, and between one call or quest ending and the
## next call: a random value between the two.
const FIRST_CALL_SECONDS := 30.0
const CALL_MIN_SECONDS := 75.0
const CALL_MAX_SECONDS := 120.0
## How many passengers the player has delivered before anyone calls.
const FIRST_CALL_DELIVERIES := 13
## Until the player has delivered this many passengers, the wait from one call or quest
## ending to the next call is short, a random value between these two, so a new player
## meets a second quest soon after the first.
const EARLY_DELIVERIES := 20
const EARLY_CALL_MIN_SECONDS := 35.0
const EARLY_CALL_MAX_SECONDS := 50.0
## Seconds before trying again when nobody on board could call.
const RETRY_SECONDS := 3.0
## Seconds the bus has flown before anyone calls, so a call never lands on leaving.
const FLIGHT_SECONDS := 2.0
## Nobody calls this close to getting off, in seconds.
const ARRIVING_SECONDS := 6.0
## What declining a quest, or never answering the call, does to the caller's happiness, and
## what failing one does.
const DECLINE_SHOCK := -5.0
const FAIL_SHOCK := -15.0
## Seconds a finished quest stays among the quests.
const SHOWN_SECONDS := 8.0
## Seconds the notice of how a quest ended shows.
const NOTICE_SECONDS := 4.0
## What the quick text over the bus says when a quest ends.
const COMPLETED_TEXT := "Quest completed!"
const COMPLETED_ICON := preload("res://shared/icons/circle_check.svg")
const FAILED_TEXT := "Quest failed!"
const FAILED_ICON := preload("res://shared/icons/circle_x.svg")

## Whether anyone calls. A quest under way carries on either way.
@export var enabled := true
## What a done quest adds to the caller's happiness at once, and to the most they can reach
## for the rest of their ride ([method Passenger.admire]): enough to lift a clean ride on a
## bare bus to five stars.
@export_range(0.0, 40.0, 0.5) var done_happiness := 20.0
@export var bus: FrameshiftBus
@export var cabin: Cabin
@export var notices: NoticeStack
@export var transmission_panel: TransmissionPanel
## Tells the quests' goals what happens in the game.
@export var quests: GoalTracker
## Stamps how a quest ended over the bus.
@export var quick_text: BusQuickText

## The quest the pointer is on in the goal panel, or null. The panel sets it.
var pointed: Quest

var _planets: Array[Planet] = []
var _ledger: Ledger
# Prices and times the trips quests ask for.
var _waiting: WaitingPassengers
# Which star system the bus works in, counted from 0 in the order they open. Quests pay by
# it, and past the first, Business passengers ask for an express quest.
var _level := 0
# Made once it is in the tree: a scene stores every member of a node another node exports,
# and dice made here would differ in every save of it.
var _rng: RandomNumberGenerator
var _until_call := FIRST_CALL_SECONDS
# Whether the next call was asked for, so it comes however few have been delivered.
var _call_asked := false
# Seconds the bus has flown since it last stopped.
var _flight_seconds := 0.0
# The call ringing, and who calls.
var _call: Notice
var _caller: Passenger
# The quest on offer in the transmission panel, and the one under way.
var _offer: Quest
var _quest: Quest
# Seconds each finished quest still shows.
var _shown: Dictionary[Quest, float] = {}


func _ready() -> void:
	if not _rng:
		_rng = RandomNumberGenerator.new()
	if quests:
		quests.goal_completed.connect(_on_goal_completed)
		quests.goal_failed.connect(_on_goal_failed)


func _process(delta: float) -> void:
	for quest: Quest in _shown.keys():
		_shown[quest] -= delta
		if _shown[quest] <= 0.0:
			_shown.erase(quest)
			quests.remove(quest.goal)
			quest_removed.emit(quest)
	if not bus or not cabin or not _waiting:
		return
	var flying := bus.state == FrameshiftBus.State.FLYING and not bus.is_towing()
	_flight_seconds = _flight_seconds + delta if flying and not bus.is_stopping() else 0.0
	if _call:
		_watch_call()
		return
	if _offer:
		_watch_offer()
		return
	if _quest or not enabled:
		return
	_until_call -= delta
	if _until_call > 0.0 or not _is_time_to_call():
		return
	_caller = _pick_caller()
	if not _caller:
		_until_call = RETRY_SECONDS
		return
	_call = notices.announce_transmission(Transmission.from_passenger(_caller), true, true)
	_call.action_pressed.connect(_on_call_answered)
	_call.declined.connect(_on_call_declined)


## Tells it the run's [param planets], which quests send passengers to, the
## [param ledger] their rewards go into, and [param waiting], which prices and times the
## trips they ask for. [param level] is the star system the bus works in, counted from 0 in
## the order they open: quests pay by it, and past the first, Business passengers ask for
## an express quest.
func start(planets: Array[Planet], ledger: Ledger, waiting: WaitingPassengers, level := 0) -> void:
	_planets = planets
	_ledger = ledger
	_waiting = waiting
	_level = level


## Makes the dice repeatable.
func seed_dice(value: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = value


## The quest on offer in the transmission panel, before the player answers, or null.
func get_offer() -> Quest:
	return _offer


## Whether a passenger's call rings, before it is answered or goes.
func is_calling() -> bool:
	return _call != null


## The quest under way, or null.
func get_quest() -> Quest:
	return _quest


## The quest under way, if any, after those just finished, oldest first.
func get_quests() -> Array[Quest]:
	var shown: Array[Quest] = []
	shown.assign(_shown.keys())
	if _quest:
		shown.append(_quest)
	return shown


## Has someone call as soon as anyone can, whatever the wait since the last call and
## however few passengers have been delivered.
func call_soon() -> void:
	_until_call = 0.0
	_call_asked = true


## The quest under way, for a save game, with its passenger as their place among
## [param on_board]. Empty with none.
func to_save(on_board: Array[Passenger]) -> Dictionary:
	if not _quest or _quest.passenger not in on_board:
		return {}
	var saved := _quest.to_save()
	saved["passenger"] = on_board.find(_quest.passenger)
	return saved


## Puts back the quest [method to_save] gave, about the passenger at its place among
## [param on_board], with its planet found by name in [param planets].
func load_save(
	saved: Dictionary, on_board: Array[Passenger], planets: Dictionary[String, Planet]
) -> void:
	var index := int(saved.get("passenger", -1))
	if index < 0 or index >= on_board.size():
		return
	var quest: Quest
	match saved.get("kind", ""):
		ExpressQuest.KIND:
			quest = ExpressQuest.new()
		FlybyQuest.KIND:
			quest = FlybyQuest.new()
		ErrandQuest.KIND:
			quest = ErrandQuest.new()
	if quest and quest.restore(saved, on_board[index], planets):
		take_on(quest)


## Makes [param quest], whose goal is built, the quest under way: tracks its goal and
## flags its passenger.
func take_on(quest: Quest) -> void:
	_quest = quest
	quest.passenger.quest_line = quest.goal.get_text()
	quests.add(quest.goal)
	quest_added.emit(quest)


# Whether a call could come now: the bus has flown a moment, no transmission shows, and
# the player has delivered enough passengers.
func _is_time_to_call() -> bool:
	if _flight_seconds < FLIGHT_SECONDS or transmission_panel.is_open():
		return false
	return _call_asked or not _ledger or _ledger.get_rating_count() >= FIRST_CALL_DELIVERIES


# Someone on board who could call now: awake, not about to get off, and with a quest to
# offer as things stand.
func _pick_caller() -> Passenger:
	var able: Array[Passenger] = []
	for passenger: Passenger in cabin.get_passengers():
		if passenger.asleep or _is_arriving(passenger):
			continue
		if _plan(passenger):
			able.append(passenger)
	return able[_rng.randi_range(0, able.size() - 1)] if not able.is_empty() else null


# The quest [param passenger] would offer as things stand, or null when none suits: a
# Business passenger an express quest where those are asked, anyone else a fly past or an
# errand, whichever the dice pick first that suits.
func _plan(passenger: Passenger) -> Quest:
	var kinds: Array[Quest] = [FlybyQuest.new(), ErrandQuest.new()]
	if _rng.randf() < 0.5:
		kinds.reverse()
	if _level > 0 and passenger.type == _waiting.business:
		kinds = [ExpressQuest.new()]
	for quest: Quest in kinds:
		quest.level = _level
		if quest.plan(passenger, bus, _planets, _waiting, _rng):
			return quest
	return null


func _is_arriving(passenger: Passenger) -> bool:
	if bus.get_next_planet() != passenger.destination:
		return false
	return bus.estimate_time_to_next_planet() < ARRIVING_SECONDS


# The call rings until it is answered, its caller leaves the bus, or the bus reaches a
# planet or is towed, which the caller takes as a no.
func _watch_call() -> void:
	var riding := _caller in cabin.get_passengers()
	var in_space := bus.state in [FrameshiftBus.State.FLYING, FrameshiftBus.State.HOLDING]
	if riding and in_space and not bus.is_towing():
		return
	_call.dismiss()
	_call = null
	if riding:
		_caller.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
	_rest()


func _on_call_answered() -> void:
	if not _call:
		return
	_call = null
	_offer = _plan(_caller)
	if not _offer:
		_rest()
		return
	transmission_panel.answered.connect(_on_answered, CONNECT_ONE_SHOT)
	transmission_panel.open(_offer.get_transmission())


# Declined from the notice, before hearing the quest: a no all the same.
func _on_call_declined() -> void:
	if not _call:
		return
	_call = null
	if _caller in cabin.get_passengers():
		_caller.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
	_rest()


# The offer stands while its transmission shows. Should that close unanswered, as when
# something else takes the panel away, the offer is off, at no cost.
func _watch_offer() -> void:
	if transmission_panel.is_open():
		return
	if transmission_panel.answered.is_connected(_on_answered):
		transmission_panel.answered.disconnect(_on_answered)
	_offer = null
	_rest()


func _on_answered(accepted: bool) -> void:
	var quest := _offer
	_offer = null
	if not quest or quest.passenger not in cabin.get_passengers():
		_rest()
		return
	if not accepted:
		quest.passenger.shock(DECLINE_SHOCK, HappinessCause.Type.QUEST_DECLINED)
		_rest()
		return
	quest.accept()
	take_on(quest)
	changed.emit()


func _on_goal_completed(goal: Goal) -> void:
	if not _quest or goal != _quest.goal:
		return
	if _ledger:
		_ledger.earn(_quest.reward_credits)
		if _quest.reward_research > 0:
			_ledger.earn_research(_quest.reward_research)
	if _quest.passenger in cabin.get_passengers():
		_quest.passenger.admire(done_happiness, true)
	notices.push("Quest done: %s" % goal.get_text(), Notice.Kind.INFO, false, NOTICE_SECONDS)
	if quick_text:
		quick_text.show_text(COMPLETED_TEXT, COMPLETED_ICON, BusQuickText.Kind.GAIN)
	_finish()


func _on_goal_failed(goal: Goal) -> void:
	if not _quest or goal != _quest.goal:
		return
	if _quest.passenger in cabin.get_passengers():
		_quest.passenger.shock(FAIL_SHOCK, HappinessCause.Type.QUEST_FAILED)
	notices.push("Quest failed: %s" % goal.get_text(), Notice.Kind.WARNING, false, NOTICE_SECONDS)
	if quick_text:
		quick_text.show_text(FAILED_TEXT, FAILED_ICON, BusQuickText.Kind.LOSS)
	_finish()


func _finish() -> void:
	_quest.passenger.quest_line = ""
	_shown[_quest] = SHOWN_SECONDS
	_quest = null
	_rest()
	changed.emit()


# Nobody calls for a while.
func _rest() -> void:
	_caller = null
	_call_asked = false
	if _ledger and _ledger.get_rating_count() < EARLY_DELIVERIES:
		_until_call = _rng.randf_range(EARLY_CALL_MIN_SECONDS, EARLY_CALL_MAX_SECONDS)
	else:
		_until_call = _rng.randf_range(CALL_MIN_SECONDS, CALL_MAX_SECONDS)
